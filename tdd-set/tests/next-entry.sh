#!/usr/bin/env bash
# Read-only next-entry CLI regression; mutations belong to the runtime.
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
cat > "$d/failed-test.md" <<'PLAN'
# Draft
## Addition
```js
// file: add.test.js
const test = require('node:test');
```
- [ ] firstCase — first behavior
```js
test('firstCase', () => {});
```
- [ ] secondCase — second behavior
```js
test('secondCase', () => {});
```
PLAN
cp "$d/failed-test.md" "$d/original.md"
bash "$root/tdd-set/bin/next.sh" "$d" > "$d/output"
[ "$(head -n 1 "$d/output")" = '## Addition' ]
grep -Fq '// file: add.test.js' "$d/output"
grep -Fq "test('firstCase'" "$d/output"
! grep -Fq secondCase "$d/output"
if bash "$root/tdd-set/bin/next.sh" "$d" check >/dev/null 2>&1; then
  echo 'FAIL: legacy check mutated the plan'; exit 1
fi
cmp "$d/failed-test.md" "$d/original.md"
sed 's/- \[ \]/- [x]/g' "$d/failed-test.md" > "$d/checked.md"
mv "$d/checked.md" "$d/failed-test.md"
set +e
bash "$root/tdd-set/bin/next.sh" "$d" > "$d/output"
rc=$?
set -e
[ "$rc" -eq 1 ] && [ ! -s "$d/output" ]
echo 'PASS: next selects one entry, preserves the plan, refuses checking, and ends silently'
