# Guard the Context Window

**Rule:** The orchestrator's context is finite and non-renewable within a
session. Every token that enters must earn its place.

**Why:** Context bloat degrades reasoning quality and halts long work. The
orchestrator's judgment is the scarcest resource in the workspace; bulk
content belongs in subagents.

**In practice:**
- Route bulk reads (whole-repo exploration, long logs, reference docs) to
  Explore subagents that return conclusions, not file dumps.
- Always-loaded text stays minimal: CLAUDE.md stays ~30 lines; the
  session-start injection is the brain *index*, never note bodies.
- Skills carry their depth in `references/` so it loads only when invoked.

See also: [[principles/cost-aware-delegation]]
