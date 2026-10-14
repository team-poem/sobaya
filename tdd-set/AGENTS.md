# Development cycle

Apply the root and app `AGENTS.md`. The human owns product intent in
`spec.md`. `failed-test.md` is a mutable behavioral scenario list, not a
frozen approval contract. Work within the user's authorized goal.

## Canon TDD

1. List desired behavioral scenarios. Select one useful next scenario;
   add, split, reorder or revise future scenarios as learning warrants.
2. Write exactly one concrete test. Inspect why it fails before implementing.
   A missing intended API can be useful RED; missing dependencies, broken
   tooling or malformed tests require diagnosis. An already passing test
   teaches that the behavior exists; report that without inventing RED.
3. Make this test and all previous tests pass with the smallest coherent
   implementation. Add newly discovered cases to the list. Do not mix
   speculative cleanup into RED-to-GREEN work.
4. At GREEN, optionally improve the design. Refactor source and tests while
   preserving their behavior and coverage; run the full suite after each
   small change. Separate structural and behavioral commits. Avoid premature
   abstraction or tidying that delays useful feedback without a concrete benefit.
5. Use what you learned to choose the next test. Repeat within the authorized
   goal; an empty list does not by itself prove the user's outcome occurred.

No exact-test approval, immutable future batch, append/replacement approval,
mandatory checkpoint review or independent completion review is required.
Explain important test choices and uncertainty in plain language; line-by-line
review copies are optional when useful or requested. Ask the human when the
expected product behavior is ambiguous or would change, not for ordinary test
selection, test corrections or behavior-preserving refactoring.

Never weaken a test to make a broken implementation appear correct. Diagnose
a wrong test against the intended behavior, explain its correction, and observe
fresh failure/pass evidence. Preserve user edits and failure diagnostics.

## Using the shell helpers

The agent can execute this cycle directly in the app. The optional `step.sh`
helper consumes one concrete test attached to the next unchecked scenario in
`failed-test.md`; all later unchecked scenarios remain prose. It materializes
that test, measures RED, delegates implementation, checks the full suite and
hygiene, then checks the scenario and commits the behavioral change.

During that active RED-to-GREEN attempt only, the implementation worker must
not change tests/support, the plan, spec, commands or Git history. It stops at
GREEN and does not commit. This prevents a false pass within an attempt; it
does not freeze tests or design between attempts. The orchestrator may refactor
at GREEN and continue without review or reapproval.

`step.sh` and its compatibility alias `loop.sh` stop after one test so the
orchestrator can learn and choose again. They do not choose future tests or
force a timed pause. `gate.sh` checks current code, including uncommitted
tidying. `review.sh` is optional. See `README.md` for migration and recovery;
the old approval commands do not grant authority or change state.

## Between features

Expose what was actually observed, what surprised you or remains unknown,
and how that changes the next scenario, design or need for tidying. Learning
and restoring room for change matter more than process artifacts. No useful
refactor or durable note is a valid result. Continue already authorized work
after making the next choice explicit; do not start an unrequested feature.

## Sources

- [Canon TDD](https://newsletter.kentbeck.com/p/canon-tdd)
- [Augmented Coding: Beyond the Vibes](https://newsletter.kentbeck.com/p/augmented-coding-beyond-the-vibes)
- [Software Engineering in the Age of AI](https://www.rise8.us/videos/kent-beck-software-engineering-in-the-age-of-ai)

The core cycle follows these sources. Sobaya's optional shell helpers are
implementation tools, not rules prescribed by Beck or a verbatim reproduction.
