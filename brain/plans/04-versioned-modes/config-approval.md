# Configuration check approval

The human explicitly replied "승인한다" on 2026-10-02 to the request to approve
the four configuration-check entries and their shared support. This approval
covers the CLI input/output contract, proposed lock fields and exact executable
tests reviewed at commit 574d9ee9482cfe6ac8a9d83740aca14872bcb0f4.

Approved source: `brain/plans/04-versioned-modes/draft-config-tests.sh`.
SHA-256: `522bfee85eca9cf1228797491fd60cb625795b5385f9cd6244633739eca92f64`.
The Korean review view is `docs/plans/sobaya-v1-config-review.md`; removing only
its added explanation lines reproduces that source exactly.

Approved entries, in order:

1. `config_selects_explicit_mode`
2. `config_rejects_missing_or_malformed_input`
3. `config_rejects_invalid_fields`
4. `lock_requires_exact_matching_runtime`

Materialize the approved file verbatim as `tests/test-config.sh`. Its historical
DRAFT comment is preserved as part of the approved bytes; this receipt records
its current approval. Do not revise bodies, fixtures or support to obtain green.

This is root Bash harness maintenance, not an app acceptance plan. The existing
app plan parser does not support Bash entries; do not create a fake app baseline
with approve.sh. Validate one entry at a time, retain receipts for actual named
failures/passes, run the full existing suite at checkpoints, and integrate the
complete approved suite into tests/run.sh at the final checkpoint. Review the
result independently before reporting completion.

Initial execution previously returned NOT PROBED because bin/sobaya did not
exist. An executable CLI scaffold may now expose the approved interface so the
named test can observe a real unsuccessful response before behavior is added.
This is not permission to treat a missing command as behavioral RED.

Approval does not include future init, installation, distribution, bump,
downgrade, mode-transition or performance-test proposals.
