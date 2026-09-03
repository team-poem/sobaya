#!/usr/bin/env bash
# Final gate for one app. PASS = every failed-test.md entry checked, suite green, no existing test line
# touched, every checked entry's test function present in the suite. The human's tests are the
# spec; nothing else is judged.
# usage: tdd-set/bin/gate.sh apps/<name> [start_commit]
set -u
app=${1:?usage: gate.sh apps/<name> [start_commit]}; app=${app%/}
cd "$app" || exit 1
start=${2:-$(cat .git/sobaya-loop-start 2>/dev/null)}
[ -n "$start" ] || { echo "no start commit"; exit 1; }
fail=0
test_globs=('*_test.go' '*_test.py' '*.test.*' '*.spec.*')

if grep -q '^- \[ \]' failed-test.md; then
  echo "FAIL unchecked entries:"; grep '^- \[ \]' failed-test.md; fail=1
fi

# test command: the app AGENTS.md "- Test: `...`" line
test_cmd=$(sed -nE 's/^- Test: `?([^`]+)`?.*/\1/p' AGENTS.md 2>/dev/null | head -1)
[ -n "$test_cmd" ] || test_cmd="go test ./..."
echo "running: $test_cmd"
if ! eval "$test_cmd"; then echo "FAIL tests red"; fail=1; fi

# ponytail: any removed/modified line in a test file is tampering; renames count too
removed=$(git diff "$start"..HEAD -- "${test_globs[@]}" | grep -E '^-[^-]' || true)
if [ -n "$removed" ]; then
  echo "FAIL test lines removed or modified since $start:"; echo "$removed"; fail=1
fi

# every entry checked during this run must have its named test function added to the suite
added=$(git diff "$start"..HEAD -- "${test_globs[@]}" | grep -E '^\+' || true)
newly_checked=0
while read -r name; do
  [ -n "$name" ] || continue
  newly_checked=$((newly_checked + 1))
  if ! grep -qE "(func |def |it\(|test\()['\"]?$name\b" <<<"$added"; then
    echo "FAIL entry checked but test not added to suite: $name"; fail=1
  fi
done < <(git diff "$start"..HEAD -- failed-test.md | sed -nE 's/^\+- \[x\] ([A-Za-z0-9_]+).*/\1/p')

echo "plan: $(grep -c '^- \[x\]' failed-test.md) checked ($newly_checked this run), commits since start: $(git rev-list --count "$start"..HEAD)"

# benchmarks: informational only (no baseline to fail against); declared as "- Bench: `...`" in AGENTS.md
bench_cmd=$(sed -nE 's/^- Bench: `?([^`]+)`?.*/\1/p' AGENTS.md 2>/dev/null | head -1)
if [ -n "$bench_cmd" ]; then
  echo "bench: $bench_cmd"; eval "$bench_cmd" 2>&1 | grep -E '^(Benchmark|ok|FAIL|PASS)' || true
fi
[ $fail -eq 0 ] && echo "PASS" || echo "GATE FAILED"
exit $fail
