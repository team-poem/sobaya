#!/bin/bash
# Real app Git hook: workspace prerequisites, then declared Format and Lint.
set -eu
set -o pipefail
root=$(cd "$(dirname "$0")/../.." && pwd -P)
app=$(git rev-parse --show-toplevel)
/bin/bash "$root/scripts/workspace-check.sh" "$root" --app "$app" --staged
cd "$app"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-hygiene.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
for label in Format Lint; do
  awk -v label="$label" '$0 ~ "^- " label ":" {sub("^- " label ":[[:space:]]*", ""); sub(/[[:space:]]*$/, ""); if ($0 ~ /^`.*`$/) {$0=substr($0,2,length($0)-2)}; print}' AGENTS.md > "$tmp/commands"
  count=$(wc -l < "$tmp/commands" | tr -d ' ')
  [ "$count" -le 1 ] || { printf 'ERROR: duplicate %s: command in AGENTS.md\n' "$label" >&2; exit 1; }
  [ "$count" = 1 ] || continue
  IFS= read -r command < "$tmp/commands"
  [ -n "$command" ] && ! printf '%s' "$command" | grep -q '<' || { printf 'ERROR: declare actual %s: command\n' "$label" >&2; exit 1; }
  rc=0; /bin/sh -c "$command" > "$tmp/out" 2> "$tmp/err" || rc=$?
  cat "$tmp/out"; cat "$tmp/err" >&2
  # A listing formatter is the one output-sensitive legacy contract. Quoted paths stay shell arguments.
  listing=0
  if [ "$label" = Format ] && printf '%s\n' "$command" | awk -f "$root/scripts/formatter-listing.awk"; then listing=1; fi
  if [ "$rc" != 0 ] || { [ "$listing" = 1 ] && grep -q '[^[:space:]]' "$tmp/out"; }; then printf 'ERROR: %s check failed: %s\n' "$label" "$command" >&2; exit 1; fi
done
