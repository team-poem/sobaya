# Serialize Shared-State Mutations

**Rule:** Concurrent actors mutating shared state need structural
serialization — one writer per app, worktree isolation, sequential merges.
Instructions alone are insufficient.

**Why:** Concurrent writes race intermittently and unreproducibly. Agents
have no coordination mechanism unless the structure provides one.

**In practice:**
- Never run two mutating agents against the same checkout; parallel mutation
  gets one worktree per agent.
- Merge one worktree at a time, verifying between merges.
- Shared harness files (index, todos) are written atomically — tmp + rename
  in scripts, single Edit calls otherwise.

See also: [[principles/make-operations-idempotent]]
