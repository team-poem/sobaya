#!/usr/bin/env bash
# DRAFT: review this case before implementing reviewed-refactor continuation.
set -eu

test_reviewed_green_refactor_allows_next_test() {
  approve
  run_cli step --policy "$POLICY"; okay
  run_cli review --policy "$POLICY"; okay
  state_is '.calls == 2 and (.receipts | length) == 1 and .active == null'
  cp "$META/state.json" "$BASE/before-tidy.json"
  cp "$APP/suite.test.js" "$BASE/protected-test.js"
  cp "$APP/failed-test.md" "$BASE/protected-plan.md"

  cat > "$APP/impl.js" <<'SOURCE'
function sum(a, b) { return a + b; }
exports.add = (a, b) => sum(a, b);
SOURCE
  git_app add impl.js
  git_app commit -qm 'refactor: name the addition operation'
  tidied_head=$(git_app rev-parse HEAD)
  cp "$APP/impl.js" "$BASE/tidied-source.js"
  run_cli review --policy "$POLICY"; okay
  cmp "$BASE/protected-test.js" "$APP/suite.test.js"
  cmp "$BASE/protected-plan.md" "$APP/failed-test.md"
  jq -e --slurpfile before "$BASE/before-tidy.json" --arg head "$tidied_head" '
    .baseline == $before[0].baseline and
    .receipts == $before[0].receipts and
    .calls == ($before[0].calls + 1) and
    .review.head == $head and
    .review.head != $before[0].review.head
  ' "$META/state.json" >/dev/null || fail 'Tidied HEAD did not get a fresh verified review'
  cp "$META/state.json" "$BASE/reviewed-tidy.json"

  cat >> "$APP/failed-test.md" <<'PLAN'

- [ ] addLargerInputs — sums another pair
```js
test('addLargerInputs', () => assert.equal(add(2, 3), 5));
```
PLAN
  commit
  run_cli approve --append; okay
  cmp "$BASE/tidied-source.js" "$APP/impl.js"
  jq -e --slurpfile before "$BASE/reviewed-tidy.json" '
    .baseline == $before[0].baseline and
    .calls == $before[0].calls and
    .receipts == $before[0].receipts and
    .review == null and
    .acceptance_history[-1].review == $before[0].review
  ' "$META/state.json" >/dev/null || fail 'Next approval lost the reviewed tidying evidence'

  run_cli step --policy "$POLICY"; okay
  contains "$BASE/stdout" 'ALREADY GREEN addLargerInputs'
  cmp "$BASE/tidied-source.js" "$APP/impl.js"
  jq -e --slurpfile before "$BASE/reviewed-tidy.json" '
    .baseline == $before[0].baseline and
    .calls == $before[0].calls and
    (.receipts | length) == 2 and
    .receipts[0] == $before[0].receipts[0] and
    .receipts[1].entry == "addLargerInputs" and
    (.receipts[1].green | index("addLargerInputs")) != null and
    .active == null
  ' "$META/state.json" >/dev/null || fail 'Next checkpoint did not preserve the feature history'
  contains "$APP/suite.test.js" "$CODE"
  contains "$APP/suite.test.js" "test('addLargerInputs', () => assert.equal(add(2, 3), 5));"
  assert_eq "$(git_app status --porcelain)" ''
}

draft_root=$(cd "$(dirname "$0")/.." && pwd)
# Reuse the unchanged, previously reviewed fixture and run only this draft.
. "$draft_root/tests/test-runner.sh" --case test_reviewed_green_refactor_allows_next_test
