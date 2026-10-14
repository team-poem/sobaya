#!/usr/bin/env bash
# DRAFT: not part of the accepted suite until the human reviews this case.
set -eu

test_next_test_approval_preserves_verified_progress() {
  approve
  run_cli step --policy "$POLICY"; okay
  state_is '.calls == 1 and (.receipts | length) == 1 and .active == null'
  cp "$META/state.json" "$BASE/first-checkpoint.json"

  cat >> "$APP/failed-test.md" <<'PLAN'

- [ ] addLargerInputs — sums another pair
```js
test('addLargerInputs', () => assert.equal(add(2, 3), 5));
```
PLAN
  commit

  run_cli step --policy "$POLICY"; rejected
  contains "$BASE/stderr" 'unapproved appended entries'
  cmp "$BASE/first-checkpoint.json" "$META/state.json"
  not_contains "$APP/suite.test.js" 'addLargerInputs'

  run_cli approve --append; okay
  jq -e --slurpfile before "$BASE/first-checkpoint.json" '
    .baseline == $before[0].baseline and
    .calls == $before[0].calls and
    .receipts == $before[0].receipts and
    .active == null
  ' "$META/state.json" >/dev/null || fail 'Next-test approval discarded verified progress'

  run_cli step --policy "$POLICY"; okay
  contains "$BASE/stdout" 'ALREADY GREEN addLargerInputs'
  contains "$APP/suite.test.js" "$CODE"
  contains "$APP/suite.test.js" "test('addLargerInputs', () => assert.equal(add(2, 3), 5));"
  jq -e --slurpfile before "$BASE/first-checkpoint.json" '
    .baseline == $before[0].baseline and
    .calls == $before[0].calls and
    (.receipts | length) == 2 and
    .receipts[0] == $before[0].receipts[0] and
    .receipts[1].entry == "addLargerInputs" and
    .receipts[1].red.status == "green" and
    (.receipts[1].green | index("addLargerInputs")) != null and
    .active == null
  ' "$META/state.json" >/dev/null || fail 'Newly approved test did not become a verified checkpoint'
  assert_eq "$(git_app status --porcelain)" ''
}

draft_root=$(cd "$(dirname "$0")/.." && pwd)
# Reuse unchanged fixtures/helpers; --case runs only the draft function above.
. "$draft_root/tests/test-runner.sh" --case test_next_test_approval_preserves_verified_progress
