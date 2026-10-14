# 다음 테스트 하나를 승인하는 흐름: 첫 테스트 검토

> 역사 기록: 아래의 개별 테스트 승인·영구 고정·필수 리뷰 절차는 2026-10-14에
> Canon TDD로 전환하며 폐기했습니다. 현재 흐름은 [사용 가이드](guide.md)를 따릅니다.
> 과거 승인 테스트 원본은 `tests/archive/approval-v1/`에 보관합니다.

검토용 — 설명 주석은 실행 코드에 포함되지 않음

승인 기록: 2026-10-14 사용자가 아래 첫 테스트를 승인했습니다. 실행 코드와 공유
도우미는 그대로 보존했고, 증분 승인 구현 뒤 이 테스트와 전체 검사가 통과했습니다.
독립 리뷰에서도 수정할 문제를 발견하지 못했습니다. 아래 초안 설명과 실패 결과는
승인 전에 제시한 기록입니다. 실행 파일의 당시 초안 주석도 원문 그대로 남겼습니다.

이 문서는 **첫 실행 테스트 하나의 승인 후보**입니다. 방향은 이미 요청하신 대로
정했습니다. 전체 기능의 테스트를 미리 완성하지 않고, 시나리오 목록에서 하나씩
골라 구체화합니다. GREEN에서 필요한 작은 구조 개선은 같은 개발 사이클에
포함하고, 기능 사이에는 배운 내용과 다음 선택을 돌아봅니다.

이번 첫 변경은 **다음 테스트를 승인해도 앞선 작업의 검증 기록과 누적 호출 수가
유지되는 것**입니다. 기존 `approve --replace`는 이 정보를 새로 시작하므로
일상적인 다음 테스트 승인에 쓰기 어렵습니다. `approve --append`를 제안합니다.
아래는 그 명령이 제공해야 할 동작의 초안이며, 현재 지원되는 명령은 아닙니다.

## 이번에 승인할 기대 동작

1. 첫 테스트를 승인하고 RED→GREEN 체크포인트를 만든다.
2. 다음 테스트 하나를 계획에 추가해도, 승인 전에는 실행을 거부한다.
3. 추가된 테스트를 승인할 때 최초 기준 커밋·누적 호출 수·기존 검증 기록을 유지한다.
4. 승인한 새 테스트를 실행하고 두 번째 검증 기록을 만든다.

두 번째 덧셈 테스트는 첫 구현으로 이미 통과하도록 의도했습니다. 덧셈 구현의
새 결함을 주장하는 테스트가 아니라 **하네스의 증분 승인**을 검증하는 fixture입니다.
따라서 두 번째 처리에서는 구현 작업자를 더 호출하지 않아야 합니다.

기존 테스트 변조 거부, 여러 항목 동시 승인 거부, 복구, GREEN 리팩터링, 기능 완료
판단은 [시나리오 목록](../brain/plans/04-incremental-tdd/overview.md)에 있습니다.
아직 그 실행 테스트들을 미리 작성하지 않았습니다. 이 한 사례의 통과만으로
새 개발 흐름 전체가 완성되었다고 판단하지 않습니다.

## 실행 결과와 범위

2026-10-14 기준으로 다음을 직접 확인했습니다.

- 기존 전체 검사 `bash tests/run.sh`: PASS.
- 초안 문법 검사 `/bin/bash -n tests/draft-next-test-approval.sh`: PASS.
- 초안 실행: 첫 RED→GREEN, 미승인 추가 항목 차단 및 상태 보존 검사를 통과한 후
  `FAIL: Unknown option --append`로 예상대로 실패.
- 독립 검토자도 동일하게 실행해 실패 지점을 확인했습니다.
- 아래 설명 주석만 제거하면 각각 원본 코드와 바이트 단위로 일치합니다.

하네스 구현, 기존 테스트, 기존 도우미는 수정하지 않았습니다. 초안은 아직
`tests/run.sh`에 등록하지 않았으며 실제 앱에 승인이나 구현을 수행하지 않습니다.
실제 Git·Node·하네스를 사용하고 모델 호출만 고정된 Bash 작업자로 대체합니다.
모델의 추론 품질이나 사용자 가치까지 검증하는 사례는 아닙니다.

## 공유 도우미와 fixture: 기존 코드, 변경 없음

원본: `tests/test-runner.sh` 1–95행. 아래 초안이 이 코드를 그대로 불러옵니다.
미사용 모드도 기존 파일에 있는 그대로 제시했습니다. 이번 사례는 `fix`만 사용합니다.

````text
// 검토: 기존 테스트 도우미 파일의 첫 95줄을 그대로 가져왔습니다.
#!/usr/bin/env bash
// 검토: Git과 Node 실행은 실제로 수행하고, 모델 작업자만 고정 동작의 셸 스크립트로 대체합니다.
# End-to-end runtime behavior: real Git/Node/Go, deterministic shell workers.
// 검토: Bash 3.2 호환 도우미이며 유료 모델 호출은 없습니다.
# Compatible with the system Bash 3.2. No paid worker calls.
// 검토: 도우미도 오류와 미정의 변수를 즉시 실패로 처리합니다.
set -eu
// 검토: 호출한 초안이 tests/에 있으므로 동일한 Sobaya 루트를 찾습니다.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
// 검토: 기존 테스트 파일의 위치입니다. 이번 --case 실행에서는 전체 사례 수집에 사용하지 않습니다.
SELF="$ROOT/tests/test-runner.sh"
// 검토: 모킹하지 않은 실제 하네스 진입점을 사용합니다.
RUNNER="$ROOT/tdd-set/lib/runner.sh"
// 검토: 실패하면 메시지, 마지막 하네스 오류, 남은 상태 파일을 출력하여 원인을 드러냅니다.
fail() { printf 'FAIL: %s\n' "$*" >&2; [ ! -f "${BASE:-}/stderr" ] || cat "$BASE/stderr" >&2; [ ! -f "${META:-}/state.json" ] || cat "$META/state.json" >&2; exit 1; }
// 검토: 두 문자열이 정확히 같은지 확인하는 도우미입니다.
assert_eq() { [ "$1" = "$2" ] || fail "expected <$2>, got <$1> ${3:-}"; }
// 검토: 파일에 요구한 문자열이 있는지 확인합니다. 전체 파일 동일성을 보장하는 도우미는 아닙니다.
contains() { grep -Fq -- "$2" "$1" || fail "$1 does not contain $2"; }
// 검토: 금지한 문자열이 파일에 있으면 실패합니다.
not_contains() { if grep -Fq -- "$2" "$1"; then fail "$1 unexpectedly contains $2"; fi; }
// 검토: 상태 JSON에 대한 jq 조건이 참인지 확인합니다.
state_is() { jq -e "$1" "$META/state.json" >/dev/null || fail "state assertion: $1"; }
// 검토: 모든 fixture Git 명령은 임시 앱 저장소 안에서 실행합니다.
git_app() { git -C "$APP" "$@"; }
// 검토: 임시 앱 변경 전체를 fixture 커밋으로 기록합니다.
commit() { git_app add -A; git_app commit -qm fixture; }
// 검토: 하네스 명령을 실행하고 종료 상태와 출력을 보관하는 도우미입니다.
run_cli() {
// 검토: 고정 작업자 모드와 테스트 파일을 전달합니다. 실패도 RC에 보관하여 초안이 기대한 거부인지 검사합니다.
  if FIXTURE_MODE="${MODE:-fix}" FIXTURE_TARGET="${TARGET:-suite.test.js}" bash "$RUNNER" "$1" "$APP" "${@:2}" >"$BASE/stdout" 2>"$BASE/stderr"; then RC=0; else RC=$?; fi
}
// 검토: 직전 명령이 성공해야 하는 지점에서 사용합니다.
okay() { [ "$RC" -eq 0 ] || fail "command exited $RC"; }
// 검토: 직전 명령이 실패해야 하는 지점에서 사용합니다. 원인은 별도 문자열 검사로 확인합니다.
rejected() { [ "$RC" -ne 0 ] || fail 'command unexpectedly passed'; }
// 검토: 임시 앱의 초기 승인 명령을 성공 조건과 함께 실행합니다. 실제 프로젝트의 인간 승인을 대신하지 않습니다.
approve() { run_cli approve; okay; }
// 검토: 기존 다른 사례용 정책 변경 도우미입니다. 이번 초안에서는 호출하지 않습니다.
policy_edit() { jq "$1" "$POLICY" > "$BASE/policy.new"; mv "$BASE/policy.new" "$POLICY"; }
// 검토: 임시 실행 자원을 정리하는 함수입니다.
cleanup() {
// 검토: 등록된 fixture 자식 프로세스가 있으면 종료하고 기다립니다.
  for pid in ${CHILDREN:-}; do kill -TERM "$pid" 2>/dev/null || :; wait "$pid" 2>/dev/null || :; done
// 검토: 이 실행이 만든 임시 디렉터리를 삭제합니다.
  rm -rf "$BASE"
}
// 검토: 실제 앱과 분리된 최소 임시 앱과 고정 작업자를 만듭니다.
setup() {
// 검토: 실행마다 별도 임시 디렉터리를 만듭니다.
  BASE=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-runner-shell.XXXXXX")
// 검토: 성공·실패 어느 경우든 종료 시 임시 자원을 정리합니다.
  trap cleanup EXIT
// 검토: 이번 초안은 정상 수정 모드 fix와 suite.test.js만 사용합니다.
  CHILDREN=''; MODE=fix; TARGET=suite.test.js
// 검토: 공백이 있는 앱 경로에서도 명령이 동작해야 합니다.
  APP="$BASE/app with spaces"; mkdir -p "$APP"
// 검토: 실제 임시 Git 저장소를 초기화합니다.
  git_app init -q
// 검토: fixture 커밋 작성자 이름을 저장소 로컬 설정에 넣습니다.
  git_app config user.name Fixture
// 검토: fixture용 비실재 이메일을 로컬 설정에 넣습니다.
  git_app config user.email fixture@example.invalid
// 검토: 사용자 서명 도구 없이 fixture 커밋을 만들 수 있게 합니다.
  git_app config commit.gpgsign false
// 검토: 사용자 Git hook이 테스트 동작에 개입하지 않도록 임시 저장소에서만 비활성화합니다.
  git_app config core.hooksPath /dev/null
// 검토: 하네스가 실제로 사용하는 저장소 내부 상태 경로입니다.
  META="$APP/.git/sobaya"
// 검토: 임시 fixture 명세는 양의 정수 덧셈입니다. 사용자의 앱 spec.md는 읽거나 바꾸지 않습니다.
  printf '# Goal\nAdd positive integers.\n' > "$APP/spec.md"
// 검토: 선언된 전체 테스트 명령은 실제 Node 테스트 러너입니다.
  printf '# Fixture\n- Test: `node --test suite.test.js`\n' > "$APP/AGENTS.md"
// 검토: 처음에는 항상 0을 반환하므로 첫 테스트의 기대값 3과 달라 실제 RED가 발생합니다.
  printf 'exports.add = (a, b) => 0;\n' > "$APP/impl.js"
// 검토: 기존 첫 테스트 본문을 저장하여 이후 보존 여부를 확인합니다.
  CODE="test('addAdds', () => assert.equal(add(1, 2), 3));"
// 검토: 첫 승인 후보인 테스트 하나와 필요한 헤더로 fixture 계획을 만듭니다.
  cat > "$APP/failed-test.md" <<'PLAN'
// 검토: fixture 계획 문서의 제목입니다.
# Plan

// 검토: 이 섹션의 헤더를 아래 테스트가 공유합니다.
## Add
```js
// 검토: 하네스가 테스트를 삽입할 파일은 앱 루트의 suite.test.js입니다.
// file: suite.test.js
// 검토: Node 기본 테스트 러너를 사용합니다.
const test = require('node:test');
// 검토: 타입 변환 없는 엄격한 동등성 검사를 사용합니다.
const assert = require('node:assert/strict');
// 검토: 별도의 실제 구현 파일에서 add를 가져옵니다.
const { add } = require('./impl.js');
```

// 검토: 첫 실행 항목은 미완료인 addAdds 하나입니다.
- [ ] addAdds — sums inputs
```js
// 검토: 1과 2의 합이 3이어야 한다는 첫 기대 동작입니다.
test('addAdds', () => assert.equal(add(1, 2), 3));
```
PLAN
// 검토: 첫 승인 입력과 잘못된 초기 구현을 임시 저장소에 커밋합니다.
  commit
// 검토: 초기 Git 커밋을 보관합니다.
  BASELINE=$(git_app rev-parse HEAD)
// 검토: 고정 동작 작업자 스크립트의 위치를 정합니다.
  WORKER="$BASE/worker.sh"
// 검토: 모델 대신 사용할 Bash 작업자를 만듭니다. 아래의 여러 모드 중 이번에는 fix만 실행합니다.
  cat > "$WORKER" <<'WORKER'
// 검토: 작업자 역시 Bash 스크립트입니다.
#!/usr/bin/env bash
// 검토: 작업자 내부 오류도 즉시 실패하게 합니다.
set -eu
// 검토: 하네스가 넘긴 임시 앱 경로를 사용합니다.
app=$SOBAYA_APP
// 검토: 초안이 전달한 fix 모드를 선택합니다.
mode=${FIXTURE_MODE:-fix}
// 검토: 하네스가 첫 테스트를 먼저 실행 파일에 넣었는지 확인한 다음 수정합니다.
grep -q addAdds "$app/${FIXTURE_TARGET:-suite.test.js}"
// 검토: 기존 공유 fixture의 동작 모드를 분기합니다. 이번 사례가 사용하는 것은 바로 다음 fix 분기뿐입니다.
case "$mode" in
// 검토: 구현 역할일 때만 a+b로 바꿉니다. 첫 테스트와 두 번째 테스트를 모두 만족합니다.
  fix) if [ "$SOBAYA_ROLE" = implement ]; then printf 'exports.add = (a, b) => a+b;\n' > "$app/impl.js"; fi ;;
// 검토: 아래 review_index는 다른 회귀 사례를 위한 모드이며 이번에는 실행하지 않습니다.
  review_index)
// 검토: 그 다른 모드에서는 리뷰 역할이 파일 실행 비트의 인덱스 변경을 시도합니다.
    if [ "$SOBAYA_ROLE" = review ]; then git -C "$app" update-index --chmod=+x impl.js
// 검토: 그 다른 모드의 구현 역할은 덧셈을 고칩니다.
    else printf 'exports.add = (a, b) => a+b;\n' > "$app/impl.js"; fi ;;
// 검토: 아래 두 모드도 다른 회귀 사례용이며 이번에는 실행하지 않습니다.
  skip_index|assume_index)
// 검토: 다른 모드의 구현 역할에서만 숨김 인덱스 플래그 조작을 합니다.
    if [ "$SOBAYA_ROLE" = implement ]; then
// 검토: 다른 회귀 사례가 지정한 숨김 인덱스 플래그를 선택합니다.
      if [ "$mode" = skip_index ]; then flag=--skip-worktree; else flag=--assume-unchanged; fi
// 검토: 그 플래그를 임시 구현 파일에 적용합니다.
      git -C "$app" update-index "$flag" impl.js
// 검토: 그 다른 모드도 구현 파일을 덧셈으로 바꿉니다.
      printf 'exports.add = (a, b) => a+b;\n' > "$app/impl.js"
    fi ;;
// 검토: 상태 변조와 시간 초과를 재현하는 다른 사례용 모드입니다. 이번에는 실행하지 않습니다.
  timeout_state)
// 검토: 그 모드가 변조하려는 임시 상태 파일 경로입니다.
    state="$app/.git/sobaya/state.json"
// 검토: 그 다른 모드는 호출 수 초기화를 시도합니다.
    jq '.calls=0' "$state" > "$state.tmp"; mv "$state.tmp" "$state"
// 검토: 그 모드는 10초 기다립니다. 이번 초안에는 이 대기가 없습니다.
    sleep 10 ;;
// 검토: 승인 테스트 변조를 검증하는 다른 사례용 모드입니다. 이번에는 실행하지 않습니다.
  tamper)
// 검토: 그 모드에서 변조할 테스트 파일을 가리킵니다.
    file="$app/${FIXTURE_TARGET:-suite.test.js}"
// 검토: 그 다른 모드는 기대값 3을 0으로 바꾸려고 합니다. 이번 초안은 이 분기를 사용하지 않습니다.
    sed 's/, 3)/, 0)/g' "$file" > "$file.tmp"; mv "$file.tmp" "$file" ;;
// 검토: 인계 보고를 재현하는 다른 사례용 모드입니다. 이번에는 실행하지 않습니다.
  handoff)
// 검토: 그 모드는 해결되지 않은 실패를 인계한다는 고정 보고서를 출력합니다.
    printf '%s\n' '{"status":"handoff","summary":"Needs another approach","reason":"The failing assertion is understood but implementation remains unresolved."}'
// 검토: 그 인계 모드는 정상 종료 코드를 반환합니다.
    exit 0 ;;
// 검토: 요구사항 충돌 보고를 재현하는 다른 사례용 모드입니다. 이번에는 실행하지 않습니다.
  defect)
// 검토: 그 모드는 인간이 검토할 추가 테스트가 필요하다는 고정 보고서를 출력합니다.
    printf '%s\n' '{"status":"defect","summary":"Requirement conflict","reason":"Need human-reviewed additional test."}'
// 검토: 그 결함 모드는 정상 종료 코드를 반환합니다.
    exit 0 ;;
esac
// 검토: fix 작업자는 완료 보고서를 출력합니다. 실제 통과 판정은 하네스가 별도로 Node 테스트를 실행해 내립니다.
printf '%s\n' '{"status":"done","summary":"Implemented the approved entry","reason":""}'
WORKER
// 검토: 이 임시 실행 전용 작업자 정책 파일을 만듭니다.
  POLICY="$BASE/policy.json"
// 검토: 외부 모델 대신 위 Bash 작업자를 사용합니다. 호출 상한 4회, 시간 제한 15초이며 자동 상향은 없습니다.
  jq -n --arg worker "$WORKER" '{version:1,mode:"selected",default_worker:"fixture",max_calls:4,timeout_seconds:15,workers:{fixture:{adapter:"command",command:["/bin/bash",$worker],model:"fixture",guidance:"guided"}},escalation:[]}' > "$POLICY"
}
````

실행 분기는 같은 파일의 다음 한 줄입니다. 중간의 기존 테스트 함수들은 정의만
되고, 이 분기에서 setup과 새 초안 하나를 실행한 후 종료합니다.

````text
// 검토: --case로 호출되면 임시 환경을 만들고 지정된 함수 하나만 실행한 뒤 종료합니다.
if [ "${1:-}" = --case ]; then setup; "$2"; exit 0; fi
````

## 첫 테스트의 정확한 실행 코드

항목: `test_next_test_approval_preserves_verified_progress`\
파일: `tests/draft-next-test-approval.sh`\
직접 실행: `/bin/bash tests/draft-next-test-approval.sh`

````text
// 검토: Bash로 실행하는 독립 초안입니다. 실제 앱을 대상으로 실행하지 않습니다.
#!/usr/bin/env bash
// 검토: 이 파일은 아직 사람이 승인한 회귀 테스트 모음에 포함되지 않습니다.
# DRAFT: not part of the accepted suite until the human reviews this case.
// 검토: 오류나 정의되지 않은 변수가 있으면 즉시 중단합니다.
set -eu

// 검토: 첫 체크포인트를 유지하면서 다음 테스트 하나를 승인하고 실행할 수 있는지 검증합니다.
test_next_test_approval_preserves_verified_progress() {
// 검토: 임시 앱의 첫 테스트를 승인하는 사용자 명령을 테스트 안에서 재현합니다.
  approve
// 검토: 고정된 가짜 작업자가 첫 실패를 고치고, 실제 하네스가 전체 Node 테스트를 검증하게 합니다.
  run_cli step --policy "$POLICY"; okay
// 검토: 작업자 호출 1회, 검증 기록 1개, 진행 중인 작업 없음이 첫 체크포인트의 조건입니다.
  state_is '.calls == 1 and (.receipts | length) == 1 and .active == null'
// 검토: 다음 승인 전후에 비교할 상태 전체를 저장합니다.
  cp "$META/state.json" "$BASE/first-checkpoint.json"

// 검토: 기존 테스트를 고치지 않고 계획 끝에 새 실행 테스트 하나만 붙입니다.
  cat >> "$APP/failed-test.md" <<'PLAN'

// 검토: 새 항목은 아직 완료되지 않은 상태이며 고유한 이름을 가집니다.
- [ ] addLargerInputs — sums another pair
```js
// 검토: 두 번째 입력 2와 3의 결과가 5인지 확인합니다. 첫 구현이 이미 만족하므로 이 사례는 승인·등록 흐름에 집중합니다.
test('addLargerInputs', () => assert.equal(add(2, 3), 5));
```
PLAN
// 검토: 승인 후보를 임시 Git 저장소에 커밋하여 dirty checkout 때문에 실패하는 일을 피합니다.
  commit

// 검토: 새 항목을 승인하기 전에 실행하면 반드시 거부되어야 합니다.
  run_cli step --policy "$POLICY"; rejected
// 검토: 거부 원인이 미승인 추가 항목인지 진단 메시지로 확인합니다.
  contains "$BASE/stderr" 'unapproved appended entries'
// 검토: 거부된 실행이 기존 상태 파일을 한 바이트도 바꾸지 않았는지 확인합니다.
  cmp "$BASE/first-checkpoint.json" "$META/state.json"
// 검토: 미승인 테스트가 실제 실행 파일에 먼저 삽입되지 않았는지 확인합니다.
  not_contains "$APP/suite.test.js" 'addLargerInputs'

// 검토: 새로 제안한 증분 승인 명령은 성공해야 합니다. 현재 하네스는 이 옵션이 없어서 여기서 실패합니다.
  run_cli approve --append; okay
// 검토: 승인 직전 상태와 지금 상태를 비교합니다. 뒤의 조건이 모두 참이어야 합니다.
  jq -e --slurpfile before "$BASE/first-checkpoint.json" '
// 검토: 기능 전체의 최초 승인 기준 커밋을 유지해야 합니다.
    .baseline == $before[0].baseline and
// 검토: 누적 작업자 호출 수를 초기화하거나 늘리지 않아야 합니다.
    .calls == $before[0].calls and
// 검토: 기존 검증 기록 전체를 그대로 보존해야 합니다.
    .receipts == $before[0].receipts and
// 검토: 승인 자체가 구현 작업을 시작하지 않아야 합니다.
    .active == null
// 검토: 조건이 하나라도 깨지면 기존 진행 기록을 잃었다는 오류로 실패합니다.
  ' "$META/state.json" >/dev/null || fail 'Next-test approval discarded verified progress'

// 검토: 승인된 새 항목을 기존 step 명령으로 처리할 수 있어야 합니다.
  run_cli step --policy "$POLICY"; okay
// 검토: 이미 통과하는 테스트임을 하네스가 명시적으로 관측해야 합니다.
  contains "$BASE/stdout" 'ALREADY GREEN addLargerInputs'
// 검토: 실행 파일에 기존 승인 테스트 본문이 그대로 남아 있어야 합니다.
  contains "$APP/suite.test.js" "$CODE"
// 검토: 실행 파일에 새 승인 테스트 본문도 정확히 들어가 있어야 합니다.
  contains "$APP/suite.test.js" "test('addLargerInputs', () => assert.equal(add(2, 3), 5));"
// 검토: 새 항목을 처리한 뒤에도 최초 체크포인트와 비교하여 연속성을 검증합니다.
  jq -e --slurpfile before "$BASE/first-checkpoint.json" '
// 검토: 새 체크포인트 뒤에도 최초 승인 기준 커밋을 유지해야 합니다.
    .baseline == $before[0].baseline and
// 검토: 이미 통과한 두 번째 사례 때문에 구현 작업자를 추가 호출하지 않아야 합니다.
    .calls == $before[0].calls and
// 검토: 검증 기록이 기존 1개에서 2개가 되어야 합니다.
    (.receipts | length) == 2 and
// 검토: 첫 검증 기록을 덮어쓰거나 다시 만들지 않아야 합니다.
    .receipts[0] == $before[0].receipts[0] and
// 검토: 두 번째 기록은 이번에 승인한 addLargerInputs에 해당해야 합니다.
    .receipts[1].entry == "addLargerInputs" and
// 검토: 새 항목의 최초 관측 결과가 이미 GREEN이었다는 사실을 기록해야 합니다.
    .receipts[1].red.status == "green" and
// 검토: 전체 테스트 실행에서 새 항목이 실제 통과한 이름 목록에 있어야 합니다.
    (.receipts[1].green | index("addLargerInputs")) != null and
// 검토: 처리가 끝났으므로 진행 중인 작업이 없어야 합니다.
    .active == null
// 검토: 이 조건들은 단순한 명령 성공이 아니라 검증된 체크포인트가 만들어졌는지 확인합니다.
  ' "$META/state.json" >/dev/null || fail 'Newly approved test did not become a verified checkpoint'
// 검토: 실행이 끝나면 임시 앱의 변경이 모두 커밋되어 checkout이 깨끗해야 합니다.
  assert_eq "$(git_app status --porcelain)" ''
}

// 검토: 이 초안 파일의 위치로 Sobaya 루트 경로를 구합니다.
draft_root=$(cd "$(dirname "$0")/.." && pwd)
// 검토: 기존 도우미를 수정하지 않고 불러옵니다. 아래 --case 분기 때문에 기존 27개 사례는 실행하지 않습니다.
# Reuse unchanged fixtures/helpers; --case runs only the draft function above.
// 검토: 공유 setup을 실행한 뒤 위에서 정의한 초안 함수 하나만 실행합니다.
. "$draft_root/tests/test-runner.sh" --case test_next_test_approval_preserves_verified_progress
````

승인은 이 문서에 설명된 정확한 실행 코드와 기존 도우미 사용 방식에 대한 것입니다.
새 테스트 본문을 바꿔야 한다면 변경된 기대 동작과 코드를 다시 제시합니다.
