---
name: nodejs
description: >-
  JavaScript / TypeScript refactor pass for the TDD loop's green phase. Applies to an app whose
  AGENTS.md `Skills:` line names nodejs. Use for a separately authorized structural refactor while the suite is green.
---

# nodejs (refactor while green)

Run in a separately authorized refactoring task after a verified checkpoint,
not inside the source-only implementation worker. Run only when the full suite is green. Behavior must not change; if a test goes red, revert that step.

**Never rename, move, or change the signature of anything a test imports or calls.** This
includes every name in a section's header block in `failed-test.md` (imports, shared constants):
that block is the head of the test file. The tests are the spec and the gate rejects any edit
to them; a name the tests use is fixed until the human approves a changed acceptance baseline.

## Checklist (stop at the first that applies, fix, rerun tests, continue)
1. The app's `Lint:` command is clean (eslint) and `Format:` exits successfully (prettier, if the app has it); success output is allowed.
2. TypeScript: no `any`, no `as` casts to silence the compiler, no `!` non-null assertions on values that can be absent.
3. Duplication between the new code and existing code → extract one function or one module.
4. Function longer than a screen or with more than one reason to change → split.
5. Errors: propagate failures or handle them at an intentional boundary; avoid swallowed failures.
6. Names express domain intent; rename vague new-code names when that improves clarity.
7. Exported surface: nothing exported that only this module uses. No default exports for new code.
8. No new dependency added to `package.json` for something a few lines cover.
9. Touched a hot path? Run the AGENTS.md `Bench:` command before and after; put both numbers in the `refactor:` commit message. A regression is not a refactor — revert it.

## Commit
Structural changes go in their own commit, message prefixed `refactor:`. Never mixed with a behavioral change.
