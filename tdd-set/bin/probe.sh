#!/usr/bin/env bash
# Probe one candidate test: drop it into the package as a temporary file, run it, report,
# delete it. Phase 0 writes an entry into failed-test.md only after this prints RED.
# usage: tdd-set/bin/probe.sh apps/<name>/<dir> <snippet-file|-> [header-file]
# Go:   <dir> is the package dir; snippet = the test func only (package/import added here).
#       No header file.
# Node: <dir> is where the test file lives; snippet = one test(...) block, exactly as it will be
#       appended to the suite. [header-file] holds the section's header block from failed-test.md
#       (the `// file:` line, imports, shared constants); the probe runs header + snippet as one
#       temporary file. Without a header file the snippet must be a complete test file.
#       vitest when package.json depends on it, else `node --test`.
# exit 0 = RED (test fails or does not build), 1 = GREEN (already passes), 2 = usage error
set -u
dir=${1:-}; src=${2:-}; hdr=${3:-}
[ -d "$dir" ] && [ -n "$src" ] || { echo "usage: probe.sh <dir> <snippet-file|-> [header-file]"; exit 2; }
[ "$src" = "-" ] && snippet=$(cat) || snippet=$(cat "$src")
[ -z "$hdr" ] || [ -f "$hdr" ] || { echo "header file not found: $hdr"; exit 2; }

# find the module / package root above <dir>
root=$dir; while [ "$root" != "/" ] && [ "$root" != "." ] && [ ! -f "$root/go.mod" ] && [ ! -f "$root/package.json" ]; do root=$(dirname "$root"); done
rel=${dir#"$root"}; rel=${rel#/}

if [ -f "$root/go.mod" ]; then
  name=$(grep -oE 'func (Test[A-Za-z0-9_]+)' <<<"$snippet" | head -1 | cut -d' ' -f2)
  [ -n "$name" ] || { echo "no 'func TestX' in snippet"; exit 2; }
  pkg=$(grep -h -m1 -oE '^package [A-Za-z0-9_]+' "$dir"/*.go 2>/dev/null | head -1 | cut -d' ' -f2)
  [ -n "$pkg" ] || pkg=main
  probe="$dir/zz_probe_test.go"
  [ -e "$probe" ] && { echo "$probe already exists; remove it first"; exit 2; }
  trap 'rm -f "$probe"' EXIT
  printf 'package %s\n\nimport "testing"\n\n%s\n' "$pkg" "$snippet" > "$probe"
  out=$(go -C "$root" test "./${rel:-.}" -run "^$name\$" 2>&1); rc=$?
  build_re='build failed|undefined:|cannot find|syntax error'
  fail_line=$(grep -m1 -E '^\s+(---|.*_test\.go:[0-9]+:)' <<<"$out" | sed 's/^ *//')
elif [ -f "$root/package.json" ]; then
  name=$(grep -oE "(test|it)\(['\"][^'\"]+" <<<"$snippet" | head -1 | sed -E "s/^(test|it)\(['\"]//")
  [ -n "$name" ] || { echo "no test('...') or it('...') in snippet"; exit 2; }
  ext=js; { [ -f "$root/tsconfig.json" ] || grep -q '"typescript"' "$root/package.json"; } && ext=ts
  probe="$dir/zz_probe.test.$ext"
  [ -e "$probe" ] && { echo "$probe already exists; remove it first"; exit 2; }
  trap 'rm -f "$probe"' EXIT
  if [ -n "$hdr" ]; then { cat "$hdr"; printf '\n%s\n' "$snippet"; } > "$probe"
  else printf '%s\n' "$snippet" > "$probe"; fi
  if grep -q '"vitest"' "$root/package.json"; then
    out=$(cd "$root" && npx vitest run "${rel:+$rel/}zz_probe.test.$ext" 2>&1); rc=$?
  else
    out=$(cd "$root" && node --test "${rel:+$rel/}zz_probe.test.$ext" 2>&1); rc=$?
  fi
  build_re='Cannot find module|SyntaxError|Failed to resolve import|error TS[0-9]+|is not defined|ReferenceError'
  fail_line=$(grep -m1 -E 'AssertionError|Error:|✖|×|FAIL' <<<"$out" | sed 's/^ *//')
else
  echo "no go.mod or package.json above $dir"; exit 2
fi

if [ $rc -eq 0 ]; then
  echo "GREEN  $name  (already passes — do not add to failed-test.md)"; exit 1
elif grep -qE "$build_re" <<<"$out"; then
  echo "RED    $name  (does not build: $(grep -m1 -E "$build_re" <<<"$out" | sed 's/^ *//' | cut -c1-100))"
else
  echo "RED    $name  (fails: ${fail_line:-see output})"
fi
exit 0
