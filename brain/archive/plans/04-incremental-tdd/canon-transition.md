# Canon TDD transition

## Authorized decision

On 2026-10-14 the human explicitly asked to discard Sobaya's exact-test
approval/freeze/review gates and prewritten future batches, adopting the
Canon TDD and augmented coding flow discussed in the conversation. That
request supersedes the prior approval contract for this change. No repeated
approval was required to implement or revise the obsolete contract tests.

The human continues to own product intent. Scenario selection, ordinary test
correction and GREEN refactoring proceed within that intent. Unclear or changed
product behavior needs a human decision. Never weaken tests to fake GREEN.

## Implemented

- Mutable behavioral list; one next concrete candidate; future cases stay prose.
- Direct agent TDD is supported. Optional step helper auto-starts execution
  without approval, measures named RED, verifies full GREEN, commits one change.
- Loop helper returns after one test for orchestrator learning/selection.
- Active implementation protects its tests/commands; no permanent test freeze.
- GREEN source and test refactoring needs no approval or independent review.
- Current-suite check permits dirty starting code and detects check side effects.
- Review is optional. Approval/append/replace/checkpoint gates are retired.
- Migration archives original v1 plan/state and retains receipts, usage, origin
  and calls; prose scenarios replace code fences. No app was mass-migrated.
- Restart archives an active attempt without deleting files or resetting budgets.
- Prior approval-specific tests are historical artifacts under
  `tests/archive/approval-v1`; execution/recovery regressions remain current.

## Verified completion

- New lifecycle tests exercise first use without approval, GREEN source/test
  refactoring with continuation, and original-preserving legacy batch migration.
- 30 runtime cases pass, including tamper protection, real Go build RED,
  cancellation, locking, hidden-index detection, optional read-only review,
  new restart/migration/no-op regressions and unchanged cumulative budgets.
- 17 suite/contract cases pass; actual Vitest integration is skipped unless
  SOBAYA_TEST_VITEST_ROOT is supplied. Go and Node execute real tests.
- A read-only reviewer found fresh restart fallthrough, source-changing gate
  checks, broken historical usage lookup, unstarted-v1 migration and false
  no-op GREEN wording. All five were fixed; new regressions cover those paths.
- Final `/bin/bash tests/run.sh` passed, log:
  `/private/tmp/sobaya-canon-verified-suite.log`. This includes 30 runtime,
  17 suite/contract and 67 tool checks, the three Canon lifecycle cases,
  next-entry and Go probe integration. No paid worker was invoked.
- Migration's hook-induced source mutation was reproduced RED and fixed by
  checking expected plan-only commit tree/parent and a clean checkout before
  updating state. The independent focused recheck found no remaining issue.
- Guidance review exercised GREEN continuation, test correction, changed intent
  and an active v1 attempt. Clarified migration/identifier wording, probe GREEN
  guidance and the Korean recovery exception; no approval/review gates remain.
- Bash syntax, git diff whitespace and five skill frontmatters pass. The skill
  quick-validator lacks PyYAML in this host; Ruby/Psych verified the metadata
  and the independent guidance audit checked behavior instead.
- Current contracts, paired READMEs, Korean guide, templates, commands, stack
  skills and relevant memory align. Prior exact-test reviews are labeled history.
  No app repository, user spec or live execution state was rewritten.

## PR integration

Integrated on origin/main f8aa55b, retaining its installed runtime, release
packaging, optional review-view generator and jq 1.6 fixes. Installed dispatch
supports migration/restart; bump accepts inactive v1/v2 state without rewriting
history. Migration also snapshots workspace pins across commit hooks.
`TMPDIR=/private/tmp /bin/bash tests/run.sh` passed, including 14 installed-flow
cases and the configuration, release and review-view suites; log:
`/private/tmp/sobaya-canon-pr-suite.log`. No paid worker ran; optional real
Vitest remains skipped. A read-only installed-integration review found no
remaining issue. Both installation fixture versions use current sources;
released-old-launcher compatibility is documented, not claimed as tested.

## Learning

The approval model existed in parser, runner, validation, templates, skills and
memory. Removing prose alone would retain the unwanted flow. Preserving test
meaning is distinct from freezing its bytes forever; active attempt integrity
can remain while GREEN test design evolves. Shell success still cannot measure
restored changeability or actual user value; those need human/agent judgment.
