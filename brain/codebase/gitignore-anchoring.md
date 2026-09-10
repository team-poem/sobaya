# Gitignore Anchoring

An unanchored directory pattern in `.gitignore` matches at EVERY depth:
`references/` once silently blocked the orchestration skill's nested
reference directory from being staged. The current equivalent path is
`.agents/skills/sobaya/references/`.

**Pattern:** anchor workspace-root ignores with a leading slash —
`/references/`, not `references/`. Reserve unanchored patterns for things
that should be ignored everywhere (e.g. `.DS_Store`).

**Evidence:** plan 01, Task 10 — the sobaya skill's references/ dir would
not stage until the pattern was anchored (commit e2d66d0).
