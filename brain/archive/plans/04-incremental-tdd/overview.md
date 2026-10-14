# Incremental TDD with human judgment

Current decision (2026-10-14): the human explicitly replaced the approval and
frozen-batch model below with Canon TDD. The incremental-approval work is
historical, not the current development contract. Implementation and current
verification are recorded in `canon-transition.md`; follow `tdd-set/AGENTS.md`.

## Authorized direction

On 2026-10-14 the human requested that Sobaya adopt Kent Beck's augmented
development and Canon TDD: list scenarios, select and concretize one test,
learn from implementation, and optionally refactor while GREEN. Remove the
requirement to prewrite the whole executable test plan and the requirement
to request a separate feature task for each relevant GREEN refactor.

The existing human test-approval boundary remains: new executable tests and
their support are drafts until reviewed. Do not interpret agreement on the
direction as approval of test code that has not been shown. Never edit an
app's human-owned spec or weaken an approved test to obtain GREEN.

Status: the human approved the exact first test on 2026-10-14. The first
increment is implemented, passes the full suite, and has an independent
completion review. The approved file remains
`tests/draft-next-test-approval.sh` with its original bytes and historical
draft comment preserved; `tests/run.sh` now includes it. Its review view is
`docs/incremental-tdd-first-test-review.md`. The remaining scenarios below
are not approved executable tests and are not claimed complete.
The next human request authorized optional GREEN tidying and feature-boundary
learning. Those orchestration instructions are applied. The human then approved
the exact continuation test, `tests/draft-reviewed-green-refactor.sh`, explained
in `docs/green-refactor-next-test-review.md`. Reviewed tidying followed by
next-test approval is implemented and passes the full suite and independent
completion review. Both approved test files retain their original bytes.
The human now requests the same GREEN-tidying continuation inside a legacy
batch with unfinished approved entries. The human approved the exact third
test, `tests/draft-batch-green-refactor.sh`; its annotated review is
`docs/batch-green-refactor-test-review.md`. The checkpoint-review mode is
implemented and verified by the exact approved case, full regression suite,
and independent completion review. Current instructions and guides are aligned.

## Intended working cycle

1. Keep a readable list of behavioral scenarios, without executable code for
   future cases. Propose the next scenario and its selection rationale.
2. Concretize, explain and probe only that test and its required support.
   The human approves the exact executable input before implementation.
3. Observe RED; implement the smallest coherent change; validate the full
   suite and protected inputs; commit the behavioral checkpoint.
4. Consider a bounded, behavior-preserving structural improvement while GREEN.
   It is part of this cycle, not a separately commissioned feature. Preserve
   tests, interfaces they reference, and acceptance commands. Verify the full
   suite after each structural change and use separate structural commits.
5. Expose the result, what was learned, remaining uncertainty, and implications
   for the next choice. Revise unimplemented scenarios within the human's
   intent; propose changed intent or executable acceptance for human review.
6. At the feature boundary, evaluate user value and changeability. Independent
   completion review remains bound to the final revision, including tidying.
   Exhausting currently concretized tests does not prove product completion.

## Smallest runtime direction

Keep scenarios separate from `failed-test.md`, which can initially remain
the append-only record of exact approved tests. This avoids redefining the
current parser's section headings, which also scope test headers. The scenario
file is planning evidence, never runtime authority to implement another test.

Use the implemented incremental approval operation (`approve --append`)
to enroll exactly one new pending executable test after a verified checkpoint.
Do not use `--replace` as the normal next-test operation: it resets the current
call count, receipts and review baseline. Keep original feature provenance and
cumulative usage while extending the acceptance record. The implementation
uses optional `acceptance_head` and `acceptance_history` fields in version-1
state; old states continue to use their original baseline.

The increment must validate protected inputs against earlier accepted work,
not merely advance a SHA to bless unrelated changes. Final review must retain
the whole feature's original diff range. Existing v1 approvals and unfinished
entries retain their evidence and recovery semantics. Existing batch plans are
not automatically rewritten or reapproved.

The second runtime increment reuses `review.sh` to validate source
tidying instead of adding a new worker role or automatic refactor phase. The
orchestrator distinguishes behavioral and structural changes by separate
verified commits. The harness validates transitions, test execution, protected
bytes and revision binding; it cannot certify that a reflection is insightful
or that passing tests prove every aspect of behavior equivalence.

## Scenario list (not executable tests or an approved baseline)

- NextTestApprovalPreservesProgress: enroll one next test after a checkpoint,
  reject execution before approval, preserve original baseline/calls/receipts,
  and execute the newly approved case. **Approved and verified, 2026-10-14.**
- IncrementalApprovalPreservesAcceptance: reject changes to earlier tests,
  fixtures, headers, spec, commands, source or checkpoint history while enrolling
  the next test. Scope any explicitly necessary support separately.
- IncrementalApprovalHasOneNextCase: reject multiple new executable cases and
  enrollment during an unfinished entry; replay does not spend or reset calls.
- IncrementalRecoveryIsCompatible: interruption, existing v1 state, locks,
  worktrees and commit-only recovery retain their current guarantees.
- ScenarioListCanEvolve: unimplemented scenarios can be added/reordered without
  changing approved executable inputs or authorizing implementation.
- GreenAllowsBoundedTidying: after a validated behavioral checkpoint, optional
  structural changes use a distinct phase/commit and the unchanged full suite.
  Orchestration policy and its reviewed-tidy-to-next-test runtime connection
  are **approved and verified, 2026-10-14**.
- GreenTidyingCannotChangeAcceptance: preserve tests and stop with evidence on
  RED, scope conflict or interruption; no automatic destructive reset.
- BatchGreenTidyingPreservesPendingWork: review a GREEN structural revision
  while approved entries remain unchecked, then continue those entries without
  reapproval or losing evidence. Keep final completion review distinct.
  **Approved and verified, 2026-10-14.**
- CompletionUsesFinalRevision: include structural changes in the final gate and
  independent review; do not reuse a review bound to an earlier HEAD.
- NextChoiceUsesLearning: report changed assumptions, observed friction,
  unknown outcomes and the next decision; no mandatory refactor, note or TODO.
  Applied as orchestration guidance, with no claim of automatic shell-loop judgment.

The first, GREEN-tidying and legacy-batch scenarios have approved executable code.
All other items remain scenario descriptions;
do not prewrite all of their tests or treat them as approved acceptance.

## Canonical files to update as behavior becomes available

- `AGENTS.md` and `tdd-set/AGENTS.md`: human judgment, per-test acceptance,
  GREEN refactoring authority and completion boundaries.
- `tdd-set/skills/tdd/SKILL.md`: scenario list and just-in-time runnable tests.
- `tdd-set/skills/{go-mistakes,nodejs}/SKILL.md`: remove separate-task-only
  restriction while retaining scoped changes, test protection and verification.
- `.agents/skills/{sobaya,reflect}/SKILL.md`: connect observed learning to the
  next decision; app-specific design learning stays in the app repository.
- Templates and `tdd-set/commands/`: distinguish scenarios from runnable cases.
- `README.md`, `README.ko.md`, `tdd-set/README.md`, `docs/guide.md`: align user
  instructions with implemented behavior; do not claim a draft command exists.
- Relevant vision/current architecture notes after implementation. Do not
  hand-edit the generated brain index or duplicate symlinked skills.

## Verification and review

The draft reuses the existing shell fixture setup and deterministic worker.
It uses real temporary Git repositories and Node tests; no paid model sessions.
It deliberately uses an already-GREEN second fixture test to isolate enrollment
from implementation. The harness test itself must fail on the current runtime.

Before implementation, show the exact draft plus its existing support in the
Korean review view and obtain approval of that one test. After implementation,
run the approved case, then `bash tests/run.sh`, then independent review. Tests
remain drafts until that approval; no existing assertion is weakened.

### Prepared evidence (2026-10-14)

- Existing full suite: `bash tests/run.sh` passed, including 27 runner cases.
- Draft syntax: `/bin/bash -n tests/draft-next-test-approval.sh` passed under
  the system Bash 3.2.
- Draft execution reached the first real RED-to-GREEN checkpoint, rejected
  unapproved execution without changing state or inserting the next test, then
  failed at `approve --append` with `Unknown option --append`, as intended.
- Independent read-only review reproduced that failure and found no blocking
  issue in the draft. It does not prove the later protection/recovery scenarios.
- All three annotated code blocks in the saved Korean review document recover
  the exact source bytes when only added `// 검토:` explanation lines are removed.
- Existing test support, accepted suites and runtime files remain unchanged.
  Unrelated concurrent README/image work belongs to another task and was preserved.

### Verified checkpoint and learning (2026-10-14)

- The human replied “승인한다” to the exact first-test review. The approved
  test SHA-256 remains
  `203c85beae3e9eb24dc050290abe4d8177b066ae960a840e48bc6838290c7572`.
  Existing shared fixture/support bytes remain unchanged.
- Implemented `approve --append` with one atomic acceptance-history update;
  original baseline, approved timestamp, cumulative calls and receipts remain.
  The command checks the previous acceptance contract, completed entries at
  the recorded checkpoint, one next unchecked entry, and no other file edits.
- Approval replay at the same acceptance HEAD is a no-op. Active work and
  `--append --replace` are rejected. Changing RED authorization still needs
  the existing human-reviewed replacement path.
- Default gates and checkpoint validation use the latest acceptance revision;
  final independent review and worker provenance retain the original baseline.
- `/bin/bash tests/draft-next-test-approval.sh`: PASS with the approved bytes.
  `/bin/bash tests/run.sh`: PASS, including all 27 existing runner cases and
  the newly registered approved test. Bash syntax and `git diff --check` pass.
- A fresh read-only reviewer found no actionable issue in the runtime and
  suite-registration diff, independently ran the approved test, and inspected
  old-state/recovery paths. Adversarial incremental cases remain future
  executable coverage; static inspection is not a substitute for them.

The first learning is that acceptance revision and feature review provenance
must be separate. Advancing only the original baseline would discard scope;
checking only candidate checkboxes would allow unverified progress to look
complete. The last recorded checkpoint supplies the completion evidence.

The original next selection was protection coverage. The subsequent human
request prioritizes GREEN tidying and feature-boundary learning; follow the
selected continuation below. Protection coverage remains in the scenario
list rather than being silently dropped or preapproved.

### GREEN tidying and learning continuation (2026-10-14)

Applied the directly authorized orchestration changes to the shared contract,
TDD/Sobaya/reflection/stack skills, command references, template guidance,
vision and paired README/user guides. Future scenarios stay outside executable
acceptance; only the next test is concretized. Relevant small GREEN tidying
is part of the task, optional and source-only, with full verification and a
separate structural commit. Final review covers the resulting revision.

At feature boundaries, expose observed outcomes, learning and the next
decision. No forced refactor, note, TODO, wait or repeated permission. An
already authorized task may continue after that judgment; new intent or
test expectations still require human review. This is an orchestration
decision, not a claimed feature-completion capability in the shell loop.

Before the second approval, the operational limit was explicit: use tidying at
the feature's final approved checkpoint. `review.sh` needs all approved tests
complete, and `--append` rejected reviewed source changes since the last
behavioral receipt. The verified continuation below removes the latter limit;
the all-approved-entries-complete requirement remains.

Selected exact draft: `test_reviewed_green_refactor_allows_next_test`. It
creates a first checkpoint and review, tidies source without changing tests,
requires a fresh review on the new HEAD, then appends one next test. It
requires original provenance, cumulative calls and behavioral receipts to
survive, keeps the used review in acceptance history, and checks that the
actual tidied source survives both approval and the next checkpoint.

The proposed implementation can recognize that verified reviewed revision
as the append comparison point. Before doing so, require byte-identical
protected inputs from the original checkpoint, and allow only the plan
append after the reviewed revision. Preserve the original behavioral receipt
and retain consumed review evidence. This is not permission to bless arbitrary
unreviewed source/support edits. No new worker or mandatory tidy call is needed.

Pre-approval evidence (historical):
- Exact draft SHA-256:
  `e728cd23ad96367e08b8e9b6ea46205027e076ccd5b72e21e0c6ecb97d3333f3`.
- Bash syntax passes. Its probe verifies the pre/post-tidy reviews and
  unchanged tests/plan, then fails at the intended plan-only append guard.
- A separate reviewer examined the draft; its recommended source-preservation
  assertions were added before the final human review view was generated.
- A separate instruction evaluation correctly handled useful final tidying,
  the blocked between-test path, and no-op learning with already authorized
  follow-up work, without extra approval or artifact requirements.
- Final documentation review found that revising a tracked app scenario
  document would itself block the next append. Resolved the instruction gap
  explicitly: keep evolving choices in conversation during the incremental
  run and persist useful app planning updates at the feature boundary.
- `/bin/bash tests/run.sh` passes; the new draft is intentionally excluded.
  Approved test/support and runtime hashes remain unchanged this turn.
- All five skill frontmatters pass YAML/name/description validation using
  system Ruby/Psych. The external skill quick validator could not run because
  PyYAML is missing in both available Python environments; no new runtime or
  dependency was added to the harness. `git diff --check` passes.

### Verified reviewed-tidy continuation (2026-10-14)

- The human replied “승인한다” to the exact second test. Its SHA-256 remains
  `e728cd23ad96367e08b8e9b6ea46205027e076ccd5b72e21e0c6ecb97d3333f3`.
  The first approved test and shared support also retain their approved bytes.
- `approve --append` still accepts a plan-only append after the last behavioral
  receipt. When other files changed, it requires a successful reviewed revision
  descending from that receipt and ancestral to the candidate HEAD.
- Protected inputs must be unchanged between the checkpoint and reviewed
  revision, including newly added, removed or renamed protected paths and
  explicit test targets. Only `failed-test.md` may change after that review.
- The used review is retained in `acceptance_history`; the current review is
  cleared for the extended plan. Original baseline, calls and behavioral
  receipts remain unchanged. No extra implementation call is spent on approval.
- The exact approved test passes under `/bin/bash`, and `tests/run.sh` now
  includes it. `/bin/bash tests/run.sh` passes all shell harness suites with
  no forbidden interpreter. Bash syntax and `git diff --check` pass.
- A fresh read-only completion reviewer independently ran the approved case
  and found no actionable issue. Ancestry, protected-path edges, stale reviews
  and the existing no-refactor path were inspected statically; negative edge
  cases are not claimed as new executable coverage.
- Canonical instructions, TDD skill and paired human guides now describe the
  working continuation. Persisted app scenario notes belong in a verified and
  reviewed revision before the next plan-only append; notes after a final
  review require a refreshed review. This document route lacks dedicated
  executable coverage and does not alter the protected-input boundary.

Learning: a behavioral receipt and a later structural review describe different
evidence. Reusing the existing review as an additional comparison point, while
retaining both records, restores room for change without inventing a new worker
role or discarding the feature's history. Feature-boundary reflection remains
an orchestrator judgment about observed value, friction and the next choice.

The first two requested increments are complete. Further protection/recovery
coverage remains in the scenario backlog. The human has now prioritized
intermediate tidying in legacy batches; its prepared next test follows below.

### Prepared legacy-batch continuation (2026-10-14)

The human explicitly requested optional GREEN tidying while unfinished tests
remain in an already approved batch. The final-review completion check must
remain intact. Proposed command: `review.sh APP --checkpoint`, reusing the
existing read-only `review` worker role, budget, suite/hygiene gate and protected
input checks. Pending entries may remain unmaterialized, but the full declared
suite of current code still has to execute and pass.

Bind each intermediate review to its originating behavioral checkpoint and
reviewed HEAD in a separate `checkpoint_reviews` history. Do not rewrite the
behavioral receipt or original approval. Intermediate success must not create
final `review` evidence or establish completion.
The checkpoint reviewer examines the structural diff since that receipt and
preservation of verified behavior; identify pending approved entries as future
work, not completion defects. The final reviewer still examines the original
feature baseline through the final HEAD after every approved entry completes.

One draft lifecycle uses the unchanged real Git/Node fixture: approve A and B
together, finish A, reject a broken tidy without spending a worker call or
changing state, review a corrected tidy, preserve pending B and final-review
rejection, finish already-GREEN B, then require a separate final review.
It checks protected test/plan bytes, source preservation, receipts, cumulative
calls, idempotent review replay, review-role usage and both prompt diff ranges.
The fixture's B deliberately needs no implementation call. Live reviewer
quality, a second RED implementation and other adversarial cases are not proved.

Evidence before approval:
- Draft SHA-256:
  `a175cc241fca18ae4d51a3df9e5858c6c8e5ef56119baf9fe3be2f2814778187`.
- Bash 3.2 syntax passes. Probe reaches A's real RED/GREEN checkpoint and
  unchanged pending B, then fails because `--checkpoint` is unknown. The draft
  requires a diagnostic naming A; an arbitrary option failure is not enough.
- An independent read-only reviewer reproduced this implementation gap and
  found consistent state/call expectations. Its pre-approval recommendations
  added review-role and actual diff-range assertions to the draft/review view.
- Removing only Korean explanation lines recovers the complete draft bytes.
  Shared support, both accepted test files, runtime and suite registration
  remain unchanged. The new draft is not registered as approved acceptance.

Learning: intermediate structural review and final feature completion need
different scope and evidence. Simply relaxing the old final gate would make
pending work look complete and give the reviewer the wrong goal. A separate
mode can reuse execution machinery without adding another worker role.

The human subsequently approved the exact annotated test. Its bytes remain
unchanged and the case is now registered in the full suite. The implementation
reuses the full gate and existing read-only role with a scoped prompt, while
persisting intermediate evidence separately. Current runtime guidance has been
updated and independently checked for consistency.

### Verified legacy-batch continuation (2026-10-14)

- The approved test remains byte-identical at SHA-256
  `a175cc241fca18ae4d51a3df9e5858c6c8e5ef56119baf9fe3be2f2814778187`.
  Both prior approved tests and the shared fixture/support remain unchanged.
- `review --checkpoint` permits pending approved entries while preserving the
  full current suite, hygiene, protected-input and ancestry gates. It records
  checkpoint/head/acceptance-bound evidence without advancing checkboxes or
  spending an implementation call. Same accepted review replay is idempotent.
- The existing read-only reviewer sees the structural diff from the last
  behavioral receipt plus pending-entry context. Default review still requires
  all entries complete and covers original feature baseline through final HEAD.
- Independent completion review found that a later failed or unavailable
  checkpoint review could leave an older final success eligible for reuse.
  Fixed by persisting `review_pending` before dispatch, checking accepted status
  for both review caches and source-bearing append approval, and retaining
  prior final completion only after a successful invocation that started from
  valid completion. Existing records remain available as history, not authority.
- `/bin/bash tests/run.sh` on the final runtime passes all shell harness suites
  with no forbidden interpreter. Bash syntax, `git diff --check`, TDD skill
  metadata and exact annotated-source comparison also pass.
- Independent runtime review found no remaining actionable issue at runner
  SHA-256 `a7711f850df1c5587f51f5eed86622fc3da604a1e660a943add2d51b24229635`.
  Documentation review confirms the mid-batch and final paths are consistent.
  Failure/cache edge fixes were assessed statically; no unapproved executable
  cases were added, and no live model reviewer quality is claimed.

Learning: a matching commit identifies the code, but does not by itself make an
old success current evidence after a later review failure. Every consumer of
that evidence, including approval, needs the same accepted-status boundary.
The requested batch continuation is complete. Additional adversarial coverage
remains in the scenario backlog; no extra task, forced tidy or approval loop is
needed to use the existing approved batch flow.

## Sources

- [Canon TDD](https://newsletter.kentbeck.com/p/canon-tdd)
- [Augmented Coding: Beyond the Vibes](https://newsletter.kentbeck.com/p/augmented-coding-beyond-the-vibes)
- [Prodacity 2026 transcript](https://www.rise8.us/videos/kent-beck-software-engineering-in-the-age-of-ai)
- [Human-supplied summary](https://lilys.ai/digest/11735640/13903314?s=1&noteVersionId=10525922)
