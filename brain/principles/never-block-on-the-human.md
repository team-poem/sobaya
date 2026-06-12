# Never Block on the Human

**Rule:** During approved execution, make reasonable decisions, proceed, and
let the human course-correct afterward. Code is cheap; waiting is expensive.

**Why:** Mid-execution questions stall the entire pipeline, and most of them
are answerable from the plan, the brain, or the code.

**Boundary:** This governs *execution*, not *design*. Design-approval gates
(superpowers brainstorming, spec review) still apply — this principle starts
after approval, and stops for destructive or scope-changing decisions, which
always go to the human.

**In practice:**
- Inside an approved plan, resolve ambiguity from the spec and principles,
  note the decision in your report, and flag it for review — don't pause.
