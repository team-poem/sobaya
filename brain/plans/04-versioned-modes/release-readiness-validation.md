# Release-readiness evidence

The human requested validation and release preparation after merging PR #7/#8.
No public v1 tag/release or consumer PR is part of this completed evidence.
Read the [Korean release report](../../../docs/plans/sobaya-v1-release-readiness.md)
for consumer scope, version-return limitations and release sequencing.

## Runtime corrections

Starting main: 2d425116ce3649dae8daee1a4848fc28a3b34647.
Validation runtime: 8ce4f1d28aaf20c1284cc10c726704e73469a78e.
The original approved suites, test bodies, fixtures and headers are unchanged.
No app spec or real consumer approval was edited. The corrections implement
existing policy validity, exact-input protection and draft-probe classification.

1. Linux jq 1.6 rejected valid policies because contains(NUL) returns true even
   for ordinary strings. Existing installed-flow entries 7/8/10/11 failed.
   9de5e450 checks decoded codepoint 0 instead, preserving nonblank/type checks.
2. After that fix, entries 7/10 still rejected their real verbatim test source.
   jq 1.6 raw slurp removes terminal NUL bytes, and the existing split/slice
   drops the last actual record. 9296d8da appends a disposable non-NUL final
   record to three producer streams and preserves producer errors with pipefail.
   Empty final argv stays meaningful. The separate --rawfile input is unaffected.
3. Independent inspection reproduced mutation of a protected newline-named
   fixture passing the old gate. 607064c0 changes the tree capture flag to m,
   preserving exact newlines, tabs, Unicode and modes. The real gate now rejects
   mutation and accepts restored bytes on jq 1.6 and jq 1.7.1.
4. Linux's unchanged tools suite exposed entries 47/48: Node 22 defaults to TAP
   and separates ReferenceError name/message, so the probe misclassified an
   unapproved missing symbol as generic RED. 8ce4f1d2 explicitly requests spec
   output, matching Node 26. The disposable one-flag candidate passed all 67
   existing tools tests; eleven independent Node 26 boundary probes also passed.
   Full acceptance TAP parsing, Go and Vitest branches are unchanged.

Independent review found no remaining runtime issues at exact 8ce4f1d2 and no
new actionable documentation issue. It confirmed the unchanged approved hashes,
Linux final suite and supplementary evidence, and bounded migration/performance
claims. Final completion review at 2d249fb447c9fbd2d8ce3bca5c860df055a06777
confirmed the macOS/Linux suite results, cross-platform artifact installation,
unchanged runtime bytes, clean checkout and accurate release/adoption limits;
no actionable findings remained. The subsequent edit only records this receipt.

## Integrated results

Both Linux and macOS exact 8ce4f1d2 full tests/run.sh exited 0 with the final
all-suites PASS. Linux also asserted its source checkout clean. All twelve installation entries, contract 38,
runner 27, tools 67, configuration/release and next/probe/verbatim regressions
ran. Bash 3.2 syntax, ShellCheck error checks and git diff --check passed.

Supplementary actual-gate newline preservation/rejection passed under jq 1.6
as well as the reviewer's jq 1.7.1. The exact Mac-built final local candidate
also installed and reinstalled on Linux without network, with matching identity,
retained archive bytes and an untouched empty consumer. No claim of cross-OS
archive-build byte equality is made.

The dedicated Linux profile is stopped, all test containers exited normally,
and the default Docker context remains desktop-linux. Existing profiles were
not started, stopped or reconfigured. No background validation remains.

## Exact approved inputs

- Installed-flow executable/draft: b27ddd26f4d6e13f8a11d11d5df2cab5278547445082e5462de5797d580080c0.
- Release executable/draft: bdc855b56d44cbb1dc60fdc1e256fa647a55dcb560a76906521a27e680473f24.
- Existing runner test: 6202c3d38a3022c4b7114eda317ba97cf0d92f30f620b280beebe55b02d9791c.

## Environment and reproduction

macOS 26.6 arm64, system Bash 3.2.57, jq 1.7.1, Git 2.50.1, Node 26.5.1,
real Go and the existing Vitest tree. Canonical command:

```bash
TMPDIR=/private/tmp \
SOBAYA_TEST_VITEST_ROOT=/Users/kangminkim/lunch/sobaya/apps/bdad-mentor-match \
/bin/bash tests/run.sh
```

Linux uses a dedicated Colima profile, source pinned by a Git bundle, no host
mounts, a non-root Debian/Node container and --network none during tests.
Bash 5.2.15, jq 1.6, Git 2.39.5, Node 22.23.3, Go 1.26.3, Vitest 3.2.4,
GNU tar 1.34 and util-linux flock 2.38.1; no shlock. Canonical tests/run.sh is
unchanged. Existing host profiles and the default Docker context are preserved.

Local evidence locations (diagnostic files, not public release assets):

- /private/tmp/sobaya-release-readiness-macos-final.log
- /private/tmp/sobaya-linux-validation.QfRjLY/: initial failures, raw jq/Node
  reproductions, sentinel/error probes, newline gate, full-final.log and image recipe.
- /private/tmp/sobaya-release-final-candidate.dLfKAy/: local-only rc.1 package,
  repeated package/install outputs and SHA256SUMS at exact runtime 8ce4f1d2.
- /private/tmp/sobaya-compat-evidence.JcgDko/: exact v0.9/project-mode source
  return exploration; reproduction scripts, identity, preserved states/usage.
- /private/tmp/sobaya-release-perf.nuQ9ZZ/: unchanged source-workflow fixture,
  interleaved raw timings, environment and results.tsv at old/main revisions.

These exploratory probes do not approve new migration acceptance criteria.
No paid models or live consumer adoption ran. Cross-platform archive build-byte
equality, crash-atomic recovery, active version handover and dependency-mode
v0.9 return remain outside the demonstrated result.
