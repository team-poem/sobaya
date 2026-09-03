---
name: gopher
description: >-
  Go refactor pass for the TDD loop's green phase. Applies to an app whose AGENTS.md `Skills:`
  line names gopher. Use after a test goes green, before commit. Structural changes only, tests must stay green after every step.
---

# Gopher (refactor while green)

Run only when the full suite is green. Behavior must not change; if a test goes red, revert that step.

**Never rename, move, or change the signature of anything a test references.** The tests are
the spec and the gate rejects any edit to them; a name the tests use is fixed until a human
changes failed-test.md.

## Checklist (stop at the first that applies, fix, rerun tests, continue)
1. `gofmt -l .` empty, `go vet ./...` clean.
2. Duplication between the new code and existing code → extract one function.
3. Function longer than a screen or with more than one reason to change → split.
4. Errors: wrapped with context (`fmt.Errorf("...: %w", err)`), never swallowed, no `panic` on normal paths.
5. Names say intent; no `data`, `tmp`, `helper`, `manager`.
6. State: prefer values over pointers unless mutation is needed; no package-level mutable vars.
7. Concurrency added? Every goroutine has an exit path and a `context.Context`.
8. Exported surface: nothing exported that only this package uses.
9. Touched a hot path? Run the AGENTS.md `Bench:` command before and after; put both numbers in
   the `refactor:` commit message. A regression is not a refactor — revert it.

## Commit
Structural changes go in their own commit, message prefixed `refactor:`. Never mixed with a behavioral change.
