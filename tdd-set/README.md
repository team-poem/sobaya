# tdd-set

The dev lifecycle of Sobaya. No plugins. Only `git`, shell, and what Claude Code and Codex ship with (skills, hooks, `claude -p`).

## Flow

```
Human:  write apps/<name>/spec.md (Goal, Must, Must not) → write failed-test.md (each case probed RED with probe.sh, then recorded as code, as many as possible) → commit
Loop:   bin/loop.sh apps/<name> → every iteration runs `claude -p "/go <name>"` → append the next failed-test.md entry's test verbatim to the suite (Go: the package's _test.go; Node: the file named by the section header, created from it if absent) → red → green → check → commit (behavioral) → refactor with the app's Skills → commit (structural, separate)
Gate:   bin/gate.sh apps/<name> → every entry checked · suite green · no existing test line touched · the test named by every checked entry exists in the suite
```

Everything runs from the sobaya root with the app named. A session opened inside an app inherits only the parent CLAUDE.md, not skills, commands, or hooks, so the harness stays in the root and the app carries three files.

## What is here

| File | Role |
|---|---|
| The app's `AGENTS.md` lines `- Test:` / `- Format:` / `- Lint:` / `- Bench:` / `- Skills:` | The only source of command lines. The gate runs Test (verdict) and Bench (printed only); the commit hook runs Format and Lint. `Skills:` names the stack skills this app uses for refactoring (e.g. `go-mistakes`) |
| `AGENTS.md` | Step 8. The TDD + Tidy First rules. `/go` reads this file and applies it to the named app (origin: BPlusTree3 `rust/docs/CLAUDE.md`, commit e1f539e). "go" = the next test in failed-test.md, Red → Green → Refactor, Tidy First, commit discipline |
| `spec-template.md` | Step 5. The human's goal document (Goal, Must, Must not). Phase 0 enumerates tests from it. The loop only reads it |
| `failed-test-template.md` | Steps 2 to 4. Failing tests written as **code** in the document before any implementation. Entry = `- [ ] TestName — what it proves` + code block. Go: a test function. Node: one `test(...)` block; each section opens with a header block (`// file:` line, imports, shared constants) that becomes the head of that test file |
| `skills/tdd/SKILL.md` | Steps 1 to 3 (Phase 0) plus loop guards (no test tampering, one line report). Only what AGENTS.md lacks |
| `skills/<stack>/SKILL.md` | Step 9. Refactor checklist per stack. Today `go-mistakes` (Go: the 100 Go Mistakes catalog, all bodies mirrored under `references/` so the checklist survives link rot) and `nodejs` (JS/TS). An app picks one or more on its `Skills:` line. Add another stack in the same shape |
| `hooks/commit-gate.sh` | Step 9, enforced. Before `git commit`, runs the app's Format and Lint lines and blocks on failure. Handles `git -C apps/<name> commit` and `cd apps/<name> && git commit`. No lines and a go.mod present → gofmt and go vet defaults |
| `commands/` | One slash command per stage, all taking the app name. `/sobaya-plan` = Phase 0, `/go` = one cycle (the same "go" as in AGENTS.md), `/gate` = gate only, `/sobaya-loop` = the whole plan, then the gate |
| `bin/install.sh` | Step 0. Creates the three app files (see Install). There is no separate scaffold step |
| `bin/probe.sh` | Steps 3 to 4. Drops one candidate test into the package as a temporary file, runs it, deletes it. RED (fails or does not build) → record it in failed-test.md; GREEN → the behavior already exists, drop it. Go (`go test -run`, snippet = the function) and Node (vitest or `node --test`, snippet = one `test(...)` block, header block via the third argument) |
| `bin/loop.sh` | Steps 6, 7, 10, 11. Only ever runs "go". Halts when an iteration adds entries (nobody inside the loop can be asked), stops after three iterations without a commit, prints the run's token/cost summary, then runs the gate. `SOBAYA_MODEL=<model>` routes the cycles to a cheaper model |
| `bin/usage.sh` | Token and cost log. `loop.sh` pipes every `claude -p --output-format json` result through `usage.sh record`, which appends one JSONL line (model, in/out/cache tokens, cost, turns, subagents) to `apps/<name>/.git/sobaya-loop-usage.log`. `usage.sh summary apps/<name> [run]` prints the per-iteration table and totals |
| `bin/gate.sh` | Steps 6 and 12. PASS = failed-test.md 100% checked · suite green · no existing line touched in a test file or anywhere under `tests/`, `test/`, `__tests__/` (helpers and fixtures are frozen with the tests) · every checked entry's test name found in the suite. The human's tests are the spec, so nothing else is judged |

## Install (per app, new or existing)

```sh
tdd-set/bin/install.sh apps/<name>     # from the sobaya root, idempotent
```

Creates only `AGENTS.md` (four command lines + a `Skills:` line), `spec.md`, and `failed-test.md`. Skills, commands, hooks, and the TDD rules stay in the root and are used from there.

## Run (all from the sobaya root, by app name)

```
/sobaya-plan <name>   apps/<name>/spec.md → draft failed-test.md (RED probes only) → asks once, "reviewed and added yours, proceed?", then waits
/go <name>            one entry: copy the test verbatim → red → green → commit → refactor with the Skills line → commit
/gate <name>          the gate only
/sobaya-loop <name>   every remaining entry, then the gate
```

From the shell:

```sh
tdd-set/bin/loop.sh apps/<name> 30
SOBAYA_MODEL=sonnet tdd-set/bin/loop.sh apps/<name> 30   # same loop on a cheaper model; compare with usage.sh
tdd-set/bin/usage.sh summary apps/<name>                  # last run's tokens and cost per iteration
tdd-set/bin/gate.sh apps/<name>
```

`loop.sh` runs `claude -p "/go <name>"` with only `go -C apps/<name>`, `gofmt`, `git -C apps/<name>` (add, commit, diff, status, log, show) and `probe.sh` allowed, in both relative and absolute path forms. If it stalls on a permission prompt, widen the allowlist with `CLAUDE_FLAGS`. Uncommitted leftovers are stashed, never lost.
