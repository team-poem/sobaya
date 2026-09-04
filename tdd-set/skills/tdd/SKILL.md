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

## Phase 0 — Plan (once per feature, before the first "go")

Steps 1–5 of the process (big feature → small features → test cases → failing tests → spec)
belong to the human. You draft `failed-test.md`; the human reviews it, adds and removes cases
directly in the file, and tells you to proceed. You ask **once**. You do not verify that the
review happened — the human is trusted; the whole loop is only as good as their test cases.

`spec.md` is the human-written goal: read it, never edit it. If it is still the template,
stop and ask the human to fill it first.

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
     `- [ ] TestName — what it proves` and the block in a fenced code block.
   - `GREEN` → the behavior already exists; do not add it. Say so.
   The probe writes and deletes its own temporary file; never put the test in the suite
   yourself. Order entries simplest first.
4. Show `failed-test.md` with every probe result and ask, once:
   **"검토·추가 끝나셨으면 이대로 진행할까요?"** Then stop. If the human edits `failed-test.md`,
   probe any entry they added or changed (so it is still a verified failing test) and ask the
   same question again. Proceed only on an explicit yes.
5. Write no implementation code in Phase 0.

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
  `apps/<name>/AGENTS.md` (e.g. `go-mistakes` for Go), one step at a time, full suite after each step. Commit **structural** changes separately, message prefixed `refactor:`. Never
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
- Never modify or delete an existing test, helper, or fixture. The gate rejects any removed or
  changed line in a test file or under the test directory; a helper is frozen with the tests.
- Never check a box whose test function is not in the suite. The gate matches names.
- If tests cannot run in this environment, say so. Do not claim green without a green run.
