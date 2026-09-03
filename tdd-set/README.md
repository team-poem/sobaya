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
| 앱 `CLAUDE.md`의 `- Test:` / `- Format:` / `- Lint:` / `- Bench:` 줄 | 명령줄의 유일한 출처. gate가 Test(판정)와 Bench(출력만)를, 커밋 훅이 Format·Lint를 읽음. Kent Beck이 agent.md에 `cargo fmt`·`cargo test`·`cargo bench`를 둔 자리 |
| `CLAUDE.md` | 8단계. **Kent Beck 원문 그대로** (BPlusTree3 `rust/docs/CLAUDE.md`, commit e1f539e, 2025-06-08). "go" = plan.md 다음 테스트, Red→Green→Refactor, Tidy First, 커밋 규율 |
| `spec-template.md` | 5단계. 사람이 쓰는 목표 문서(Goal·Must·Must not). Phase 0이 테스트를 뽑는 근거. 루프는 읽기만 |
| `plan-template.md` | 2~4단계. 작은 기능별 실패 테스트 **코드**를 문서에 먼저 적어두는 목록. 항목 = `- [ ] TestName — 증명 내용` + 코드 블록 |
| `skills/tdd/SKILL.md` | 1~3단계 Phase 0 + 루프 가드(테스트 변조 금지, 한 줄 보고). CLAUDE.md에 없는 것만 |
| `skills/gopher/SKILL.md` | 9단계. Go 리팩터 체크리스트. 다른 언어면 같은 형식으로 하나 더 만들면 됨 |
| `hooks/commit-gate.sh` | 9단계 강제. `git commit` 전에 CLAUDE.md의 Format·Lint 명령을 돌려 실패 시 차단. 줄이 없고 go.mod가 있으면 gofmt/go vet 기본값 |
| `commands/` | 단계별 슬래시 명령. `/plan` = Phase 0, `/go` = 사이클 하나(CLAUDE.md의 "go"와 동일), `/gate` = 게이트만, `/loop [n]` = 전체 자동 실행 후 게이트. Kent Beck은 평문 "go"만 썼고 슬래시 명령은 우리 추가 |
| `bin/probe.sh` | 3~4단계. 후보 테스트 하나를 임시 파일로 패키지에 넣고 돌린 뒤 삭제. RED(실패·미빌드)면 plan.md에 적고, GREEN이면 이미 있는 행위라 버림. Go 전용 |
| `bin/loop.sh` | 6·7·10·11단계. 미체크 항목이 남아 있는 동안 반복, 커밋 없는 반복 3회면 정체로 중단, 끝나면 gate 실행 |
| `bin/gate.sh` | 6·12단계. 루프 완료 판정 = plan.md 100% 체크 · 스위트 green · 기존 테스트 무변조 · 체크 항목의 테스트 이름 대조. 사람이 쓴 테스트가 곧 spec이라 별도 판정자 없음 |

## 설치 (프로젝트마다)
```sh
P=apps/<name>   # run from the sobaya root
mkdir -p $P/.claude/skills
cp -r tdd-set/skills/tdd tdd-set/skills/gopher $P/.claude/skills/
cp -r tdd-set/commands $P/.claude/commands      # /plan /go /gate /loop
cp tdd-set/CLAUDE.md $P/CLAUDE.md      # 이미 있으면 내용을 이어 붙임
# $P/CLAUDE.md 에 명령줄 3개를 적는다 (Kent Beck의 agent.md 자리):
#   - Test: `go test ./...`
#   - Format: `gofmt -l .`
#   - Lint: `go vet ./...`
#   - Bench: `go test -bench=. -benchmem ./...`   (선택)
cp tdd-set/spec-template.md $P/spec.md
cp tdd-set/plan-template.md $P/plan.md
```
`$P/.claude/settings.json`에 훅 추가:
```json
{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/../../tdd-set/hooks/commit-gate.sh"}]}]}}
```

## 실행
세션 안에서 단계별로:
```
/plan        spec.md → plan.md (probe로 RED 확인된 항목만), 승인 대기
/go          항목 하나: 테스트 그대로 옮김 → red → green → 커밋 → refactor → 커밋
/gate        게이트만
/loop 30     남은 항목 전부 자동 (최대 30회) 후 게이트
```
셸에서 직접:
```sh
cd $P
../../tdd-set/bin/loop.sh 30
../../tdd-set/bin/gate.sh
```
loop.sh는 go test / go vet / gofmt / git add·commit·diff·status 만 허용한 채 `claude -p`를 돕니다.
프롬프트에서 멈추면 `CLAUDE_FLAGS`로 허용 범위를 넓히면 됩니다.
반복이 끝났는데 커밋 안 된 변경이 남으면 stash에 보관합니다 (`git stash list`).
