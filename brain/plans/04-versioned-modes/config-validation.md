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

Subsequent entries are not yet claimed green by this checkpoint.
