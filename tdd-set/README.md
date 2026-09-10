# tdd-set

Sobaya's provider-neutral development runtime. The shared contract is
[`../AGENTS.md`](../AGENTS.md); the development rules are
[`AGENTS.md`](AGENTS.md). The human owns acceptance. Workers implement;
the runtime materializes tests, validates progress, and commits checkpoints.

The canonical implementation is shell: Bash 3.2, jq, Git, and standard Unix
tools. Go/Node/Vitest execute app tests, not the harness coordinator. Changing
the harness runtime language needs explicit user approval; agreement on the
architecture does not supply that approval.

Writer locking uses `shlock` on macOS/BSD or `flock` on Linux. Version-1
approval state and usage records remain compatible, including existing call
counts, fractional timestamps, and an unfinished entry resumed explicitly.

## Commands

Paths in the table are relative to `tdd-set/`; from the Sobaya root, prefix
them with `tdd-set/`. `APP` means `apps/<name>`. First activate root Git hooks
with `bash scripts/setup.sh .`. Existing conflicting hooks are preserved;
integrate them explicitly before activation.

| Command | Purpose |
|---|---|
| `bin/install.sh APP` | Prepare an independent app repo and missing contract/templates |
| `bin/approve.sh APP` | Record human approval of committed spec, plan, and app acceptance contract |
| `bin/approve.sh APP --replace` | Explicitly replace approval after human review; preserve the prior baseline history |
| `bin/next.sh APP` | Read the next unchecked entry (draft or approved); never change a checkbox |
| `bin/step.sh APP [--policy PATH]` | Materialize and validate one entry with an implementation worker |
| `bin/loop.sh APP [max_iterations] [--policy PATH]` | Continue through checkpoints, final gate, and independent review |
| `bin/gate.sh APP` | Verify final acceptance against the recorded baseline |
| `bin/review.sh APP [--policy PATH] [--worker NAME]` | Run a separate read-only reviewer against the current revision |
| `bin/status.sh APP` | Inspect approval, progress, and recovery/review state |
| `bin/doctor.sh APP` | Check Git/hooks, workspace, policy, worker executable availability, and clean app state |
| `bin/probe.sh TARGET - [HEADER]` | Probe a draft candidate supplied on stdin |
| `bin/usage.sh summary APP [RUN_ID]` | Summarize recorded worker usage |

Approval is an explicit human decision, not a worker inference. An agent
may run `approve.sh` on the human's behalf only when those exact inputs
have already been approved. A repeat loop invocation does not reset the
baseline. `--replace` requires renewed approval of changed acceptance inputs.

## App contract and test representation

The app has its own Git repository, `AGENTS.md`, `spec.md`, and
`failed-test.md`. Shared rules and skills remain in Sobaya. Installation is
idempotent; review the generated commands before approving the app.

The app `AGENTS.md` declares `- Test:`, optional `- Format:`, `- Lint:`,
`- Bench:`, and `- Skills:`. `Test:` is the full acceptance suite, not a
filtered test. Supported runners are direct `go test`, `node --test`, locally
installed `vitest run`, and simple npm script wrappers around these commands.
Shell chains, npm pre/post lifecycle hooks, and reporter overrides are rejected.
Install dependencies explicitly; the harness does not download a test runner.
Test/format/lint checks must succeed at validated checkpoints.
Format commands succeed by exit status even if they print a success message;
the `gofmt -l` adapter additionally rejects a nonempty unformatted-file list.
Benchmarks report relevant performance evidence; they do not replace tests.

Each plan entry has an identifier, checkbox, and fenced test code. Section
headers are approved test support, including their `// file:` destination.
Node sections require an explicit destination and the imports/constants used
by their test blocks. For Go, `- Test-File:` can name a relative destination;
an explicit `// file:` header can include package/import declarations.
Keep every approved body and header verbatim. Required setup should be
reviewed before the baseline is frozen, not repaired by a worker later.

By default RED must be an executed named test failure. For a new Go API, the
human may approve `bin/approve.sh APP --allow-go-undefined-red`. This records
an explicit exception: the existing suite must pass first, and compiler
diagnostics must consist only of undefined symbols in the selected test file.
Missing import qualifiers, syntax errors, and unrelated build failures remain
errors. The receipt records `build-red`, and GREEN still requires the actual
test to execute and pass. Without this exception, prepare reviewed runnable
stubs. A preparation failure can resume after fixing implementation/environment;
protected tests and headers remain immutable.

A probe RED is evidence of failure, not evidence that an expectation is
correct. Missing dependencies, imports, and environment errors require
diagnosis. The human reviews the test's meaning. Agent-generated cases
remain drafts until approved; implementation cannot silently amend them.

## Checkpoints, review, and recovery

The runtime selects one approved entry, adds its test, and observes RED.
The implementation worker receives the current entry and needed contracts;
it edits source only, does not alter tests/plan/acceptance commands, and does
not commit. The runtime checks protected files and Git state, verifies the
full suite is GREEN, then checks the entry and commits the behavioral change.
A worker's successful exit or `done` report is never enough.

If an approved entry already passes, the runtime records `ALREADY GREEN`,
validates and commits its exact test without an implementation call. It does
not invent RED evidence; final independent review still applies.

`step.sh` completes one checkpoint. `loop.sh` continues to the final gate
and a separate read-only review of the resulting HEAD. The reviewer uses
a fresh context without the implementation conversation. It may use the
same model; independence concerns context and role, not a different label.
Review success is bound to the reviewed revision. Findings or unavailable
review leave review pending; do not report the feature complete.

Request structural refactoring as a separate task after the feature. It
must preserve behavior, remain green, and use separate structural commits.
The current implementation worker is not authorized to make refactor commits.

On failure, inspect status and diagnostics. The runtime preserves the
workspace rather than automatically stashing or resetting it. Use the
explicit `--resume` option on step/loop only after examining the preserved
implementation state and cause. A changed test needs a separate draft,
human review, committed inputs, and explicit `approve.sh APP --replace`.
A failed checkpoint commit can resume without rerunning the worker when the
verified content is unchanged. Interrupts and timeouts stop the worker process
group before releasing its lock; abrupt coordinator death leaves an orphan
record that blocks a second writer while that group is alive.
Do not edit runtime scripts while a run is active.

The logical boundary is a verified entry. Fresh sessions are the safe
current default. This architecture does not require a new session for every
future entry, but session reuse is not an implemented guarantee.

## Worker policy

Pass `--policy PATH` to select an explicit policy. The default is Astra
through Codex. Model/provider changes never change acceptance criteria.

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
implements with guided instructions, Astra reviews, and Astra implementation
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

`max_calls` is cumulative for the approved baseline, including review calls.
Repeated step/loop/resume does not reset it; leave capacity for final review.
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
{"status":"done","summary":"Implemented the approved entry.","reason":"","usage":{}}
```

`status` is `done`, `handoff`, or `defect`. Include diagnostic `reason` for
handoffs and defects. The runtime still validates filesystem and test
results independently. Policy files are executable authority: review the
command argv and allowed workers before an unattended run.

## Skills, prompts, and host integration

`skills/tdd/` handles draft planning and approval. Stack skills are loaded
only when relevant (`go-mistakes`, `nodejs`). `commands/` contains neutral
task prompt references, not provider-specific slash-command registrations.
`AGENTS.md` is canonical; there is no second provider instruction tree.

Brain indexing and workspace checks are explicit scripts:

```sh
bash scripts/setup.sh .
bash scripts/setup.sh . --check --app apps/example
bash scripts/brain-index.sh . --check
bash scripts/workspace-check.sh .
```

Host hooks may improve feedback, but acceptance is enforced by the runtime
rather than assumed from a hook registration. Verify actual host wiring
separately. `doctor.sh` verifies configured executables exist but does not
validate credentials/model access or run the acceptance suite. Harness tests use temporary repositories and fake workers;
they must not launch paid model sessions. Check the repository test runner
for the maintained suite rather than treating old test counts as a contract.
