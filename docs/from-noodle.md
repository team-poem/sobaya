# From noodle to Sobaya

The kitchen conventions come from [poteto/noodle](https://github.com/poteto/noodle), a Go event loop that schedules LLM "cook" sessions over file-based work orders. Sobaya keeps its flow and drops its machinery.

| noodle (Go runtime) | Sobaya (Claude Code native) |
|---|---|
| Event-loop cycles drive everything | `loop.sh` drives the TDD cycles; an interactive session drives everything else |
| `mise.json` context brief, rebuilt per cycle | `sobaya` skill pre-flight: brain index (hook-injected) → relevant notes → `apps.md` + app git status → todos + active plans |
| `schedule` agent writes `orders-next.json` | The human-written `plan.md`; the next unchecked entry is the next order |
| Orders advance through stages: execute → quality → reflect | cycle → gate → refuter review → reflect, each stage's deliverable declared up front |
| Cooks spawn as provider-CLI child processes, one skill each | `claude -p "go"` per cycle; subagents via the Agent tool for everything around it |
| Git worktree per cook, merge locks, sequential merges | One writer per app; parallel mutation = one worktree per agent; merges sequential, verified between |
| `stage_yield` — deliverable ≠ process exit | Every cycle ends in a commit; leftovers are stashed, never lost |
| Crash recovery: `orders.json` staging + session adoption | `plan.md` checkboxes are the state; any session resumes at the next unchecked entry |
| Scheduler-driven recovery, never auto-retry | Three cycles without a commit stop the loop; diagnose-then-decide |
| Brain vault + reflect/meditate self-improvement | Ported intact: reflect routes learnings (structure > skill edit > note > todo), meditate audits the vault with subagents |
| `inject-brain` / `auto-index-brain` hooks | Ported as fail-open POSIX hooks, with a wiring fix (Claude Code matchers are tool names, not paths) |
| Autonomous cron loop, web UI, NDJSON event sourcing | Deliberately absent |
