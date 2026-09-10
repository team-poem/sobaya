#!/bin/bash
# Explicit, atomic brain index generation. --check never writes to the vault.
set -eu
set -o pipefail
TOOLS_DIR=$(cd "$(dirname "$0")" && pwd -P)
. "$TOOLS_DIR/tools-common.sh"
[ $# -ge 1 ] && [ $# -le 2 ] || { tools_error 'usage: brain-index.sh ROOT [--check]'; exit 1; }
root=$(tools_abs "$1"); check=${2:-}
[ -z "$check" ] || [ "$check" = --check ] || { tools_error 'unknown option'; exit 1; }
brain=$root/brain; index=$brain/index.md
[ -d "$brain" ] || { tools_error "brain directory not found: $brain"; exit 1; }
[ ! -L "$index" ] && { [ ! -e "$index" ] || [ -f "$index" ]; } || { tools_error "index must be a regular file: $index"; exit 1; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-index.XXXXXX"); atomic=
trap 'rm -rf "$tmp"; [ -z "$atomic" ] || rm -f "$atomic"' EXIT
find "$brain" -type f -name '*.md' -print0 > "$tmp/files"
: > "$tmp/paths"
while IFS= read -r -d '' file; do
  tools_plain_path "$file" || exit 1
  printf '%s\n' "${file#"$brain/"}" >> "$tmp/paths"
done < "$tmp/files"
tools_index_render "$tmp/paths" > "$tmp/expected"
if [ -f "$index" ] && cmp -s "$index" "$tmp/expected"; then printf 'brain index current\n'; exit 0; fi
if [ "$check" = --check ]; then tools_error "brain index is stale; run scripts/brain-index.sh $root"; exit 1; fi
atomic=$(mktemp "$brain/.index.XXXXXX")
cat "$tmp/expected" > "$atomic"
chmod 644 "$atomic"
mv -f "$atomic" "$index"; atomic=
printf 'updated %s\n' "$index"
