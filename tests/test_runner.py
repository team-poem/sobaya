"""End-to-end harness tests: real Git/Node, deterministic local workers."""
import json
import os
import signal
import time
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "tdd-set/lib/runner.py"


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sobaya-runner-")
        self.base = Path(self.tmp.name)
        self.app = self.base / "app with spaces"
        self.app.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.hooksPath", "/dev/null")
        (self.app / "spec.md").write_text("# Goal\nAdd positive integers.\n")
        (self.app / "AGENTS.md").write_text("# Fixture\n- Test: `node --test suite.test.js`\n")
        (self.app / "impl.js").write_text("exports.add = (a, b) => 0;\n")
        header = "// file: suite.test.js\nconst test = require('node:test');\nconst assert = require('node:assert/strict');\nconst { add } = require('./impl.js');"
        self.code = "test('addAdds', () => assert.equal(add(1, 2), 3));"
        (self.app / "failed-test.md").write_text("# Plan\n\n## Add\n```js\n" + header + "\n```\n\n- [ ] addAdds — sums inputs\n```js\n" + self.code + "\n```\n")
        self.commit()
        self.baseline = self.git("rev-parse", "HEAD")
        self.worker = self.base / "worker.py"
        self.worker.write_text("""import json, os
from pathlib import Path
app = Path(os.environ['SOBAYA_APP'])
mode = os.environ.get('FIXTURE_MODE', 'fix')
assert 'addAdds' in (app/'suite.test.js').read_text()
if mode == 'fix' and os.environ['SOBAYA_ROLE'] == 'implement':
    (app/'impl.js').write_text('exports.add = (a, b) => a+b;\\n')
elif mode == 'review_index':
    import subprocess
    if os.environ['SOBAYA_ROLE'] == 'review':
        subprocess.run(['git','update-index','--chmod=+x','impl.js'],cwd=app,check=True)
    else:
        (app/'impl.js').write_text('exports.add = (a, b) => a+b;\\n')
elif mode == 'timeout_state':
    import time
    p=app/'.git/sobaya/state.json'
    state=json.loads(p.read_text()); state['calls']=0; p.write_text(json.dumps(state))
    time.sleep(10)
elif mode == 'tamper':
    (app/'suite.test.js').write_text((app/'suite.test.js').read_text().replace(', 3)', ', 0)'))
elif mode == 'handoff':
    print(json.dumps({'status':'handoff','summary':'Needs another approach','reason':'The failing assertion is understood but implementation remains unresolved.'}))
    raise SystemExit(0)
elif mode == 'defect':
    print(json.dumps({'status':'defect','summary':'Requirement conflict','reason':'Need human-reviewed additional test.'}))
    raise SystemExit(0)
print(json.dumps({'status':'done','summary':'Implemented the approved entry','reason':''}))
""")
        self.policy = self.base / "policy.json"
        self.policy.write_text(json.dumps({"version": 1, "mode": "selected", "default_worker": "fixture", "max_calls": 4, "timeout_seconds": 15, "workers": {"fixture": {"adapter": "command", "command": [sys.executable, str(self.worker)], "model": "fixture", "guidance": "guided"}}, "escalation": []}))

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.app), *args], text=True).strip()

    def commit(self):
        self.git("add", "-A")
        self.git("commit", "-qm", "fixture")

    def run_cli(self, command, *args, mode="fix"):
        env = dict(os.environ, FIXTURE_MODE=mode, PYTHONDONTWRITEBYTECODE="1")
        return subprocess.run([sys.executable, str(RUNNER), command, str(self.app), *args], env=env, text=True, capture_output=True, timeout=40)

    def approve(self):
        r = self.run_cli("approve")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_fresh_run_requires_explicit_approval(self):
        r = self.run_cli("step", "--policy", str(self.policy))
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("approv", r.stderr.lower())
        self.assertEqual(self.git("rev-parse", "HEAD"), self.baseline)

    def test_red_green_checkpoint_and_baseline_survive_replay(self):
        self.approve()
        r = self.run_cli("loop", "--policy", str(self.policy))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("RED", r.stdout)
        self.assertIn("PASS", r.stdout)
        self.assertEqual(self.git("status", "--porcelain"), "")
        state = json.loads((self.app / ".git/sobaya/state.json").read_text())
        self.assertEqual(state["baseline"], self.baseline)
        self.assertEqual(state["calls"], 2)  # implementation plus independent review
        self.assertEqual(state["status"], "complete")
        head = self.git("rev-parse", "HEAD")
        r = self.run_cli("loop", "--policy", str(self.policy))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.git("rev-parse", "HEAD"), head)
        self.assertEqual(json.loads((self.app / ".git/sobaya/state.json").read_text())["baseline"], self.baseline)

    def test_staged_and_untracked_work_refused_without_stash(self):
        self.approve()
        p = self.app / "user.txt"
        p.write_text("user work")
        for staged in (False, True):
            if staged:
                self.git("add", "user.txt")
            r = self.run_cli("step", "--policy", str(self.policy))
            self.assertNotEqual(r.returncode, 0)
            self.assertTrue(p.exists())
            self.assertEqual(self.git("stash", "list"), "")

    def test_worker_test_mutation_is_rejected_and_preserved(self):
        self.approve()
        r = self.run_cli("step", "--policy", str(self.policy), mode="tamper")
        self.assertNotEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("protect", r.stderr.lower())
        self.assertEqual(self.git("rev-parse", "HEAD"), self.baseline)
        self.assertIn("[ ] addAdds", (self.app / "failed-test.md").read_text())
        self.assertEqual(self.git("stash", "list"), "")

    def test_handoff_is_saved_and_explicit_resume_completes_same_item(self):
        self.approve()
        r = self.run_cli("step", "--policy", str(self.policy), mode="handoff")
        self.assertNotEqual(r.returncode, 0)
        state = json.loads((self.app / ".git/sobaya/state.json").read_text())
        self.assertEqual(state["active"]["entry"], "addAdds")
        self.assertTrue((self.app / ".git/sobaya/handoff.json").exists())
        r = self.run_cli("step", "--policy", str(self.policy))
        self.assertNotEqual(r.returncode, 0)
        r = self.run_cli("step", "--resume", "--policy", str(self.policy))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(json.loads((self.app / ".git/sobaya/state.json").read_text())["calls"], 2)

    def test_call_budget_is_not_reset_by_resume(self):
        data = json.loads(self.policy.read_text())
        data["max_calls"] = 1
        self.policy.write_text(json.dumps(data))
        self.approve()
        self.run_cli("step", "--policy", str(self.policy), mode="handoff")
        r = self.run_cli("step", "--resume", "--policy", str(self.policy))
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("budget", r.stderr.lower())

    def test_changed_plan_cannot_reapprove_implicitly(self):
        self.approve()
        p = self.app / "failed-test.md"
        p.write_text(p.read_text().replace(", 3)", ", 0)"))
        self.commit()
        r = self.run_cli("approve")
        self.assertNotEqual(r.returncode, 0)
        r = self.run_cli("approve", "--replace")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_failed_commit_can_resume_without_another_worker_call(self):
        self.approve()
        hooks = self.app / ".git/hooks"
        hooks.mkdir(exist_ok=True)
        hook = hooks / "pre-commit"
        hook.write_text("#!/bin/sh\nexit 1\n")
        hook.chmod(0o755)
        self.git("config", "core.hooksPath", str(hooks))
        r = self.run_cli("step", "--policy", str(self.policy))
        self.assertNotEqual(r.returncode, 0)
        state = json.loads((self.app / ".git/sobaya/state.json").read_text())
        self.assertEqual(state["active"]["phase"], "committing")
        hook.write_text("#!/bin/sh\nexit 0\n")
        r = self.run_cli("step", "--resume", "--policy", str(self.policy))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(json.loads((self.app / ".git/sobaya/state.json").read_text())["calls"], 1)

    def test_next_is_read_only_and_checking_is_runner_owned(self):
        r = self.run_cli("next")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(self.code, r.stdout)
        r = self.run_cli("next", "check")
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_timeout_cannot_erase_budget(self):
        data = json.loads(self.policy.read_text())
        data["timeout_seconds"] = 1
        self.policy.write_text(json.dumps(data))
        self.approve()
        r = self.run_cli("step", "--policy", str(self.policy), mode="timeout_state")
        self.assertNotEqual(r.returncode, 0)
        state = json.loads((self.app / ".git/sobaya/state.json").read_text())
        self.assertEqual(state["calls"], 1)
        self.assertEqual(state["baseline"], self.baseline)

    def test_review_index_mutation_cannot_complete(self):
        self.approve()
        r = self.run_cli("loop", "--policy", str(self.policy), mode="review_index")
        self.assertNotEqual(r.returncode, 0, r.stdout + r.stderr)
        state = json.loads((self.app / ".git/sobaya/state.json").read_text())
        self.assertNotEqual(state["status"], "complete")
        self.assertIsNone(state["review"])

    def test_header_checkbox_and_trailing_spaces_are_verbatim(self):
        p = self.app / "failed-test.md"
        text = p.read_text().replace("const test =", "const example = `\\n- [ ] addAdds\\n`;\nconst test =")
        text = text.replace(self.code + "\n", self.code + "  \n\n")
        p.write_text(text)
        self.commit()
        self.approve()
        r = self.run_cli("step", "--policy", str(self.policy))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(self.code + "  \n\n", (self.app / "suite.test.js").read_text())
        self.assertIn("- [ ] addAdds", (self.app / "suite.test.js").read_text())

    def test_explicit_arbitrary_test_filename(self):
        p = self.app / "failed-test.md"
        p.write_text(p.read_text().replace("suite.test.js", "checks.js"))
        p = self.app / "AGENTS.md"
        p.write_text(p.read_text().replace("suite.test.js", "checks.js"))
        self.worker.write_text(self.worker.read_text().replace("suite.test.js", "checks.js"))
        self.commit()
        self.approve()
        r = self.run_cli("step", "--policy", str(self.policy))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_escalation_requires_explicit_policy_and_diagnosis(self):
        second = self.base / "second.py"
        second.write_text("from pathlib import Path\nimport os,json\nPath(os.environ['SOBAYA_APP'],'impl.js').write_text('exports.add=(a,b)=>a+b;\\n')\nprint(json.dumps({'status':'done','summary':'fixed','reason':''}))\n")
        data = json.loads(self.policy.read_text())
        data.update(mode="economy", escalation=["second"])
        data["workers"]["second"] = {"adapter": "command", "command": [sys.executable, str(second)], "model": "explicit-second"}
        self.policy.write_text(json.dumps(data))
        self.approve()
        r = self.run_cli("step", "--policy", str(self.policy), mode="handoff")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        state = json.loads((self.app / ".git/sobaya/state.json").read_text())
        self.assertEqual(state["calls"], 2)
        self.assertEqual(state["baseline"], self.baseline)

    def test_worktree_and_lock(self):
        self.approve()
        import fcntl
        with (self.app / ".git/sobaya/lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            r = self.run_cli("step", "--policy", str(self.policy))
            self.assertNotEqual(r.returncode, 0)
            self.assertIn("writer", r.stderr)
        worktree = self.base / "linked"
        self.git("worktree", "add", "-qb", "linked", str(worktree))
        self.app = worktree
        self.approve()
        r = self.run_cli("step", "--policy", str(self.policy))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


    def test_cancel_stops_worker_before_unlock_and_preserves_resume(self):
        self.worker.write_text("""import os,time,json
from pathlib import Path
app=Path(os.environ['SOBAYA_APP'])
(app/'.git/worker-started').write_text(str(os.getpid()))
time.sleep(1)
(app/'escaped.txt').write_text('late write')
print(json.dumps({'status':'done','summary':'late','reason':''}))
""")
        self.approve()
        process = subprocess.Popen([sys.executable, str(RUNNER), 'step', str(self.app), '--policy', str(self.policy)],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
        try:
            deadline = time.monotonic() + 10
            while not (self.app / '.git/worker-started').exists() and time.monotonic() < deadline:
                time.sleep(.02)
            self.assertTrue((self.app / '.git/worker-started').exists())
            process.send_signal(signal.SIGINT)
            output = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 130, output)
            time.sleep(1.1)
            self.assertFalse((self.app / 'escaped.txt').exists())
            state = json.loads((self.app / '.git/sobaya/state.json').read_text())
            self.assertEqual(state['calls'], 1)
            self.assertEqual(state['active']['phase'], 'implement')
            self.assertFalse((self.app / '.git/sobaya/worker.json').exists())
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()

    def test_non_object_policy_and_worker_results_fail_with_diagnostic(self):
        self.approve()
        original = self.policy.read_text()
        self.policy.write_text('[]')
        result = self.run_cli('step', '--policy', str(self.policy))
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('Traceback', result.stderr)
        self.policy.write_text(original)
        self.worker.write_text("print('[]')")
        result = self.run_cli('step', '--policy', str(self.policy))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('result must contain', result.stderr)
        self.assertNotIn('Traceback', result.stderr)

    def test_codex_adapter_contract_and_reported_usage_without_live_call(self):
        executable = self.base / 'codex'
        executable.write_text('#!' + sys.executable + """
import os, sys, json
from pathlib import Path
args=sys.argv[1:]
assert args[0]=='exec'
assert args[args.index('--model')+1]=='fixture-codex'
role=os.environ['SOBAYA_ROLE']
assert args[args.index('--sandbox')+1]==('read-only' if role=='review' else 'workspace-write')
assert 'approval_policy="never"' in args
schema=json.loads(Path(args[args.index('--output-schema')+1]).read_text())
assert schema['type']=='object'
assert sys.stdin.read()
if role=='implement':
    (Path(os.environ['SOBAYA_APP'])/'impl.js').write_text('exports.add=(a,b)=>a+b;')
Path(args[args.index('--output-last-message')+1]).write_text(json.dumps({'status':'done','summary':'verified adapter','reason':''}))
print(json.dumps({'type':'turn.completed','usage':{'input_tokens':11,'output_tokens':7}}))
""")
        executable.chmod(0o755)
        data=json.loads(self.policy.read_text())
        data['workers']['fixture']={'adapter':'codex','model':'fixture-codex'}
        self.policy.write_text(json.dumps(data))
        self.approve()
        result=subprocess.run([sys.executable,str(RUNNER),'loop',str(self.app),'--policy',str(self.policy)],
                              env=dict(os.environ,PATH=str(self.base)+os.pathsep+os.environ['PATH']),
                              text=True,capture_output=True,timeout=40)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        rows=[json.loads(line) for line in (self.app/'.git/sobaya/usage.jsonl').read_text().splitlines()]
        self.assertEqual([r['role'] for r in rows], ['implement','review'])
        self.assertEqual(rows[0]['usage']['input_tokens'],11)


    def go_fixture(self, body=None):
        (self.app/'AGENTS.md').write_text('# Go fixture\n- Test: `go test ./...`\n')
        (self.app/'go.mod').write_text('module fixture\n\ngo 1.23\n')
        (self.app/'calc.go').write_text('package fixture\n')
        code=body or 'func TestNewAdd(t *testing.T) { if NewAdd(1,2)!=3 { t.Fatal("wrong sum") } }'
        (self.app/'failed-test.md').write_text('# Plan\n## Add\n```go\n// file: calc_test.go\npackage fixture\nimport "testing"\n```\n- [ ] TestNewAdd — adds\n```go\n'+code+'\n```\n')
        self.worker.write_text("""import json, os
from pathlib import Path
app=Path(os.environ['SOBAYA_APP'])
if os.environ['SOBAYA_ROLE']=='implement':
    (app/'calc.go').write_text('package fixture\\nfunc NewAdd(a,b int) int { return a+b }\\n')
print(json.dumps({'status':'done','summary':'implemented NewAdd','reason':''}))
""")
        self.commit()

    def test_explicit_missing_go_symbol_red_finishes_with_real_execution(self):
        self.go_fixture()
        result=self.run_cli('approve','--allow-go-undefined-red')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        result=self.run_cli('loop','--policy',str(self.policy))
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('BUILD-RED TestNewAdd',result.stdout)
        state=json.loads((self.app/'.git/sobaya/state.json').read_text())
        self.assertEqual(state['receipts'][0]['red']['status'],'build-red')
        self.assertIn('TestNewAdd',state['receipts'][0]['green'])
        self.assertEqual(state['status'],'complete')

    def test_preparing_build_error_can_resume_after_implementation_stub(self):
        self.go_fixture()
        self.approve()
        result=self.run_cli('step','--policy',str(self.policy))
        self.assertNotEqual(result.returncode,0)
        self.assertIn('build/infrastructure',result.stderr)
        state=json.loads((self.app/'.git/sobaya/state.json').read_text())
        self.assertEqual(state['calls'],0)
        (self.app/'calc.go').write_text('package fixture\nfunc NewAdd(a,b int) int { return 0 }\n')
        result=self.run_cli('step','--resume','--policy',str(self.policy))
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('RED TestNewAdd',result.stdout)

    def test_compile_red_permission_does_not_allow_syntax_error(self):
        self.go_fixture('func TestNewAdd(t *testing.T) { broken syntax }')
        result=self.run_cli('approve','--allow-go-undefined-red')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        result=self.run_cli('step','--policy',str(self.policy))
        self.assertNotEqual(result.returncode,0)
        state=json.loads((self.app/'.git/sobaya/state.json').read_text())
        self.assertEqual(state['calls'],0)
        self.assertEqual(state['active']['phase'],'preparing')


    def test_compile_red_permission_does_not_allow_missing_import(self):
        self.go_fixture('func TestNewAdd(t *testing.T) { os.Exit(1) }')
        result=self.run_cli('approve','--allow-go-undefined-red')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        result=self.run_cli('step','--policy',str(self.policy))
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(json.loads((self.app/'.git/sobaya/state.json').read_text())['calls'],0)


    def test_already_green_records_truth_and_only_calls_reviewer(self):
        (self.app/'impl.js').write_text('exports.add=(a,b)=>a+b;')
        self.commit()
        self.approve()
        result=self.run_cli('loop','--policy',str(self.policy))
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('ALREADY GREEN',result.stdout)
        state=json.loads((self.app/'.git/sobaya/state.json').read_text())
        self.assertEqual(state['calls'],1)
        self.assertEqual(state['receipts'][0]['red']['status'],'green')
        self.assertEqual(state['status'],'complete')

    def test_live_orphan_blocks_new_writer_and_dead_record_is_recoverable(self):
        self.approve()
        child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)'],start_new_session=True)
        record=self.app/'.git/sobaya/worker.json'
        record.write_text(json.dumps({'pid':child.pid}))
        try:
            result=self.run_cli('step','--policy',str(self.policy))
            self.assertNotEqual(result.returncode,0)
            self.assertIn('still alive',result.stderr)
            self.assertEqual(self.git('status','--porcelain'),'')
        finally:
            child.kill();child.wait()
        result=self.run_cli('step','--policy',str(self.policy))
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)


    def test_checkpoint_hygiene_failure_blocks_commit_even_without_hooks(self):
        p=self.app/'AGENTS.md';p.write_text(p.read_text()+'- Lint: `false`\n')
        self.commit()
        self.approve()
        head=self.git('rev-parse','HEAD')
        result=self.run_cli('step','--policy',str(self.policy))
        self.assertNotEqual(result.returncode,0)
        self.assertIn('Lint',result.stderr)
        self.assertEqual(self.git('rev-parse','HEAD'),head)
        self.assertIn('[ ] addAdds',(self.app/'failed-test.md').read_text())


if __name__ == "__main__":
    unittest.main()
