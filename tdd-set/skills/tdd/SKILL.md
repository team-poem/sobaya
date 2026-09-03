---
name: tdd
description: >-
  Plan phase and loop guards on top of the app AGENTS.md (the TDD + Tidy First rules).
  Use when the user asks to plan a feature test-first, says "tdd", or before the first "go".
  The Red/Green/Refactor cycle itself lives in AGENTS.md; this skill only adds what it lacks.
---

# TDD (failed-test.md driven)

The rules in `tdd-set/AGENTS.md` say `plan.md`; in this workspace that file is `failed-test.md`.

Everything runs from the sobaya root with the app named: `/sobaya-plan <name>`, `/go <name>`.
All paths below are `apps/<name>/...`; use `git -C apps/<name>`, `go -C apps/<name>`, or for Node
`cd apps/<name> && npm|npx ...` as one command. Entry names are identifiers: Go `TestX`, Node a test
whose title starts with the identifier (`it("loginRejectsEmptyEmail: ...")`) — the gate matches on it.

`tdd-set/AGENTS.md` holds the cycle rules: "go" = next unchecked test in `failed-test.md`, Red → Green →
Refactor (Tidy First), commit discipline. Follow it exactly. This skill adds only what it lacks.

## What a test looks like — four rules

Every entry in `failed-test.md`, and every test already in the app, follows these. They come
from Kent Beck (Test Desiderata, "Composable Tests", the xUnit patterns in *TDD by Example*).

1. **Isolated.** Each test builds its own fixture from scratch and leaves nothing behind. The
   suite gives the same result in any order. A test never reads what another test wrote.
2. **Shared setup only as the section header.** What several tests need (imports, constants,
   one setup call such as starting a server in a temp copy of the data) lives in the section's
   header block, and nowhere else. Tests that need a different fixture go in a different
   section, hence a different file. Whatever leaves the test body must stay readable at a
   glance: if the reader has to open a helper to know what the test asserts, it is in the
   wrong place.
3. **Evident data.** The expected value, the actual value, and how they relate appear in the
   test body itself. Never computed in a helper, never hidden behind a name.
4. **Readable and specific over short.** When these rules pull against each other, keep the
   test readable (the reader sees why it was written) and specific (when it fails, the cause is
   obvious), even if it gets longer. Say which way you leaned in the entry's one-line description.

**Existing apps: audit before adding.** If the app already has tests, check every one of them
against the four rules before Phase 0 writes a single new entry. Every violation is fixed, no
exceptions: a structural `refactor:` commit that the human reviews like any test change, made
before the loop's start commit so the gate's frozen-tests check begins after it.

## Phase 0 — Plan (once per feature, before the first "go")

Steps 1–5 of the process (big feature → small features → test cases → failing tests → spec)
belong to the human. You draft `failed-test.md`; the human reviews it, adds and removes cases
directly in the file, and tells you to proceed. You ask **once**. You do not verify that the
review happened — the human is trusted; the whole loop is only as good as their test cases.

`spec.md` is the human-written goal: read it, never edit it. If it is still the template,
stop and ask the human to fill it first.

0. If the app already has tests, run the audit above and fix what fails it. Show the human
   the list of violations and the fixes; commit them before anything else.
1. Restate the big feature in one line and split it into small features. Each small feature is
   one unit of behavior a reader can name.
2. For every small feature, enumerate test cases. **More is better.** Cover: the simplest case,
   the degenerate/empty case, boundaries, duplicates, error paths, ordering. Stop only when you
   cannot name another case.
3. **Probe each case before writing it down.**
   - Go: write the complete test function and run
     `tdd-set/bin/probe.sh apps/<name>/<package-dir> -` with it on stdin.
   - Node: per small feature, first write the section's **header block** (a `// file:` line naming
     the test file relative to the app root, the imports, the shared constants) to a temp file
     outside the app, e.g. `${TMPDIR:-/tmp}/sobaya-header.ts`. Then write each case as one
     `test(...)` block whose title starts with the entry name and run
     `tdd-set/bin/probe.sh apps/<name>/<test-dir> - ${TMPDIR:-/tmp}/sobaya-header.ts`
     with the block on stdin. The probe runs header + block as one temporary file.
   - `RED` → record it in `failed-test.md` (format in `failed-test-template.md`): the section's
     header block once at the top of the section, then per entry a checkbox line
     `- [ ] TestName — what it proves` and the block in a fenced code block. Check the entry
     against the four rules above before recording it.
   - `GREEN` → the behavior already exists; do not add it. Say so.
   The probe writes and deletes its own temporary file; never put the test in the suite
   yourself. Order entries simplest first.
4. Show `failed-test.md` with every probe result and ask, once:
   **"검토·추가 끝나셨으면 이대로 진행할까요?"** Then stop. If the human edits `failed-test.md`,
   probe any entry they added or changed (so it is still a verified failing test) and ask the
   same question again. Proceed only on an explicit yes.
5. Write no implementation code in Phase 0.
6. **Green baseline tests steer the loop.** If you install characterization tests for existing
   behavior before the loop (they probe GREEN, so they go straight into the suite, not into
   `failed-test.md`), their fixtures must already satisfy every `Must` in `spec.md` — e.g. send
   every field the new rule will require. A baseline that violates the new rule forces "go" to
   narrow the implementation until the baseline stays green, and the gate cannot tell.
   (rubi, 2026-09-03: a fixture missing one cell's sentence made the server skip cells with no key.)

## "go" — one entry per cycle

- Take the next unchecked entry and put its code block into the suite **verbatim, by appending
  only**. Do not rename, reword, or weaken it. If the test cannot compile or is wrong, stop and
  say so.
  - Go: append the function to the package's `_test.go` file (create it with the `package` line
    and `import "testing"` if absent).
  - Node: the target file is the `// file:` line of the entry's section header. If the file does
    not exist, create it from the header block exactly. Then append a blank line and the entry
    block at the end. Never edit lines already in the file; the gate rejects any changed line.
- Run the full suite. Expect the new test red. If it is green already, write no code:
  check the box, commit, and report that the entry needed no change.
- Red → minimal code → full suite green. Commit this **behavioral** change: test + code +
  the checked box, one commit.
- Then, still green, refactor with the stack skills named on the `Skills:` line of
  `apps/<name>/AGENTS.md` (e.g. `gopher` for Go), one step at a time, full suite after each step. Commit **structural** changes separately, message prefixed `refactor:`. Never
  in the behavioral commit.
- Report in one line, stop.

## Defect found during a "go"

`tdd-set/AGENTS.md`'s defect rule applies (API-level failing test first, then the smallest test that reproduces
the problem), through the plan: probe each of the two tests with `probe.sh`, **append** them
as new unchecked entries at the end of `failed-test.md` (never edit or reorder existing entries),
commit that `failed-test.md` change on its own, and stop. Inside `loop.sh` nobody can answer, so the
loop halts there; the human looks at the new entries and re-runs the loop to proceed.

## Loop guards

- Never take a "go" on entries the human has not been shown (Phase 0's question, or the
  defect halt above).
- Never modify or delete an existing test. The gate rejects any removed or changed test line.
- Never check a box whose test function is not in the suite. The gate matches names.
- If tests cannot run in this environment, say so. Do not claim green without a green run.
