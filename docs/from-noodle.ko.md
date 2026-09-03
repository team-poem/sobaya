# noodle에서 Sobaya로

주방 컨벤션은 [poteto/noodle](https://github.com/poteto/noodle)에서 왔습니다. 파일 기반 작업 주문 위에서 LLM "쿡" 세션을 스케줄링하는 Go 이벤트 루프입니다. Sobaya는 그 플로우를 유지하고 기계는 버렸습니다.

| noodle (Go 런타임) | Sobaya (Claude Code 네이티브) |
|---|---|
| 이벤트 루프 사이클이 모든 것을 구동 | `loop.sh`가 TDD 사이클을 구동, 나머지는 대화형 세션이 구동 |
| 사이클마다 재생성되는 `mise.json` 컨텍스트 브리프 | `sobaya` 스킬의 사전점검: brain 인덱스(훅 주입) → 관련 노트 → `apps.md` + 앱 git 상태 → todos + 진행 중 플랜 |
| `schedule` 에이전트가 `orders-next.json` 작성 | 사람이 쓴 `plan.md`; 다음 미체크 항목이 다음 주문 |
| 주문이 스테이지를 따라 전진: execute → quality → reflect | 사이클 → 게이트 → 반박자 리뷰 → reflect, 각 단계의 산출물을 먼저 선언 |
| 쿡은 프로바이더 CLI 자식 프로세스, 스킬 하나씩 | 사이클마다 `claude -p "go"`; 그 둘레는 Agent 도구로 서브에이전트 |
| 쿡마다 git 워크트리, 머지 락, 순차 머지 | 앱당 작성자 1명; 병렬 변경은 에이전트당 워크트리 1개; 머지는 순차, 사이사이 검증 |
| `stage_yield` — 산출물 ≠ 프로세스 종료 | 모든 사이클은 커밋으로 끝남; 잔여물은 stash에 보관 |
| 크래시 복구: `orders.json` 스테이징 + 세션 입양 | `plan.md` 체크박스가 곧 상태; 어떤 세션이든 다음 미체크 항목에서 재개 |
| 스케줄러 주도 복구, 자동 재시도 없음 | 커밋 없는 사이클 3회면 루프 중단; 진단 후 결정 |
| brain 볼트 + reflect/meditate 자기개선 | 그대로 이식: reflect가 학습을 라우팅(구조 > 스킬 수정 > 노트 > todo), meditate가 서브에이전트로 볼트 감사 |
| `inject-brain` / `auto-index-brain` 훅 | fail-open POSIX 훅으로 이식 + 와이어링 수정(Claude Code matcher는 경로가 아니라 도구 이름) |
| 자율 cron 루프, 웹 UI, NDJSON 이벤트 소싱 | 의도적으로 제외 |
