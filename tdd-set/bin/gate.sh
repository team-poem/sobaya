#!/bin/bash
# Check current code, including GREEN refactors, without any approval/review prerequisite.
set -eu
here=$(cd "$(dirname "$0")/../lib" && pwd)
. "$here/contract.sh"
[ "$#" = 1 ] || { sb_error 'usage: gate.sh APP'; exit 1; }
result_file=$(mktemp)
trap 'rm -f "$result_file"' EXIT
if contract_gate "$1" >"$result_file"; then
  jq -r '.output//empty' "$result_file"
  echo 'PASS — current full suite and hygiene checks; assess feature outcome separately.'
else rc=$?; cat "$result_file" >&2; echo 'CHECK FAILED' >&2; exit "$rc"; fi
