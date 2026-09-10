#!/usr/bin/env bash
# End-to-end runtime behavior: real Git/Node/Go, deterministic shell workers.
# Compatible with the system Bash 3.2. No paid worker calls.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SELF="$ROOT/tests/test-runner.sh"
RUNNER="$ROOT/tdd-set/lib/runner.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; [ ! -f "${BASE:-}/stderr" ] || cat "$BASE/stderr" >&2; [ ! -f "${META:-}/state.json" ] || cat "$META/state.json" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected <$2>, got <$1> ${3:-}"; }
contains() { grep -Fq -- "$2" "$1" || fail "$1 does not contain $2"; }
not_contains() { if grep -Fq -- "$2" "$1"; then fail "$1 unexpectedly contains $2"; fi; }
state_is() { jq -e "$1" "$META/state.json" >/dev/null || fail "state assertion: $1"; }
git_app() { git -C "$APP" "$@"; }
commit() { git_app add -A; git_app commit -qm fixture; }
run_cli() {
  if FIXTURE_MODE="${MODE:-fix}" FIXTURE_TARGET="${TARGET:-suite.test.js}" bash "$RUNNER" "$1" "$APP" "${@:2}" >"$BASE/stdout" 2>"$BASE/stderr"; then RC=0; else RC=$?; fi
}
okay() { [ "$RC" -eq 0 ] || fail "command exited $RC"; }
rejected() { [ "$RC" -ne 0 ] || fail 'command unexpectedly passed'; }
approve() { run_cli approve; okay; }
policy_edit() { jq "$1" "$POLICY" > "$BASE/policy.new"; mv "$BASE/policy.new" "$POLICY"; }
cleanup() {
  for pid in ${CHILDREN:-}; do kill -TERM "$pid" 2>/dev/null || :; wait "$pid" 2>/dev/null || :; done
  rm -rf "$BASE"
}
setup() {
  BASE=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-runner-shell.XXXXXX")
  trap cleanup EXIT
  CHILDREN=''; MODE=fix; TARGET=suite.test.js
  APP="$BASE/app with spaces"; mkdir -p "$APP"
  git_app init -q
  git_app config user.name Fixture
  git_app config user.email fixture@example.invalid
  git_app config commit.gpgsign false
  git_app config core.hooksPath /dev/null
  META="$APP/.git/sobaya"
  printf '# Goal\nAdd positive integers.\n' > "$APP/spec.md"
  printf '# Fixture\n- Test: `node --test suite.test.js`\n' > "$APP/AGENTS.md"
  printf 'exports.add = (a, b) => 0;\n' > "$APP/impl.js"
  CODE="test('addAdds', () => assert.equal(add(1, 2), 3));"
  cat > "$APP/failed-test.md" <<'PLAN'
# Plan

## Add
```js
// file: suite.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { add } = require('./impl.js');
```

- [ ] addAdds — sums inputs
```js
test('addAdds', () => assert.equal(add(1, 2), 3));
```
PLAN
  commit
  BASELINE=$(git_app rev-parse HEAD)
  WORKER="$BASE/worker.sh"
  cat > "$WORKER" <<'WORKER'
#!/usr/bin/env bash
set -eu
app=$SOBAYA_APP
mode=${FIXTURE_MODE:-fix}
grep -q addAdds "$app/${FIXTURE_TARGET:-suite.test.js}"
case "$mode" in
  fix) if [ "$SOBAYA_ROLE" = implement ]; then printf 'exports.add = (a, b) => a+b;\n' > "$app/impl.js"; fi ;;
  review_index)
    if [ "$SOBAYA_ROLE" = review ]; then git -C "$app" update-index --chmod=+x impl.js
    else printf 'exports.add = (a, b) => a+b;\n' > "$app/impl.js"; fi ;;
  skip_index|assume_index)
    if [ "$SOBAYA_ROLE" = implement ]; then
      if [ "$mode" = skip_index ]; then flag=--skip-worktree; else flag=--assume-unchanged; fi
      git -C "$app" update-index "$flag" impl.js
      printf 'exports.add = (a, b) => a+b;\n' > "$app/impl.js"
    fi ;;
  timeout_state)
    state="$app/.git/sobaya/state.json"
    jq '.calls=0' "$state" > "$state.tmp"; mv "$state.tmp" "$state"
    sleep 10 ;;
  tamper)
    file="$app/${FIXTURE_TARGET:-suite.test.js}"
    sed 's/, 3)/, 0)/g' "$file" > "$file.tmp"; mv "$file.tmp" "$file" ;;
  handoff)
    printf '%s\n' '{"status":"handoff","summary":"Needs another approach","reason":"The failing assertion is understood but implementation remains unresolved."}'
    exit 0 ;;
  defect)
    printf '%s\n' '{"status":"defect","summary":"Requirement conflict","reason":"Need human-reviewed additional test."}'
    exit 0 ;;
esac
printf '%s\n' '{"status":"done","summary":"Implemented the approved entry","reason":""}'
WORKER
  POLICY="$BASE/policy.json"
  jq -n --arg worker "$WORKER" '{version:1,mode:"selected",default_worker:"fixture",max_calls:4,timeout_seconds:15,workers:{fixture:{adapter:"command",command:["/bin/bash",$worker],model:"fixture",guidance:"guided"}},escalation:[]}' > "$POLICY"
}
wait_file() {
  waited=0
  while [ ! -f "$1" ] && [ "$waited" -lt 200 ]; do sleep 0.05; waited=$((waited+1)); done
  [ -f "$1" ] || fail "worker did not create $1"
}

test_fresh_run_requires_explicit_approval() {
  run_cli step --policy "$POLICY"; rejected
  grep -iq approv "$BASE/stderr" || fail 'missing approval diagnostic'
  assert_eq "$(git_app rev-parse HEAD)" "$BASELINE"
}
test_red_green_checkpoint_and_baseline_survive_replay() {
  approve
  run_cli loop --policy "$POLICY"; okay
  contains "$BASE/stdout" RED; contains "$BASE/stdout" PASS
  assert_eq "$(git_app status --porcelain)" ''
  state_is ".baseline == \"$BASELINE\" and .calls == 2 and .status == \"complete\""
  head=$(git_app rev-parse HEAD)
  run_cli loop --policy "$POLICY"; okay
  assert_eq "$(git_app rev-parse HEAD)" "$head"
  state_is ".baseline == \"$BASELINE\""
}
test_staged_and_untracked_work_refused_without_stash() {
  approve
  printf 'user work' > "$APP/user.txt"
  for staged in no yes; do
    if [ "$staged" = yes ]; then git_app add user.txt; fi
    run_cli step --policy "$POLICY"; rejected
    [ -f "$APP/user.txt" ] || fail 'user work disappeared'
    assert_eq "$(git_app stash list)" ''
  done
}
test_worker_test_mutation_is_rejected_and_preserved() {
  approve; MODE=tamper
  run_cli step --policy "$POLICY"; rejected
  grep -iq protect "$BASE/stderr" || fail 'missing protected-input diagnostic'
  assert_eq "$(git_app rev-parse HEAD)" "$BASELINE"
  contains "$APP/failed-test.md" '[ ] addAdds'
  assert_eq "$(git_app stash list)" ''
}
test_handoff_is_saved_and_explicit_resume_completes_same_item() {
  approve; MODE=handoff
  run_cli step --policy "$POLICY"; rejected
  state_is '.active.entry == "addAdds"'
  [ -f "$META/handoff.json" ] || fail 'handoff missing'
  # Persisted version-1 data used fractional timestamps/durations before the
  # shell port. Keep its unfinished snapshot and cumulative calls unchanged.
  jq '.approved_at=1789000000.125' "$META/state.json" > "$BASE/state.old"
  mv "$BASE/state.old" "$META/state.json"
  jq -nc --arg baseline "$BASELINE" '{run_id:"pre-shell-run",baseline:$baseline,worker:"fixture",model:"fixture",role:"implement",entry:"addAdds",duration_seconds:0.25,usage:{input_tokens:13,output_tokens:7}}' >> "$META/usage.jsonl"
  run_cli usage pre-shell-run; okay
  jq -e '.calls == 1 and .duration_seconds == 0.25 and .usage[0].input_tokens == 13' "$BASE/stdout" >/dev/null || fail 'existing version-1 usage was not retained'
  MODE=fix; run_cli step --policy "$POLICY"; rejected
  run_cli step --resume --policy "$POLICY"; okay
  state_is ".version == 1 and .approved_at == 1789000000.125 and .calls == 2 and .baseline == \"$BASELINE\""
}
test_call_budget_is_not_reset_by_resume() {
  policy_edit '.max_calls=1'; approve; MODE=handoff
  run_cli step --policy "$POLICY"; rejected
  MODE=fix; run_cli step --resume --policy "$POLICY"; rejected
  grep -iq budget "$BASE/stderr" || fail 'missing budget diagnostic'
}
test_changed_plan_cannot_reapprove_implicitly() {
  approve
  sed 's/, 3)/, 0)/g' "$APP/failed-test.md" > "$BASE/plan.new"; mv "$BASE/plan.new" "$APP/failed-test.md"
  commit; run_cli approve; rejected
  run_cli approve --replace; okay
}
test_failed_commit_can_resume_without_another_worker_call() {
  approve
  hooks="$APP/.git/hooks"; mkdir -p "$hooks"
  printf '#!/bin/sh\nexit 1\n' > "$hooks/pre-commit"; chmod +x "$hooks/pre-commit"
  git_app config core.hooksPath "$hooks"
  run_cli step --policy "$POLICY"; rejected
  state_is '.active.phase == "committing"'
  printf '#!/bin/sh\nexit 0\n' > "$hooks/pre-commit"
  run_cli step --resume --policy "$POLICY"; okay
  state_is '.calls == 1'
}
test_next_is_read_only_and_checking_is_runner_owned() {
  run_cli next; okay; contains "$BASE/stdout" "$CODE"
  run_cli next check; rejected
  assert_eq "$(git_app status --porcelain)" ''
}
test_timeout_cannot_erase_budget() {
  policy_edit '.timeout_seconds=1'; approve; MODE=timeout_state
  run_cli step --policy "$POLICY"; rejected
  state_is ".calls == 1 and .baseline == \"$BASELINE\""
}
test_review_index_mutation_cannot_complete() {
  approve; MODE=review_index
  run_cli loop --policy "$POLICY"; rejected
  state_is '.status != "complete" and .review == null'
}
test_header_checkbox_and_trailing_spaces_are_verbatim() {
  awk '/^const test =/ {print "const example = `\\n- [ ] addAdds\\n`;"} /test\('\''addAdds'\''/ {$0=$0 "  \n"} {print}' "$APP/failed-test.md" > "$BASE/plan.new"
  mv "$BASE/plan.new" "$APP/failed-test.md"
  commit; approve; run_cli step --policy "$POLICY"; okay
  awk -v code="$CODE" '$0 == code "  " {if (getline > 0 && $0 == "") found=1} END {exit !found}' "$APP/suite.test.js" || fail 'test trailing spaces or empty line lost'
  contains "$APP/suite.test.js" '- [ ] addAdds'
}
test_explicit_arbitrary_test_filename() {
  for file in failed-test.md AGENTS.md; do
    sed 's/suite\.test\.js/checks.js/g' "$APP/$file" > "$BASE/file.new"; mv "$BASE/file.new" "$APP/$file"
  done
  TARGET=checks.js; commit; approve
  run_cli step --policy "$POLICY"; okay
}
test_escalation_requires_explicit_policy_and_diagnosis() {
  second="$BASE/second.sh"
  cat > "$second" <<'WORKER'
#!/bin/sh
printf 'exports.add=(a,b)=>a+b;\n' > "$SOBAYA_APP/impl.js"
printf '%s\n' '{"status":"done","summary":"fixed","reason":""}'
WORKER
  jq --arg second "$second" '.mode="economy" | .escalation=["second"] | .workers.second={adapter:"command",command:["/bin/bash",$second],model:"explicit-second"}' "$POLICY" > "$BASE/policy.new"; mv "$BASE/policy.new" "$POLICY"
  approve; MODE=handoff
  run_cli step --policy "$POLICY"; okay
  state_is ".calls == 2 and .baseline == \"$BASELINE\""
}
test_worktree_and_lock() {
  approve
  cp "$WORKER" "$BASE/original-worker.sh"
  cat > "$WORKER" <<'WORKER'
#!/bin/sh
printf started > "$SOBAYA_APP/.git/lock-worker-started"
sleep 10
WORKER
  bash "$RUNNER" step "$APP" --policy "$POLICY" > "$BASE/first.out" 2> "$BASE/first.err" & first=$!; CHILDREN="$first"
  wait_file "$APP/.git/lock-worker-started"
  run_cli step --policy "$POLICY"; rejected
  contains "$BASE/stderr" writer
  kill -TERM "$first"; wait "$first" 2>/dev/null || :; CHILDREN=''
  cp "$BASE/original-worker.sh" "$WORKER"
  worktree="$BASE/linked"; git_app worktree add -qb linked "$worktree"
  APP=$worktree
  metadata_path=$(git_app rev-parse --absolute-git-dir); META="$metadata_path/sobaya"
  approve; run_cli step --policy "$POLICY"; okay
}
test_cancel_stops_worker_before_unlock_and_preserves_resume() {
  cat > "$WORKER" <<'WORKER'
#!/bin/sh
printf '%s' "$$" > "$SOBAYA_APP/.git/worker-started"
sleep 1
printf 'late write' > "$SOBAYA_APP/escaped.txt"
printf '%s\n' '{"status":"done","summary":"late","reason":""}'
WORKER
  approve
  bash "$RUNNER" step "$APP" --policy "$POLICY" > "$BASE/cancel.out" 2> "$BASE/cancel.err" & pid=$!; CHILDREN="$pid"
  wait_file "$APP/.git/worker-started"
  kill -TERM "$pid"
  if wait "$pid"; then cancel_rc=0; else cancel_rc=$?; fi
  CHILDREN=''; assert_eq "$cancel_rc" 130
  sleep 1.1
  [ ! -e "$APP/escaped.txt" ] || fail 'cancelled worker performed late write'
  state_is '.calls == 1 and .active.phase == "implement"'
  [ ! -e "$META/worker.json" ] || fail 'worker record survived cancellation'
}
test_non_object_policy_and_worker_results_fail_with_diagnostic() {
  approve; cp "$POLICY" "$BASE/original-policy.json"
  printf '[]\n' > "$POLICY"
  run_cli step --policy "$POLICY"; rejected; not_contains "$BASE/stderr" Traceback
  cp "$BASE/original-policy.json" "$POLICY"
  printf "#!/bin/sh\nprintf '[]\\n'\n" > "$WORKER"
  run_cli step --policy "$POLICY"; rejected
  contains "$BASE/stderr" 'result must contain'; not_contains "$BASE/stderr" Traceback
}
test_codex_adapter_contract_and_reported_usage_without_live_call() {
  cat > "$BASE/codex" <<'CODEX'
#!/usr/bin/env bash
set -eu
[ "$1" = exec ]; shift
model=''; sandbox=''; schema=''; last=''; approval=no
while [ "$#" -gt 0 ]; do
  case "$1" in
    --model) model=$2; shift 2 ;;
    --sandbox) sandbox=$2; shift 2 ;;
    --output-schema) schema=$2; shift 2 ;;
    --output-last-message) last=$2; shift 2 ;;
    -c) [ "$2" != 'approval_policy="never"' ] || approval=yes; shift 2 ;;
    *) shift ;;
  esac
done
[ "$model" = fixture-codex ]
[ "$approval" = yes ]
if [ "$SOBAYA_ROLE" = review ]; then [ "$sandbox" = read-only ]; else [ "$sandbox" = workspace-write ]; fi
jq -e '.type == "object"' "$schema" >/dev/null
prompt=$(cat); [ -n "$prompt" ]
if [ "$SOBAYA_ROLE" = implement ]; then printf 'exports.add=(a,b)=>a+b;' > "$SOBAYA_APP/impl.js"; fi
printf '%s\n' '{"status":"done","summary":"verified adapter","reason":""}' > "$last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":11,"output_tokens":7}}'
CODEX
  chmod +x "$BASE/codex"
  policy_edit '.workers.fixture={adapter:"codex",model:"fixture-codex"}'
  approve
  PATH="$BASE:$PATH" run_cli loop --policy "$POLICY"; okay
  jq -se 'map(.role) == ["implement","review"] and .[0].usage.input_tokens == 11' "$META/usage.jsonl" >/dev/null || fail 'Codex usage or role evidence missing'
}
go_fixture() {
  printf '# Go fixture\n- Test: `go test ./...`\n' > "$APP/AGENTS.md"
  printf 'module fixture\n\ngo 1.23\n' > "$APP/go.mod"
  printf 'package fixture\n' > "$APP/calc.go"
  go_code=${1:-'func TestNewAdd(t *testing.T) { if NewAdd(1,2)!=3 { t.Fatal("wrong sum") } }'}
  {
    printf '# Plan\n## Add\n```go\n// file: calc_test.go\npackage fixture\nimport "testing"\n```\n- [ ] TestNewAdd — adds\n```go\n'
    printf '%s\n```\n' "$go_code"
  } > "$APP/failed-test.md"
  cat > "$WORKER" <<'WORKER'
#!/bin/sh
if [ "$SOBAYA_ROLE" = implement ]; then
  printf 'package fixture\nfunc NewAdd(a,b int) int { return a+b }\n' > "$SOBAYA_APP/calc.go"
fi
printf '%s\n' '{"status":"done","summary":"implemented NewAdd","reason":""}'
WORKER
  commit
}
test_explicit_missing_go_symbol_red_finishes_with_real_execution() {
  go_fixture; run_cli approve --allow-go-undefined-red; okay
  run_cli loop --policy "$POLICY"; okay
  contains "$BASE/stdout" 'BUILD-RED TestNewAdd'
  state_is '.receipts[0].red.status == "build-red" and (.receipts[0].green | index("TestNewAdd")) != null and .status == "complete"'
}
test_preparing_build_error_can_resume_after_implementation_stub() {
  go_fixture; approve
  run_cli step --policy "$POLICY"; rejected
  contains "$BASE/stderr" build/infrastructure; state_is '.calls == 0'
  printf 'package fixture\nfunc NewAdd(a,b int) int { return 0 }\n' > "$APP/calc.go"
  run_cli step --resume --policy "$POLICY"; okay
  contains "$BASE/stdout" 'RED TestNewAdd'
}
test_compile_red_permission_does_not_allow_syntax_error() {
  go_fixture 'func TestNewAdd(t *testing.T) { broken syntax }'
  run_cli approve --allow-go-undefined-red; okay
  run_cli step --policy "$POLICY"; rejected
  state_is '.calls == 0 and .active.phase == "preparing"'
}
test_compile_red_permission_does_not_allow_missing_import() {
  go_fixture 'func TestNewAdd(t *testing.T) { os.Exit(1) }'
  run_cli approve --allow-go-undefined-red; okay
  run_cli step --policy "$POLICY"; rejected; state_is '.calls == 0'
}
test_already_green_records_truth_and_only_calls_reviewer() {
  printf 'exports.add=(a,b)=>a+b;' > "$APP/impl.js"
  commit; approve
  run_cli loop --policy "$POLICY"; okay
  contains "$BASE/stdout" 'ALREADY GREEN'
  state_is '.calls == 1 and .receipts[0].red.status == "green" and .status == "complete"'
}
test_live_orphan_blocks_new_writer_and_dead_record_is_recoverable() {
  approve
  set -m
  sleep 30 & orphan=$!; CHILDREN="$orphan"
  set +m
  jq -n --argjson pid "$orphan" '{pid:$pid}' > "$META/worker.json"
  run_cli step --policy "$POLICY"; rejected
  contains "$BASE/stderr" 'still alive'; assert_eq "$(git_app status --porcelain)" ''
  kill -TERM "$orphan"; wait "$orphan" 2>/dev/null || :; CHILDREN=''
  run_cli step --policy "$POLICY"; okay
}
test_checkpoint_hygiene_failure_blocks_commit_even_without_hooks() {
  printf '%s\n' '- Lint: `false`' >> "$APP/AGENTS.md"
  commit; approve; head=$(git_app rev-parse HEAD)
  run_cli step --policy "$POLICY"; rejected
  contains "$BASE/stderr" Lint
  assert_eq "$(git_app rev-parse HEAD)" "$head"
  contains "$APP/failed-test.md" '[ ] addAdds'
}
hidden_index_worker_is_rejected() {
  MODE=$1; expected_flag=$2
  approve
  run_cli loop --policy "$POLICY"; rejected
  grep -iq 'index' "$BASE/stderr" || fail 'missing hidden-index diagnostic'
  assert_eq "$(git_app rev-parse HEAD)" "$BASELINE"
  state_is '.status != "complete" and .review == null and .calls == 1'
  contains "$APP/failed-test.md" '[ ] addAdds'
  assert_eq "$(git_app ls-files -v -- impl.js)" "$expected_flag impl.js"
  assert_eq "$(cat "$APP/impl.js")" 'exports.add = (a, b) => a+b;'
  assert_eq "$(git_app show HEAD:impl.js)" 'exports.add = (a, b) => 0;'
}
test_worker_skip_worktree_cannot_hide_uncommitted_implementation() {
  hidden_index_worker_is_rejected skip_index S
}
test_worker_assume_unchanged_cannot_hide_uncommitted_implementation() {
  hidden_index_worker_is_rejected assume_index h
}

if [ "${1:-}" = --case ]; then setup; "$2"; exit 0; fi
count=0; failures=0
for test_name in $(sed -n 's/^\(test_[a-z_]*\)() {.*/\1/p' "$SELF"); do
  count=$((count+1))
  if bash "$SELF" --case "$test_name"; then printf 'ok %s - %s\n' "$count" "$test_name"
  else printf 'not ok %s - %s\n' "$count" "$test_name"; failures=$((failures+1)); fi
done
printf 'Runner: %s cases, %s failures\n' "$count" "$failures"
[ "$count" -eq 27 ] && [ "$failures" -eq 0 ]
