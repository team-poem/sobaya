---
name: tdd
description: >-
  Plan phase and loop guards on top of CLAUDE.md (Kent Beck's TDD + Tidy First rules, verbatim).
  Use when the user asks to plan a feature test-first, says "tdd", or before the first "go".
  The Red/Green/Refactor cycle itself lives in CLAUDE.md; this skill only adds what it lacks.
---

# TDD (plan.md driven)

`CLAUDE.md` holds the cycle rules: "go" = next unchecked test in `plan.md`, Red → Green →
Refactor (Tidy First), commit discipline. Follow it exactly. This skill adds only what it lacks.

## Phase 0 — Plan (once per feature, before the first "go")

`spec.md` is the human-written goal: read it, never edit it.

1. Restate the big feature in one line.
2. Split it into small features. Each small feature is one unit of behavior a reader can name.
3. For every small feature, enumerate test cases. **More is better.** Cover: the simplest case,
   the degenerate/empty case, boundaries, duplicates, error paths, ordering. Stop only when you
   cannot name another case.
4. **Probe each case, one at a time, before writing it down.** Write the complete test
   function, run `../../tdd-set/bin/probe.sh <package-dir> -` with it on stdin (path from a
   Sobaya app root; adjust if tdd-set lives elsewhere), and read the result:
   - `RED` → append the entry to `plan.md` (format in `plan-template.md`): a checkbox line
     `- [ ] TestName — what it proves`, then the test function in a fenced code block.
   - `GREEN` → the behavior already exists; do not add it. Say so in the report.
   The probe writes and deletes its own temporary file; never put the test in the suite
   yourself. Every entry in `plan.md` is therefore a verified failing test at plan time.
   Every line of `spec.md` must be covered by at least one entry. Order: simplest first.
5. Show the list (with each probe result) and wait for approval. Do not write implementation
   code in Phase 0.

## "go" — one entry per cycle

- Take the next unchecked entry. Copy its code block **verbatim** into the suite. Do not
  rename, reword, or weaken it. If the test cannot compile or is wrong, stop and say so.
- Run the full suite. Expect the new test red. If it is green already, write no code:
  check the box, commit, and report that the entry needed no change.
- Red → minimal code → full suite green. Commit this **behavioral** change: test + code +
  the checked box, one commit.
- Then, still green, refactor (Go: `gopher` checklist), one step at a time, full suite after
  each step. Commit **structural** changes separately, message prefixed `refactor:`. Never
  in the behavioral commit.
- Report in one line, stop.

## Defect found during a "go"

CLAUDE.md's rule applies (API-level failing test first, then the smallest test that reproduces
the problem), through the plan: probe each of the two tests with `probe.sh`, **append** them
as new unchecked entries at the end of `plan.md` (never edit or reorder existing entries),
commit that `plan.md` change on its own, and stop. The next "go" cycles take them in order.

## Loop guards

- Never modify or delete an existing test. The gate rejects any removed or changed test line.
- Never check a box whose test function is not in the suite. The gate matches names.
- If tests cannot run in this environment, say so. Do not claim green without a green run.
