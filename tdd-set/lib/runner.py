#!/usr/bin/env python3
"""Small model-neutral coordinator. Git remains the source of progress."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import fcntl
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

sys.dont_write_bytecode = True
from contract import (BuildFailure, ContractError, TestFailure, ensure_clean, gate, git,
                      git_dir, load_plan, run_hygiene, run_suite, validate_plan)

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "tdd-set/worker-result.schema.json"
DEFAULT_POLICY = ROOT / "tdd-set/policies/default.json"


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".pending-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def metadata(app):
    return git_dir(app) / "sobaya"


@contextmanager
def locked(app):
    folder = metadata(app)
    folder.mkdir(parents=True, exist_ok=True)
    with (folder / "lock").open("a+") as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ContractError("Another Sobaya operation owns this worktree; no second writer is allowed.")
        try:
            yield
        finally:
            fcntl.flock(stream, fcntl.LOCK_UN)


def read_json(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as error:
        raise ContractError(f"Cannot read {path}: {error}") from error


def state_for(app):
    path = metadata(app) / "state.json"
    if not path.exists():
        raise ContractError("No approved baseline. Review and commit spec.md / failed-test.md, then run approve.sh APP.")
    state = read_json(path)
    if not isinstance(state, dict) or state.get("version") != 1 or not isinstance(state.get("baseline"), str):
        raise ContractError("Invalid approval state; inspect it before explicitly replacing the approval.")
    git(app, "rev-parse", "--verify", state["baseline"] + "^{commit}")
    return state


def save(app, state):
    atomic_json(metadata(app) / "state.json", state)


def policy_for(path):
    policy = read_json(path)
    if not isinstance(policy, dict) or policy.get("version") != 1 or policy.get("mode") not in ("selected", "quality", "economy"):
        raise ContractError("Policy needs version 1 and mode selected, quality, or economy.")
    for key in ("max_calls", "timeout_seconds"):
        if type(policy.get(key)) is not int or policy[key] < 1:
            raise ContractError(f"Policy {key} must be a positive integer.")
    workers = policy.get("workers")
    if not isinstance(workers, dict) or not workers:
        raise ContractError("Policy workers must be a nonempty map.")
    for name, worker in workers.items():
        if not isinstance(worker, dict) or worker.get("adapter") not in ("codex", "command"):
            raise ContractError(f"Unsupported adapter for {name}.")
        if not isinstance(worker.get("model"), str) or not worker["model"].strip():
            raise ContractError(f"Worker {name} requires an explicit model label.")
        if worker.get("guidance", "concise") not in ("concise", "guided"):
            raise ContractError(f"Worker {name} guidance must be concise or guided.")
        if worker["adapter"] == "command":
            argv = worker.get("command")
            if not isinstance(argv, list) or not argv or not all(isinstance(x, str) and x for x in argv):
                raise ContractError(f"Worker {name} command must be an argv array, never a shell string.")
    allowed = [policy.get("default_worker"), policy.get("review_worker", policy.get("default_worker"))]
    escalation = policy.get("escalation", [])
    if not isinstance(escalation, list) or not all(isinstance(x, str) for x in escalation):
        raise ContractError("Policy escalation must list explicitly allowed worker names.")
    if any(not isinstance(name, str) or name not in workers for name in allowed + escalation):
        raise ContractError("Policy selects a worker missing from its allowed workers.")
    return policy


def approve(app, replace=False, allow_go_undefined_red=False):
    ensure_clean(app)
    entries = load_plan(app)
    if not entries:
        raise ContractError("Approval needs at least one valid test entry.")
    spec = (app / "spec.md").read_text()
    if not spec.strip() or re.search(r"<what must be true|<requirement 1>|<feature>|<name>", spec):
        raise ContractError("The human must fill spec.md before approval.")
    if any("..." == e.code.strip() or "<" in e.name for e in entries):
        raise ContractError("The test plan still contains template placeholders.")
    for name in ("AGENTS.md", "spec.md", "failed-test.md"):
        git(app, "cat-file", "-e", "HEAD:" + name)
    head = git(app, "rev-parse", "HEAD").strip()
    path = metadata(app) / "state.json"
    if path.exists():
        old = state_for(app)
        if not replace:
            if allow_go_undefined_red and not old.get("allow_go_undefined_red"):
                raise ContractError("Changing RED authorization requires human-reviewed approve --replace.")
            validate_plan(app, old["baseline"])
            print(f"Approval retained: {old['baseline']}")
            return
        atomic_json(metadata(app) / "approvals" / (str(uuid.uuid4()) + ".json"), old)
    state = {"version": 1, "baseline": head, "approved_at": time.time(), "calls": 0,
             "active": None, "receipts": [], "review": None, "status": "approved",
             "allow_go_undefined_red": allow_go_undefined_red}
    save(app, state)
    print(f"Approved baseline {head}. Acceptance criteria are identical for every worker.")


def paths(app):
    raw = git(app, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
    return sorted(set(raw.split("\0")) - {""})


def protected(path):
    parts = Path(path).parts
    return path in ("spec.md", "failed-test.md", "AGENTS.md") or any(
        part in ("tests", "test", "__tests__", "fixtures", "testdata") for part in parts
    ) or any(fnmatch.fnmatch(path, glob) for glob in ("*_test.go", "*_test.py", "test_*.py", "*.test.*", "*.spec.*", "*conftest.py"))


def snapshot(app, only_protected=False):
    result = {}
    targets = {e.target for e in load_plan(app) if e.target} if only_protected else set()
    for name in paths(app):
        if only_protected and not protected(name) and name not in targets:
            continue
        p = app / name
        if p.is_symlink():
            result[name] = "symlink:" + os.readlink(p)
        elif p.is_file():
            result[name] = str(p.stat().st_mode & 0o777) + ":" + hashlib.sha256(p.read_bytes()).hexdigest()
        elif p.exists():
            result[name] = "directory"
        else:
            result[name] = "missing"
    return result


def verify_active(app, state):
    active = state["active"]
    if git(app, "rev-parse", "HEAD").strip() != active["head"]:
        raise ContractError("Worker changed HEAD. Preserve and inspect its commits; the runner will not reset or accept them.")
    if snapshot(app, True) != active["protected"]:
        raise ContractError("Protected test, fixture, plan, or instruction content changed. Edits are preserved for inspection.")


def materialize(app, entry):
    target = entry.target
    header = entry.header
    if not target and entry.language in ("go", "golang"):
        agents = (app / "AGENTS.md").read_text()
        match = re.search(r"^- Test-File: `?([^`\n]+)`?", agents, re.M)
        target = match.group(1).strip() if match else "sobaya_test.go"
        if not header:
            packages = set()
            for file in app.glob("*.go"):
                match = re.search(r"^package\s+(\w+)", file.read_text(), re.M)
                if match:
                    packages.add(match.group(1))
            if len(packages) != 1:
                raise ContractError("Go plan needs an explicit // file: header with package/imports when its target is ambiguous.")
            header = f'package {packages.pop()}\n\nimport "testing"\n'
    if not target:
        raise ContractError(f"Entry {entry.name} needs a // file: section header.")
    relative = Path(target)
    if relative.is_absolute() or ".." in relative.parts or ".git" in relative.parts or target in ("spec.md", "failed-test.md", "AGENTS.md"):
        raise ContractError("Planned test target must be a protected test path inside the app.")
    target_path = app / relative
    if not target_path.resolve().is_relative_to(app.resolve()) or target_path.is_symlink():
        raise ContractError("Planned test target escapes the app or is a symlink.")
    existing = target_path.read_text() if target_path.exists() else header
    if entry.code in existing:
        return target
    target_path.parent.mkdir(parents=True, exist_ok=True)
    with target_path.open("w") as stream:
        separator = "\n" if existing.endswith("\n") else "\n\n"
        stream.write(existing + separator + entry.code)
    return target


def named(names, name):
    return any(value == name or any(value.startswith(name + suffix) for suffix in (":", " ", "/")) for value in names)


def approved_go_build_red(result, target, source):
    if result.runner != "go" or not target:
        return False
    output = []
    for line in result.output.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            output.append(line)
            continue
        if isinstance(event, dict) and isinstance(event.get("Output"), str):
            output.extend(event["Output"].splitlines())
    diagnostics = [line for line in output if re.search(r"\.go:\d+:\d+:", line)]
    if not diagnostics:
        return False
    pattern = re.compile(r"^(?:\./)?" + re.escape(target) + r":\d+:\d+: undefined: ([A-Za-z_][A-Za-z_0-9]*)$")
    if any(re.search(r"\b" + re.escape(match[1]) + r"\s*\.", source)
           for line in diagnostics if (match := pattern.fullmatch(line))):
        return False
    # No missing imports, syntax/type errors, unrelated packages, or named
    # behavioral failures may be relabeled as an approved missing symbol.
    return all(pattern.fullmatch(line) for line in diagnostics) and not any(
        marker in "\n".join(output) for marker in ("no required module", "cannot find package", "syntax error", "too many errors"))


def checked_suite(app, name, timeout, build_red_target=None):
    before = snapshot(app)
    try:
        try:
            result = run_suite(app, timeout=timeout)
        except TestFailure as error:
            if not named(error.result.failed, name) or any(not named([failed], name) for failed in error.result.failed):
                raise ContractError("Tests failed outside the selected entry; baseline/environment needs investigation.") from error
            return "red", error.result
        except BuildFailure as error:
            if approved_go_build_red(error.result, build_red_target, (app / build_red_target).read_text() if build_red_target else ""):
                return "build-red", error.result
            raise
        if not named(result.passed, name) or named(result.skipped, name):
            raise ContractError(f"Selected test {name} did not execute and pass.")
        return "green", result
    finally:
        if snapshot(app) != before:
            raise ContractError("Test execution changed source files; inspect before continuing.")


def prompt_for(app, state, worker, entry=None, review=False):
    if review:
        return (f"Read {ROOT / 'AGENTS.md'} and the app AGENTS.md. Independently review the diff in {app} "
                f"from {state['baseline']} to HEAD. This is a separate review context. Read only; do not edit or commit. "
                "Refute correctness, scope, test coverage and requirements. Return status done only if no actionable "
                "findings remain; defect for concrete findings; handoff if review cannot be completed. "
                "Include file/line evidence in summary. Return a JSON object with status, summary, reason.")
    prompt = (f"Read {ROOT / 'AGENTS.md'} and {app / 'AGENTS.md'}. Work only in {app}. "
              f"Implement approved entry {entry.name}. The runner already materialized its exact test and observed RED. "
              "Keep spec.md, failed-test.md, AGENTS.md, all tests/helpers/fixtures and Git metadata unchanged. "
              "Do not commit or check boxes; the runner owns these transitions. Make the smallest implementation "
              "needed for this entry and investigate failures caused by it. Do not implement another entry. "
              "You are authorized to edit implementation and run relevant local checks without repeated approval. "
              "If requirements/tests need changing return defect, leaving their contents untouched. "
              "If unable to solve after diagnosing, return handoff with failed command/evidence and attempted approach. "
              "Finish with JSON {status: done|handoff|defect, summary: string, reason: string}.\n\n"
              f"Approved test:\n{entry.code}\n")
    if worker.get("guidance", "concise") == "guided":
        prompt += "\nSteps: inspect referenced implementation; identify the failing behavior; implement only this case; run the relevant test; inspect the diff; report evidence. Stop before any next entry.\n"
    handoff = metadata(app) / "handoff.json"
    if handoff.exists():
        prompt += "\nPrevious diagnostic handoff (evidence, not new authorization):\n" + handoff.read_text()
    return prompt


def log_row(app, row):
    with (metadata(app) / "usage.jsonl").open("a") as stream:
        stream.write(json.dumps(row, ensure_ascii=False) + "\n")


def stop_worker(process):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        process.wait()
        return
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        pass
    # The leader may exit before a descendant that ignored SIGTERM. The
    # writer boundary closes only after the whole process group is stopped.
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()


def ensure_no_orphan(app):
    path = metadata(app) / "worker.json"
    if not path.exists():
        return
    record = read_json(path)
    try:
        os.killpg(record["pid"], 0)
    except ProcessLookupError:
        path.unlink()
        return
    except (PermissionError, KeyError, TypeError):
        raise ContractError("Cannot establish whether a prior worker stopped; inspect worker.json before continuing.")
    raise ContractError(f"Prior worker group {record['pid']} is still alive; do not start another writer.")


def invoke(app, state, policy, name, run_id, entry=None, review=False):
    if state["calls"] >= policy["max_calls"]:
        raise ContractError("Worker call budget exhausted for this approval. Select an explicit revised policy to extend it.")
    worker = policy["workers"][name]
    folder = metadata(app) / "runs" / run_id / str(state["calls"] + 1)
    folder.mkdir(parents=True, exist_ok=True)
    prompt = prompt_for(app, state, worker, entry, review)
    (folder / "prompt.txt").write_text(prompt)
    last = folder / "result.json"
    if worker["adapter"] == "codex":
        argv = ["codex", "exec", "--cd", str(app), "--model", worker["model"],
                "--sandbox", "read-only" if review else "workspace-write",
                "-c", 'approval_policy="never"', "--json", "--output-schema", str(SCHEMA),
                "--output-last-message", str(last), "-"]
    else:
        argv = worker["command"]
    env = dict(os.environ, SOBAYA_APP=str(app), SOBAYA_BASELINE=state["baseline"],
               SOBAYA_RUN_ID=run_id, SOBAYA_WORKER=name, SOBAYA_MODEL=worker["model"],
               SOBAYA_ENTRY=entry.name if entry else "", SOBAYA_ROLE="review" if review else "implement")
    state["calls"] += 1
    save(app, state)
    expected_state = (metadata(app) / "state.json").read_bytes()
    print(f"Worker {name} ({worker['model']}), {'review' if review else entry.name}, call {state['calls']}/{policy['max_calls']}", flush=True)
    started = time.monotonic()
    row = {"run_id": run_id, "baseline": state["baseline"], "worker": name, "model": worker["model"],
           "role": "review" if review else "implement", "entry": entry.name if entry else None}
    try:
        with (folder / "stdout.log").open("w+") as stdout, (folder / "stderr.log").open("w+") as stderr:
            try:
                process = subprocess.Popen(argv, cwd=app, env=env, stdin=subprocess.PIPE,
                                           stdout=stdout, stderr=stderr, text=True, start_new_session=True)
            except OSError as error:
                raise ContractError(f"Worker could not start: {error}") from error
            atomic_json(metadata(app) / "worker.json", {"pid": process.pid, "run_id": run_id, "worker": name})
            try:
                process.communicate(prompt, timeout=policy["timeout_seconds"])
                stop_worker(process)
            except subprocess.TimeoutExpired:
                stop_worker(process)
                raise ContractError(f"Worker timed out. Outputs and edits are preserved at {folder}.")
            except BaseException:
                stop_worker(process)
                raise
            finally:
                (metadata(app) / "worker.json").unlink(missing_ok=True)
            if (metadata(app) / "state.json").read_bytes() != expected_state:
                save(app, state)
                raise ContractError("Worker changed protected approval state; original state restored, source edits preserved.")
            stdout.seek(0)
            output = stdout.read()
            if process.returncode:
                raise ContractError(f"Worker exited {process.returncode}; inspect {folder / 'stderr.log'}. No blind retry.")
        if worker["adapter"] == "codex":
            result = read_json(last)
            for line in output.splitlines():
                try:
                    event = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(event, dict):
                    continue
                if event.get("type") == "turn.completed":
                    row["usage"] = event.get("usage", {})
                if event.get("type") in ("turn.failed", "error"):
                    raise ContractError(f"Codex reported an error; inspect {folder}.")
        else:
            try:
                result = json.loads(output.strip().splitlines()[-1])
            except (ValueError, IndexError) as error:
                raise ContractError(f"Worker returned invalid JSON; inspect {folder}.") from error
            row["usage"] = result.get("usage", {}) if isinstance(result, dict) else {}
        if not isinstance(result, dict) or result.get("status") not in ("done", "handoff", "defect") or not isinstance(result.get("summary"), str) or not isinstance(result.get("reason"), str):
            raise ContractError("Worker result must contain status, summary, and reason.")
        if result["status"] != "done" and not result["reason"].strip():
            raise ContractError("Handoff/defect requires diagnostic evidence, not an empty reason.")
        atomic_json(last, result)
        row["status"] = result["status"]
        return result
    finally:
        try:
            intact = (metadata(app) / "state.json").read_bytes() == expected_state
        except OSError:
            intact = False
        if not intact:
            save(app, state)
        row["duration_seconds"] = round(time.monotonic() - started, 3)
        log_row(app, row)


def handoff(app, state, result, worker):
    state["status"] = "needs_human" if result["status"] == "defect" else "handoff"
    atomic_json(metadata(app) / "handoff.json", {
        "baseline": state["baseline"], "head": git(app, "rev-parse", "HEAD").strip(),
        "entry": state.get("active", {}).get("entry") if state.get("active") else None,
        "worker": worker, "status": result["status"], "summary": result["summary"],
        "reason": result["reason"], "diff": git(app, "diff", "HEAD", "--stat")})
    save(app, state)


def commit_active(app, state):
    active = state["active"]
    if snapshot(app) != active["verified_content"]:
        raise ContractError("Verified content changed after GREEN; inspect changes before replacing approval.")
    head = git(app, "rev-parse", "HEAD").strip()
    if head == active["head"]:
        git(app, "add", "--all")
        active["tree"] = git(app, "write-tree").strip()
        save(app, state)
        git(app, "commit", "-m", f"feat: satisfy {active['entry']}")
        head = git(app, "rev-parse", "HEAD").strip()
    parents = git(app, "rev-list", "--parents", "-n", "1", head).split()
    if parents != [head, active["head"]] or git(app, "rev-parse", "HEAD^{tree}").strip() != active.get("tree"):
        raise ContractError("Committed tree or parent differs from the verified checkpoint; inspect without resetting baseline.")
    gate(app, state["baseline"], complete=False, run_tests=False)
    receipt = {**active["receipt"], "head": head, "before": active["head"]}
    state["receipts"].append(receipt)
    state["active"] = None
    state["review"] = None
    state["status"] = "checkpoint"
    save(app, state)
    print(f"Checkpoint {receipt['entry']}: {head}")


def finish_entry(app, state, entry, result, timeout):
    verify_active(app, state)
    before = snapshot(app)
    run_hygiene(app, timeout)
    if snapshot(app) != before:
        raise ContractError("Hygiene checks changed source files; inspect and resume after formatting implementation.")
    verdict, suite = checked_suite(app, entry.name, timeout)
    if verdict != "green":
        raise ContractError(f"Entry {entry.name} is still RED. Edits preserved; inspect and resume explicitly.")
    print(f"GREEN {entry.name}", flush=True)
    plan = app / "failed-test.md"
    text = plan.read_text()
    lines, count, fenced = [], 0, False
    pattern = re.compile(r"^- \[ \] " + re.escape(entry.name) + r"(?=\s|$)")
    for line in text.splitlines(keepends=True):
        if line.startswith("```"):
            fenced = not fenced
        if not fenced and count == 0 and pattern.match(line):
            line = pattern.sub("- [x] " + entry.name, line, count=1)
            count += 1
        lines.append(line)
    text = "".join(lines)
    if count != 1:
        raise ContractError("Selected checkbox is missing or changed.")
    plan.write_text(text)
    state["active"]["protected"] = snapshot(app, True)
    state["active"]["phase"] = "committing"
    state["active"]["verified_content"] = snapshot(app)
    state["active"]["receipt"] = {"entry": entry.name, "red": state["active"]["red"],
                                  "green": sorted(suite.passed), "summary": result["summary"]}
    save(app, state)
    commit_active(app, state)


def step(app, state, policy, worker_name, run_id, resume=False):
    if state.get("active"):
        if not resume:
            raise ContractError("An unfinished entry is preserved. Inspect status/handoff, then use --resume or a reviewed approve --replace.")
        if state["active"]["phase"] == "committing":
            commit_active(app, state)
            return True
        verify_active(app, state)
        entry = next((e for e in load_plan(app) if e.name == state["active"]["entry"]), None)
        if not entry or entry.checked:
            raise ContractError("Active entry changed; inspect the saved checkpoint before proceeding.")
        if state["active"]["phase"] not in ("preparing", "implement"):
            raise ContractError("Invalid active phase; inspect the saved evidence before proceeding.")
    else:
        ensure_clean(app)
        entries = validate_plan(app, state["baseline"])
        approved = {e.name for e in load_plan(app, rev=state["baseline"])}
        if any(e.name not in approved for e in entries):
            raise ContractError("Plan has unapproved appended entries; human review and approve --replace are required.")
        entry = next((e for e in entries if not e.checked), None)
        if not entry:
            return False
        if state.get("allow_go_undefined_red"):
            before = snapshot(app)
            run_suite(app, timeout=policy["timeout_seconds"])
            if snapshot(app) != before:
                raise ContractError("Baseline suite modified source files.")
            ensure_clean(app)
        state["active"] = {"entry": entry.name, "head": git(app, "rev-parse", "HEAD").strip(),
                           "phase": "preparing", "protected": snapshot(app, True), "red": None}
        save(app, state)
    if state["active"]["phase"] == "preparing":
        target = materialize(app, entry)
        state["active"]["protected"] = snapshot(app, True)
        save(app, state)
        verdict, suite = checked_suite(app, entry.name, policy["timeout_seconds"],
                                       target if state.get("allow_go_undefined_red") else None)
        state["active"]["red"] = {"status": verdict, "failed": sorted(getattr(suite, "failed", set())), "output": suite.output}
        state["active"]["phase"] = "implement"
        save(app, state)
        print(f"{verdict.upper() if verdict != 'green' else 'ALREADY GREEN'} {entry.name}", flush=True)
        if verdict == "green":
            finish_entry(app, state, entry, {"summary": "Already green; no implementation change required."}, policy["timeout_seconds"])
            return True
    choices = [worker_name]
    if policy["mode"] != "selected":
        choices += [n for n in policy.get("escalation", []) if n != worker_name]
    for name in choices:
        result = invoke(app, state, policy, name, run_id, entry)
        verify_active(app, state)
        if result["status"] == "done":
            finish_entry(app, state, entry, result, policy["timeout_seconds"])
            return True
        handoff(app, state, result, name)
        if result["status"] == "defect":
            raise ContractError("Worker found a requirement/test issue. Human review required; approved tests remain unchanged.")
    raise ContractError(f"Diagnostic handoff saved at {metadata(app) / 'handoff.json'}. Resume explicitly with an allowed worker.")


def review(app, state, policy, worker, run_id):
    ensure_clean(app)
    if state.get("active"):
        raise ContractError("Cannot review an unfinished entry.")
    gate(app, state["baseline"])
    head = git(app, "rev-parse", "HEAD").strip()
    if state.get("review") and state["review"].get("head") == head:
        print("PASS — existing independent review matches HEAD.")
        return
    before = snapshot(app)
    result = invoke(app, state, policy, worker, run_id, review=True)
    if snapshot(app) != before or git(app, "rev-parse", "HEAD").strip() != head:
        raise ContractError("Review worker changed the repository; its review is rejected and edits preserved.")
    ensure_clean(app)
    if result["status"] != "done":
        handoff(app, state, result, worker)
        state["status"] = "review_pending"
        save(app, state)
        raise ContractError("Independent review needs attention; findings preserved in handoff.json.")
    state["review"] = {"head": head, "worker": worker, "summary": result["summary"], "at": time.time()}
    state["status"] = "complete"
    save(app, state)
    print("PASS — exact commit validated and independently reviewed.")


def summary(app, run_id=None):
    path = metadata(app) / "usage.jsonl"
    rows = [json.loads(line) for line in path.read_text().splitlines() if line.strip()] if path.exists() else []
    if run_id is None and rows:
        run_id = rows[-1]["run_id"]
    rows = [r for r in rows if r["run_id"] == run_id]
    print(json.dumps({"run_id": run_id, "calls": len(rows), "duration_seconds": round(sum(r["duration_seconds"] for r in rows), 3),
                      "usage": [r.get("usage", {}) for r in rows]}, ensure_ascii=False))


def main():
    def terminate(_signum, _frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, terminate)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("approve", "step", "loop", "status", "review", "usage", "doctor", "next"))
    parser.add_argument("app", type=Path)
    parser.add_argument("limit", nargs="?", help="loop iteration limit, or usage run ID")
    parser.add_argument("--policy", type=Path, default=DEFAULT_POLICY)
    parser.add_argument("--worker")
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--allow-go-undefined-red", action="store_true", help="approval only: allow missing Go symbols in the selected approved test")
    args = parser.parse_args()
    app = args.app.resolve()
    try:
        if args.command == "next":
            if args.limit:
                raise ContractError("Only the runner may check an entry after validated execution. Use step.sh APP.")
            entry = next((e for e in load_plan(app) if not e.checked), None)
            if entry is None:
                return 1
            if entry.heading:
                print(entry.heading)
            if entry.header:
                print(f"```{entry.language}\n{entry.header.rstrip()}\n```")
            print(f"- [ ] {entry.name}\n```{entry.language}\n{entry.code.rstrip()}\n```")
            return 0
        if args.command == "doctor":
            print(f"Harness: {ROOT}\nApp: {app}\nGit metadata: {git_dir(app)}")
            policy = policy_for(args.policy)
            print(f"Policy: {policy['mode']}; default worker: {policy['default_worker']}")
            subprocess.run([sys.executable, str(ROOT / "scripts/workspace-check.py"), str(ROOT)], check=True)
            subprocess.run([sys.executable, str(ROOT / "scripts/setup.py"), str(ROOT), "--check", "--app", str(app)], check=True)
            for name, worker in policy["workers"].items():
                executable = "codex" if worker["adapter"] == "codex" else worker["command"][0]
                candidate = str(app / executable) if "/" in executable and not Path(executable).is_absolute() else executable
                if not shutil.which(candidate):
                    raise ContractError(f"Worker {name} executable unavailable: {executable}")
            ensure_clean(app)
            print("Local setup checks passed. No paid worker call was made.")
            return 0
        if args.command == "usage":
            summary(app, args.limit)
            return 0
        if args.command == "status":
            state = state_for(app)
            entries = load_plan(app)
            print(json.dumps({**state, "head": git(app, "rev-parse", "HEAD").strip(),
                              "pending": [e.name for e in entries if not e.checked],
                              "dirty": bool(git(app, "status", "--porcelain"))}, ensure_ascii=False, indent=2))
            return 0
        if args.allow_go_undefined_red and args.command != "approve":
            raise ContractError("--allow-go-undefined-red is an approval decision, valid only with approve.")
        with locked(app):
            ensure_no_orphan(app)
            if args.command == "approve":
                approve(app, args.replace, args.allow_go_undefined_red)
                return 0
            policy = policy_for(args.policy)
            worker = args.worker or policy["default_worker"]
            if worker not in policy["workers"]:
                raise ContractError("Selected worker is not allowed by this policy.")
            state = state_for(app)
            run_id = str(uuid.uuid4())
            if args.command == "review":
                review(app, state, policy, args.worker or policy.get("review_worker", worker), run_id)
                return 0
            maximum = 1 if args.command == "step" else int(args.limit or policy["max_calls"])
            if maximum < 1:
                raise ContractError("Iteration limit must be positive.")
            for iteration in range(maximum):
                if not step(app, state, policy, worker, run_id, resume=args.resume and iteration == 0):
                    break
            if args.command == "loop":
                if any(not e.checked for e in load_plan(app)):
                    raise ContractError("Iteration limit reached; verified progress preserved, plan still pending.")
                review(app, state, policy, policy.get("review_worker", worker), run_id)
            summary(app, run_id)
        return 0
    except (ContractError, OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Stopped; worker process group terminated, edits and approval preserved.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
