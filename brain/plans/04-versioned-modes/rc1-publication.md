# v1.0.0-rc.1 publication

The human said to proceed after PR #9 and the proposed prerelease/consumer
validation sequence. Read-only refresh found PR #9 already merged by the human
at d06384544e81cd373d81e2a940ab336868e04854. Root did not merge it again.

Published [v1.0.0-rc.1](https://github.com/team-poem/sobaya/releases/tag/v1.0.0-rc.1)
on 2026-10-06 at 04:25:57 UTC. GitHub reports draft=false and prerelease=true;
the tag resolves directly to d06384544e81cd373d81e2a940ab336868e04854.
The latest stable release remains v0.9.0.

## Published identity

| Asset | SHA-256 |
|---|---|
| install-runtime.sh | 4f2201dfe8afe7041233451bcfd4de24b86a9e3ddd5558f5e525bba9d7fb2ccf |
| sobaya-1.0.0-rc.1.json | e19564a05a104e4f38c4403495d100ede632d7c844daf64fae67adeada3b3e26 |
| sobaya-1.0.0-rc.1.tar.gz | d8b4e49a149a0e637c94a6663fb6433b8d0621dc376e31d776babbea247551b8 |

The earlier local candidate at 8ce4f1d2 used a different archive hash. Never
substitute it for this public release. Published tags/assets were not moved
or overwritten.

## Verification

Independent preflight found the merge tree identical to final receipt5ec9548;
runtime/test bytes match the macOS/Linux validated 8ce4f1d2 revision. Existing
full-suite evidence therefore applies; no code or accepted test changed.

Packaged the exact merge twice in an isolated clone with its matching local
tag. Both archive/manifest pairs are byte-identical. Standalone install and
reinstall return the same identity. Independent review inspected all 66
allowlisted payload files and modes against the commit, bootstrap identity,
installed files, archive commit marker and release notes; no findings remained.
Reviewed notes SHA-256: 59b22f90b4d9911fbbca6d2f1a1bcaa679a1d655875709c571ded4bcd1ff0930.

Uploaded all three assets into a draft prerelease, downloaded them back and
compared every byte with the reviewed local files. GitHub's asset digests match
the table. Published with prerelease=true and latest=false, then verified the
public tag, release metadata and latest-stable API response.

Fetched public bootstrap/manifest URLs with unauthenticated HTTPS and compared
their bytes. The downloaded bootstrap installed into a fresh external store
without --archive, exercising its real fixed GitHub archive URL and identity
checks. It selected the exact d0638454/d8b4e49a tuple. No app approval or paid
model was involved in this download/install check.

The actual public payload also passed a separate two-mode fixture smoke.
Reused the approved installed-cycle body and support verbatim, redirecting only
asset resolution to the verified public release and adding command capture.
Dependency and project mode each passed init, fixture approval, actual RED/GREEN
and full declared Node suite, Git checkpoint, deterministic review, gate and
status. Each retained its baseline with calls=2 and exact review HEAD; app trees
were clean and status preserved metadata. Provider/network sentinels were unused.
This is published-artifact fixture validation, not real Poem acceptance or a
live-model review. Evidence: /private/tmp/sobaya-public-smoke-evidence.ZgrLOI/.

Evidence: /private/tmp/sobaya-rc1-publish.LZ5rI2/ contains source, reviewed
assets/notes, repeat receipts, draft-download, public-download, published.json,
published-tag.json, latest.json and public-install.json.

## Consumer preflight and next decision

Poem main is 1ebbf5f350be98d0d4c9fd8915cde753d90a66ce. Its unchanged suites pass
hooks84/loop48/sobaya32 in isolated repositories with local remotes. Evidence:
/private/tmp/sobaya-poem-adoption.BF4CUw/. PR #3 removed app CLAUDE.md symlinks;
preserve that change. Its issue #4 requests broader template relocation/library
packaging, which is separate from this connection work. No duplicate v1 adoption
PR was found.

Asked the human to select first support for generated Go/Node apps (recommended)
or expansion to run the Bash-only template itself through Sobaya TDD. The latter
requires an explicitly reviewed shell-test evidence/plan interface. Main's
placeholder Test and absent spec/plan must not be fabricated into an approval.
No consumer code, pin or approval has changed and no consumer PR has been sent.

For generated apps, prepare an opt-in installed adapter while retaining legacy
connections. Proposed future cases cover exact pin sync, existing-contract
preservation, missing feature inputs, hook health after join, collaboration
before Sobaya hygiene, explicit legacy-hook conflicts, worktree isolation,
live-lock detection, candidate rollback and plan-archive pin preservation.
These are design candidates, not approved executable tests. The exact CLI and
tests require a human-reviewed draft before implementation.

Real consumer adoption, real-model cost/quality comparison, active cross-version
resume, automatic legacy-hook migration and crash-atomic recovery are not
claimed by this publication. v0.9 remains a source-checkout fallback with the
previously recorded completed-project/manual-hook-restoration limits.
