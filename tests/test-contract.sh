#!/bin/bash
# Real Node/Go/Vitest evidence and isolated Git fixtures; Bash 3.2 + jq only.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tdd-set/lib/contract.sh"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
count=0; failures=0
expect_rc() {
  local expected=$1 actual; shift
  if "$@" >"$case_dir/result" 2>"$case_dir/errors"; then actual=0; else actual=$?; fi
  [ "$expected" -eq "$actual" ] || { echo "expected rc=$expected got=$actual: $*" >&2; cat "$case_dir/result" "$case_dir/errors" >&2; return 1; }
}
contains() { grep -q "$1" "$case_dir/errors"; }
g() { git -C "$app" "$@"; }
commit() { g add -A && g commit -qm fixture; }
fixture() {
  case_dir=$(mktemp -d "$work/case.XXXXXX"); app="$case_dir/app with spaces"; mkdir "$app"
  g init -q; g config user.name Test; g config user.email test@example.invalid; g config commit.gpgsign false; g config core.hooksPath /dev/null
  printf '%s\n' '- Test: `node --test calc.test.js`' >"$app/AGENTS.md"
  printf '# Addition\nReturn sum.\n' >"$app/spec.md"
  printf '{"type":"module"}\n' >"$app/package.json"
  printf 'export const add = (a,b) => 0;\n' >"$app/calc.js"
  cat >"$case_dir/header" <<'EOF'
// file: calc.test.js
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {add} from './calc.js';
EOF
  printf "test('addAdds: positive sum', () => assert.equal(add(1,2),3));\n" >"$case_dir/code"
  cp "$case_dir/header" "$app/calc.test.js"
  { printf '# Addition\n\n## Positive\n```js\n'; cat "$case_dir/header"; printf '\x60\x60\x60\n\n- [ ] addAdds — sum\n```js\n'; cat "$case_dir/code"; printf '\x60\x60\x60\n'; } >"$app/failed-test.md"
  commit; baseline=$(g rev-parse HEAD)
}
green() {
  printf 'export const add = (a,b) => a+b;\n' >"$app/calc.js"
  cat "$case_dir/header" "$case_dir/code" >"$app/calc.test.js"
  sed 's/^- \[ \] addAdds/- [x] addAdds/' "$app/failed-test.md" >"$case_dir/checked"; cp "$case_dir/checked" "$app/failed-test.md"
  commit
}
run_case() {
  count=$((count+1))
  if /bin/bash "$0" __case "$1"; then echo "ok $count - $1"; else echo "not ok $count - $1"; failures=$((failures+1)); fi
}
test_plan_exact() {
  contract_plan "$app" >"$case_dir/entries"
  jq -e --rawfile code "$case_dir/code" --rawfile header "$case_dir/header" 'length==1 and .[0].name=="addAdds" and .[0].checked==false and .[0].code==$code and .[0].header==$header and .[0].heading=="## Positive" and .[0].target=="calc.test.js"' "$case_dir/entries" >/dev/null
}
test_plan_malformed() {
  cp "$app/failed-test.md" "$case_dir/original"
  for kind in empty missing duplicate unclosed upper; do
    case "$kind" in
      empty) printf '# Plan\n' >"$app/failed-test.md";;
      missing) printf '%s\n' '- [x] TestAdd' >"$app/failed-test.md";;
      duplicate) cat "$case_dir/original" "$case_dir/original" >"$app/failed-test.md";;
      unclosed) sed '$d' "$case_dir/original" >"$app/failed-test.md";;
      upper) sed 's/^- \[ \]/- [X]/' "$case_dir/original" >"$app/failed-test.md";;
    esac
    expect_rc 1 contract_plan "$app" || return 1
  done
}
test_go_plan_exact() {
  printf '## Add\n- [ ] TestAdd — sum\n```go\nfunc TestAdd(t *testing.T) {}\n```\n' >"$app/failed-test.md"
  contract_plan "$app" >"$case_dir/entries"
  jq -e '.[0]|.name=="TestAdd" and .checked==false and .language=="go" and .heading=="## Add" and .target==null and .header=="" and .code=="func TestAdd(t *testing.T) {}\n"' "$case_dir/entries" >/dev/null
}
test_changed_header() {
  green
  awk '/import \{add\}/{print "// altered header"} {print}' "$app/failed-test.md" >"$case_dir/plan"; cp "$case_dir/plan" "$app/failed-test.md"; commit
  expect_rc 1 contract_gate "$app" "$baseline"; contains '[Aa]pproved plan'
}
test_index_flags_hide_broken_head() {
  green; printf 'export const add=()=>0;\n' >"$app/calc.js"; commit
  for flag in skip-worktree assume-unchanged; do
    g update-index "--$flag" calc.js
    printf 'export const add=(a,b)=>a+b;\n' >"$app/calc.js"
    test -z "$(g status --porcelain)"
    expect_rc 1 contract_gate "$app" "$baseline"
    contains 'index flags'
    g update-index "--no-$flag" calc.js
    g checkout -- calc.js
  done
}
test_valid_gate() { green; expect_rc 0 contract_gate "$app" "$baseline"; jq -e '.passed|index("addAdds: positive sum")!=null' "$case_dir/result" >/dev/null; }
test_pending() { expect_rc 1 contract_gate "$app" "$baseline"; contains '[Uu]nchecked'; }
test_weakened_plan() {
  green
  sed 's/add(1,2),3/add(1,2),0/' "$app/failed-test.md" >"$case_dir/weakened"; cp "$case_dir/weakened" "$app/failed-test.md"
  sed 's/add(1,2),3/add(1,2),0/' "$app/calc.test.js" >"$case_dir/weakened"; cp "$case_dir/weakened" "$app/calc.test.js"; commit
  expect_rc 1 contract_gate "$app" "$baseline"; contains '[Aa]pproved plan'
}
test_deleted_plan() { printf '# Plan\n' >"$app/failed-test.md"; commit; expect_rc 1 contract_gate "$app" "$baseline"; }
test_frozen_spec_commands() {
  green; good=$(g rev-parse HEAD)
  printf changed >"$app/spec.md"; commit; expect_rc 1 contract_gate "$app" "$baseline"; contains '[Aa]pproved spec'
  g reset --hard -q "$good"; printf '%s\n' '- Test: `true`' >"$app/AGENTS.md"; commit
  expect_rc 1 contract_gate "$app" "$baseline"; contains '[Aa]pproved AGENTS'
}
test_frozen_header_checkbox() {
  awk '/import \{add\}/{print "const markdown = `\n- [ ] literal\n`;"} {print}' "$app/failed-test.md" >"$case_dir/plan"; cp "$case_dir/plan" "$app/failed-test.md"; commit; baseline=$(g rev-parse HEAD)
  sed 's/- \[ \] literal/- [x] literal/' "$app/failed-test.md" >"$case_dir/plan"; cp "$case_dir/plan" "$app/failed-test.md"; commit
  expect_rc 1 contract_validate "$app" "$baseline"; contains '[Aa]pproved plan'
}
test_invalid_baseline_missing_plan() { green; expect_rc 1 contract_gate "$app" nonexistent; g rm -q failed-test.md; commit; expect_rc 1 contract_gate "$app" "$baseline"; }
test_dirty_head() { green; printf 'export const add=()=>0;\n' >"$app/calc.js"; commit; printf 'export const add=(a,b)=>a+b;\n' >"$app/calc.js"; expect_rc 1 contract_gate "$app" "$baseline"; contains clean; }
test_index_untracked() { green; printf changed >"$app/calc.js"; g add calc.js; expect_rc 1 contract_gate "$app" "$baseline"; g reset --hard -q HEAD; printf new >"$app/untracked"; expect_rc 1 contract_gate "$app" "$baseline"; }
test_negative_binary_fixtures() {
  mkdir "$app/tests"; printf '%s\n' -3 >"$app/tests/expected"; printf '\000old' >"$app/tests/binary"; commit; baseline=$(g rev-parse HEAD); green; good=$(g rev-parse HEAD)
  printf '%s\n' -0 >"$app/tests/expected"; commit; expect_rc 1 contract_gate "$app" "$baseline"; contains '[Pp]rotected'
  g reset --hard -q "$good"; printf '\000new' >"$app/tests/binary"; commit; expect_rc 1 contract_gate "$app" "$baseline"; contains '[Pp]rotected'
}
test_rename() { green; g mv calc.test.js renamed.test.js; commit; expect_rc 1 contract_gate "$app" "$baseline"; contains '[Pp]rotected'; }
test_commented() { green; { cat "$case_dir/header"; printf '/*\n'; cat "$case_dir/code"; printf '*/\n'; } >"$app/calc.test.js"; commit; expect_rc 1 contract_gate "$app" "$baseline"; contains executed; }
test_skipped() {
  sed "s/positive sum', ()/positive sum', {skip:true}, ()/" "$case_dir/code" >"$case_dir/skip"; cp "$case_dir/skip" "$case_dir/code"
  sed "s/positive sum', ()/positive sum', {skip:true}, ()/" "$app/failed-test.md" >"$case_dir/plan"; cp "$case_dir/plan" "$app/failed-test.md"; commit; baseline=$(g rev-parse HEAD); green
  expect_rc 1 contract_gate "$app" "$baseline"; contains executed
}
test_unsupported_runner() { printf '%s\n' '- Test: `true`' >"$app/AGENTS.md"; commit; baseline=$(g rev-parse HEAD); green; expect_rc 1 contract_gate "$app" "$baseline"; contains '[Uu]nsupported'; }
test_appended_unapproved() {
  green; printf '\n- [ ] addZero — zero\n```js\ntest("addZero", () => {});\n```\n' >>"$app/failed-test.md"; commit
  expect_rc 0 contract_validate "$app" "$baseline"; expect_rc 1 contract_gate "$app" "$baseline"
  sed 's/- \[ \] addZero/- [x] addZero/' "$app/failed-test.md" >"$case_dir/plan"; cp "$case_dir/plan" "$app/failed-test.md"; commit; expect_rc 1 contract_validate "$app" "$baseline"; contains '[Uu]napproved'
}
test_explicit_target() {
  g mv calc.test.js checks.js
  for file in AGENTS.md failed-test.md; do sed 's/calc.test.js/checks.js/g' "$app/$file" >"$case_dir/edit"; cp "$case_dir/edit" "$app/$file"; done
  sed 's/calc.test.js/checks.js/g' "$case_dir/header" >"$case_dir/newheader"; cp "$case_dir/newheader" "$app/checks.js"; commit; baseline=$(g rev-parse HEAD)
  printf 'export const add=(a,b)=>a+b;\n' >"$app/calc.js"; cat "$case_dir/newheader" "$case_dir/code" >"$app/checks.js"
  sed 's/^- \[ \] addAdds/- [x] addAdds/' "$app/failed-test.md" >"$case_dir/plan"; cp "$case_dir/plan" "$app/failed-test.md"; commit; expect_rc 0 contract_gate "$app" "$baseline"
}
test_npm_frozen_script() {
  printf '%s\n' '- Test: `npm test`' >"$app/AGENTS.md"; printf '{"type":"module","scripts":{"test":"node --test calc.test.js"}}\n' >"$app/package.json"; commit; baseline=$(g rev-parse HEAD); green
  expect_rc 0 contract_gate "$app" "$baseline"
  printf '{"type":"module","scripts":{"test":"true"}}\n' >"$app/package.json"; commit; expect_rc 1 contract_gate "$app" "$baseline"; contains '[Aa]pproved package'
}
test_real_red_build_error() {
  cat "$case_dir/header" "$case_dir/code" >"$app/calc.test.js"; expect_rc 10 contract_suite "$app"; jq -e '.failed|index("addAdds: positive sum")!=null' "$case_dir/result" >/dev/null
  printf 'not valid JS !!!\n' >"$app/calc.test.js"; expect_rc 11 contract_suite "$app"
}
test_timeout() { printf 'setInterval(()=>{},1000);\n' >"$app/calc.test.js"; expect_rc 1 contract_suite "$app" 0.1; contains 'timed out'; }
test_side_effect() { green; printf "import {writeFileSync} from 'node:fs'; writeFileSync('leftover','side effect'); export const add=(a,b)=>a+b;\n" >"$app/calc.js"; commit; expect_rc 1 contract_gate "$app" "$baseline"; contains clean; }
test_uncheck_complete() { green; baseline=$(g rev-parse HEAD); sed 's/- \[x\]/- [ ]/' "$app/failed-test.md" >"$case_dir/plan"; cp "$case_dir/plan" "$app/failed-test.md"; commit; expect_rc 1 contract_validate "$app" "$baseline"; contains completed; }
test_saved_baseline() {
  green; expect_rc 1 contract_saved_baseline "$app"
  printf '%s' "$baseline" >"$app/.git/sobaya-loop-start"; expect_rc 1 contract_saved_baseline "$app"
  mkdir "$app/.git/sobaya"; printf '{bad' >"$app/.git/sobaya/state.json"; expect_rc 1 contract_saved_baseline "$app"
}
test_worktree() { green; g worktree add -q -b linked "$case_dir/linked"; metadata=$(contract_git_dir "$case_dir/linked"); mkdir -p "$metadata/sobaya"; jq -n --arg baseline "$baseline" '{baseline:$baseline}' >"$metadata/sobaya/state.json"; expect_rc 0 /bin/bash "$ROOT/tdd-set/bin/gate.sh" "$case_dir/linked"; grep -q PASS "$case_dir/result"; }
test_hygiene_hooks_disabled() {
  initial=$baseline
  for kind in Format Lint; do
    g reset --hard -q "$initial"; printf '%s\n' '- Test: `node --test calc.test.js`' "- $kind: \`false\`" >"$app/AGENTS.md"; commit; baseline=$(g rev-parse HEAD); green
    expect_rc 1 contract_gate "$app" "$baseline"; contains "$kind"
  done
}
test_hygiene_output_mutation() {
  printf '%s\n' '- Test: `node --test calc.test.js`' '- Format: `printf format-checked`' '- Lint: `printf lint-checked`' >"$app/AGENTS.md"; commit; baseline=$(g rev-parse HEAD); green
  expect_rc 0 contract_gate "$app" "$baseline"; contains format-checked; contains lint-checked
  printf '%s\n' '- Test: `node --test calc.test.js`' '- Format: `printf changed > newfile`' >"$app/AGENTS.md"; commit; baseline=$(g rev-parse HEAD); expect_rc 1 contract_gate "$app" "$baseline"; contains clean
}
test_gofmt() { command -v gofmt >/dev/null || return 0; printf '%s\n' '- Test: `node --test calc.test.js`' '- Format: `gofmt -l ugly.go`' >"$app/AGENTS.md"; printf 'package calc\nfunc f( ){}\n' >"$app/ugly.go"; commit; baseline=$(g rev-parse HEAD); green; expect_rc 1 contract_gate "$app" "$baseline"; contains Format; }
test_quoted_gofmt() { command -v gofmt >/dev/null || return 0; printf '%s\n' '- Test: `node --test calc.test.js`' '- Format: `"gofmt" "-l" ugly.go`' >"$app/AGENTS.md"; printf 'package calc\nfunc f( ){}\n' >"$app/ugly.go"; commit; baseline=$(g rev-parse HEAD); green; expect_rc 1 contract_gate "$app" "$baseline"; contains Format; }
test_go_evidence() {
  command -v go >/dev/null || return 0
  printf '%s\n' '- Test: `go test ./...`' >"$app/AGENTS.md"; printf 'module fixture\n\ngo 1.22\n' >"$app/go.mod"; printf 'package calc\nfunc Add(a,b int)int{return a+b}\n' >"$app/calc.go"
  printf 'package calc\nimport "testing"\nfunc TestAdd(t *testing.T){if Add(1,2)!=3{t.Fatal("bad")}}\n' >"$app/calc_test.go"
  expect_rc 0 contract_suite "$app"; jq -e '.passed|index("TestAdd")!=null' "$case_dir/result" >/dev/null
  sed 's/!=3/!=4/' "$app/calc_test.go" >"$case_dir/go"; cp "$case_dir/go" "$app/calc_test.go"; expect_rc 10 contract_suite "$app"
  sed 's/Add(1,2)/Missing(1,2)/' "$app/calc_test.go" >"$case_dir/go"; cp "$case_dir/go" "$app/calc_test.go"; expect_rc 11 contract_suite "$app"; jq -e '.output|contains("undefined:")' "$case_dir/result" >/dev/null
}
test_go_import_additions() {
  printf 'package calc\nimport "testing"\nfunc TestOld(t *testing.T) {}\n' >"$case_dir/old"
  printf 'package calc\nimport "testing"\nimport "fmt"\nfunc TestOld(t *testing.T) {}\nfunc TestNew(t *testing.T) {}\n' >"$case_dir/new"
  _contract_additions calc_test.go "$case_dir/old" "$case_dir/new" false "$case_dir"
  printf 'package calc\nimport "testing"\nfunc TestOld(t *testing.T) { t.Skip() }\n' >"$case_dir/new"
  expect_rc 1 _contract_additions calc_test.go "$case_dir/old" "$case_dir/new" false "$case_dir"
}
test_vitest_evidence() {
  [ -n "${SOBAYA_TEST_VITEST_ROOT:-}" ] || { echo 'skip: set SOBAYA_TEST_VITEST_ROOT for actual Vitest'; return 0; }
  mkdir -p "$app/node_modules/.bin"; ln -s "$SOBAYA_TEST_VITEST_ROOT/node_modules/.bin/vitest" "$app/node_modules/.bin/vitest"; ln -s "$SOBAYA_TEST_VITEST_ROOT/node_modules/vitest" "$app/node_modules/vitest"
  printf '%s\n' '- Test: `vitest run --maxWorkers=1`' >"$app/AGENTS.md"
  printf "import {test,expect} from 'vitest'; test('addAdds',()=>expect(1+2).toBe(3));\n" >"$app/calc.test.js"
  expect_rc 0 contract_suite "$app"; jq -e '.passed|index("addAdds")!=null' "$case_dir/result" >/dev/null
  sed 's/toBe(3)/toBe(4)/' "$app/calc.test.js" >"$case_dir/vite"; cp "$case_dir/vite" "$app/calc.test.js"; expect_rc 10 contract_suite "$app"
  sed 's/test(/test.skip(/' "$app/calc.test.js" >"$case_dir/vite"; cp "$case_dir/vite" "$app/calc.test.js"; expect_rc 0 contract_suite "$app"; jq -e '.skipped|index("addAdds")!=null' "$case_dir/result" >/dev/null
}
test_process_groups() {
  export SOBAYA_WORKER_RECORD="$case_dir/worker.json"
  expect_rc 7 sb_run 2 "$case_dir/out" "$case_dir/err" /dev/null "$app" -- /bin/sh -c 'exit 7'; test ! -e "$SOBAYA_WORKER_RECORD"
  expect_rc 124 sb_run 0.1 "$case_dir/out" "$case_dir/err" /dev/null "$app" -- sleep 30; test ! -e "$SOBAYA_WORKER_RECORD"
  cat >"$case_dir/cancel.sh" <<'EOF'
#!/bin/bash
. "$1"
sb_run 30 "$2/out" "$2/err" /dev/null "$2" -- node -e 'require("fs").writeFileSync("pid",String(process.pid)); setInterval(()=>{},1000)'
exit $?
EOF
  set -m
  /bin/bash "$case_dir/cancel.sh" "$CONTRACT_LIB/common.sh" "$case_dir" >"$case_dir/cancelout" 2>"$case_dir/cancelerr" & coordinator=$!
  set +m
  tries=0; while [ ! -f "$case_dir/pid" ] && [ "$tries" -lt 100 ]; do sleep 0.02; tries=$((tries+1)); done
  test -f "$case_dir/pid"; child=$(cat "$case_dir/pid"); kill -INT "$coordinator"
  if wait "$coordinator"; then cancelled_rc=0; else cancelled_rc=$?; fi
  test "$cancelled_rc" -eq 130; ! sb_group_alive "$child"; test ! -e "$SOBAYA_WORKER_RECORD"
}
test_live_orphan() {
  set -m
  sleep 30 & orphan=$!
  set +m
  jq -n --argjson pid "$orphan" '{pid:$pid}' >"$case_dir/worker.json"
  expect_rc 1 sb_assert_no_orphan "$case_dir/worker.json"
  test -f "$case_dir/worker.json"
  kill -KILL -- "-$orphan"; wait "$orphan" 2>/dev/null || :
  expect_rc 0 sb_assert_no_orphan "$case_dir/worker.json"
  test ! -f "$case_dir/worker.json"
}
test_suite_cancellation() {
  export SOBAYA_CANCEL_MARKER="$case_dir/pid"
  printf 'import fs from "node:fs"; fs.writeFileSync(process.env.SOBAYA_CANCEL_MARKER,String(process.ppid));setInterval(()=>{},1000);\n' >"$app/calc.test.js"
  cat >"$case_dir/cancel-suite.sh" <<'EOF'
#!/bin/bash
. "$1"
contract_suite "$2" 30
exit $?
EOF
  set -m
  /bin/bash "$case_dir/cancel-suite.sh" "$CONTRACT_LIB/contract.sh" "$app" >"$case_dir/out" 2>"$case_dir/err" & coordinator=$!
  set +m
  tries=0; while [ ! -f "$case_dir/pid" ] && [ "$tries" -lt 100 ]; do sleep 0.02; tries=$((tries+1)); done
  test -f "$case_dir/pid"; child=$(cat "$case_dir/pid"); kill -INT "$coordinator"
  if wait "$coordinator"; then cancelled_rc=0; else cancelled_rc=$?; fi
  test "$cancelled_rc" -eq 130; ! sb_group_alive "$child"
}
if [ "${1:-}" = __case ]; then set -e; fixture; "$2"; exit; fi
for test in test_plan_exact test_plan_malformed test_valid_gate test_pending test_weakened_plan test_deleted_plan test_frozen_spec_commands test_frozen_header_checkbox test_invalid_baseline_missing_plan test_dirty_head test_index_untracked test_negative_binary_fixtures test_rename test_commented test_skipped test_unsupported_runner test_appended_unapproved test_explicit_target test_npm_frozen_script test_real_red_build_error test_timeout test_side_effect test_uncheck_complete test_saved_baseline test_worktree test_hygiene_hooks_disabled test_hygiene_output_mutation test_gofmt test_quoted_gofmt test_go_evidence test_go_import_additions test_vitest_evidence test_process_groups test_live_orphan test_suite_cancellation; do run_case "$test"; done
run_case test_go_plan_exact
run_case test_changed_header
run_case test_index_flags_hide_broken_head
printf '%s tests, %s failures\n' "$count" "$failures"
[ "$failures" -eq 0 ]
