#!/bin/bash
# Probe exactly one candidate: RED=0, GREEN=1, ERROR=2.
set -u
set -o pipefail
TOOLS_DIR=$(cd "$(dirname "$0")" && pwd -P)
. "$TOOLS_DIR/tools-common.sh"
error() { printf 'ERROR  %s\n' "$*"; exit 2; }
[ $# -ge 2 ] && [ $# -le 3 ] || error 'usage: probe.sh DIRECTORY SNIPPET|- [HEADER]'
dir=$(tools_abs "$1") || error 'invalid test directory'
[ -d "$dir" ] || error "test directory not found: $dir"
src=$2; header=${3:-}; timeout=${SOBAYA_PROBE_TIMEOUT:-30}; case "$timeout" in .*) timeout=0$timeout ;; esac
printf '%s\n' "$timeout" | grep -qE '^([0-9]+([.][0-9]+)?|[.][0-9]+)$' && awk -v n="$timeout" 'BEGIN {exit !(n>0)}' || error 'SOBAYA_PROBE_TIMEOUT must be positive seconds'
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-probe.XXXXXX") || error 'cannot create diagnostics directory'
probe=; base=
cleanup() { [ -z "$probe" ] || rm -f "$probe"; [ -z "$base" ] || rm -f "$base"; rm -rf "$tmp"; }
trap cleanup EXIT
if [ "$src" = - ]; then cat > "$tmp/snippet"; else cat "$src" > "$tmp/snippet" || error "cannot read snippet: $src"; fi
[ -z "$header" ] || [ -f "$header" ] || error "header not found: $header"
root=$dir
while [ ! -f "$root/go.mod" ] && [ ! -f "$root/package.json" ]; do
  [ "$root" != / ] || error "no go.mod or package.json above $dir"
  root=$(dirname "$root")
done
runtime() { command -v "$1" >/dev/null 2>&1 || error "missing runtime: $1"; }
runtime jq
isgo=0; vitest=0
if [ -f "$root/go.mod" ]; then
  isgo=1; runtime go; runtime gofmt
  grep -oE 'func[[:space:]]+Test[A-Za-z0-9_]+[[:space:]]*\(' "$tmp/snippet" | sed -E 's/^func[[:space:]]+//;s/[[:space:]]*\($//' > "$tmp/names"
  pkg=
  for file in "$dir"/*.go; do
    [ -f "$file" ] || continue; case "$file" in *_test.go) continue ;; esac
    pkg=$(sed -nE 's/^package[[:space:]]+([A-Za-z0-9_]+).*/\1/p' "$file" | head -n 1)
    [ -z "$pkg" ] || break
  done
  if [ -z "$pkg" ]; then
    for file in "$dir"/*_test.go; do [ -f "$file" ] || continue; pkg=$(sed -nE 's/^package[[:space:]]+([A-Za-z0-9_]+).*/\1/p' "$file" | head -n 1); [ -z "$pkg" ] || break; done
  fi
  pkg=${pkg:-main}; suffix=_test.go
else
  runtime node
  grep -oE "(test|it)[[:space:]]*\([[:space:]]*['\"][^'\"]+" "$tmp/snippet" | sed -E "s/^(test|it)[[:space:]]*\([[:space:]]*['\"]//" > "$tmp/names"
  jq -e 'type=="object"' "$root/package.json" >/dev/null || error 'invalid package.json'
  if jq -e '((.dependencies // {}) + (.devDependencies // {})) | has("vitest")' "$root/package.json" >/dev/null; then
    vitest=1; runtime npx
    [ -f "$root/node_modules/.bin/vitest" ] || error 'vitest is not installed locally; install dependencies before probing'
  fi
  ext=js
  if [ -f "$root/tsconfig.json" ] || jq -e '((.dependencies // {}) + (.devDependencies // {})) | has("typescript")' "$root/package.json" >/dev/null; then ext=ts; fi
  suffix=.test.$ext
fi
[ "$(wc -l < "$tmp/names" | tr -d ' ')" = 1 ] || error 'snippet must contain exactly one named test'
IFS= read -r name < "$tmp/names"
base=$(mktemp "$dir/zz_sobaya_probe_XXXXXX") || error 'cannot create probe file'
probe=$base$suffix
[ ! -e "$probe" ] || error 'probe filename collision'
mv "$base" "$probe" || error 'cannot create test file'; base=
if [ "$isgo" = 1 ]; then
  { printf 'package %s\n\n' "$pkg"; grep -qE '^import([[:space:]]|\()' "$tmp/snippet" || printf 'import "testing"\n\n'; cat "$tmp/snippet"; printf '\n'; } > "$probe"
else
  { if [ -n "$header" ]; then cat "$header"; printf '\n'; fi; cat "$tmp/snippet"; printf '\n'; } > "$probe"
fi
common=$TOOLS_DIR/../tdd-set/lib/common.sh
[ -f "$common" ] || error 'shared execution helper is missing'
. "$common"
execute() {
  local cwd=$1; shift
  rc=0
  SOBAYA_WORKER_RECORD="$tmp/process.json" sb_run "$timeout" "$tmp/out" "$tmp/err" /dev/null "$cwd" -- "$@" || rc=$?
  cat "$tmp/out" "$tmp/err" > "$tmp/combined"
  case "$rc" in 124) cat "$tmp/combined"; error "timeout after ${timeout}s" ;; 130) cat "$tmp/combined"; error 'probe canceled; process group stopped' ;; 127) cat "$tmp/combined"; error 'runtime could not start' ;; esac
  [ "$rc" -lt 128 ] || { cat "$tmp/combined"; error "runner terminated by signal (status $rc)"; }
}
pattern=$(printf '%s' "$name" | sed 's/[][\\.^$*+?(){}|]/\\&/g')
if [ "$isgo" = 1 ]; then
  execute "$dir" gofmt -e "$probe"
  [ "$rc" = 0 ] || { cat "$tmp/combined"; error 'Go syntax error'; }
  rel=${dir#"$root"}; rel=${rel#/}; rel=${rel:-.}
  execute "$root" go test -json "./$rel" -run "^$pattern\$" -count=1
  jq -Rr --arg name "$name" 'fromjson? | select(.Test==$name) | .Action' "$tmp/combined" > "$tmp/actions"
  jq -Rj '. as $line | (try fromjson catch {Output:($line+"\n")}) | .Output // empty' "$tmp/combined" > "$tmp/diagnostics"
elif [ "$vitest" = 1 ]; then
  rel=${probe#"$root/"}
  execute "$root" npx --no-install vitest run "$rel" -t "^$pattern\$"
  cp "$tmp/combined" "$tmp/diagnostics"
else
  execute "$root" node --check "$probe"
  [ "$rc" = 0 ] || { cat "$tmp/combined"; error 'Node syntax/runtime error'; }
  execute "$root" node --test "--test-name-pattern=^$pattern\$" "${probe#"$root/"}"
  cp "$tmp/combined" "$tmp/diagnostics"
fi
cat "$tmp/diagnostics"
if [ "$rc" = 0 ]; then
  if [ "$isgo" = 1 ] && { ! grep -qx pass "$tmp/actions" || grep -qx skip "$tmp/actions"; }; then error 'candidate test did not run'; fi
  grep -qE '\[no tests to run\]|\[no test files\]|No test files found|(^|[^a-z])tests 0([^0-9]|$)|(^|[^a-z])pass 0([^0-9]|$)|Tests[[:space:]]+[0-9]+ skipped' "$tmp/diagnostics" && error 'candidate test did not run'
  printf 'GREEN  %s  (already passes — do not add to failed-test.md)\n' "$name"; exit 1
fi
infrastructure='SyntaxError|syntax error|Cannot find (module|package)|ERR_MODULE_NOT_FOUND|Failed to resolve import|no required module provides package|missing go.sum|cannot find package|no such file or directory|permission denied|No test files found|ENOTFOUND|ECONNREFUSED|go: (downloading|errors parsing)|error TS[0-9]+|is not a function|ERR_UNKNOWN_FILE_EXTENSION|ERR_UNSUPPORTED'
grep -qiE "$infrastructure" "$tmp/diagnostics" && error 'candidate could not run; fix syntax/dependencies/environment before recording it'
undefined=0; only_undefined=1
grep -qE 'undefined:[[:space:]]*[A-Za-z_]|ReferenceError:[[:space:]]*[A-Za-z_][A-Za-z0-9_]* is not defined' "$tmp/diagnostics" && undefined=1
if [ "$isgo" = 1 ]; then
  if sed -nE 's/^.*\.go:[0-9]+:[0-9]+: (.*)$/\1/p' "$tmp/diagnostics" | grep -qv '^undefined:'; then only_undefined=0; fi
fi
if [ "$undefined" = 1 ] && [ "${SOBAYA_PROBE_ALLOW_UNDEFINED:-}" = 1 ] && [ "$only_undefined" = 1 ]; then printf 'RED    %s  (undefined new symbol explicitly allowed)\n' "$name"; exit 0; fi
if [ "$undefined" = 1 ] || grep -qE 'build failed|FAIL.*\[setup failed\]' "$tmp/diagnostics"; then error 'build/reference error; allow deliberately new undefined symbols with SOBAYA_PROBE_ALLOW_UNDEFINED=1'; fi
behavioral=0
if [ "$isgo" = 1 ]; then grep -qF -- "--- FAIL: $name " "$tmp/diagnostics" && behavioral=1
else
  grep -qE 'ERR_ASSERTION|AssertionError|expected .+ to ' "$tmp/diagnostics" && behavioral=1
  if grep -E 'not ok [0-9]+ - |[✖×] ' "$tmp/diagnostics" | grep -qF "$name"; then behavioral=1; fi
fi
[ "$behavioral" = 1 ] || error 'runner failed without a verified candidate test failure'
printf 'RED    %s  (fails: assertion/test failure; diagnostics above)\n' "$name"
exit 0
