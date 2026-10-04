# Installed runtime, mode connection and bump

Status: implementation requested; exact new test inputs awaiting review.
On 2026-10-04 the human explicitly requested "승인한 구현 진행햐".
Automatic approval review rejected materializing and committing this draft as
approved because the exact new inputs had not yet been shown to the human.
The rejected command did not run. Complete one concrete review packet for
all three stages, then request approval of those inputs once; do not restart
the agreed architecture discussion or infer a new approval record.

Remote preflight: PR #6 merged at 3c9456d; PR #7 remains open at f6e0766.
origin/main still points to 3c9456d. Continue from f6e0766 on
codex/sobaya-v1-install-plan in the existing managed worktree. Leave the
original dirty checkout and other project work untouched. Stack a draft PR
on PR #7, without assuming or performing a merge or publishing v1.

## Proposed command contract

Bootstrap from a separately trusted standalone script:

```
bash tdd-set/lib/install-runtime.sh --root CONSUMER --install-root STORE \
  --version VERSION --manifest TRUSTED_JSON [--archive LOCAL_ARCHIVE]
```

No prior Sobaya command, mode, consumer Git repository or config is required
for bootstrap. Consumer must exist. STORE is explicit and outside it.
The installer validates one manifest object, exact version/artifact name and
runtime tuple, archive SHA, Git archive commit marker and permitted payload.
A commit marker is consistency evidence, not an independent provenance proof.
The human trusts the separately obtained manifest and bootstrap script.
Without --archive, download only the fixed team-poem/sobaya GitHub Releases
archive URL for that version, with HTTP failure and HTTPS-only redirects.
Do not accept arbitrary URLs from metadata or implicitly trust a remote manifest.

Use STORE/runtimes/VERSION/runtime, archive.tar.gz and manifest.json plus any
owned completion/integrity metadata. Success prints one object with runtime
and absolute runtime_path. A stable STORE/bin/sobaya is also provided.
Identical verified installs are idempotent. Different identity, altered files,
incomplete paths, files or links are conflicts, never automatic repair.
Do not select incomplete installations. Preserve other versions and consumer
data on failure. Standalone installer lives in tdd-set/lib because the approved
packer already includes that tree; do not change its exact two-output contract.

The stable CLI takes --root and --install-root, without storing personal
installation paths in shared sobaya.json or sobaya.lock:

```
sobaya init --root WORKSPACE --install-root STORE --mode dependency --version V
sobaya init --root WORKSPACE --install-root STORE --mode project --version V --app APP
sobaya sync --root WORKSPACE --install-root STORE [--archive LOCAL_ARCHIVE]
sobaya doctor|approve|step|loop|gate|status ... [--app APP] [existing runtime flags]
sobaya bump --root WORKSPACE --install-root STORE --version V \
  --manifest TRUSTED_JSON [--archive LOCAL_ARCHIVE]
```

Configuration check keeps its previously approved interface and read-only
semantics. Installed dispatch selects the exact local lock tuple once per
operation, never downloads or silently falls back, and preserves the current
approval/checkpoint engine. Protect workspace config/lock from worker mutation.
Installation integrity checks belong at invocation boundaries, not per-entry
downloads or extra model calls. Performance still needs release measurements.

## Connection scope

Project mode attaches an explicitly selected app under the existing workspace's
apps directory and preserves brain and workspace instructions. Repeating init
for another app registers it for workspace validation. Dependency mode uses
the consumer repository itself, preserving its existing monorepo layout.
Do not replace AGENTS.md, spec.md or failed-test.md; generated local connection
instructions and worker prompts name installed tdd-set/AGENTS.md explicitly.
No initialization, installation or sync invents approval or changes usage.

Generate owned hook forwarding/metadata outside tracked acceptance inputs.
Pre-commit invokes the original executable hook first; only success proceeds
to Sobaya hygiene. Preserve original files, symlinks, arguments, streams and
exit behavior. Forward existing supported hooks; do not generate executable
no-op hooks for absent protocols. Refuse unsupported/conflicting connection
shapes before modifying configuration rather than reporting false success.

Linked-worktree tests explicitly enable extensions.worktreeConfig before init.
Use worktree-specific hook configuration; never redirect a shared local setting
to one worktree's private metadata. Automatic migration of repositories with
common core.worktree/bare/sparse settings is not authorized by this packet.
Existing source-checkout commands and tests remain intact.

## Sync and bump

Sync installs exactly the existing reviewed config/lock and does not repin or
rewire the consumer. Bump verifies/installs the candidate, temporarily exposes
the candidate configuration for validation, and runs the full declared suite
and hygiene through the candidate runtime. Project bump checks every connected
app, not just the selected/first app. Preserve unknown config fields.

On successful bump leave only sobaya.json and sobaya.lock as reviewable changes;
do not commit, push or reapprove automatically. Preserve hooks, approval state,
call counts and completed review. On validation failure restore both original
documents exactly. Reject bump when an entry is active. Coordinate cooperating
operations with existing locks so a running runtime cannot be changed beneath
it. Do not replace the running shell files in place.

The initial tests cover ordinary validation/download/identity/path failures and
an interrupted entry, not SIGKILL/power-loss atomicity of two file renames or
hostile concurrent filesystem mutation. Config check must continue to fail
closed on mismatched documents. Full crash recovery, complex hook protocols,
fresh workspace scaffolding, published-asset smoke tests, genuine v0.9/v1/v0.9
compatibility, and performance parity remain explicit release work.

## Test and review discipline

Draft: draft-install-flow-tests.sh. Human review: the Korean
docs/plans/sobaya-v1-install-flow-review.md. All shared fixture code belongs
to approval. Fixture packages copy current runtime source into temporary Git
repositories, use the real packer, and inject only a suite-call trace wrapper
that delegates the real contract_suite. Workers are deterministic command
adapters; Node/Git/test gates remain real. curl/provider sentinels prevent
unintended calls; the download test substitutes acquisition only, not validation.

Before approval, run Bash 3.2 syntax, exact annotated-copy recovery, support
probes and no-op controls, then independent draft review. The absent installer
is NOT PROBED, not RED. After human approval materialize the exact draft and
record approval; do not create fake app approve.sh state for root Bash tests.
Progress one named entry at a time with real RED (or honest ALREADY GREEN),
the current/prior entries, the full existing suite and protected-input checks.
Register the full approved suite additively at the last checkpoint, and bind
independent completion review to the resulting commit before declaring done.
