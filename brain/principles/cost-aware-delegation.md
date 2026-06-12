# Cost-Aware Delegation

**Rule:** Every dispatch gets a budget and a hard-capped scope. A longer
brief is cheaper than rediscovery turns.

**Why:** Without explicit scope, delegated work expands to fill available
resources, and an under-briefed agent burns turns rediscovering context the
orchestrator already had.

**In practice:**
- Dispatch prompts state: target app path, the task, constraints, what NOT
  to touch, and the expected report format (templates live in the sobaya
  skill's references).
- Match agent count and model to the work; don't fan out ten agents where
  two suffice.
- Repeatedly re-dispatching failing work is backpressure ignored, not
  progress ([[principles/fix-root-causes]]).

See also: [[principles/guard-the-context-window]]
