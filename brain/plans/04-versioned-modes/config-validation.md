# Configuration check validation

Approved test source SHA-256:
`522bfee85eca9cf1228797491fd60cb625795b5385f9cd6244633739eca92f64`.
Approval is recorded in config-approval.md at commit 9b0baf1. Existing app
approval state is not used or changed by this root-maintenance work.

Each checkpoint runs the approved current/prior entries with
`/bin/bash tests/test-config.sh __case NAME` and the entire existing
`tests/run.sh` suite with local Vitest available through
`SOBAYA_TEST_VITEST_ROOT`. Full-suite runs execute real Node, Go and Vitest,
38 contract cases, 27 runner cases, 67 tools cases, and next/probe/gate
regressions. Workers are deterministic fixtures, without paid model calls.

## Entry 1

`config_selects_explicit_mode`: an executable response-only CLI scaffold
returned 2; the actual named assertion failed with `valid config returned 2`.
This is separate from the pre-approval missing-command NOT PROBED result.
The implementation then selected the explicit workspace's mode/version/lock
data. The approved entry and full existing suite passed; approved source and
materialized test compared byte-for-byte. No installation, network or worker
operation was added.

## Entry 2

`config_rejects_missing_or_malformed_input`: before document validation,
the named assertion failed with `invalid config returned 0 instead of 2`.
Each slurped file now requires exactly one JSON object; jq read/parse errors
retain their filename diagnostics and the CLI normalizes failure to exit 2.
Entries 1–2 and the full existing suite passed. The approved test source
remains byte-for-byte identical to tests/test-config.sh.

## Entry 3

`config_rejects_invalid_fields`: before field validation, the named assertion
failed with `invalid config returned 0 instead of 2`. Configuration schema,
explicit mode, runtime object and exact release-version syntax are now checked
before output. Versions retain their spelling; branch aliases, ranges and a
v prefix are rejected. Entries 1–3 and the full existing suite passed; the
approved test source still compares byte-for-byte with tests/test-config.sh.

## Entry 4 and integrated suite

`lock_requires_exact_matching_runtime`: before lock-field validation, the
named assertion failed with `invalid config returned 0 instead of 2`.
The lock now requires schema version 1, an object runtime, the exact configured
version, a full 40-digit hexadecimal commit and a 64-digit hexadecimal SHA-256.
Absolute regex anchors reject trailing newlines as part of a version or hash.

All four approved entries passed. tests/run.sh now includes tests/test-config.sh
without changing its approved bytes or removing any existing suite; its
interpreter scan also includes the extensionless bin/sobaya launcher. The
entire integrated suite passed with real Node, Go and local Vitest. Bash 3.2
syntax and git diff --check passed. No worker, gate or approval implementation
changed. These checks validate local metadata, not artifact authenticity or
overall v1 installation/rollback/performance compatibility.

An independent completion review must be bound to the resulting revision;
its result is reported with the final commit in PR #6.
