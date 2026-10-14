# Model-neutral execution evidence

The human's 2026-10-14 decision retired exact-test approvals, permanently
frozen test baselines and mandatory independent completion/checkpoint reviews.
The current authority is the Canon TDD cycle in `tdd-set/AGENTS.md`, not the
historical approval rules from the September harness migration.

Model policies choose workers and guidance; they do not change product intent.
A successful worker exit or checked box still does not establish execution.
The optional runner snapshots tests and commands only for the active
RED-to-GREEN attempt and verifies the full suite before recording progress.
At GREEN the orchestrator can refactor source and tests while preserving
behavior, then select another case without a reviewer or approval ritual.

The useful transition protections remain: failed commits resume against the
verified content, parent and tree; worker cancellation terminates its process
group before releasing the writer lock; live orphan records block another
writer. Call budgets remain cumulative through restart and migration.
Old v1 records are archived with original plans instead of being reused as
current authority. Optional reviewers are read-only and cannot change Git state.

GREEN checks may start with uncommitted refactoring, but must compare content
and Git state before and after execution. A test can import correct code,
overwrite it with broken code and still pass; its exit status cannot certify
the checkout that remains. No-op commands must not claim fresh GREEN evidence.

Configuration files do not prove active integration. `setup.sh --check` checks
real hook resolution, and `doctor.sh` checks configured executables, not live
credentials or API behavior. Harness tests use real Git and test runners with
fake workers; they do not establish a model's judgment or user value.

See [[principles/prove-it-works]] and [[principles/encode-lessons-in-structure]].
