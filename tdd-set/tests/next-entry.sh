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
python3 - "$d/output" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
assert s.startswith('## Addition\n')
assert '// file: add.test.js' in s and "test('firstCase'" in s
assert 'secondCase' not in s
PY
if bash "$root/tdd-set/bin/next.sh" "$d" check >/dev/null 2>&1; then
  echo 'FAIL: legacy check mutated the plan'; exit 1
fi
cmp "$d/failed-test.md" "$d/original.md"
python3 - "$d/failed-test.md" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); p.write_text(p.read_text().replace('- [ ]', '- [x]'))
PY
set +e
bash "$root/tdd-set/bin/next.sh" "$d" > "$d/output"
rc=$?
set -e
[ "$rc" -eq 1 ] && [ ! -s "$d/output" ]
echo 'PASS: next selects one entry, preserves the plan, refuses checking, and ends silently'
