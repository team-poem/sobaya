# tdd-set

Optional shell helpers for the Canon TDD cycle in [AGENTS.md](AGENTS.md).
Human intent stays in `spec.md`; `failed-test.md` is an evolving scenario list.
The agent may run the cycle directly or use these helpers. No exact-test
approval, permanently frozen tests, prewritten future batch or mandatory
independent review is required.

The runtime uses Bash 3.2, jq, Git and standard Unix tools. Go/Node/local
Vitest run app tests. A different harness runtime language still needs explicit
user approval. Locks use shlock on macOS/BSD or flock on Linux; each checkout
has one writer. Do not edit runtime scripts while an invocation is active.

## Commands

Run from the workspace root; prefix paths below with `tdd-set/`.
`APP` means an independent app repository, normally `apps/<name>`.

| Command | Purpose |
|---|---|
| `bin/install.sh APP` | Install missing app templates and the real Git hook |
| `bin/next.sh APP` | Read the next unchecked scenario without mutation |
| `bin/step.sh APP [--policy PATH] [--worker NAME]` | Materialize one concrete test, observe RED, implement and verify GREEN |
| `bin/loop.sh APP [--policy PATH]` | Compatibility alias for one step; returns to the orchestrator for learning |
| `bin/gate.sh APP` | Check current full suite and hygiene, including uncommitted tidying |
| `bin/review.sh APP [--policy PATH] [--worker NAME]` | Optional read-only review of current committed work; pending scenarios are allowed |
| `bin/status.sh APP` | Inspect current attempt, pending scenarios and legacy state |
| `bin/migrate.sh APP` | Archive a legacy plan/state and convert executable batches into mutable scenarios |
| `bin/restart.sh APP` | Archive an active attempt while preserving edits and cumulative worker calls |
| `bin/doctor.sh APP` | Check local tools, hooks, policy and workspace without a paid call |
| `bin/probe.sh TARGET - [HEADER]` | Diagnose one candidate supplied on stdin |
| `bin/review-view.sh SOURCE NOTES_JSON OUTPUT.md` | Optional source-and-rationale view for a useful human review |
| `bin/usage.sh summary APP [RUN_ID]` | Read recorded worker usage, including historical runs |

`approve.sh`, `--append`, `--replace`, `--checkpoint`, old loop iteration counts
and gate baseline arguments are retired and return diagnostics. They do not
silently grant approval or execute work. Product intent still comes from the
human's request; a runnable test is not permission for an unrequested feature.

## Scenario list and the next test

A plain list is sufficient when an agent works directly in app test files:

```md
- [ ] addPositive — add two positive integers
- [ ] addZero — add zero
```

The optional runner takes exactly one concrete candidate attached to the next
unchecked scenario. Later unchecked scenarios must stay prose. Example:

````md
# Addition
## Sum
```js
// file: sum.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const {add} = require('./sum.js');
```
- [ ] addPositive — 1 + 2 is 3
```js
test('addPositive', () => assert.equal(add(1,2),3));
```
- [ ] addZero — choose this test after the first result
````

Node targets need `// file:` plus imports/setup. Go can use an explicit header
with package/imports, or `- Test-File:` in the app contract. Headers initialize
new files; if a file already exists its required imports/setup must already
be present. Prepare that support at GREEN rather than silently changing it
inside a RED-to-GREEN implementation attempt.

Only the plan may be dirty when starting `step.sh`; the behavioral commit
includes that selected test and the updated scenario. Commit or isolate other
existing work first, so the runner never sweeps unrelated edits into a commit.
There is no requirement to commit a failing candidate or ask for approval.

The runner snapshots tests/support, the plan, spec and commands only during
an active attempt. It inserts the candidate, measures an actual named failure,
then calls the implementation worker. A passing candidate is recorded as
ALREADY GREEN and needs no implementation call. A missing Go symbol in the
selected test may count as build RED after the previous suite passed; syntax,
missing import/dependency and infrastructure errors do not count.

Before advancement, the full suite and hygiene checks must pass. Worker
reports alone cannot advance the checkbox. The runner commits a small
behavioral change and returns; it does not choose another test or demand a
review. `loop.sh` intentionally returns at the same boundary.

At GREEN, refactor source and test code when useful, preserve behavior and
assertion strength, run the suite after each change, and commit structure
separately. Future scenarios and test interfaces can change without reapproval.
The runtime does not prove that a test refactor preserves semantic coverage;
the agent must inspect that judgment and involve the human for changed intent.

## Checks and recovery

App `AGENTS.md` declares `- Test:`, optional `- Format:`, `- Lint:`, `- Bench:`
and `- Skills:`. Supported suite commands are direct `go test`, `node --test`,
local `vitest run`, and simple npm script wrappers. No runner is downloaded.
Shell chains, npm lifecycle hooks and reporter overrides are rejected.
Format/lint must succeed; gofmt listing output identifies formatting failures.

`gate.sh` reports current suite evidence, not product completion. It permits
initially dirty files but rejects test/hygiene side effects that change code or
Git state while checking. Review is an optional tool, with no cached approval
needed for future work. Full-suite evidence and user feedback answer different
questions; at feature boundaries expose outcomes, learning and the next choice.

On failure preserve edits, inspect diagnostics and use `step.sh APP --resume`
for an unfinished implementation. Calls/timeouts remain bounded by policy;
no automatic destructive reset or model upgrade is allowed. A failed commit
can resume without another worker invocation when verified content is intact.

For a test mistake, use `restart.sh APP` after diagnosis. It archives the
attempt and does not erase code or tests. Correct the test within the intended
behavior, restore a coherent GREEN starting revision, then select/probe the
corrected test and measure evidence afresh. Do not use restart to invent RED
for behavior that is already implemented; acknowledge ALREADY GREEN instead.
Human consultation is for ambiguous or changed intent, not the restart command.

## Migrating existing apps

Use `migrate.sh APP` with a clean checkout and no active attempt. It works for
an unstarted legacy plan with no test file yet: conversion changes metadata
and plan text, and does not claim GREEN. Original plan and state are saved
under the worktree Git directory's `sobaya/history/<run-id>/`. Existing test
files, behavioral receipts, original origin commit, usage and cumulative
calls remain; the plan retains scenario descriptions and checkboxes while
removing executable fences. Pending tests are now revisable future choices.

An unfinished v1 attempt must first be diagnosed. `restart.sh APP` archives
its active evidence and preserves edits. Resolve/correct the work, record a
coherent starting revision, and migrate before selecting the next test. No
app repository is mass-migrated by updating Sobaya itself.

State version 2 records execution history; `baseline` names the session origin
for usage/optional review, not immutable acceptance authority. Archived v1
state retains approval/review history. New runtime decisions never consume
those historical approvals as permission. Migration and restart do not reset
worker budgets.

## Worker policy

Pass `--policy PATH` to select an explicit policy. The default is Astra
through Codex. Model/provider changes never change intended behavior.

```json
{
  "version": 1,
  "mode": "selected",
  "default_worker": "astra",
  "review_worker": "astra",
  "max_calls": 20,
  "timeout_seconds": 900,
  "workers": {
    "astra": {
      "adapter": "codex",
      "model": "gpt-6-astra",
      "guidance": "concise"
    }
  },
  "escalation": []
}
```

For a concrete lower-model path, inspect `policies/economy.example.json`: Sol
implements with guided instructions, Astra is available for optional review, and Astra implementation
is allowed only after Sol returns a diagnostic handoff. Select it with
`--policy tdd-set/policies/economy.example.json` from the workspace root.
Use `mode: selected` with your chosen default when automatic escalation is
unwanted. `quality` and `economy` are explicit policy labels, not hidden model
ranking or automatic task classification.

Workers have exact model identifiers and `concise` or `guided` guidance.
Use `guided` when a worker benefits from more explicit procedural context;
keep scope and evidence requirements identical. `selected` uses the chosen
worker and ignores escalation. `quality` and `economy` may use only the
explicitly configured workers and escalation chain. A fallback requires a
structured diagnostic handoff and an acceptable workspace state; failure
alone never authorizes an automatic upgrade. `review_worker` optionally
selects the reviewer; otherwise the selected worker is used in a fresh call.

`max_calls` is cumulative for the execution session, including optional review calls.
Repeated step/loop/resume, restart and migration do not reset it.
`timeout_seconds` bounds a worker invocation. These are execution limits,
not a currency budget. Usage records contain reported token/cost information;
missing provider usage is unknown, not zero. No estimated dollar spend is
substituted for unavailable provider data.

An alternate provider uses an explicit command adapter:

```json
{
  "adapter": "command",
  "command": ["/absolute/path/to/worker-adapter", "--your-option"],
  "model": "your-exact-model-label",
  "guidance": "guided"
}
```

Put this object under a chosen key in `workers` and select that key. The
runtime supplies the prompt on stdin; the adapter must return the result as
a **single JSON object on the final stdout line** (diagnostic lines may precede it):

```json
{"status":"done","summary":"Implemented the selected test.","reason":"","usage":{}}
```

`status` is `done`, `handoff`, or `defect`. Include diagnostic `reason` for
handoffs and defects. The runtime still validates filesystem and test
results independently. Policy files are executable authority: review the
command argv and allowed workers before an unattended run.

## Skills and local validation

The TDD skill supports scenario selection and the learning cycle. Stack skills
support relevant optional GREEN tidying. Commands are provider-neutral prompt
references; adapters do not redefine the cycle. Use `bash tests/run.sh` for
local deterministic fixtures; it makes no paid model calls. Historical
approval-contract tests live in `tests/archive/approval-v1/` and are not active
acceptance. Passing harness tests does not prove an arbitrary feature's user
outcome or the quality of a live model's judgment.
