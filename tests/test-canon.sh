#!/bin/bash
# Canon TDD behavior with real Git/Node and a deterministic implementation worker.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
app="$work/app with spaces"
mkdir "$app"
git -C "$app" init -q
git -C "$app" config user.name Fixture
git -C "$app" config user.email fixture@example.invalid
git -C "$app" config commit.gpgsign false
git -C "$app" config core.hooksPath /dev/null
printf '# Sum\nAdd integers.\n' > "$app/spec.md"
printf '%s\n' '- Test: `node --test sum.test.js`' > "$app/AGENTS.md"
printf 'exports.add = (a,b) => 0;\n' > "$app/sum.js"
cat > "$app/failed-test.md" <<'PLAN'
# Scenarios
## Sum
```js
// file: sum.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const {add} = require('./sum.js');
```
- [ ] addPositive — add two positive integers
```js
test('addPositive', () => assert.equal(add(1,2),3));
```
- [ ] addZero — explore zero after the first result
PLAN
git -C "$app" add -A
git -C "$app" commit -qm initial
cat > "$work/worker.sh" <<'WORKER'
#!/bin/bash
set -eu
[ "$SOBAYA_ROLE" = implement ] || { echo 'Unexpected mandatory review' >&2; exit 1; }
printf 'exports.add = (a,b) => a+b;\n' > "$SOBAYA_APP/sum.js"
printf '%s\n' '{"status":"done","summary":"Added integers","reason":""}'
WORKER
jq -n --arg worker "$work/worker.sh" '{version:1,mode:"selected",default_worker:"fixture",max_calls:4,timeout_seconds:10,workers:{fixture:{adapter:"command",model:"fixture",command:["/bin/bash",$worker]}}}' > "$work/policy.json"
bash "$ROOT/tdd-set/bin/step.sh" "$app" --policy "$work/policy.json" > "$work/out" 2> "$work/err" || { cat "$work/out" "$work/err" >&2; exit 1; }
grep -q '^RED addPositive' "$work/out"
grep -q '^GREEN addPositive' "$work/out"
grep -q '^\- \[x\] addPositive' "$app/failed-test.md"
grep -q '^\- \[ \] addZero' "$app/failed-test.md"
jq -e '.version==2 and .calls==1 and .active==null' "$app/.git/sobaya/state.json" >/dev/null
[ -z "$(git -C "$app" status --porcelain)" ]
printf 'PASS: one RED/GREEN cycle without test approval or mandatory review; future scenario remains prose.\n'

# Learning can change future scenarios and the shape of existing tests at GREEN.
printf 'function sum(left,right) { return left + right; }\nexports.add = sum;\n' > "$app/sum.js"
sed "s/assert.equal(add(1,2),3)/assert.equal(add(2,1),3)/" "$app/sum.test.js" > "$work/tidy"
cp "$work/tidy" "$app/sum.test.js"
bash "$ROOT/tdd-set/bin/gate.sh" "$app" > "$work/gate"
git -C "$app" add -A
git -C "$app" commit -qm 'refactor: clarify sum'
tidy=$(git -C "$app" rev-parse HEAD)
cat >> "$app/failed-test.md" <<'PLAN'
```js
test('addZero', () => assert.equal(add(4,0),4));
```
- [ ] addNegative — choose this later if useful
PLAN
# The next candidate does not need its own commit or approval.
bash "$ROOT/tdd-set/bin/loop.sh" "$app" --policy "$work/policy.json" > "$work/out"
grep -q 'ALREADY GREEN addZero' "$work/out"
grep -q '^\- \[ \] addNegative' "$app/failed-test.md"
jq -e '.calls==1 and (.receipts|length)==2 and .active==null and .review==null' "$app/.git/sobaya/state.json" >/dev/null
git -C "$app" merge-base --is-ancestor "$tidy" HEAD
grep -q 'function sum' "$app/sum.js"
grep -q 'add(2,1)' "$app/sum.test.js"
printf 'PASS: GREEN source/test refactoring and mutable next scenarios need neither approval nor review.\n'

# An old batch becomes a list; original tests, counters and evidence survive.
cat >> "$app/failed-test.md" <<'PLAN'
```js
test('addNegative', () => assert.equal(add(-1,1),0));
```
- [ ] addReverse — reconsider ordering later
```js
test('addReverse', () => assert.equal(add(2,1),3));
```
PLAN
git -C "$app" add -A
git -C "$app" commit -qm 'fixture: legacy batch'
jq '.version=1 | .approved_at=123 | .acceptance_head=.baseline' "$app/.git/sobaya/state.json" > "$work/legacy"
cp "$work/legacy" "$app/.git/sobaya/state.json"
cp "$app/failed-test.md" "$work/legacy-plan"
cp "$app/sum.test.js" "$work/tests-before"
bash "$ROOT/tdd-set/bin/migrate.sh" "$app" > "$work/out"
archive=$(jq -r '.legacy_history[-1]' "$app/.git/sobaya/state.json")
cmp "$archive/state.json" "$work/legacy"
cmp "$archive/failed-test.md" "$work/legacy-plan"
cmp "$app/sum.test.js" "$work/tests-before"
! grep -q '^```' "$app/failed-test.md"
grep -q '^\- \[x\] addZero' "$app/failed-test.md"
grep -q '^\- \[ \] addNegative' "$app/failed-test.md"
jq -e '.version==2 and .calls==1 and (.receipts|length)==2 and .active==null' "$app/.git/sobaya/state.json" >/dev/null
if bash "$ROOT/tdd-set/bin/step.sh" "$app" --policy "$work/policy.json" > "$work/out" 2> "$work/err"; then
  echo 'FAIL: executed an unselected future test' >&2; exit 1
fi
grep -q 'needs one concrete test' "$work/err"
printf 'PASS: legacy batch migration preserves actual tests and history while releasing future scenarios.\n'
