#!/usr/bin/env bash
# Exercise the canonical harness with fake suites to verify coverage and failures.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TEMP=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-shards.XXXXXX")
trap 'rm -rf "$TEMP"' EXIT
mkdir -p "$TEMP/tests" "$TEMP/scripts" "$TEMP/tdd-set/bin" "$TEMP/tdd-set/lib" "$TEMP/tdd-set/hooks" "$TEMP/tdd-set/tests" "$TEMP/.githooks" "$TEMP/bin"
cp "$ROOT/tests/run.sh" "$TEMP/tests/run.sh"
: > "$TEMP/bin/sobaya"
git -C "$TEMP" init -q
for suite in tests/test-contract.sh tests/test-runner.sh tests/test-canon.sh tests/test-tools.sh tests/test-config.sh tests/test-release.sh tests/test-install-flow.sh tests/test-review-view.sh tdd-set/tests/next-entry.sh tdd-set/tests/probe-go-imports.sh tests/test-ci-shards.sh; do
  cat > "$TEMP/$suite" <<'SH'
printf '%s\n' "$0" >> "$SHARD_RECORD"
[ "${FAIL_SUITE:-}" != "${0##*/}" ]
SH
done
run_shard() {
  : > "$TEMP/record"
  (cd "$TEMP" && SHARD_RECORD="$TEMP/record" SOBAYA_CI_SHARD="$1" bash tests/run.sh > /dev/null)
  sed "s|$TEMP/||" "$TEMP/record" | sort > "$TEMP/$2"
}
run_shard all full
run_shard 1 first
run_shard 2 second
cat "$TEMP/first" "$TEMP/second" | sort > "$TEMP/combined"
cmp "$TEMP/full" "$TEMP/combined"
[ "$(wc -l < "$TEMP/full" | tr -d ' ')" -eq 11 ]
if (cd "$TEMP" && SHARD_RECORD="$TEMP/record" SOBAYA_CI_SHARD=invalid bash tests/run.sh > /dev/null 2>&1); then
  echo 'Invalid shard unexpectedly passed' >&2; exit 1
fi
if (cd "$TEMP" && SHARD_RECORD="$TEMP/record" SOBAYA_CI_SHARD=1 FAIL_SUITE=test-contract.sh bash tests/run.sh > /dev/null 2>&1); then
  echo 'Failing suite unexpectedly passed' >&2; exit 1
fi
printf 'PASS: shard coverage, invalid selection, and suite failure\n'
