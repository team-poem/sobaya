# 미완료 묶음 플랜의 GREEN 정리: 테스트 검토

> 역사 기록: 아래의 개별 테스트 승인·영구 고정·필수 리뷰 절차는 2026-10-14에
> Canon TDD로 전환하며 폐기했습니다. 현재 흐름은 [사용 가이드](guide.md)를 따릅니다.
> 과거 승인 테스트 원본은 `tests/archive/approval-v1/`에 보관합니다.

승인·구현 완료 — 설명 주석은 실행 코드에 포함되지 않음

2026-10-14 사용자가 아래의 정확한 테스트를 승인했습니다. 실행 파일의 `DRAFT`
주석까지 원문을 보존했고, 단독 실행·전체 회귀 검사·독립 완료 리뷰를 통과했습니다.
`tests/run.sh`에도 등록했습니다. 아래 초안 설명과 RED 결과는 승인 전 검토 기록입니다.

요청한 변경을 검증하는 **실행 테스트 하나**입니다. 두 테스트를 처음부터 승인한
묶음 플랜에서 첫 항목만 완료하고, 필요한 구조 정리를 검증·리뷰한 뒤 기존에 승인된
두 번째 항목으로 이어갑니다. 남은 테스트의 재승인이나 `--replace`는 필요하지 않습니다.

구현한 명령은 `tdd-set/bin/review.sh APP --checkpoint`입니다. 중간 리뷰는
현재 검증된 체크포인트 이후의 구조 변경을 확인합니다. 기본 `review.sh APP`은
모든 항목을 마친 최종 리뷰로 유지합니다. **아래 RED 기록은 `--checkpoint` 구현 전의 결과입니다.**

## 승인할 기대 동작

1. 두 승인 항목 중 첫 번째만 GREEN 체크포인트로 완료한다.
2. 정리가 기존 테스트를 깨뜨리면 전체 검사에서 거부하고 상태·호출 수를 보존한다.
3. 수정한 정리는 미완료 항목이 있어도 중간 리뷰를 통과한다. 테스트·플랜은 그대로다.
4. 중간 리뷰는 별도 이력에 남고, 작업 전체를 완료로 표시하지 않는다. 같은 리뷰를
   재요청해도 호출이나 기록을 중복하지 않는다.
5. 최종 리뷰는 남은 항목 때문에 계속 거부한다. 다음 승인 항목을 진행하면 정리한
   소스·기존 행동 기록·중간 리뷰 이력을 보존한다.
6. 모든 항목을 마친 뒤 마지막 HEAD를 별도 최종 리뷰해야 완료가 된다.

중간 작업자에게는 마지막 행동 체크포인트 SHA, 남은 항목, 아직 예정된 항목을 완료
결함으로 판단하지 않는 지침을 전달합니다. 최종 작업자의 범위는 원래 기능 기준부터
마지막 HEAD까지로 유지합니다. 중간 이력의 제안 저장 위치는 `checkpoint_reviews`이며,
기존 최종 리뷰인 `review`와 구별합니다. 승인된 테스트의 의미·보호 규칙은 유지합니다.

## 재사용하는 코드와 검증 한계

공유 fixture·도우미는 `tests/test-runner.sh`의 1–95행 및 `--case` 실행 분기입니다.
[첫 검토 문서의 공유 도우미](incremental-tdd-first-test-review.md)에 전체 코드와
한국어 설명이 있습니다. 이 공유 코드와 앞서 승인한 두 테스트는 변경하지 않습니다.
공유 코드 SHA-256:
`6202c3d38a3022c4b7114eda317ba97cf0d92f30f620b280beebe55b02d9791c`.

실제 임시 Git 저장소, Node 테스트 실행과 하네스를 사용합니다. 모델 호출은 기존의
고정 Bash 작업자가 대신하므로 비용이 들지 않습니다. 작업자의 실제 설계 판단 품질은
검증하지 않습니다. 기존 읽기 전용 `review` 역할의 사용 기록, 전달한 프롬프트의
범위와 성공 결과가 어떤 상태로 기록되는지를
검증합니다. 여기서 정리 전후 테스트 통과가 모든 입력의 행동 동등성을 증명하지는 않습니다.

두 번째 항목은 첫 구현으로 이미 GREEN이 되도록 의도했습니다. 새 기능의 누락을
주장하는 테스트가 아니라 **기존 승인 항목으로 이어가는 하네스의 흐름**을 검증합니다.
추가 구현 호출이 필요한 두 번째 RED 사례는 이번 테스트의 범위가 아닙니다.

잘못된 정리 후보를 임시 fixture에 커밋하는 것은 리뷰 게이트의 거부를 검증하기
위해서입니다. 실제 개발에서는 작은 정리 후 전체 검사·필수 검사를 통과한 다음
구조 커밋을 만듭니다. 테스트 변조, 잘못된 조상 관계, 활성 구현 중 리뷰, 오래된
중간 리뷰 재사용 등의 별도 적대적 사례는 시나리오 목록에 남깁니다.

## 정확한 실행 코드

항목: `test_batch_green_refactor_preserves_pending_work`\
파일: `tests/draft-batch-green-refactor.sh`\
직접 실행: `/bin/bash tests/draft-batch-green-refactor.sh`

초안 SHA-256: `a175cc241fca18ae4d51a3df9e5858c6c8e5ef56119baf9fe3be2f2814778187`.

````text
// 검토: Bash로 실행하며 임시 Git·Node fixture만 사용합니다.
#!/usr/bin/env bash
// 검토: 승인 전 작성한 초안 주석을 보존했습니다. 승인 후 정규 회귀 검사에 등록했습니다.
# DRAFT: review this case before implementing intermediate batch review.
// 검토: 명령 실패나 미정의 변수가 있으면 즉시 중단합니다.
set -eu

// 검토: 미완료 승인 항목이 남은 묶음에서 정리·중간 리뷰·이어서 진행·최종 리뷰를 확인합니다.
test_batch_green_refactor_preserves_pending_work() {
// 검토: 최초 승인 전에 두 번째 항목을 추가해 처음부터 두 항목이 있는 묶음 플랜을 만듭니다.
  cat >> "$APP/failed-test.md" <<'PLAN'

// 검토: 두 번째 항목은 아직 완료하지 않은 addLargerInputs입니다.
- [ ] addLargerInputs — sums another pair
```js
// 검토: 두 번째 테스트는 2+3이 5인지 확인합니다. 첫 구현으로 이미 GREEN이 되도록 의도했습니다.
test('addLargerInputs', () => assert.equal(add(2, 3), 5));
```
PLAN
// 검토: 두 항목을 담은 임시 플랜을 승인 기준 후보로 커밋합니다.
  commit
// 검토: 임시 fixture에서 두 항목을 함께 승인합니다. 실제 앱의 인간 승인을 대신하지 않습니다.
  approve
// 검토: 첫 항목 하나만 RED에서 GREEN으로 구현하고 검증된 체크포인트를 만듭니다.
  run_cli step --policy "$POLICY"; okay
// 검토: 구현 호출 1회·행동 기록 1개이며 최종 리뷰와 진행 중 항목이 없어야 합니다.
  state_is '.calls == 1 and (.receipts | length) == 1 and .review == null and .active == null'
// 검토: 첫 번째 항목만 완료 표시가 되었는지 확인합니다.
  contains "$APP/failed-test.md" '[x] addAdds'
// 검토: 두 번째 승인 항목은 미완료 상태로 남아 있어야 합니다.
  contains "$APP/failed-test.md" '[ ] addLargerInputs'
// 검토: 두 번째 테스트는 실행 파일에 아직 삽입되지 않아야 합니다.
  not_contains "$APP/suite.test.js" 'addLargerInputs'
// 검토: 리팩터링 전 승인 상태 전체를 보관합니다.
  cp "$META/state.json" "$BASE/before-tidy.json"
// 검토: 첫 실행 테스트 원본을 보관합니다.
  cp "$APP/suite.test.js" "$BASE/protected-test.js"
// 검토: 완료·미완료 표시까지 포함한 승인 플랜 원본을 보관합니다.
  cp "$APP/failed-test.md" "$BASE/protected-plan.md"

// 검토: 게이트 실패를 재현하기 위해 임시 덧셈 구현을 의도적으로 뺄셈으로 바꿉니다.
  printf 'exports.add = (a, b) => a-b;\n' > "$APP/impl.js"
// 검토: 이 실패 후보의 구현 파일만 스테이징합니다.
  git_app add impl.js
// 검토: 게이트가 검사할 실패 후보 커밋입니다. 실제 개발에서는 정리 커밋 전에도 전체 검사를 합니다.
  git_app commit -qm 'fixture: broken tidy candidate'
// 검토: 중간 리뷰를 요청해도 실제 테스트가 실패하는 정리는 거부해야 합니다.
  run_cli review --checkpoint --policy "$POLICY"; rejected
// 검토: 실패 진단에 실제 기존 테스트 이름 addAdds가 있어야 합니다. 알 수 없는 옵션 오류만으로는 통과하지 않습니다.
  contains "$BASE/stderr" 'addAdds'
// 검토: 게이트 실패는 호출 수·승인·기존 검증 기록 등 상태를 전혀 바꾸지 않아야 합니다.
  cmp "$BASE/before-tidy.json" "$META/state.json"
// 검토: 실패한 소스는 자동으로 되돌리지 않고 진단할 수 있게 보존해야 합니다.
  assert_eq "$(cat "$APP/impl.js")" 'exports.add = (a, b) => a-b;'

// 검토: 실패한 후보를 진단한 뒤 구현을 수정합니다. 테스트나 플랜은 바꾸지 않습니다.
  cat > "$APP/impl.js" <<'SOURCE'
// 검토: 내부 함수 sum이 원래의 덧셈 동작을 수행합니다.
function sum(a, b) { return a + b; }
// 검토: 기존 공개 이름 exports.add와 인자는 유지하며 내부 함수에 위임합니다.
exports.add = (a, b) => sum(a, b);
SOURCE
// 검토: 수정한 구조 변경 파일만 스테이징합니다.
  git_app add impl.js
// 검토: 검증 대상인 수정된 구조 변경을 별도 커밋으로 만듭니다.
  git_app commit -qm 'refactor: name the addition operation'
// 검토: 중간 리뷰가 정확히 이 커밋을 가리키는지 비교할 HEAD를 보관합니다.
  tidied_head=$(git_app rev-parse HEAD)
// 검토: 후속 작업이 정리한 소스를 보존하는지 바이트 단위로 비교할 원본을 보관합니다.
  cp "$APP/impl.js" "$BASE/tidied-source.js"
// 검토: 미완료 항목이 있어도 현재 전체 테스트가 GREEN인 정리는 중간 리뷰를 통과해야 합니다.
  run_cli review --checkpoint --policy "$POLICY"; okay
// 검토: 실행 테스트는 정리 전과 완전히 같아야 합니다.
  cmp "$BASE/protected-test.js" "$APP/suite.test.js"
// 검토: 승인 플랜도 완료 표시까지 정리 전과 완전히 같아야 합니다.
  cmp "$BASE/protected-plan.md" "$APP/failed-test.md"
// 검토: 정리 전 상태와 새 HEAD를 사용해 중간 리뷰 결과를 확인합니다.
  jq -e --slurpfile before "$BASE/before-tidy.json" --arg head "$tidied_head" '
// 검토: 기능 전체의 최초 승인 기준을 보존해야 합니다.
    .baseline == $before[0].baseline and
// 검토: 최초 승인 시각을 다시 시작하지 않아야 합니다.
    .approved_at == $before[0].approved_at and
// 검토: 중간 리뷰가 다음 테스트의 승인 기준을 새로 만들거나 바꾸면 안 됩니다.
    .acceptance_head == $before[0].acceptance_head and
// 검토: 다음 테스트 승인 이력도 그대로여야 합니다.
    .acceptance_history == $before[0].acceptance_history and
// 검토: 기존 행동 체크포인트 기록을 정리 기록으로 덮어쓰면 안 됩니다.
    .receipts == $before[0].receipts and
// 검토: 실패한 게이트는 호출을 쓰지 않고 성공한 중간 리뷰만 1회를 추가해야 합니다.
    .calls == ($before[0].calls + 1) and
// 검토: 최종 완료 리뷰는 없고 상태는 checkpoint이며 진행 중인 구현도 없어야 합니다.
    .review == null and .status == "checkpoint" and .active == null and
// 검토: 별도 중간 리뷰 이력이 정확히 하나 생겨야 합니다.
    (.checkpoint_reviews | length) == 1 and
// 검토: 중간 리뷰는 정리한 새 HEAD에 연결되어야 합니다.
    .checkpoint_reviews[0].head == $head and
// 검토: 그 리뷰는 어느 행동 체크포인트 이후의 정리인지 함께 기록해야 합니다.
    .checkpoint_reviews[0].checkpoint == $before[0].receipts[-1].head
// 검토: 진행 기록을 잃거나 중간 리뷰를 완료로 처리하면 테스트를 실패시킵니다.
  ' "$META/state.json" >/dev/null || fail 'Intermediate review lost progress or claimed completion'
// 검토: 기존 읽기 전용 sandbox를 선택하는 review 역할로 호출되었는지 확인합니다. 이 fixture 자체는 Codex sandbox를 실행하지 않습니다.
  tail -n 1 "$META/usage.jsonl" | jq -e '.role == "review"' >/dev/null || fail 'Checkpoint reviewer did not use the read-only review role'
// 검토: 실제 기록된 마지막 작업자 호출의 실행 ID를 찾습니다.
  review_run=$(tail -n 1 "$META/usage.jsonl" | jq -r .run_id)
// 검토: 그 중간 리뷰 작업자에게 전달된 프롬프트 파일을 찾습니다.
  review_prompt="$META/runs/$review_run/$(jq -r .calls "$META/state.json")/prompt.txt"
// 검토: 중간 리뷰의 diff 범위는 마지막 행동 체크포인트 SHA부터 HEAD까지라고 명시되어야 합니다.
  contains "$review_prompt" "from $(jq -r '.receipts[-1].head' "$BASE/before-tidy.json") to HEAD"
// 검토: 아직 남은 승인 항목 addLargerInputs가 리뷰 문맥에 전달되어야 합니다.
  contains "$review_prompt" 'addLargerInputs'
// 검토: 미구현 예정 항목을 완료 결함으로 취급하지 않는다는 지침을 명시적으로 전달해야 합니다.
  contains "$review_prompt" 'Pending approved entries are not completion defects.'
// 검토: 성공한 중간 리뷰 상태를 보관합니다.
  cp "$META/state.json" "$BASE/reviewed-tidy.json"
// 검토: 동일 HEAD에 중간 리뷰를 다시 요청해도 성공해야 합니다.
  run_cli review --checkpoint --policy "$POLICY"; okay
// 검토: 동일 리뷰 재실행은 호출 수·시각·리뷰 이력까지 중복 변경하지 않아야 합니다.
  cmp "$BASE/reviewed-tidy.json" "$META/state.json"
// 검토: 아직 미완료 항목이 있으므로 일반 최종 리뷰는 계속 거부해야 합니다.
  run_cli review --policy "$POLICY"; rejected
// 검토: 거부 이유는 미완료 플랜 항목이어야 합니다.
  contains "$BASE/stderr" 'Unchecked plan entries remain'
// 검토: 거부된 최종 리뷰는 중간 리뷰 결과나 호출 수를 바꾸지 않아야 합니다.
  cmp "$BASE/reviewed-tidy.json" "$META/state.json"
// 검토: 실제 상태 명령으로 남은 항목을 조회합니다.
  run_cli status; okay
// 검토: 미완료 목록은 두 번째 항목 하나이며 완료 상태가 아니어야 합니다.
  jq -e '.pending == ["addLargerInputs"] and .status != "complete"' "$BASE/stdout" >/dev/null || fail 'Pending batch entry disappeared'
// 검토: 리뷰만으로 다음 실행 테스트를 미리 삽입해서는 안 됩니다.
  not_contains "$APP/suite.test.js" 'addLargerInputs'

// 검토: 추가 승인이나 기준 교체 없이 기존에 승인된 다음 항목을 진행합니다.
  run_cli step --policy "$POLICY"; okay
// 검토: 이 fixture의 두 번째 항목은 첫 구현으로 이미 GREEN임을 정직하게 기록해야 합니다.
  contains "$BASE/stdout" 'ALREADY GREEN addLargerInputs'
// 검토: 이미 통과하는 항목 때문에 정리된 구현을 바꾸면 안 됩니다.
  cmp "$BASE/tidied-source.js" "$APP/impl.js"
// 검토: 다음 체크포인트가 원래 상태와 정리 커밋을 올바르게 이어받았는지 확인합니다.
  jq -e --slurpfile before "$BASE/reviewed-tidy.json" --arg head "$tidied_head" '
// 검토: 최초 승인 기준을 계속 유지해야 합니다.
    .baseline == $before[0].baseline and
// 검토: 최초 승인 시각도 그대로여야 합니다.
    .approved_at == $before[0].approved_at and
// 검토: 이미 GREEN인 다음 항목에는 추가 구현 호출을 쓰면 안 됩니다.
    .calls == $before[0].calls and
// 검토: 행동 검증 기록이 첫 항목과 두 번째 항목의 두 개가 되어야 합니다.
    (.receipts | length) == 2 and
// 검토: 첫 행동 기록의 모든 필드를 그대로 유지해야 합니다.
    .receipts[0] == $before[0].receipts[0] and
// 검토: 새 기록은 정리한 HEAD에서 시작한 addLargerInputs의 체크포인트여야 합니다.
    .receipts[1].before == $head and .receipts[1].entry == "addLargerInputs" and
// 검토: 실제로 통과한 테스트 이름 목록에 addLargerInputs가 있어야 합니다.
    (.receipts[1].green | index("addLargerInputs")) != null and
// 검토: 다음 항목을 커밋해도 중간 리뷰 이력을 잃지 않아야 합니다.
    .checkpoint_reviews == $before[0].checkpoint_reviews and
// 검토: 두 항목의 GREEN만으로 최종 리뷰 완료를 주장하지 않아야 합니다.
    .review == null and .status == "checkpoint" and .active == null
// 검토: 이어서 진행하면서 체크포인트나 중간 리뷰 증거를 잃으면 실패시킵니다.
  ' "$META/state.json" >/dev/null || fail 'Batch continuation lost its checkpoint or review evidence'
// 검토: 첫 테스트의 정확한 승인 코드가 실행 파일에 남아 있어야 합니다.
  contains "$APP/suite.test.js" "$CODE"
// 검토: 두 번째 테스트도 정확한 코드로 실행 파일에 삽입되어 있어야 합니다.
  contains "$APP/suite.test.js" "test('addLargerInputs', () => assert.equal(add(2, 3), 5));"
// 검토: 최종 리뷰 전 상태를 보관합니다.
  cp "$META/state.json" "$BASE/before-final.json"
// 검토: 최종 완료 리뷰가 검사해야 할 마지막 커밋을 기록합니다.
  final_head=$(git_app rev-parse HEAD)
// 검토: 이제 모든 승인 항목이 완료되었으므로 일반 최종 리뷰가 성공해야 합니다.
  run_cli review --policy "$POLICY"; okay
// 검토: 최종 리뷰의 호출·이력·커밋 연결을 검사합니다.
  jq -e --slurpfile before "$BASE/before-final.json" --arg head "$final_head" '
// 검토: 최종 리뷰까지 최초 기능 기준을 보존해야 합니다.
    .baseline == $before[0].baseline and
// 검토: 중간 리뷰를 재사용하지 않고 독립 최종 리뷰 호출을 정확히 1회 추가해야 합니다.
    .calls == ($before[0].calls + 1) and
// 검토: 행동 체크포인트 기록은 최종 리뷰 중에 바뀌면 안 됩니다.
    .receipts == $before[0].receipts and
// 검토: 중간 리뷰 이력도 계속 남아 있어야 합니다.
    .checkpoint_reviews == $before[0].checkpoint_reviews and
// 검토: 최종 리뷰가 마지막 HEAD를 가리킨 뒤에만 complete가 되어야 합니다.
    .review.head == $head and .status == "complete" and
// 검토: 최종 리뷰 커밋은 이전 중간 리뷰 커밋과 달라야 합니다.
    .review.head != .checkpoint_reviews[0].head
// 검토: 중간 리뷰를 최종 완료 근거로 재사용하면 실패시킵니다.
  ' "$META/state.json" >/dev/null || fail 'Final completion reused an intermediate review'
// 검토: 마지막 최종 리뷰 호출의 실행 ID를 찾습니다.
  final_run=$(tail -n 1 "$META/usage.jsonl" | jq -r .run_id)
// 검토: 최종 리뷰 작업자에게 전달한 프롬프트를 찾습니다.
  final_prompt="$META/runs/$final_run/$(jq -r .calls "$META/state.json")/prompt.txt"
// 검토: 최종 리뷰의 diff 범위는 원래 기능 승인 기준 SHA부터 HEAD까지라고 명시되어야 합니다.
  contains "$final_prompt" "from $(jq -r .baseline "$BASE/before-final.json") to HEAD"
// 검토: 최종 리뷰도 정리된 실제 소스를 그대로 보존해야 합니다.
  cmp "$BASE/tidied-source.js" "$APP/impl.js"
// 검토: 마지막에 임시 앱의 작업 트리와 인덱스가 깨끗해야 합니다.
  assert_eq "$(git_app status --porcelain)" ''
}

// 검토: 이 초안 파일의 위치로 Sobaya 루트를 찾습니다.
draft_root=$(cd "$(dirname "$0")/.." && pwd)
// 검토: 기존 승인된 공유 도우미는 그대로 사용하고 새 사례만 초안으로 둡니다.
# Reuse unchanged approved support; only this new case is a draft.
// 검토: 공유 fixture를 초기화한 뒤 이 테스트 한 사례만 실행합니다.
. "$draft_root/tests/test-runner.sh" --case test_batch_green_refactor_preserves_pending_work
````

## 구현 전 확인

Bash 3.2 문법 검사를 통과했습니다. 실행은 첫 항목의 실제 RED→GREEN 체크포인트와
미완료 항목 보존까지 진행한 뒤 `Unknown option --checkpoint`에서 실패합니다.
실패 진단에 `addAdds`가 있어야 한다는 첫 중간 게이트 검사가 이 오류를 잡습니다.
이는 새 명령이 없다는 증거이며, 아직 후속 중간 리뷰·진행·완료 검사가 통과한 것은 아닙니다.

이 구현 전 probe 당시에는 런타임, 정규 suite 등록, 기존 승인 테스트·도우미를
변경하지 않았습니다. 설명 주석만 제거하면 이 문서의 실행 코드가 승인 파일과
바이트 단위로 일치합니다.
