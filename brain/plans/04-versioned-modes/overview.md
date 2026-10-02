# Versioned project and dependency modes

Status: architecture and the first four configuration-check entries authorized
on 2026-10-02. See [the exact approval record](config-approval.md). Implementation
is proceeding through those entries; later tranches remain unapproved drafts.
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

## Next bounded entry

Implement the approved read-only `sobaya config check --root PATH` command.
The exact command/output/lock schema and executable tests were reviewed at
574d9ee and explicitly approved by the human. The source is materialized
verbatim as tests/test-config.sh. Do not alter existing tests or spec.md.
The app probe supports Go/Node, not Bash: report a missing future CLI as NOT
PROBED, never as behavioral RED. After approval, use the root Bash harness
maintenance workflow, one reviewed entry at a time, with the full existing
suite and independent review. Do not invent a Node wrapper or call approve.sh
on the Sobaya root as though it were an app with approved spec.md.

Draft artifacts: [executable Bash](draft-config-tests.sh) and
[Korean review view](../../../docs/plans/sobaya-v1-config-review.md).
Four proposed entries cover explicit mode/version selection, input documents,
configuration fields, and matching lock data. Each invocation checks preservation
of paths, file contents and an executable consumer hook. Hashes are fake fixtures;
installed artifact identity is outside this tranche.

Validation: Bash 3.2 syntax and byte-for-byte annotation removal passed. The
absent future CLI reports NOT PROBED with exit 2 before any test entry executes.
An always-successful /usr/bin/true control is rejected by all four entries.
Draft SHA-256: 522bfee85eca9cf1228797491fd60cb625795b5385f9cd6244633739eca92f64.
Independent review prompted multi-document JSON rejection, executable-hook
preservation and isolated Git configuration; these were incorporated before
human review. None of these checks establishes behavioral RED/GREEN for v1.

## Subsequent work

Mode-specific init and hook/instruction composition; versioned distribution,
locked dispatch and bump; upgrade failure recovery and 0.9/1.0/0.9 state+hook
compatibility; performance comparison; prerelease consumer validation. Keep
runtime installations immutable during active runs. State version 1, approval
baselines, accumulated calls and interrupted entries need compatibility tests.
No performance threshold or guarantee has been invented; measure the existing
baseline, then expose comparison evidence before release.

Consumer evidence: poem-collaboration-harness-template already records repo/sha
in harness/sobaya.lock, but sync currently pulls its branch and only warns on
lock mismatch. Its integration must later be updated separately. The exact
cloud-native-go repository is still unknown and does not block core planning.

## Workspace

Work on codex/sobaya-v1-design in the attached sobaya-v1-plan managed worktree.
The original checkout contains unrelated user changes and must remain intact.
The first four entries are approved; no app approval/checkpoint state is being
changed. Further test proposals remain drafts until separately reviewed.
