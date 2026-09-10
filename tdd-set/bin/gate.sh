#!/bin/bash
set -u
here=$(cd "$(dirname "$0")/../lib" && pwd)
. "$here/contract.sh"
app=${1:?usage: gate.sh APP [BASELINE]}
baseline=${2:-}
[ -n "$baseline" ] || baseline=$(contract_saved_baseline "$app") || exit 1
result_file=$(mktemp) || exit 1
trap 'rm -f "$result_file"' EXIT
if contract_gate "$app" "$baseline" >"$result_file"; then
  jq -r '.output//empty' "$result_file"
  echo PASS
else rc=$?; echo 'GATE FAILED' >&2; exit "$rc"; fi
