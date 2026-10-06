# Release packaging validation

Approved source SHA-256:
`bdc855b56d44cbb1dc60fdc1e256fa647a55dcb560a76906521a27e680473f24`.
Approval and the verbatim tests/test-release.sh were committed at c0afa00;
see release-approval.md. No app approval state is created or changed.

Each checkpoint runs the approved current/prior entries with
`/bin/bash tests/test-release.sh __case NAME`, compares the materialized file
with the approved source, and runs the entire existing tests/run.sh with
local Vitest supplied through SOBAYA_TEST_VITEST_ROOT. Those suites execute
real Node, Go and Vitest with deterministic workers, without paid model calls.

## Entry 1

`package_pins_runtime_and_manifest`: a response-only script returned 2 and
the named assertion failed with `valid package returned 2`. This is actual
behavioral RED, separate from the earlier missing-script NOT PROBED result.
The minimal packer then archived the selected committed runtime files with
their executable modes and wrote a sidecar manifest using the completed
archive's SHA-256. The focused entry passed, including the extracted CLI's
read-only config check against manifest-derived consumer metadata.
The full existing suite passed, as did Bash 3.2 syntax, git diff --check,
and the byte-for-byte approved-source comparison.

## Entry 2

`package_is_repeatable_from_pinned_commit`: the actual test failed when tar
could not find `sobaya/bin/sobaya`, excluded by the committed export-ignore
attribute. A temporary shared bare Git clone now overrides export-ignore and
export-subst through its own info/attributes, never modifying the source.
Entries 1–2 passed: archive/manifest bytes repeat despite dirty source files
or an annotated tag, and export attributes no longer change selected bytes.
The full existing suite, Bash 3.2 syntax, git diff --check and the unchanged
approved-source comparison all passed before this checkpoint.

## Entry 3

`package_rejects_invalid_identity_and_payload`: the pre-validation packer
failed the named assertion with `invalid package returned 0 instead of 2`.
It now requires exact SemVer, a full existing commit object, a repository
root, and a matching local version tag. It checks required runtime roots
and rejects non-regular selected entries, including symlinks and gitlinks.
Inherited repository-selection environment and replacement objects cannot
redirect these reads away from the explicitly selected commit/source.
Entries 1–3, the full existing suite, Bash 3.2 syntax, git diff --check and
the byte-for-byte approved-source comparison passed at this checkpoint.

## Entry 4 and integrated suite

`package_preserves_existing_output_and_source`: the named source snapshot
assertion failed with `packaging changed the source repository` because a
source-contained output was accepted. The packer now resolves physical paths
and rejects such outputs before staging. Temporary files are created beside
the output, so even a source-contained TMPDIR cannot change source content.
Existing output directories, files and symlinks are refused; final mkdir
claims a new directory only after archive and manifest preparation.

tests/run.sh includes the complete approved test-release.sh additively.
All four release entries and the full integrated suite passed with real Node,
Go and local Vitest. Bash 3.2 syntax, git diff --check, approved-source equality
and exact recovery of the executable source after removing only the review
explanations passed. Each of the four entries has actual RED evidence above;
none was reported as ALREADY GREEN or inferred from a worker report.

Independent completion review must be bound to the resulting revision before
reporting completion. No installer, init, dispatch, bump, public release, or
app acceptance/state transition is introduced by the packer. Same-environment
repeatability is demonstrated, not cross-platform archive equality, atomic
two-file visibility, concurrent source mutation/pruning safety, trusted remote
retrieval, v0.9/v1 rollback compatibility, or model-performance parity.

## Independent review corrections

Review of e927727 found two violations of the existing approved contract:
a dangling output symlink with a trailing slash was followed and its target
created, and global Git tar.umask=0111 removed executable/traversal bits.
Both were reproduced against that clean commit before implementation changes.
The approved test baseline remains unchanged.

The packer strips trailing output separators before checking the original
entry and requires that entry's parent to exist before resolving paths. It
also overrides tar.umask with 0022: Git initializes tar modes to 0666/0777,
so this retains committed 0644/0755 modes in the archive headers themselves.
Re-running the independent reproducer now returns 2 with empty stdout and
no created symlink target; the conflicting global mask still yields an
executable CLI. Direct tar-header inspection confirms 0755 for bin/sobaya
and 0644 for AGENTS.md, independent of extraction umask.
After these corrections, all four approved packaging entries and the full
integrated suite passed again, alongside Bash 3.2 syntax, git diff --check,
approved-source equality and review-copy recovery. Independent re-review is
bound to the resulting correction commit; its outcome is recorded in PR #7.
