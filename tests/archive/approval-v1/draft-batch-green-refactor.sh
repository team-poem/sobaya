#!/usr/bin/env bash
# DRAFT: review this case before implementing intermediate batch review.
set -eu

test_batch_green_refactor_preserves_pending_work() {
  cat >> "$APP/failed-test.md" <<'PLAN'

- [ ] addLargerInputs — sums another pair
```js
test('addLargerInputs', () => assert.equal(add(2, 3), 5));
```
PLAN
  commit
  approve
  run_cli step --policy "$POLICY"; okay
  state_is '.calls == 1 and (.receipts | length) == 1 and .review == null and .active == null'
  contains "$APP/failed-test.md" '[x] addAdds'
  contains "$APP/failed-test.md" '[ ] addLargerInputs'
  not_contains "$APP/suite.test.js" 'addLargerInputs'
  cp "$META/state.json" "$BASE/before-tidy.json"
  cp "$APP/suite.test.js" "$BASE/protected-test.js"
  cp "$APP/failed-test.md" "$BASE/protected-plan.md"

  printf 'exports.add = (a, b) => a-b;\n' > "$APP/impl.js"
  git_app add impl.js
  git_app commit -qm 'fixture: broken tidy candidate'
  run_cli review --checkpoint --policy "$POLICY"; rejected
  contains "$BASE/stderr" 'addAdds'
  cmp "$BASE/before-tidy.json" "$META/state.json"
  assert_eq "$(cat "$APP/impl.js")" 'exports.add = (a, b) => a-b;'

  cat > "$APP/impl.js" <<'SOURCE'
function sum(a, b) { return a + b; }
exports.add = (a, b) => sum(a, b);
SOURCE
  git_app add impl.js
  git_app commit -qm 'refactor: name the addition operation'
  tidied_head=$(git_app rev-parse HEAD)
  cp "$APP/impl.js" "$BASE/tidied-source.js"
  run_cli review --checkpoint --policy "$POLICY"; okay
  cmp "$BASE/protected-test.js" "$APP/suite.test.js"
  cmp "$BASE/protected-plan.md" "$APP/failed-test.md"
  jq -e --slurpfile before "$BASE/before-tidy.json" --arg head "$tidied_head" '
    .baseline == $before[0].baseline and
    .approved_at == $before[0].approved_at and
    .acceptance_head == $before[0].acceptance_head and
    .acceptance_history == $before[0].acceptance_history and
    .receipts == $before[0].receipts and
    .calls == ($before[0].calls + 1) and
    .review == null and .status == "checkpoint" and .active == null and
    (.checkpoint_reviews | length) == 1 and
    .checkpoint_reviews[0].head == $head and
    .checkpoint_reviews[0].checkpoint == $before[0].receipts[-1].head
  ' "$META/state.json" >/dev/null || fail 'Intermediate review lost progress or claimed completion'
  tail -n 1 "$META/usage.jsonl" | jq -e '.role == "review"' >/dev/null || fail 'Checkpoint reviewer did not use the read-only review role'
  review_run=$(tail -n 1 "$META/usage.jsonl" | jq -r .run_id)
  review_prompt="$META/runs/$review_run/$(jq -r .calls "$META/state.json")/prompt.txt"
  contains "$review_prompt" "from $(jq -r '.receipts[-1].head' "$BASE/before-tidy.json") to HEAD"
  contains "$review_prompt" 'addLargerInputs'
  contains "$review_prompt" 'Pending approved entries are not completion defects.'
  cp "$META/state.json" "$BASE/reviewed-tidy.json"
  run_cli review --checkpoint --policy "$POLICY"; okay
  cmp "$BASE/reviewed-tidy.json" "$META/state.json"
  run_cli review --policy "$POLICY"; rejected
  contains "$BASE/stderr" 'Unchecked plan entries remain'
  cmp "$BASE/reviewed-tidy.json" "$META/state.json"
  run_cli status; okay
  jq -e '.pending == ["addLargerInputs"] and .status != "complete"' "$BASE/stdout" >/dev/null || fail 'Pending batch entry disappeared'
  not_contains "$APP/suite.test.js" 'addLargerInputs'

  run_cli step --policy "$POLICY"; okay
  contains "$BASE/stdout" 'ALREADY GREEN addLargerInputs'
  cmp "$BASE/tidied-source.js" "$APP/impl.js"
  jq -e --slurpfile before "$BASE/reviewed-tidy.json" --arg head "$tidied_head" '
    .baseline == $before[0].baseline and
    .approved_at == $before[0].approved_at and
    .calls == $before[0].calls and
    (.receipts | length) == 2 and
    .receipts[0] == $before[0].receipts[0] and
    .receipts[1].before == $head and .receipts[1].entry == "addLargerInputs" and
    (.receipts[1].green | index("addLargerInputs")) != null and
    .checkpoint_reviews == $before[0].checkpoint_reviews and
    .review == null and .status == "checkpoint" and .active == null
  ' "$META/state.json" >/dev/null || fail 'Batch continuation lost its checkpoint or review evidence'
  contains "$APP/suite.test.js" "$CODE"
  contains "$APP/suite.test.js" "test('addLargerInputs', () => assert.equal(add(2, 3), 5));"
  cp "$META/state.json" "$BASE/before-final.json"
  final_head=$(git_app rev-parse HEAD)
  run_cli review --policy "$POLICY"; okay
  jq -e --slurpfile before "$BASE/before-final.json" --arg head "$final_head" '
    .baseline == $before[0].baseline and
    .calls == ($before[0].calls + 1) and
    .receipts == $before[0].receipts and
    .checkpoint_reviews == $before[0].checkpoint_reviews and
    .review.head == $head and .status == "complete" and
    .review.head != .checkpoint_reviews[0].head
  ' "$META/state.json" >/dev/null || fail 'Final completion reused an intermediate review'
  final_run=$(tail -n 1 "$META/usage.jsonl" | jq -r .run_id)
  final_prompt="$META/runs/$final_run/$(jq -r .calls "$META/state.json")/prompt.txt"
  contains "$final_prompt" "from $(jq -r .baseline "$BASE/before-final.json") to HEAD"
  cmp "$BASE/tidied-source.js" "$APP/impl.js"
  assert_eq "$(git_app status --porcelain)" ''
}

draft_root=$(cd "$(dirname "$0")/.." && pwd)
# Reuse unchanged approved support; only this new case is a draft.
. "$draft_root/tests/test-runner.sh" --case test_batch_green_refactor_preserves_pending_work
