# Release packaging approval

On 2026-10-02 the human replied "승인한 구현 진행햐" after reviewing the
four release-packaging entries and shared support in Draft PR #7. This
authorizes implementation of those exact inputs at commit
5a53042ff47b9401eb14e613bb93db06658d0c73, not the later installation/init/bump
tranches. The intervening request to rewrite issue #4 was not test approval.

Approved source: brain/plans/04-versioned-modes/draft-release-tests.sh.
SHA-256: bdc855b56d44cbb1dc60fdc1e256fa647a55dcb560a76906521a27e680473f24.
The exact source is materialized as tests/test-release.sh, preserving even
its historical DRAFT comment. No comments are stripped at runtime.
The human review view is docs/plans/sobaya-v1-release-review.md; removing
only its added explanation lines recovers the approved bytes.

Approved entries, in order:

1. package_pins_runtime_and_manifest
2. package_is_repeatable_from_pinned_commit
3. package_rejects_invalid_identity_and_payload
4. package_preserves_existing_output_and_source

This is root Bash harness maintenance. Do not create an app baseline with
approve.sh: the app parser supports Go/Node, not these shell entries. Run
each entry's actual failure before its implementation (or record ALREADY
GREEN honestly), then the current/prior entries and the full existing
tests/run.sh suite at each checkpoint. Add the approved full release suite
to tests/run.sh at the final checkpoint without changing its bytes or
removing any existing suite. Bind independent completion review to the
resulting revision before reporting completion.

The missing packager previously produced NOT PROBED, not behavioral RED.
A response-only script can now expose the approved command so the first
named test can observe an actual unsuccessful response.
