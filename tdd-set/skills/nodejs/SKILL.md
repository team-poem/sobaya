---
name: nodejs
description: >-
  JavaScript / TypeScript refactor pass for the TDD loop's green phase. Applies to an app whose
  AGENTS.md `Skills:` line names nodejs. Use after a test goes green, before commit.
---

# nodejs (refactor while green)

Run only when the full suite is green. Behavior must not change; if a test goes red, revert that step.

**Never rename, move, or change the signature of anything a test imports or calls.** The tests
are the spec and the gate rejects any edit to them; a name the tests use is fixed until a human
changes failed-test.md.

## Checklist (stop at the first that applies, fix, rerun tests, continue)
1. The app's `Lint:` command is clean (eslint) and `Format:` prints nothing (prettier, if the app has it).
2. TypeScript: no `any`, no `as` casts to silence the compiler, no `!` non-null assertions on values that can be absent.
3. Duplication between the new code and existing code → extract one function or one module.
4. Function longer than a screen or with more than one reason to change → split.
5. Errors: every `await` is inside a `try` or returns a `Result`-like value; never swallowed; no bare `catch {}`.
6. Names say intent; no `data`, `tmp`, `helper`, `utils2`, `handler`.
7. Exported surface: nothing exported that only this module uses. No default exports for new code.
8. No new dependency added to `package.json` for something a few lines cover.
9. Touched a hot path? Run the AGENTS.md `Bench:` command before and after; put both numbers in the `refactor:` commit message. A regression is not a refactor — revert it.

## Commit
Structural changes go in their own commit, message prefixed `refactor:`. Never mixed with a behavioral change.
