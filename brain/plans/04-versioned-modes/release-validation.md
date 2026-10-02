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
