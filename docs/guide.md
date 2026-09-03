# Sobaya 사용 가이드

README가 "무엇"이라면 이 문서는 "어떻게"입니다. 세션에서 실제로 벌어지는 흐름 중심으로 설명합니다.

## 세션의 시작

`sobaya/`에서 `claude`를 열면 SessionStart 훅이 `brain/index.md`를 주입합니다. 세션은 인덱스에서 **관련 있는 노트만** 골라 읽습니다 — 전부 읽는 것은 컨텍스트 낭비입니다(원칙: guard-the-context-window).

## 시나리오 1 — 새 앱 만들기

1. "todo 앱 하나 만들자" → **new-app** 스킬: `apps/todo-app` 생성, `git init -b main`, 앱 CLAUDE.md(명령줄 4개 + Kent Beck TDD 규칙 원문)·README·spec/plan 템플릿 설치, `brain/apps.md` 등록.
2. 사용자가 앱 루트 `spec.md`(Goal·Must·Must not)를 채웁니다. 에이전트가 대신 쓰지 않습니다. 이게 끝나기 전엔 구현 시작 금지.
3. **tdd** 스킬 Phase 0: 큰 기능을 작은 기능으로 쪼개고, 작은 기능마다 테스트 케이스를 최대한 열거하고, 케이스 하나씩 `tdd-set/bin/probe.sh`로 돌려 RED임을 확인한 것만 앱 루트 `plan.md`에 **완전한 실패 테스트 코드**로 적습니다(항목 = 체크박스 한 줄 + 코드 블록). GREEN이 나오면 이미 있는 행위이므로 적지 않습니다. 코드는 문서에만 있고 스위트엔 아직 없습니다. 승인 전엔 구현을 쓰지 않습니다.
4. 구현: 앱 안에서 `tdd-set/bin/loop.sh` — "go" 한 번에 항목 하나: 문서의 테스트 코드를 그대로 스위트에 옮기고 Red → Green → 체크 → 커밋(행위 변경), 그다음 green 상태에서 Refactor → 별도 커밋(구조 변경). 커밋 없는 반복 3회면 정체로 멈춥니다. 끝나면 `gate.sh`가 검사합니다: 전부 체크·스위트 green·기존 테스트 무변조·체크 항목의 테스트가 스위트에 존재. 사람이 쓴 테스트가 곧 spec이라 그 이상은 판정하지 않습니다. 세션 안에서 서브에이전트로 돌릴 땐 **sobaya** 디스패치 규칙대로.

## 시나리오 2 — 기존 앱에 기능 추가

1. **사전점검(mise):** brain 인덱스 → 관련 노트, `brain/apps.md`, `git -C apps/<앱> status`, 진행 중 플랜 확인. 한 문단 브리프 작성.
2. **탐색:** 모르는 코드는 Explore 에이전트가 읽고 결론만 가져옵니다.
3. **실행:** general-purpose 에이전트에 작업 지시서(경로·작업·제약·금지 파일·보고 형식)를 줍니다. 템플릿: `.claude/skills/sobaya/references/dispatch-patterns.md`
4. **리뷰:** 구현하지 않은 독립 에이전트가 "반박하라"는 프롬프트로 검증합니다.
5. **reflect:** 배운 것을 brain에 기록합니다.

## 시나리오 3 — 한 앱에서 병렬 작업

기본 규칙은 **앱당 작성자 1명**입니다. 정말 병렬이 필요하면:

- 에이전트마다 워크트리 하나 (`isolation: worktree`), 서로 겹치지 않는 "건드리지 말 것" 목록 지정
- 머지는 **한 번에 하나씩**, 머지 사이에 테스트 실행
- 읽기 전용 에이전트는 자유롭게 병렬 가능

## 시나리오 4 — 실패한 위임 작업

맹목 재시도 금지. 출력과 산출물을 읽고 → 진단(진짜 버그면 CLAUDE.md 결함 규칙: API 수준 실패 테스트 → 최소 재현 테스트 → 둘 다 green) → 브리프 수정 / 분해 변경 / 직접 수행 중 결정합니다.

## brain 운영 규칙

| 항목 | 규칙 |
|---|---|
| `index.md` | 훅이 자동 생성 — **직접 수정 금지** (수정해도 다음 brain 쓰기 때 덮어씌워짐) |
| 노트 | 주제당 한 파일, 150–600단어, problem → cause → pattern → evidence |
| todos | 번호는 영구, `<!-- next-id -->` 증가, 완료는 archive로 이동 |
| 플랜 | `NN-slug/` 디렉토리, 완료 시 `archive/plans/`로 이동 + `plans/index.md` 체크 |
| reflect | 세션 학습을 구조 > 스킬 > 노트 > todo 순으로 라우팅 |
| meditate | reflect가 쌓이면 실행 — 비용이 크니 자주 돌리지 않기 |

## 훅 동작

- **inject-brain** (SessionStart): `brain/index.md`를 세션 컨텍스트에 출력. 볼트가 없으면 조용히 통과.
- **auto-index-brain** (PostToolUse Edit|Write): 수정된 파일 경로에 `/brain/`이 있으면 인덱스를 디스크 상태로부터 재생성. 변화 없으면 fast-path 종료, 쓰기는 원자적(tmp+mv). 모든 이상 상황은 exit 0 — **훅이 세션을 깨는 일은 없습니다.**

검증: `sh tests/hooks-test.sh` → `ALL PASS`

## 자주 묻는 것

- **인덱스에 새 파일이 안 보여요** — 훅은 brain 파일을 Edit/Write로 수정할 때 돕니다. 셸로 파일을 만들었다면 아무 brain 파일이나 한 번 Edit하거나 테스트 페이로드로 스크립트를 직접 실행하세요.
- **plans/ 안의 파일이 인덱스에 없어요** — 의도된 동작입니다. 플랜 내부 파일은 `plans/index.md`를 통해 접근합니다.
- **noodle을 더 가져오고 싶어요** — `references/noodle/`이 작업 클론입니다. `brain/codebase/noodle-reference.md`에 어디를 봐야 하는지 정리돼 있습니다.
