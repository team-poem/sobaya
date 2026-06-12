# Persistent CWD and Reference Clones

Shell cwd persists between Bash calls in a session. A `cd` into
`references/noodle` (a foreign git repo) made later bare `git` commands hit
the wrong repository — `git add` failed with "pathspec did not match" only
because the path happened not to exist there; a quieter command could have
mutated the clone.

**Pattern:**
- Always run harness git commands as `git -C /abs/path/to/sobaya ...`.
- Never bare-`cd` into `references/*`; use `git -C references/noodle ...`
  or a subshell `(cd ... && cmd)` for one-off reads.
- Subagent briefs in this workspace state this rule explicitly (see the
  sobaya skill's dispatch patterns).

**Evidence:** plan 01 execution, 2026-06-12 — one failed commit plus a
diagnosis turn. Same family as noodle's worktree CWD gotchas.

See also: [[codebase/noodle-reference]]
