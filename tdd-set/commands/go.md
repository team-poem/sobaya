---
description: One TDD cycle in one app — next unchecked entry in apps/<name>/failed-test.md, red → green → refactor → commit
---
App: `apps/$ARGUMENTS`. Read `tdd-set/AGENTS.md` and follow it for this app: where it says `plan.md`, use
`apps/$ARGUMENTS/failed-test.md`. Git: `git -C apps/$ARGUMENTS ...`. Go: `go -C apps/$ARGUMENTS ...`.
Node: `cd apps/$ARGUMENTS && npm|npx|node ...` as one command. Never a bare `cd`.
Commit with `git -C apps/$ARGUMENTS commit -m "<one line>"` — a plain quoted message only. No heredoc,
no `$(...)`, no multi-line body: the loop runs you with a fixed allowlist and any command substitution
turns the commit into a permission prompt nobody can answer, so the cycle ends uncommitted. Tests enter
the suite by appending only: Go into the package's `_test.go`; Node into the file named by the
section's `// file:` header (create it from the header block if absent, then append the entry
block at the end). Never change a line that is already there. The command lines and the `Skills:` line are in `apps/$ARGUMENTS/AGENTS.md`; for the
refactor step apply only the skills that line names. Then: go
