# Preserve implementation verification failures

Selected from the working workspace's backlog item 14. The user authorized
one remaining feature through Canon TDD, with learning and design choices
made visible. Product intent: retain the actual suite failure after an
implementation attempt exits, separately from the initial RED.

## Scenarios

- [x] Preserve a changed assertion failure after a worker reports completion;
  retain initial RED, source edits, pending scenario and used calls.
- [x] Preserve a regression outside the selected test, without a checkpoint.
- [x] Keep evidence from failed retries distinguishable and usable on resume.
- [x] Diagnose suite infrastructure failure without treating it as behavioral RED.
  Promoted to the next test after cycle 1: timeout emits stderr but no suite JSON.
- [x] Preserve rejection when the process succeeds without executing the selected test.
  Discovered while reviewing cycle 2; process success is not accepted GREEN.

Only the next scenario becomes executable. Shell/Git/Node fixtures run the
real coordinator without paid model calls. Work in the existing isolated
Canon worktree; do not modify the dirty primary checkout during experiments.

## Learning

The first app candidate, TerminalSafety, was already implemented and tested
in the main game. A stale checkbox in a story-only branch was not evidence
of a missing feature, so that candidate was rejected without inventing RED.

Cycle 1 observed RED: the original actual=0 remained in state while the
post-implementation actual=42 disappeared at cleanup. Added per-run/per-call
suite-failure.json before rejection. The selected test and full ten-suite
harness run passed. No useful structural refactor was needed at this boundary.

Inspecting that result exposed another path: timeout emits diagnostics to
stderr and produces no parsed suite JSON. The next test therefore exercises
that path before changing the storage design. This moves infrastructure
diagnostics ahead of the initially listed regression scenario.

Cycle 2 observed RED: timeout's marker and reason appeared on the terminal
but were absent from the saved artifact, whose suite was null. Capturing
contract stderr preserves both. The selected test and full ten-suite run
passed; no contract return semantics or acceptance rules were weakened.

A further review found an exit-code-0 path rejected because the selected
test never executed. This becomes the next scenario: keep rejection reason
separate from the contract exit code. No speculative runner refactor was
needed at the second GREEN boundary.

Cycle 3 observed RED: process.exit(0) prevented the selected test from
registering. Existing acceptance correctly rejected the run, but the
rc!=0-only retention rule lost the evidence. The implementation now computes
the existing selected-test predicate once, and uses it for retention and
acceptance. The record distinguishes the contract exit code from the
rejection reason. The focused scenario passed after that change.

The remaining regression and retry scenarios were concretized separately,
after the earlier results. Both passed on first execution. No RED or extra
implementation was invented. The retry check proves earlier artifact bytes,
initial RED, cumulative calls and usage survive two failures and a successful
third attempt. Independent review found no further material defect.

Final verification passed on behavioral commit af54cadd: 35 runner cases and
all ten declared harness suites (184 reported cases overall). The optional
actual Vitest probe skipped because SOBAYA_TEST_VITEST_ROOT was not set.
Real Git/Node/Go and deterministic shell workers were used; no paid models.
No runtime edits were made during verification. The implementation uses
existing per-run storage and atomic JSON writing, so no separate refactoring
framework or state schema change is warranted.

## Feature boundary

The observed outcome is durable rejection evidence with separate provenance,
not a claim that every failed coordinator operation is archived. Separate
hygiene failures and external interruption before artifact writing remain
outside this bounded feature. Existing acceptance, initial RED and budgets
are preserved. No new feature was started after this outcome review.

Behavioral commits: 0c710240, fdfdd159, af54cadd. Logs and the Korean briefing
are retained in the primary workspace under
outputs/failed-suite-evidence-20261021/. The root working copy receives only
the verified runner/test/README patch; unrelated existing changes and index
are preserved. Pinned installed runtimes are not automatically repinned.

## Design choice

Store implementation verification alongside its existing worker run, not
over the initial RED. This makes changes in the failure diagnosable while
preserving call accounting and the current attempt's recovery semantics.
