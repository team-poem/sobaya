---
priority: []
# nothing ranked yet — 2..6 are backlog candidates from plan 01's Future Work
---

# Todos

<!-- next-id: 12 -->
<!-- completed todos live in archive/completed_todos.md -->
<!-- completed plans live in archive/plans/ -->

## Workspace

2. [ ] ruminate skill — mine past session transcripts for uncaptured
   patterns, batched subagent analysis (port from noodle).
3. [ ] Cross-provider adversarial review — opposite-model reviewers via a
   second provider CLI; blocked until one is installed.
4. [ ] Optional autonomous cycles — schedule/execute loop via /loop or
   /schedule once the harness has proven itself in interactive use.
5. [ ] unslop skill — de-AI writing pass for human-facing docs (port from
   noodle).
6. [ ] .agents/ multi-harness indirection — only if a second harness is
   adopted (migrate-callers, then delete).
11. [ ] loop.sh: `Bash(cd apps/<name> && npm:*)` allowlist patterns never
   match — Claude Code splits compound commands on `&&` and permission-checks
   each part, so Node apps get every npm/node call denied and ship with the
   suite unrun. Verified with two `claude -p --model haiku` runs: the `&&`
   pattern is denied, `Bash(cd:*)` + `Bash(npm:*)` runs the suite. Workaround
   in use is the documented `CLAUDE_FLAGS` wholesale override. Fix: drop the
   `cd <app> &&` prefix from the patterns — the per-app scoping it was meant
   to give never took effect anyway.

