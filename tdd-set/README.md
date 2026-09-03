# tdd-set

외부 제품 없음. `git` + 셸 + Claude Code 기본 기능(skill, hook, `claude -p`)만 사용.

## 흐름
```
사람:  spec.md 작성(Goal·Must·Must not) → plan.md 작성(케이스 하나씩 probe.sh로 RED 확인 후 문서에 코드로 기록, 많이) → 커밋
루프:  bin/loop.sh  →  매 반복 `claude -p "go"`  →  plan.md 다음 항목의 테스트 코드를 그대로 스위트에 옮김 → Red→Green→체크→커밋(행위) → Refactor(gopher)→커밋(구조, 별도)
게이트: bin/gate.sh →  전부 체크 · 스위트 green · 기존 테스트 무변조 · 체크한 항목의 테스트 함수가 스위트에 존재
```

## 구성
| 파일 | 역할 |
|---|---|
| 앱 `AGENTS.md`의 `- Test:` / `- Format:` / `- Lint:` / `- Bench:` / `- Skills:` 줄 | 명령줄의 유일한 출처. gate가 Test(판정)와 Bench(출력만)를, 커밋 훅이 Format·Lint를 읽음. `Skills:`는 이 앱이 리팩터에 쓰는 스택 스킬 이름(예: gopher) |
| `AGENTS.md` | 8단계. TDD + Tidy First 규칙. `/go`가 이 파일을 읽고 해당 앱에 적용(출처: BPlusTree3 `rust/docs/CLAUDE.md`, commit e1f539e). "go" = plan.md 다음 테스트, Red→Green→Refactor, Tidy First, 커밋 규율 |
| `spec-template.md` | 5단계. 사람이 쓰는 목표 문서(Goal·Must·Must not). Phase 0이 테스트를 뽑는 근거. 루프는 읽기만 |
| `plan-template.md` | 2~4단계. 작은 기능별 실패 테스트 **코드**를 문서에 먼저 적어두는 목록. 항목 = `- [ ] TestName — 증명 내용` + 코드 블록 |
| `skills/tdd/SKILL.md` | 1~3단계 Phase 0 + 루프 가드(테스트 변조 금지, 한 줄 보고). AGENTS.md에 없는 것만 |
| `skills/<stack>/SKILL.md` | 9단계. 스택별 리팩터 체크리스트. 지금은 `gopher`(Go). 앱이 `Skills:` 줄로 고름. 다른 스택은 같은 형식으로 하나 더 |
| `hooks/commit-gate.sh` | 9단계 강제. `git commit` 전에 CLAUDE.md의 Format·Lint 명령을 돌려 실패 시 차단. 줄이 없고 go.mod가 있으면 gofmt/go vet 기본값 |
| `commands/` | 단계별 슬래시 명령, 전부 앱 이름을 인자로 받음. `/sobaya-plan` = Phase 0, `/go` = 사이클 하나(AGENTS.md의 "go"와 동일), `/gate` = 게이트만, `/sobaya-loop [n]` = 전체 자동 실행 후 게이트. 슬래시 명령은 우리 추가 |
| `bin/install.sh` | 0단계. 앱에 파일 셋 생성(위 '설치'). 별도 스캐폴드 단계 없음 |
| `bin/probe.sh` | 3~4단계. 후보 테스트 하나를 임시 파일로 패키지에 넣고 돌린 뒤 삭제. RED(실패·미빌드)면 plan.md에 적고, GREEN이면 이미 있는 행위라 버림. Go 전용 |
| `bin/loop.sh` | 6·7·10·11단계. "go"만 돌림. 회차가 항목을 추가하면(물어볼 사람이 없으니) 중단, 커밋 없는 반복 3회면 정체로 중단, 끝나면 gate 실행 |
| `bin/gate.sh` | 6·12단계. 루프 완료 판정 = plan.md 100% 체크 · 스위트 green · 기존 테스트 무변조 · 체크 항목의 테스트 이름 대조. 사람이 쓴 테스트가 곧 spec이라 별도 판정자 없음 |

## 설치 (앱마다, 새것이든 기존이든)
```sh
tdd-set/bin/install.sh apps/<name>     # sobaya 루트에서. 멱등
```
앱에 만드는 건 셋뿐: `AGENTS.md`(명령줄 4개 + `Skills:` 줄), `spec.md`, `plan.md`. 스킬·명령·훅·TDD 규칙은 루트에 있고 루트에서 씁니다. 앱 폴더에서 세션을 열면 상위 CLAUDE.md만 상속되고 스킬·명령·훅은 안 넘어오기 때문입니다.

## 실행 (전부 sobaya 루트에서, 앱 이름으로)
```
/sobaya-plan <name>   apps/<name>/spec.md → plan.md 초안(probe RED만) → "검토·추가 끝나셨으면 이대로 진행할까요?" 한 번 묻고 대기
/go <name>            항목 하나: 테스트 그대로 옮김 → red → green → 커밋 → Skills: 줄의 스킬로 refactor → 커밋
/gate <name>          게이트만
/sobaya-loop <name>   남은 항목 전부 자동 후 게이트
```
셸에서 직접:
```sh
tdd-set/bin/loop.sh apps/<name> 30
tdd-set/bin/gate.sh apps/<name>
```
loop.sh는 `go -C apps/<name>`, `gofmt`, `git -C apps/<name>` add·commit·diff·status·log·show, probe.sh만 허용한 채 `claude -p "/go <name>"`를 돕니다.
프롬프트에서 멈추면 `CLAUDE_FLAGS`로 허용 범위를 넓히면 됩니다. 커밋 안 된 잔여물은 stash에 보관합니다.
