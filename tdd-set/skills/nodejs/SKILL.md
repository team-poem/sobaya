---
name: nodejs
description: >-
  JavaScript / TypeScript refactor pass for the TDD loop's green phase. Applies to an app whose
  AGENTS.md `Skills:` line names nodejs. Use for relevant optional structural tidying at a verified GREEN checkpoint.
---

# nodejs (refactor while green)

Run as orchestrator-led tidying within the authorized development task,
after the implementation worker finishes its verified entry. Follow
`tdd-set/AGENTS.md` for the cycle and current runtime limits. Start GREEN
and preserve behavior. On RED, stop and diagnose; preserve edits for recovery.
Use the checklist to investigate concrete friction in the current change,
not to force every item into compliance. Skip when no useful improvement exists.

At GREEN, source and test code can be renamed, moved or reorganized together
while preserving behavior and assertions. Run the suite after each small
change. No byte-frozen test baseline or renewed approval is required.

## Checklist (stop at the first that applies, fix, rerun tests, continue)
1. The app's `Lint:` command is clean (eslint) and `Format:` exits successfully (prettier, if the app has it); success output is allowed.
2. TypeScript: no `any`, no `as` casts to silence the compiler, no `!` non-null assertions on values that can be absent.
3. Duplication between the new code and existing code → extract one function or one module.
4. Function longer than a screen or with more than one reason to change → split.
5. Errors: propagate failures or handle them at an intentional boundary; avoid swallowed failures.
6. Names express domain intent; rename vague new-code names when that improves clarity.
7. Exported surface: nothing exported that only this module uses. No default exports for new code.
8. No new dependency added to `package.json` for something a few lines cover.
9. Touched a hot path? Run the AGENTS.md `Bench:` command before and after; put both numbers in the `refactor:` commit message. Stop and diagnose a regression before advancing.

## Commit
Structural changes go in their own commit, message prefixed `refactor:`. Never mixed with a behavioral change.
