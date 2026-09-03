#!/usr/bin/env bash
# Probe one candidate test: drop it into the package as a temporary file, run it, report,
# delete it. Phase 0 writes an entry into plan.md only after this prints RED.
# usage: tdd-set/bin/probe.sh apps/<name>/<package-dir> <snippet-file>   (snippet = the test func only)
#        tdd-set/bin/probe.sh apps/<name>/<package-dir> - <<'EOF' ... EOF  (snippet on stdin)
# exit 0 = RED (test fails or does not build), 1 = GREEN (already passes), 2 = usage error
# ponytail: Go only; other stacks need their own probe with the same contract
set -u
dir=${1:-}; src=${2:-}
[ -d "$dir" ] && [ -n "$src" ] || { echo "usage: probe.sh <package-dir> <snippet-file|->"; exit 2; }
[ "$src" = "-" ] && snippet=$(cat) || snippet=$(cat "$src")
name=$(grep -oE 'func (Test[A-Za-z0-9_]+)' <<<"$snippet" | head -1 | cut -d' ' -f2)
[ -n "$name" ] || { echo "no 'func TestX' in snippet"; exit 2; }
pkg=$(grep -h -m1 -oE '^package [A-Za-z0-9_]+' "$dir"/*.go 2>/dev/null | head -1 | cut -d' ' -f2)
[ -n "$pkg" ] || pkg=main

probe="$dir/zz_probe_test.go"
[ -e "$probe" ] && { echo "$probe already exists; remove it first"; exit 2; }
trap 'rm -f "$probe"' EXIT
printf 'package %s\n\nimport "testing"\n\n%s\n' "$pkg" "$snippet" > "$probe"

# run from the module root so the package path resolves
mod=$dir; while [ "$mod" != "/" ] && [ "$mod" != "." ] && [ ! -f "$mod/go.mod" ]; do mod=$(dirname "$mod"); done
[ -f "$mod/go.mod" ] || { echo "no go.mod above $dir"; exit 2; }
rel=${dir#"$mod"}; rel=${rel#/}
out=$(go -C "$mod" test "./${rel:-.}" -run "^$name\$" 2>&1); rc=$?
if [ $rc -eq 0 ]; then
  echo "GREEN  $name  (already passes — do not add to plan.md)"; exit 1
elif grep -qE 'build failed|undefined:|cannot find|syntax error' <<<"$out"; then
  echo "RED    $name  (does not build: $(grep -m1 -E 'undefined:|syntax error|cannot find' <<<"$out" | sed 's/^.*: //'))"
else
  echo "RED    $name  (fails: $(grep -m1 -E '^\s+(---|.*_test\.go:[0-9]+:)' <<<"$out" | sed 's/^ *//'))"
fi
exit 0
