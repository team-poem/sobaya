# Baseline tests steer the loop

A green characterization test installed before a `tdd-set` loop is a constraint the loop
will honor over the spec. "go" only sees red → green and the gate only checks that no test
line changed, so if a baseline fixture violates a rule the new feature introduces, the loop
narrows the implementation until that fixture passes and leaves a comment saying so.

Seen in `apps/rubi` (2026-09-03): the baseline re-designation test posted without a sentence
for cell C5, so the loop made the server validate only cells whose key was present —
`contexts: {}` was accepted. Caught in review, fixed by widening the fixture and adding a
RED entry for the missing-key case.

Rule: before the loop, run every baseline fixture against `spec.md`'s Must list; make fixtures
over-satisfy the new rules. Encoded in the `tdd` skill, Phase 0 step 6.

Related: [[principles/prove-it-works]], [[codebase/thin-shell-needs-a-refuter]]
