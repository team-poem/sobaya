# Versioned project and dependency modes

Status: architecture, four configuration-check entries, and four local release
packaging entries authorized on 2026-10-02 and implemented. See the exact
approval records ([configuration](config-approval.md), [packaging](release-approval.md))
and validation evidence ([configuration](config-validation.md), [packaging](release-validation.md)).
Installation, init, dispatch and bump tests were subsequently approved on
2026-10-05; their implementation is recorded in install-flow-validation.md.
The detailed human-facing decisions are in
[the Korean design](../../../docs/plans/sobaya-v1-design.md).

## Fixed scope

One Bash 3.2/jq/Git core, with project and dependency integration profiles.
Configuration belongs to the consuming workspace, not a global runtime switch.
Use sobaya.json (config_version, mode, runtime.version) and a JSON sobaya.lock
for exact commit/artifact pinning. Distribute through GitHub Releases and an
installer; no npm or TOML dependency. Retain existing acceptance semantics,
project workflow and performance. Do not fold issue #4 acceptance redesigns
into packaging work.

## Baseline evidence

Published v0.9.0 at e789ce4eb4ce70109474eddd83bcce2f0481ed16, including PR #5.
Clean-worktree validation passed the entire tests/run.sh with actual Node, Go,
and Vitest: 38 contract cases, 27 runner cases, 67 tools cases, plus next/probe/
gate regressions. Fake workers only; no paid model calls. Independent release
preflight found no blocker. This source release requires a Git checkout; it
does not provide the proposed v1 launcher, configuration or installer.

## Implemented configuration tranche

The approved read-only `bin/sobaya config check --root PATH` is implemented.
The exact command/output/lock schema and executable tests were reviewed at
574d9ee and explicitly approved by the human. The source is materialized
verbatim as tests/test-config.sh. Do not alter existing tests or spec.md.
The app probe supports Go/Node, not Bash: report a missing future CLI as NOT
PROBED, never as behavioral RED. After approval, use the root Bash harness
maintenance workflow, one reviewed entry at a time, with the full existing
suite and independent review. Do not invent a Node wrapper or call approve.sh
on the Sobaya root as though it were an app with approved spec.md.

Approved artifacts: [executable Bash](draft-config-tests.sh) and
[Korean review view](../../../docs/plans/sobaya-v1-config-review.md).
Four entries cover explicit mode/version selection, input documents,
configuration fields, and matching lock data. Each invocation checks preservation
of paths, file contents and an executable consumer hook. Hashes are fake fixtures;
installed artifact identity is outside this tranche.

Before approval, Bash 3.2 syntax and byte-for-byte annotation removal passed.
The absent future CLI reported NOT PROBED with exit 2 before any test executed.
An always-successful /usr/bin/true control was rejected by all four entries.
Draft SHA-256: 522bfee85eca9cf1228797491fd60cb625795b5385f9cd6244633739eca92f64.
Independent review prompted multi-document JSON rejection, executable-hook
preservation and isolated Git configuration; these were incorporated before
human review. After approval, each entry observed an actual named failure,
then passed together with the full existing suite. The four entries are now
included in tests/run.sh; see config-validation.md for checkpoint evidence.
This is not evidence for the remaining v1 integration or distribution work.

The human subsequently requested `┎` review markers. The TDD skill, guide and
current review view now use language-appropriate `// ┎` or `# ┎` comments.
Removing only the added review explanations still reproduces the approved
source exactly; no runtime stripping or approved-test edit was introduced.

## Implemented release packaging tranche

PR #6 was merged as 3c9456d. The human requested continuation. Read-only
inspection found that init needs actual distribution commit/hash evidence
before it can create a meaningful lock. The existing hook embeds a checkout
path and doctor assumes a Git workspace, so introducing local init first
would either fake release identity or prematurely redesign dispatch.

Implement a local release packer before mode integration. See
[approved executable source](draft-release-tests.sh) and
[Korean annotated review](../../../docs/plans/sobaya-v1-release-review.md).
Four approved entries cover the pinned runtime archive and sidecar manifest,
repeatability/source isolation, invalid identity or payload, and preserving
existing outputs/source state. The human explicitly approved implementation
after the issue #4 rewrite; approval and verbatim materialization are c0afa00.
scripts/package-release.sh implements these entries and tests/run.sh includes
tests/test-release.sh. The approved test and review code remain unchanged.

The packer uses an explicit source root, exact release version, full commit,
matching local version tag, and a new output directory outside the source.
Its allowlist excludes workspace content and uses canonical tdd-set skills.
The manifest retains the existing runtime version/commit/sha256 tuple. A
checksum establishes identity, not authenticity. Full init/doctor/hook
usability and trusted release retrieval still need subsequent tests.

Draft checks: Bash 3.2 syntax and annotation/source equivalence pass; the
missing package-release.sh is NOT PROBED, not RED/GREEN. All four entries
reject an always-successful no-op control. No live network or model work
is part of these probes. Independent draft review found permission-bit and
output-symlink-target snapshot gaps plus a Git prerequisite-order issue.
All were fixed before approval; adversarial controls now fail as intended,
while a non-mutating diagnostic control can traverse the error fixtures.
Re-review found no remaining findings at draft SHA-256
bdc855b56d44cbb1dc60fdc1e256fa647a55dcb560a76906521a27e680473f24.
Those were test-draft checks, not packer RED/GREEN evidence. The subsequent
actual failures and full-suite checkpoints are recorded in release-validation.md.
The private shared clone overrides export attributes without changing source
configuration. Temporary files are staged beside the output, then mkdir claims
a new output directory. This does not guarantee crash-atomic visibility of both
files or safety under concurrent source mutation/object pruning.

## Installed runtime tranche

The human explicitly requested resuming installation, mode connection and bump
on 2026-10-04. Tests for all three stages were presented as
one review packet: [plan](install-flow-plan.md), [draft](draft-install-flow-tests.sh),
[Korean review](../../../docs/plans/sobaya-v1-install-flow-review.md).
The exact twelve entries and shared support were approved on 2026-10-05 after
PR #8's complete review view; see [approval](install-flow-approval.md).
The implementation provides the standalone verified installer, workspace-local
project/dependency connections, original hook forwarding and worktree isolation,
exact installed dispatch, reviewed-lock sync, and candidate-runtime bump checks
across all connected apps. Shared locks coordinate init, runtime and bump.
Candidate failure restores pins, protected approval metadata and Git hook
configuration; active entries cannot bump. No automatic commit or reapproval.
The source, review and materialized tests remain byte-identical after removing
only review explanations. Checkpoint and final-review evidence is recorded in
[install-flow-validation.md](install-flow-validation.md); the practical Korean
guide is [installed-runtime.md](../../../docs/installed-runtime.md).

## Release preparation

PR #7 and #8 were merged; main is 2d425116. Release exploration is recorded in
[the Korean readiness report](../../../docs/plans/sobaya-v1-release-readiness.md).
The actual v0.9 project-mode completed-state round trip preserved approval,
calls and usage with manual restoration of the original hooksPath. Active
entries reject cross-version resume before another worker call; same-origin
resume still works. Installed snapshots add workspace pin paths. Existing v0.9
managed hooks remain live dependencies and cause duplicate hygiene under the
v1 forwarding hook. This is not a demonstrated dependency-mode round trip or
an installable v0.9 downgrade. Do not erase snapshots or reapprove to bypass it.

Three interleaved source-workflow measurements per revision passed the exact
unchanged runner fixture. Medians: v0.9 4.099s, main 4.274s. Small sample,
overlapping ranges and concurrent VM setup prevent a performance verdict.
Installed dispatch and real-model cost/quality remain unmeasured. No threshold
has been invented. Crash-atomic two-document recovery is outside the current
approved implementation; normal failure/cancellation recovery is separate.

An isolated Linux VM runs genuine flock with jq 1.6. Existing approved tests
exposed valid-policy rejection caused by contains(NUL), fixed at 9de5e450
without changing tests. Follow-up fixes preserve terminal NUL records, protect
newline-named fixtures and stabilize Node 22/26 probe reporting. Both Linux and
macOS full suites pass at 8ce4f1d2. The exact Mac-built local candidate also installs
and reinstalls on Linux; the dedicated VM is stopped. Evidence
is in [release-readiness-validation.md](release-readiness-validation.md).

Consumer audit at poem-collaboration-harness-template 3db86615 found no committed
legacy lock: attach generates repo/sha/checked at harness/sobaya.lock. Sync
currently pulls a source branch and injects adapters. First adoption needs a
migration PR for connections, hook/worktree handling, lock ownership and
upstream release notifications. The template's own shell suites are outside
the current Go/Node/Vitest contract; supporting generated apps and treating the
template itself as an app are separate decisions. Do not invent main-branch
spec/plan approval. The first consumer selection and exact cloud-native-go
address are pending; no consumer mutation has been performed.

## Workspace

Continue release preparation on codex/sobaya-v1-release-readiness in the
existing sobaya-v1-plan managed worktree. v0.9.0 remains the published release;
local prerelease archives and isolated tags are diagnostics, not publication.
The original checkout contains unrelated user changes and must remain intact.
The four configuration, four packaging and twelve installed-flow entries are
approved. No real consumer app approval/checkpoint state is being changed.
Further test proposals remain drafts until separately reviewed.
