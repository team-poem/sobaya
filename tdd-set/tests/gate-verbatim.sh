#!/usr/bin/env bash
# Real Node runner regression: a copied approved test passes; rewriting it fails.
set -eu
gate=$(cd "$(dirname "$0")/../bin" && pwd)/gate.sh
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
git -C "$d" init -q
git -C "$d" config user.email t@t
git -C "$d" config user.name t
git -C "$d" config commit.gpgsign false
cat > "$d/AGENTS.md" <<'EOF'
- Test: `node --test calc.test.js`
EOF
printf '# Sum\nReturn the sum of the arguments.\n' > "$d/spec.md"
printf '{"type":"module"}\n' > "$d/package.json"
printf 'export const add = (a,b) => a+b;\n' > "$d/calc.js"
cat > "$d/calc.test.js" <<'EOF'
// file: calc.test.js
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {add} from './calc.js';
EOF
cat > "$d/failed-test.md" <<'EOF'
# Addition
## Sum
```js
// file: calc.test.js
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {add} from './calc.js';
```
- [ ] addAdds — positive sum
```js
test('addAdds: positive sum', () => assert.equal(add(1,2),3));
```
EOF
git -C "$d" add -A
git -C "$d" commit -qm start
start=$(git -C "$d" rev-parse HEAD)
printf "test('addAdds: positive sum', () => assert.equal(add(1,2),3));\n" >> "$d/calc.test.js"
sed 's/- \[ \]/- [x]/' "$d/failed-test.md" > "$d/plan.tmp"
mv "$d/plan.tmp" "$d/failed-test.md"
git -C "$d" add -A
git -C "$d" commit -qm verbatim
out=$(bash "$gate" "$d" "$start" 2>&1)
echo "ok   - gate: real executed verbatim entry passes ($(tail -1 <<<"$out"))"
sed 's/add(1,2),3/add(1,2),0/' "$d/calc.test.js" > "$d/test.tmp"
mv "$d/test.tmp" "$d/calc.test.js"
git -C "$d" add -A
git -C "$d" commit -qm rewritten
if out=$(bash "$gate" "$d" "$start" 2>&1); then
  echo 'FAIL - gate accepted a rewritten test'; exit 1
fi
grep -q 'not verbatim' <<<"$out"
echo 'ok   - gate: rewritten body fails as not verbatim'
echo 'ALL PASS'
