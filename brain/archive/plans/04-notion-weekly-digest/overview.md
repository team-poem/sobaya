# Plan 04 — notion-weekly-digest (Spec)

> Status: shipped (2026-07-05 audit: phase-1 executed — app implemented and posting to the Notion staging page, runbook in app README; archived) · Created 2026-06-29

## One-liner

매주 수동 실행으로 개발 뉴스(GeekNews + Hacker News)를 수집·인기순 선별하고,
로컬 GPT-5.5(codex)로 한국어 요약해서 Notion "레퍼런스 아티클" 양식의 불릿으로
Joh's Notion 스테이징 페이지에 게시한다. 사용자는 검토 후 Aisle 워크스페이스로 복사한다.

## Problem / Goal

개발 관련 뉴스(GeekNews, Hacker News 등)를 매주 직접 찾아 읽고 요약·정리해
Notion 레퍼런스 페이지에 쌓는 일을 반복하고 있다. 이 수집→선별→요약→게시
과정을 반자동화해서, 한 번의 수동 실행으로 그 주의 가치 있는 글들을 정해진
양식으로 뽑아 Notion에 올린다.

비목표(YAGNI):
- 완전 무인 자동화(cron) — 이번엔 안 함. 수동 실행만.
- Aisle 워크스페이스 직접 쓰기 — Aisle은 API/integration이 막혀 있어 불가능.
  최종 게시(Aisle)는 사람이 복사하는 수동 단계로 남긴다.
- 다중 사용자/설정 UI, 웹 대시보드.

## Key Decisions (확정됨)

| 항목 | 결정 |
|---|---|
| 소스 | GeekNews(news.hada.io RSS) + Hacker News(Algolia/Firebase API) |
| 큐레이션 | 인기순(포인트/댓글)으로 후보 추림 → GPT-5.5가 가치 있는 5~8개 선별 |
| 요약 엔진 | 로컬 `codex exec`(GPT-5.5). 맥북에 로그인된 ChatGPT auth 재사용, API 키 불필요 |
| 요약 언어 | 한국어 |
| 본문 처리 | 스크립트가 원문 본문을 미리 fetch → codex에는 텍스트만 넘김(오프라인 요약) |
| 출력 양식 | 아티클 1개 = 불릿 1개 + 하위 요약 불릿(중첩). 아래 "Output Format" 참조 |
| 게시 대상 | Joh's Notion 스테이징 페이지(개인 워크스페이스, integration 허용됨) |
| Notion 쓰기 | **옵션 1** — 스크립트는 markdown까지만 생성. Claude가 연결된 Notion MCP로 스테이징 페이지에 추가(토큰 설정 0) |
| 실행 | 수동. 사용자가 Claude에게 "이번주 다이제스트 돌려줘" → Claude가 파이프라인 실행 + MCP 게시 |
| 앱 위치/스택 | `apps/notion-weekly-digest`, Python 3.11+, 독립 git repo |

## Output Format (Notion 레퍼런스 아티클 양식)

기존 Aisle "Reference Article" 페이지에서 추출한 패턴. 아티클 1개당:

```
- [아티클 제목](원문 링크)
	- 한 줄 요약 — 이게 뭔지 한 줄로
	- 핵심 내용 2~3문장 요약
	- (선택) 핵심 takeaway 또는 추가 참고 링크
```

- 최상위 불릿 = `[원문 제목](원문 링크)` 마크다운 링크
- 하위 불릿(중첩) = 한국어 요약(한 줄 + 2~3문장), 필요 시 추가 포인트·링크
- 주차별 섹션으로 묶고, 섹션 사이 빈 줄/구분선(`---`) 사용
- 주차 헤더 예: `## 2026-W27 (06.29~07.05)` 또는 사용자 취향에 맞춘 헤딩

양식 레퍼런스로 읽은 Joh's Notion 페이지: `38e45793-1cd2-8081-beb7-c9f758c907d1`
(개인 메모·이미지가 섞인 사본 — 양식 골격만 참고. 실제 게시는 별도의 깨끗한
스테이징 페이지에 한다. 스테이징 페이지 ID는 빌드 시 확정/생성.)

## Architecture

수동 실행 1회 = 다음 파이프라인. 1~3단계는 자립형 Python 스크립트(`run.py`),
4단계(Notion 쓰기)는 Claude가 MCP로 수행.

```
[수집] sources/ ──▶ [랭킹] rank.py ──▶ [선별+요약] summarize.py(codex exec)
   │                                          │
   └─ geeknews.py / hackernews.py             ▼
                                       [렌더] render.py ──▶ output/digest-YYYY-MM-DD.md
                                                                   │
                                              (Claude reads md) ──▶ [게시] Notion MCP ──▶ 스테이징 페이지
                                                                   │
                                                       state/seen.json (주차 간 중복 방지)
```

### Components (단일 책임, 독립 테스트 가능)

- **`sources/geeknews.py`** — news.hada.io RSS 파싱 → 정규화된 `Article` 리스트
  (title, url, points/comments, published_at, source). RSS에 점수가 없으면
  페이지 메타 또는 가능한 신호로 인기 추정. 입력=fixture로 테스트.
- **`sources/hackernews.py`** — HN Algolia API(`hn.algolia.com/api/v1/search`)로
  지난 1주 story를 points 정렬 수집 → `Article` 리스트. fixture로 테스트.
- **`models.py`** — `Article`, `Summary` 데이터클래스(소스 간 공통 인터페이스).
- **`rank.py`** — 수집 article들을 인기순 정렬, 상위 N(기본 ~25) 후보 선택.
  순수 함수, 테스트 용이.
- **`summarize.py`** — 후보 목록 + (스크립트가 fetch한) 본문 텍스트로 프롬프트 구성
  → `codex exec` 호출 → 출력 파싱 → 선별된 5~8개의 구조화된 `Summary`.
  codex 호출은 테스트에서 mock.
- **`fetch_content.py`** — 후보 URL의 본문을 가볍게 추출(요약 입력용). 실패해도
  제목/메타로 폴백. 네트워크 의존이라 통합 테스트는 별도.
- **`render.py`** — `Summary` 리스트 → 위 "Output Format" 마크다운. 순수 함수.
- **`state.py`** — 이미 게시한 URL을 `state/seen.json`에 저장/조회(주차 간 중복 방지).
- **`run.py`** — 파이프라인 오케스트레이션. `output/digest-YYYY-MM-DD.md` 생성 + stdout 출력.

### 실행 흐름 (수동)

1. 사용자: "이번주 다이제스트 돌려줘"
2. Claude: `python run.py` 실행 → 수집·랭킹·codex 요약 → `output/digest-*.md` 생성
3. Claude: 생성된 markdown을 읽어 Notion MCP(`notion-update-page` 등)로
   스테이징 페이지에 주차 섹션 추가
4. 사용자: Notion에서 검토 → Aisle로 복사

## Error Handling

- **소스 일부 실패**: 한 소스가 죽어도 나머지로 진행, 경고 로그. 둘 다 실패 시 중단.
- **본문 fetch 실패**: 해당 글은 제목/RSS 요약만으로 요약하거나 후보에서 제외(로그).
- **codex exec 실패/빈 출력**: 부분 결과 게시 금지. 에러 표면화 후 중단(재실행 안내).
- **codex 출력 파싱 실패**: 엄격한 출력 계약(아래) + 파싱 실패 시 원문 출력 보존하고 중단.
- **Notion 쓰기**: 같은 주차 섹션 중복 방지(이미 존재하면 append 대신 사용자 확인).
  글 단위 중복은 `seen.json`으로 사전 차단.
- **멱등성**: 같은 주 재실행 시 `seen.json` 덕분에 동일 글 재요약/재게시 안 함.

## codex exec 출력 계약

`summarize.py`는 codex에 "정확히 이 마크다운 구조로만 출력하라"고 지시하고,
스크립트는 그 출력을 `Summary` 구조로 파싱한다. 느슨한 자연어 응답을 막기 위해
출력은 위 Output Format의 불릿 구조를 그대로 따르도록 고정한다. (구체 프롬프트와
파싱 규칙은 phase 플랜에서 확정.)

## Testing Strategy

- **단위**: 각 source 파서(fixture RSS/JSON → Article), `rank.py`(정렬/선택),
  `render.py`(Summary → 마크다운), `state.py`(seen 저장/조회).
- **codex 경계**: `summarize.py`는 codex 호출을 mock한 단위 테스트 + 실제 출력
  샘플로 파서 검증.
- **통합(수동/옵트인)**: 실제 소스 fetch, 실제 codex 1회 호출 스모크 테스트.
- 실제 GPT/네트워크는 기본 테스트에서 호출하지 않음.

## Open Items (빌드 시 확정)

- 스테이징 페이지: 전용 깨끗한 페이지를 새로 만들지, 기존 페이지 재사용할지 → 빌드 시 확정.
- GeekNews RSS에 인기 신호(포인트)가 노출되는지 확인 → 없으면 랭킹 방식 보정.
- 주당 게시 개수 기본값(5~8) 및 주차 헤더 표기 형식 최종 확정.

## Out of Scope (이번 플랜 아님)

- 루트 하네스의 `AGENTS.md` 오타(`.Codex/` → `.codex/`)는 이 앱과 무관 — 별도 처리.
