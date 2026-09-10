# Model-neutral checkpoint integrity

Sobaya's September 2026 migration replaces provider-specific instructions and
model-exclusive maintenance with a shared AGENTS.md contract and a deterministic
shell runtime. Model policies affect the chosen worker and guidance; they never
change the approved spec, test bodies, headers, or acceptance commands.

The important failures were at transitions, not prompt wording. A successful
worker exit or checked box did not establish test execution. Repeated runs could
lose the original baseline, and cancellation could release a writer lock while
its child continued modifying files. Commit hooks could fail after GREEN or
change the staged tree, making a naive retry repeat implementation or accept
untested content. Regression fixtures now exercise those failures with real Git
and actual test runners, while deterministic workers avoid paid model calls.

Approval is stored in worktree-local Git metadata and survives repeated commands.
The runner materializes one approved entry, saves protected content, observes
named RED (or an explicitly approved and narrowly classified Go build RED), and
verifies the full suite before committing. Already passing entries are recorded
honestly without a worker call. Checkpoint recovery binds to the verified content,
parent commit, and resulting tree. Worker and test-runner cancellation terminates
the process group before the writer boundary is released. An orphan record blocks
a new writer after abrupt coordinator death while the previous group remains alive.

Fresh review context is independent even when it uses the same model. Completion
requires a final gate and a read-only review bound to HEAD. Call budgets accumulate
per approval, including review; structured diagnostic handoff is required before
configured escalation. Token reports are evidence, not a guaranteed money cap.

Configuration files do not prove active integration. `scripts/setup.sh --check`
verifies real Git hook resolution; `doctor.sh` checks declared worker executables.
Neither proves model credentials or live API behavior. This migration was tested
with fixture adapters, including Codex argv/schema/usage handling, not a live model
session. Ordinary Git hooks improve feedback; acceptance checks must also run
inside the deterministic engine so a missing hook cannot silently bypass them.

See [[principles/encode-lessons-in-structure]] and
[[archive/codebase/legacy-loop-cost-measurement]].
