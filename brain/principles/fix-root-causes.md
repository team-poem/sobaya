# Fix Root Causes

**Rule:** Never paper over symptoms. Trace every problem to its root cause
and fix it there.

**Why:** Symptom fixes accumulate into workarounds that make the system
harder to reason about while the real bug stays. Root-cause fixes are slower
once and cheaper forever.

**In practice:**
- A failed dispatch is diagnosed from its output before any re-dispatch.
- When you apply the same fix twice, stop — the second occurrence is the
  signal to find the underlying cause or to encode a guard
  ([[principles/encode-lessons-in-structure]]).

See also: [[principles/prove-it-works]]
