# Make Operations Idempotent

**Rule:** Scripts and conventions converge to the correct state no matter
how many times they run or where they start from.

**Why:** Sessions get interrupted and hooks re-fire. If a re-run produces a
different outcome, every interruption becomes a debugging session.

**In practice:**
- The index hook rebuilds from disk state (never appends) and exits without
  writing when nothing changed.
- Scaffolds (new-app) refuse existing targets instead of half-applying over
  them.
- Resuming a plan means re-reading its checkboxes and continuing; re-running
  a completed step must be a no-op.

See also: [[principles/serialize-shared-state-mutations]]
