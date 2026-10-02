#!/bin/bash
# Read local configuration without installation or workspace mutations.
set -eu
root=$1
[ -d "$root" ] || { printf '%s\n' 'ERROR: --root must name an existing directory' >&2; exit 2; }
command -v jq >/dev/null || { printf '%s\n' 'ERROR: jq is required' >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd -P)
if result=$(jq -cn --slurpfile config "$root/sobaya.json" --slurpfile lock "$root/sobaya.lock" -f "$here/config-check.jq"); then
  printf '%s\n' "$result"
else
  exit 2
fi
