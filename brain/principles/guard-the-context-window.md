# Guard the Context Window

**Rule:** The orchestrator's context is finite and non-renewable within a
session. Every token that enters must earn its place.

**Why:** Context bloat degrades reasoning quality and halts long work. The
orchestrator's judgment is the scarcest resource in the workspace; bulk
content belongs in subagents.

**In practice:**
- Route bulk reads (whole-repo exploration, long logs, reference docs) to
  Explore subagents that return conclusions, not file dumps.
- Keep always-loaded AGENTS.md concise. Read the brain index first,
  then only relevant notes; verify any optional host injection separately.
- Skills carry their depth in `references/` so it loads only when invoked.

See also: [[principles/cost-aware-delegation]]
