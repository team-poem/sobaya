# 검증한 GREEN 정리 뒤 다음 테스트로 이어가기

> 역사 기록: 아래의 개별 테스트 승인·영구 고정·필수 리뷰 절차는 2026-10-14에
> Canon TDD로 전환하며 폐기했습니다. 현재 흐름은 [사용 가이드](guide.md)를 따릅니다.
> 과거 승인 테스트 원본은 `tests/archive/approval-v1/`에 보관합니다.

승인·구현 완료 — 설명 주석은 실행 코드에 포함되지 않음

2026-10-14 사용자가 아래의 정확한 테스트를 승인했습니다. 원본을 바꾸지 않고
구현했으며, 단독 실행·전체 회귀 검사·독립 완료 리뷰를 통과했습니다.
`tests/run.sh`에 등록했고, 파일의 `DRAFT` 주석은 승인된 원문 보존을 위해 남겼습니다.
승인 원본 SHA-256:
`e728cd23ad96367e08b8e9b6ea46205027e076ccd5b72e21e0c6ecb97d3333f3`.

아래는 새 실행 테스트 **하나**를 검토한 내용입니다. 기능 경계에서 같은 작업 안의 선택적
정리와 회고를 하는 지침은 이미 반영했습니다. 이 테스트는 **테스트 사이에서 정리한
소스를 검증·리뷰한 다음, 기존 이력을 유지하며 다음 테스트를 승인하는 연결**을 다룹니다.

## 기대 동작

1. 첫 테스트의 GREEN과 정리 전 리뷰를 확보한다.
2. 테스트를 바꾸지 않고 구현을 정리한 별도 커밋을 만든다.
3. 정리된 새 HEAD로 전체 검사를 실행하고 새 리뷰를 받는다.
4. 다음 테스트 하나를 승인하며 정리한 소스·최초 기준·호출 수·행동 검증 기록을 보존한다.
5. 이전 리뷰 증거는 승인 이력에 남기고, 새 플랜의 현재 완료 리뷰는 비운다.
6. 새 테스트를 실제 체크포인트까지 진행한다.

구현 전 하네스는 3번까지 성공했지만 4번에서
`Only failed-test.md may change after the verified checkpoint for append approval.`
오류로 실패했습니다. 정리된 커밋을 리뷰했어도 비교 기준이 마지막 행동 체크포인트에
머물러 있었기 때문입니다. 승인 후에는 검증한 리뷰 HEAD를 추가 비교 기준으로
사용하고, 소비한 리뷰 증거를 승인 이력에 보존하도록 구현했습니다.

이 테스트의 구현은 새 리팩터링 작업자나 자동 정리 명령을 요구하지 않습니다.
기존 `review.sh`의 검증 증거를 활용합니다. 리뷰받지 않은 소스 변경, 보호 입력
변조, 리뷰 이후 추가 변경을 허용한다는 승인은 아닙니다. 기존 보호 규칙을 유지해야 합니다.

현재 `review.sh`는 모든 승인 항목이 완료되어 있어야 합니다. 따라서 이 사례는
한 테스트씩 승인하는 새 흐름을 대상으로 하며, 미완료 항목이 남은 예전 묶음 플랜
중간의 정리까지 지원한다고 주장하지 않습니다.

## 그대로 사용하는 공유 코드와 생략하는 것

원본은 `tests/test-runner.sh`의 1–95행 fixture·도우미 및 `--case` 실행 분기입니다.
[이전 검토 문서](incremental-tdd-first-test-review.md)의 공유 도우미 절에 전체 코드와
한국어 설명이 있습니다. 그 파일은 이전 승인 이후 바뀌지 않았습니다.
SHA-256: `6202c3d38a3022c4b7114eda317ba97cf0d92f30f620b280beebe55b02d9791c`.

실제 임시 Git 저장소, 실제 Node 전체 테스트, 실제 하네스를 사용합니다. 모델 호출은
고정 Bash 작업자로 대체하므로 비용이 들지 않습니다. 리뷰 작업자는 성공 보고만
반환하며 **리뷰 호출과 HEAD 연결을 검증할 뿐, 사람·모델의 설계 판단 품질을 검증하지
않습니다**. 전체 테스트 통과가 가능한 모든 입력의 행동 동등성을 증명하는 것도 아닙니다.

두 번째 덧셈 테스트는 의도적으로 이미 GREEN입니다. 정리 후 승인 연결을 검증하며
새 덧셈 기능이 빠졌다고 주장하지 않습니다. source 정리는 임시 fixture의 검증 후보로
커밋한 뒤 실제 review 게이트로 검사합니다. 실제 개발에서는 계약에 따라 구조 변경을
커밋하기 전에도 전체 검사를 통과시킵니다.

## 정확한 실행 코드

항목: `test_reviewed_green_refactor_allows_next_test`\
파일: `tests/draft-reviewed-green-refactor.sh`\
직접 실행: `/bin/bash tests/draft-reviewed-green-refactor.sh`

````text
// 검토: Bash로 실행하는 독립 초안입니다. 실제 앱이 아닌 임시 fixture에서만 동작합니다.
#!/usr/bin/env bash
// 검토: 작성 당시의 초안 표시를 그대로 보존했습니다. 승인 후 정규 회귀 검사에 등록했습니다.
# DRAFT: review this case before implementing reviewed-refactor continuation.
// 검토: 명령 오류나 미정의 변수가 있으면 즉시 실패합니다.
set -eu

// 검토: GREEN 정리를 새 HEAD에서 검증·리뷰한 뒤 다음 테스트 승인으로 이어갈 수 있는지 확인합니다.
test_reviewed_green_refactor_allows_next_test() {
// 검토: 임시 앱의 첫 테스트에 대한 승인 명령을 재현합니다. 실제 앱의 인간 승인을 대신하지 않습니다.
  approve
// 검토: 고정 작업자가 첫 RED를 고치고 하네스가 첫 GREEN 체크포인트를 만듭니다.
  run_cli step --policy "$POLICY"; okay
// 검토: 정리 전 HEAD에도 리뷰를 만들어 두어 나중에 이 낡은 리뷰가 재사용되는지 구별합니다.
  run_cli review --policy "$POLICY"; okay
// 검토: 구현 1회와 리뷰 1회로 누적 호출은 2회이며 행동 검증 기록은 하나여야 합니다.
  state_is '.calls == 2 and (.receipts | length) == 1 and .active == null'
// 검토: 정리 전 상태 전체를 이후 비교용으로 보관합니다.
  cp "$META/state.json" "$BASE/before-tidy.json"
// 검토: 실행 테스트 원본을 보관하여 정리 중 바뀌지 않았는지 확인합니다.
  cp "$APP/suite.test.js" "$BASE/protected-test.js"
// 검토: 승인 계획 원본도 보관합니다.
  cp "$APP/failed-test.md" "$BASE/protected-plan.md"

// 검토: 임시 구현만 구조적으로 바꿉니다. 아직 검증할 후보 변경입니다.
  cat > "$APP/impl.js" <<'SOURCE'
// 검토: 덧셈 연산을 내부 함수 sum으로 옮깁니다. 기대 동작은 계속 두 인자의 덧셈입니다.
function sum(a, b) { return a + b; }
// 검토: 테스트가 사용하는 외부 이름 exports.add와 인자 형태는 유지하고 내부 함수에 위임합니다.
exports.add = (a, b) => sum(a, b);
SOURCE
// 검토: 임시 구현 파일만 커밋 대상으로 올립니다.
  git_app add impl.js
// 검토: 검증 대상으로 삼을 구조 변경 커밋을 만듭니다. 하네스는 다음 review 단계에서 실제 전체 검사를 실행합니다.
  git_app commit -qm 'refactor: name the addition operation'
// 검토: 정리된 커밋을 정확한 리뷰 대상과 비교하기 위해 기록합니다.
  tidied_head=$(git_app rev-parse HEAD)
// 검토: 정리한 소스의 실제 바이트를 보관합니다. 이후 승인이 이를 되돌려서는 안 됩니다.
  cp "$APP/impl.js" "$BASE/tidied-source.js"
// 검토: 현재 하네스의 전체 게이트와 리뷰를 다시 실행합니다. 고정 리뷰 작업자는 판단 품질을 모사하지 않습니다.
  run_cli review --policy "$POLICY"; okay
// 검토: 정리·검증·리뷰를 거쳐도 실행 테스트가 한 바이트도 바뀌지 않아야 합니다.
  cmp "$BASE/protected-test.js" "$APP/suite.test.js"
// 검토: 기존 승인 계획도 그대로여야 합니다.
  cmp "$BASE/protected-plan.md" "$APP/failed-test.md"
// 검토: 정리 전후의 상태와 새 커밋을 비교합니다.
  jq -e --slurpfile before "$BASE/before-tidy.json" --arg head "$tidied_head" '
// 검토: 기능 전체의 원래 승인 기준은 유지해야 합니다.
    .baseline == $before[0].baseline and
// 검토: 기존 행동 체크포인트 기록을 구조 변경 기록으로 덮어쓰지 않아야 합니다.
    .receipts == $before[0].receipts and
// 검토: 이전 리뷰를 재사용하지 않고 새 리뷰 작업자를 정확히 한 번 더 호출해야 합니다.
    .calls == ($before[0].calls + 1) and
// 검토: 리뷰 성공은 정리한 새 HEAD에 연결되어야 합니다.
    .review.head == $head and
// 검토: 정리 전 HEAD에 대한 리뷰와 달라야 합니다.
    .review.head != $before[0].review.head
// 검토: 어느 조건이든 깨지면 정리한 HEAD의 새 리뷰가 검증되지 않은 것으로 실패합니다.
  ' "$META/state.json" >/dev/null || fail 'Tidied HEAD did not get a fresh verified review'
// 검토: 다음 승인에서 보존해야 할 정리 리뷰와 누적 상태를 저장합니다.
  cp "$META/state.json" "$BASE/reviewed-tidy.json"

// 검토: 다음 실행 테스트 하나만 계획에 추가합니다.
  cat >> "$APP/failed-test.md" <<'PLAN'

// 검토: 새 항목은 addLargerInputs이며 아직 미완료입니다.
- [ ] addLargerInputs — sums another pair
```js
// 검토: 2와 3의 합이 5인지 검사합니다. 이미 통과하는 fixture여서 승인 연결과 기록 보존에 집중합니다.
test('addLargerInputs', () => assert.equal(add(2, 3), 5));
```
PLAN
// 검토: 승인할 새 계획을 임시 저장소에 커밋해 깨끗한 상태로 만듭니다.
  commit
// 검토: 정리한 HEAD가 검증·리뷰되었으므로 다음 테스트 승인이 성공해야 합니다. 현재는 여기서 실패합니다.
  run_cli approve --append; okay
// 검토: 승인을 처리하며 정리한 실제 소스를 이전 코드로 되돌리면 안 됩니다.
  cmp "$BASE/tidied-source.js" "$APP/impl.js"
// 검토: 승인 직전 정리 리뷰와 현재 상태를 비교합니다.
  jq -e --slurpfile before "$BASE/reviewed-tidy.json" '
// 검토: 기능 전체의 최초 기준 커밋을 유지해야 합니다.
    .baseline == $before[0].baseline and
// 검토: 승인이 작업자를 호출하거나 누적 호출 수를 초기화하면 안 됩니다.
    .calls == $before[0].calls and
// 검토: 기존 행동 검증 기록은 그대로여야 합니다.
    .receipts == $before[0].receipts and
// 검토: 다음 테스트가 추가되어 현재 플랜의 완료 리뷰는 비워야 합니다.
    .review == null and
// 검토: 소비한 정리 리뷰 증거는 이번 승인 이력에 정확히 보존해야 합니다.
    .acceptance_history[-1].review == $before[0].review
// 검토: 위 조건이 깨지면 검증된 정리 증거가 사라졌다고 실패합니다.
  ' "$META/state.json" >/dev/null || fail 'Next approval lost the reviewed tidying evidence'

// 검토: 새로 승인한 항목을 실제 하네스의 step으로 처리합니다.
  run_cli step --policy "$POLICY"; okay
// 검토: 추가 구현이 필요 없는 테스트임을 하네스가 명시적으로 관측해야 합니다.
  contains "$BASE/stdout" 'ALREADY GREEN addLargerInputs'
// 검토: 다음 체크포인트까지 끝난 뒤에도 정리한 소스가 그대로 남아 있어야 합니다.
  cmp "$BASE/tidied-source.js" "$APP/impl.js"
// 검토: 다음 체크포인트가 기존 기능 이력을 이어받았는지 비교합니다.
  jq -e --slurpfile before "$BASE/reviewed-tidy.json" '
// 검토: 새 체크포인트 뒤에도 최초 승인 기준을 보존해야 합니다.
    .baseline == $before[0].baseline and
// 검토: 이미 통과하는 테스트 때문에 작업자를 더 호출하지 않아야 합니다.
    .calls == $before[0].calls and
// 검토: 기존 행동 기록 하나에 새 기록 하나가 추가되어야 합니다.
    (.receipts | length) == 2 and
// 검토: 첫 행동 기록 전체는 바뀌면 안 됩니다.
    .receipts[0] == $before[0].receipts[0] and
// 검토: 두 번째 기록은 방금 승인한 addLargerInputs의 것이어야 합니다.
    .receipts[1].entry == "addLargerInputs" and
// 검토: 전체 테스트 실행에서 이 항목이 실제 통과한 이름 목록에 있어야 합니다.
    (.receipts[1].green | index("addLargerInputs")) != null and
// 검토: 체크포인트가 끝났으므로 진행 중인 작업이 없어야 합니다.
    .active == null
// 검토: 위 조건이 깨지면 다음 체크포인트가 기존 이력을 잃었다고 실패합니다.
  ' "$META/state.json" >/dev/null || fail 'Next checkpoint did not preserve the feature history'
// 검토: 실행 파일에 첫 승인 테스트 코드가 여전히 있어야 합니다.
  contains "$APP/suite.test.js" "$CODE"
// 검토: 실행 파일에 새 승인 테스트 코드도 정확히 있어야 합니다.
  contains "$APP/suite.test.js" "test('addLargerInputs', () => assert.equal(add(2, 3), 5));"
// 검토: 마지막 체크포인트가 끝나면 임시 앱의 모든 변경이 커밋되어 있어야 합니다.
  assert_eq "$(git_app status --porcelain)" ''
}

// 검토: 초안 파일의 위치로 Sobaya 루트를 찾습니다.
draft_root=$(cd "$(dirname "$0")/.." && pwd)
// 검토: 이전에 검토한 기존 도우미와 fixture를 수정 없이 재사용합니다.
# Reuse the unchanged, previously reviewed fixture and run only this draft.
// 검토: 공유 setup 뒤 이 초안 함수 하나만 실행하며 기존 27개 사례를 다시 실행하지 않습니다.
. "$draft_root/tests/test-runner.sh" --case test_reviewed_green_refactor_allows_next_test
````

2026-10-14 구현 전 probe: Bash 문법 검사 통과. 정리 전·후 리뷰와 보호된 코드 보존 검사는
통과하고 위의 append 제한에서 예상대로 실패했습니다. 초안은 정규 suite에 포함하지
않았고, 당시에는 이 연결을 지원하는 런타임 구현도 변경하지 않았습니다. 검토용 설명만
제거하면 이 문서의 코드가 실행 원본과 정확히 일치하도록 대조했습니다.
