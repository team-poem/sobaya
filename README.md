<div align="center">

<img src="logo.svg" alt="Sobaya" width="180">

### Sobaya

Failing tests first, then the agent.

**English** · [한국어](README.ko.md) · [Guide](docs/guide.md) · [tdd-set reference](tdd-set/README.md) · [Contract](AGENTS.md)

</div>

`sobaya` is an agentic engineering workspace. The human writes the spec and every failing test. A loop turns them green one test at a time under TDD + Tidy First rules. A gate refuses anything that touched the tests. No plugins, no daemon. Just git, shell, `claude -p`, and markdown.

## Features

- Failing tests are the spec: every case is written as code and proven red before any implementation exists. Node cases share one file per small feature, so imports and constants live in a header block, not in every entry
- One test per cycle: copy it into the suite, watch it fail, write the minimum, refactor while green, commit
- Behavioral and structural changes never share a commit
- Deterministic gate: plan 100% checked, suite green, no existing test line touched, every checked entry present in the suite
- Command lines declared once in the app `AGENTS.md` (`Test`, `Format`, `Lint`, `Bench`) and enforced by the gate and a commit hook. A `Skills:` line picks the stack skills that app uses
- One harness in the root: contract, skills, commands, hooks, TDD rules. Apps carry only `AGENTS.md`, `spec.md`, `failed-test.md` and are worked on from the root, by name
- Persistent memory in `brain/`, injected at session start. Shell hooks that fail open. One writer per app

## The loop

```mermaid
flowchart LR
    S["apps/name/spec.md<br>human: goal · must · must not"] --> P["/sobaya-plan name<br>enumerate cases → probe each red → failed-test.md as code"]
    P -- yes --> G["/go name × N<br>copy test verbatim → red → green → commit<br>refactor while green → commit"]
    G --> T["/gate name<br>100% checked · suite green<br>tests untouched · names present"]
    T --> R["review<br>refuter subagent"]
    R --> F["reflect → brain/"]
    F -. next session .-> S
```

- **Spec.** The human fills `spec.md`. Agents read it, never edit it.
- **Plan.** `/sobaya-plan <name>` drafts `apps/<name>/failed-test.md`: split the feature, enumerate as many cases as possible, probe each one, keep only those that print RED. It asks once, *reviewed and added yours, proceed?*, and the human edits the file directly. Nothing verifies the review. The loop is exactly as good as the human's tests.
- **Cycle.** `/go <name>` takes the next unchecked entry, appends its test to the suite (Go: the package test file; Node: the file the section header names), and runs one Red → Green → Refactor cycle, refactoring with the skills the app's `Skills:` line names. `/sobaya-loop <name>` repeats it until the plan is done or stalls.
- **Gate.** `/gate <name>` is PASS or FAIL, nothing in between. A defect found during the loop is appended to `failed-test.md` as two probed tests and the loop halts for the human.
- **Review, reflect.** An independent subagent refutes the work. Learnings land in `brain/` for the next session.

## Installation

```sh
tdd-set/bin/install.sh apps/<name>
```

Creates the three files an app carries: `AGENTS.md` (command lines + `Skills:`), `spec.md`, `failed-test.md`. Works on a new or an existing app, and is idempotent. Everything else stays in the root. Details in the [tdd-set reference](tdd-set/README.md#install-per-app-new-or-existing).

## Usage

- Session: `cd sobaya && claude` (or Codex). Fill `apps/<name>/spec.md`, run `/sobaya-plan <name>`, answer yes, then `/go <name>` per cycle or `/sobaya-loop <name>`, then `/gate <name>`. See the [usage guide](docs/guide.md).
- Shell: `tdd-set/bin/loop.sh apps/<name> 30` and `tdd-set/bin/gate.sh apps/<name>` from the root. See the [tdd-set reference](tdd-set/README.md).
- Another stack: add `tdd-set/skills/<stack>`, name it on the app's `Skills:` line, swap the command lines. Today: `go-mistakes` (Go, the 100 Go Mistakes catalog mirrored locally) and `nodejs` (vitest or `node --test`).

## What the gate enforces

| Check | Fails when |
|---|---|
| Plan complete | any `- [ ]` remains in `failed-test.md` |
| Suite green | the `Test:` command exits non-zero |
| Tests untouched | any line in a test file, or anything under a test directory (helpers, fixtures), was removed or modified since the loop started |
| Names present | an entry was checked but no test function with that name was added |

The commit hook blocks `git commit` when `Format:` prints anything or `Lint:` fails.

## Documentation

- [Usage guide](docs/guide.md) (Korean): how a session actually flows
- [tdd-set reference](tdd-set/README.md): every file, script, and command
- [AGENTS.md](AGENTS.md): the harness contract every agent reads
- [From noodle to Sobaya](docs/from-noodle.md): where the workspace conventions come from

## Attribution

- **Kent Beck.** `tdd-set/AGENTS.md` is his BPlusTree3 `rust/docs/CLAUDE.md` verbatim (commit `e1f539e`). The plan as a checklist comes from his TCRSkill `failed-test.md`. The command lines in the app `AGENTS.md` follow his `agent.md`.
- **noodle.** Brain vault, reflect and meditate, deterministic hooks, one writer per app. [Mapping](docs/from-noodle.md)
