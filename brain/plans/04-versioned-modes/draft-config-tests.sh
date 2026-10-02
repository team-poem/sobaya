#!/bin/bash
# DRAFT: proposed root-harness tests; not part of the approved suite.
set -eu
set -o pipefail

for tool in jq git; do command -v "$tool" >/dev/null || { printf "NOT PROBED: missing %s\n" "$tool" >&2; exit 2; }; done
ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
CLI=${SOBAYA_CLI:-"$ROOT/bin/sobaya"}
case "$CLI" in /*) ;; *) printf "NOT PROBED: SOBAYA_CLI must be absolute\n" >&2; exit 2 ;; esac
[ -x "$CLI" ] || { printf "NOT PROBED: future CLI is absent: %s\n" "$CLI" >&2; exit 2; }
export SOBAYA_CLI="$CLI"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

fail() { printf "FAIL: %s\n" "$*" >&2; exit 1; }
snapshot() {
  (cd "$APP"; find . -print | LC_ALL=C sort; find . -type f -exec cksum {} \; | LC_ALL=C sort) > "$1"
}
setup() {
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-config-draft.XXXXXX")
  trap 'rm -rf "$WORK"' EXIT
  APP="$WORK/workspace's path"
  COMMIT=0123456789abcdef0123456789abcdef01234567
  SHA256=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
}
fixture() {
  rm -rf "$APP"
  mkdir -p "$APP/.githooks"
  git -C "$APP" init -q
  git -C "$APP" config core.hooksPath .githooks
  mkdir -p "$APP/.git/sobaya"
  printf "Existing consumer instructions\n" > "$APP/AGENTS.md"
  printf "#!/bin/sh\nexit 0\n" > "$APP/.githooks/pre-commit"
  chmod 755 "$APP/.githooks/pre-commit"
  printf '{"version":1,"calls":7,"active":null}\n' > "$APP/.git/sobaya/state.json"
  jq -n --arg mode "$1" --arg version "$2" '{config_version:1,mode:$mode,runtime:{version:$version}}' > "$APP/sobaya.json"
  jq -n --arg version "$2" --arg commit "$COMMIT" --arg sha256 "$SHA256" '{lock_version:1,runtime:{version:$version,commit:$commit,sha256:$sha256}}' > "$APP/sobaya.lock"
}
rewrite() {
  jq "$2" "$APP/$1" > "$WORK/changed.json"
  mv "$WORK/changed.json" "$APP/$1"
}
invoke() {
  snapshot "$WORK/before"
  if (cd "$WORK"; "$CLI" config check --root "$APP") > "$WORK/stdout" 2> "$WORK/stderr"; then RC=0; else RC=$?; fi
  snapshot "$WORK/after"
  cmp -s "$WORK/before" "$WORK/after" || fail "config check changed workspace content or paths"
  [ -x "$APP/.githooks/pre-commit" ] || fail "config check disabled existing hook"
}
expect_valid() {
  invoke
  [ "$RC" -eq 0 ] || fail "valid config returned $RC"
  [ ! -s "$WORK/stderr" ] || fail "valid config wrote stderr"
  expected=$(jq -n --slurpfile config "$APP/sobaya.json" --slurpfile lock "$APP/sobaya.lock" '{config_version:$config[0].config_version,mode:$config[0].mode,runtime:$lock[0].runtime}')
  jq -e -s --argjson expected "$expected" 'length == 1 and .[0] == $expected' "$WORK/stdout" >/dev/null || fail "wrong selected configuration"
}
expect_invalid() {
  invoke
  [ "$RC" -eq 2 ] || fail "invalid config returned $RC instead of 2"
  [ ! -s "$WORK/stdout" ] || fail "invalid config wrote stdout"
  grep -Fq -- "$1" "$WORK/stderr" || fail "diagnostic must identify $1"
}

config_selects_explicit_mode() {
  for mode in project dependency; do
    fixture "$mode" 1.0.0
    expect_valid
  done
  for version in 0.9.0 1.0.0-rc.1; do
    fixture dependency "$version"
    expect_valid
  done
}

config_rejects_missing_or_malformed_input() {
  fixture dependency 1.0.0
  mkdir -p "$APP/apps" "$APP/brain"
  rm "$APP/sobaya.json"
  expect_invalid sobaya.json
  for text in '' '{' '[]' 'null' 'true'; do
    fixture dependency 1.0.0
    printf "%s" "$text" > "$APP/sobaya.json"
    expect_invalid sobaya.json
  done
  fixture dependency 1.0.0
  cat "$APP/sobaya.json" "$APP/sobaya.json" > "$WORK/two.json"
  mv "$WORK/two.json" "$APP/sobaya.json"
  expect_invalid sobaya.json
}

config_rejects_invalid_fields() {
  for change in 'del(.config_version)' '.config_version = 2' '.config_version = "1"'; do
    fixture dependency 1.0.0
    rewrite sobaya.json "$change"
    expect_invalid config_version
  done
  for change in 'del(.mode)' '.mode = "automatic"' '.mode = 1'; do
    fixture dependency 1.0.0
    rewrite sobaya.json "$change"
    expect_invalid mode
  done
  for change in 'del(.runtime)' '.runtime = []' 'del(.runtime.version)' '.runtime.version = 1'; do
    fixture dependency 1.0.0
    rewrite sobaya.json "$change"
    expect_invalid runtime
  done
  for version in "" main latest "^1.0.0" v1.0.0 01.0.0; do
    fixture dependency "$version"
    expect_invalid runtime.version
  done
}

lock_requires_exact_matching_runtime() {
  fixture dependency 1.0.0
  rm "$APP/sobaya.lock"
  expect_invalid sobaya.lock
  for text in '{' '[]'; do
    fixture dependency 1.0.0
    printf "%s" "$text" > "$APP/sobaya.lock"
    expect_invalid sobaya.lock
  done
  fixture dependency 1.0.0
  cat "$APP/sobaya.lock" "$APP/sobaya.lock" > "$WORK/two.json"
  mv "$WORK/two.json" "$APP/sobaya.lock"
  expect_invalid sobaya.lock
  for change in 'del(.lock_version)' '.lock_version = 2' '.lock_version = "1"'; do
    fixture dependency 1.0.0
    rewrite sobaya.lock "$change"
    expect_invalid lock_version
  done
  fixture dependency 1.0.0
  rewrite sobaya.lock '.runtime.version = "1.0.1"'
  expect_invalid runtime.version
  for change in 'del(.runtime)' '.runtime = []' 'del(.runtime.version)'; do
    fixture dependency 1.0.0
    rewrite sobaya.lock "$change"
    expect_invalid runtime
  done
  for change in 'del(.runtime.commit)' '.runtime.commit = "0123456"' '.runtime.commit = "main"' '.runtime.commit = ("g" * 40)'; do
    fixture dependency 1.0.0
    rewrite sobaya.lock "$change"
    expect_invalid runtime.commit
  done
  for change in 'del(.runtime.sha256)' '.runtime.sha256 = "01234567"' '.runtime.sha256 = ("g" * 64)'; do
    fixture dependency 1.0.0
    rewrite sobaya.lock "$change"
    expect_invalid runtime.sha256
  done
}

if [ "${1:-}" = __case ]; then
  setup
  "$2"
  exit
fi
failures=0
for name in config_selects_explicit_mode config_rejects_missing_or_malformed_input config_rejects_invalid_fields lock_requires_exact_matching_runtime; do
  if /bin/bash "$0" __case "$name"; then
    printf "PASS: %s\n" "$name"
  else
    printf "FAIL: %s\n" "$name"
    failures=$((failures + 1))
  fi
done
[ "$failures" -eq 0 ]
