# Foundational Thinking

**Rule:** Structural decisions (data layout, file boundaries, phase
ordering) optimize for option value. Code-level decisions optimize for
simplicity.

**Why:** Real over-engineering is the premature decision that closes doors;
the right structure chosen early opens them. Meanwhile clever code mostly
closes understanding.

**In practice:**
- Many small phases beat a few large ones: they keep serial/parallel options
  open until dispatch time.
- Directory boundaries (apps/ as independent repos, brain/ sections) are
  chosen for how they will be navigated and archived, not for today's
  convenience.
- Inside a file, prefer the boring implementation.
