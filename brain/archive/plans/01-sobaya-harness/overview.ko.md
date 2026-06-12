# Plan 01 — Sobaya 하네스 (한글 번역본)

> **번역 안내** — 이 문서는 `overview.md`(영어 원본, 2026-06-12, status: active)의 한글 번역본입니다. 기준 문서는 영어 원본이고, 이 파일은 사람 검토용입니다. 본문에 인용한 CLAUDE.md 초안도 검토 편의를 위해 번역했지만, 실제 파일은 영어로 만듭니다.

## 요약

Sobaya를 만든다. 서브에이전트 중심의 멀티 프로젝트 작업을 위한 Claude Code 하네스 환경이며, 프레임워크가 아니다. 프로젝트는 `apps/<이름>` 아래에 독립 git 저장소로 두고, 워크스페이스 루트는 영속 메모리(`brain/`), 오케스트레이션 스킬 4종, 결정론적 훅 2종, 짧은 하네스 계약(`CLAUDE.md`)을 제공한다. 패턴은 poteto/noodle에서 추출했고, superpowers 플러그인과 함께 동작하도록 다듬었다.

## 배경

사용자는 max effort의 Opus 4.8 / Fable 5 세션이 서브에이전트를 기본 수단으로 삼아 여러 프로젝트의 복합 작업을 오케스트레이션하는 워크스페이스를 원한다. noodle(Go로 만든 에이전트 오케스트레이션 프레임워크)은 이런 작업 방식에 가장 잘 맞는 검증된 기법들을 보여준다 — 파일 기반 상태, 유일한 확장점으로서의 스킬, 스스로 개선되는 brain 볼트, 워크트리 격리. 다만 noodle은 독립 실행되는 자율 프레임워크다. Sobaya는 noodle의 런타임은 빼고 작업 방식만 빌린다. Claude Code 자체가 오케스트레이터가 되고, 개발 수명주기는 superpowers가 맡고, Sobaya는 둘 다 제공하지 않는 것만 더한다.

## 원천 분석 (noodle)

noodle의 정체: 파일 기반 작업 주문(`orders.json`) 위에서 LLM "쿡(cook)" 세션을 스케줄링하는 Go 이벤트 루프. 각 쿡은 격리된 git 워크트리에서 스킬 하나를 실행하고, 시스템은 행동 전에 brain 볼트를 읽고 배운 것을 다시 써넣는다. 세 가지 핵심 아이디어: (1) 모든 것은 파일이다, (2) 스킬이 유일한 확장점이다, (3) LLM은 판단을, 결정론적 메카닉은 Go가 맡는다.

Sobaya가 가져오는 것:

- **Brain 볼트** — Obsidian 호환 마크다운 메모리: `principles/`(증류된 의사결정 규칙), `codebase/`(주제당 한 파일, 150–600단어의 gotcha 노트), `plans/NN-slug/`(overview + phase 파일), `todos.md`(영구 번호 ID), `archive/`, 본문을 넣지 않는 wikilink 인덱스.
- **자기개선 루프** — reflect(세션에서 배운 것을 라우팅: 구조적 인코딩 > 스킬 수정 > brain 노트 > todo)와 meditate(서브에이전트 auditor + reviewer가 볼트를 감사하고, 노트 2개 이상이 뒷받침하는 패턴을 원칙으로 추출하고, 스킬을 다듬는다. 조기 종료 게이트 포함).
- **결정론적 훅** — SessionStart에 brain 인덱스 주입, brain 쓰기 후 인덱스 자동 재생성. POSIX 셸로만 작성하고, LLM을 쓰지 않으며, 실패 시 조용히 통과한다(fail-open).
- **Go 메카닉의 컨벤션화** — 원자적 쓰기, 대상당 작성자 1명, 병렬 변경 시 워크트리 격리, 디스패치 전 영속화, 산출물을 파일로 남기기(stage_yield), 재시도 대신 진단, 사전 컨텍스트 브리프(mise), 동시성 상한. 아래 컨벤션 표 참고.

Sobaya가 가져오지 **않는** 것: Go 바이너리와 이벤트 루프, 자율 스케줄링(`schedule`/`execute` 태스크 타입, cron 사이클), 웹 UI, 멀티 하네스용 `.agents/` 간접 구조, NDJSON 이벤트 소싱, 그리고 25개 스킬 중 약 21개(plan/TDD/디버깅/리뷰는 superpowers가 이미 제공하고, 나머지는 noodle CLI 전용이다).

## 설계 결정

**D1. 프레임워크가 아니라 하네스.** Sobaya는 Claude Code 세션이 오케스트레이션을 잘하게 만드는 컨벤션 + 스킬 + 훅이다. 데몬도, 스케줄러도 없고, 셸 훅 2개 말고는 새 런타임 코드가 없다.
- *대안 A — noodle을 Claude 네이티브 자율 루프로 이식(orders.json + /loop):* 기각. 사용자가 명시적으로 범위에서 제외했다. 다만 나중에 `/loop`, `/schedule`로 추가할 수 있는 구조는 남겨둔다.
- *대안 B — noodle 자체를 설치:* 기각. noodle이 세션 수명주기를 가져가므로 대화형 Claude Code + superpowers 사용과 충돌한다.

**D2. 선별 스킬 오버레이(4종), 개발 수명주기는 superpowers 소유.** Sobaya는 `sobaya`, `new-app`, `reflect`, `meditate`만 추가한다.
- *대안 — 25종 전체 이식:* 기각. `plan`/`debugging`/`testing`/`review`가 superpowers 트리거와 충돌하고(유지보수 이중화, 스킬 선택 모호), noodle CLI 전제 스킬(`worktree`, `todo`, `noodle`)은 여기 없는 바이너리를 가정한다. subtract-before-you-add 위반.
- *대안 — 스킬 없이 CLAUDE.md만:* 기각. 자기개선 루프가 텍스트 지시로만 남는데, 그게 실패한다는 것이 바로 noodle의 encode-lessons-in-structure 원칙이다.

**D3. 루트 저장소는 하네스만 추적하고, 앱은 독립 저장소로 둔다.** `apps/*`는 gitignore하고 각 앱에서 따로 `git init`한다. 근거: 무관한 프로젝트 히스토리를 섞으면 안 되고, git 워크트리는 저장소 단위이므로 앱별 저장소여야 병렬 변경 격리가 자연스럽다.
- *대안 — 모노레포 하나:* 기각. 앱 워크트리와 앱별 리모트가 어색해지고, 하네스 히스토리가 앱 노이즈로 채워진다.

**D4. 플랜/스펙 위치 통일: `brain/plans/NN-slug/`.** `overview.md`가 스펙이고(이 문서가 첫 사례), `phase-*.md` 파일들이 구현 플랜이다. CLAUDE.md에 사용자 선호 경로로 선언해서 플러그인 기본 경로를 오버라이드한다(superpowers는 이런 오버라이드를 명시적으로 존중한다).
- *대안 — superpowers 기본 경로 `docs/superpowers/specs/` + 별도 플랜:* 기각. 한 수명주기에 문서 시스템이 두 개면 어긋나기 시작한다.

**D5. 훅은 3종이 아니라 2종.** noodle의 `block-sleep.sh`는 뺀다. 현재 Claude Code 하네스가 foreground `sleep`을 자체 차단하므로, 다시 추가하면 중복 메커니즘이다(subtract-before-you-add). 이식하며 고친 것도 있다: noodle은 `auto-index-brain.sh`를 훅 matcher `"brain/"`로 연결했지만, Claude Code matcher는 경로가 아니라 도구 *이름*에 매칭된다 — Sobaya는 matcher를 `Edit|Write`로 두고 스크립트 안에서 `file_path`를 필터링한다.

**D6. `.agents/` 간접 구조를 두지 않는다.** noodle은 Claude와 Codex를 한 소스로 서빙하려고 `.claude/{skills,hooks} -> .agents/` 심링크를 쓴다. Sobaya는 Claude Code만 대상으로 하므로 스킬과 훅을 `.claude/` 바로 아래에 둔다. 두 번째 하네스가 생기면 그때 옮긴다(migrate-callers, then delete).

**D7. 언어 분리.** 에이전트가 소비하는 텍스트(CLAUDE.md, 스킬, brain)는 영어, 사람이 읽는 문서(README.md, docs/)는 한국어. 미래 세션이 이 규칙을 유지하도록 CLAUDE.md에 선언한다.

**D8. 메모리 시스템 두 개, 라우팅은 명시적으로.** Claude Code의 auto-memory(`~/.claude/projects/...`)에는 사용자 선호와 프로젝트를 가로지르는 사실을, `brain/`에는 워크스페이스·앱 지식(저장소 안, 공유 가능)을 담는다. reflect 스킬이 이 라우팅 규칙을 인코딩한다.

## 범위

포함:
- 루트 git 저장소, `.gitignore`, 디렉토리 골격(`apps/`는 `.gitkeep`으로 유지)
- `CLAUDE.md` 하네스 계약(~30줄, 영어)
- `brain/` 시딩: `index.md`, `vision.md`, `principles.md` + 원칙 파일 10종, `codebase/noodle-reference.md`, `apps.md`, `todos.md`, `plans/index.md`, `archive/` 골격
- `.claude/skills/` 아래 스킬 4종: `sobaya`(+ `references/dispatch-patterns.md`), `new-app`, `reflect`, `meditate`
- `.claude/hooks/` 아래 훅 2종 + `.claude/settings.json` 연결
- `README.md`(한국어, 배너 우선 양식 — 컴포넌트 명세 참고) + `banner.svg` + `docs/guide.md`(한국어)
- `references/noodle/` — Sobaya를 만들고 확장하는 동안 참조할 poteto/noodle 작업 클론을 워크스페이스에 상주(gitignore됨, 사용자 요청)
- 검증: 훅(합성 stdin 테스트, 인덱스 golden 비교)과 `new-app`(스모크 테스트)

제외 (이후 후보, 빌드 후 todos로 추적):
- `ruminate`(과거 대화 마이닝), `unslop`, 교차 프로바이더 적대적 리뷰(codex CLI 필요), `/loop`/`/schedule` 기반 자율 사이클, `.agents/` 멀티 하네스 구조, 첫 실제 앱.

## 제약

- **superpowers 호환:** Sobaya 스킬은 superpowers 트리거와 겹치면 안 된다. `new-app`은 새 앱 설계를 superpowers:brainstorming에 넘기고, `sobaya`는 플래닝을 writing-plans에, 디버깅을 systematic-debugging에 넘긴다.
- **모델 불문 max effort:** 컨벤션은 Opus 4.8과 Fable 5에서 모두 동작해야 하고, 특정 모델 티어에만 있는 도구나 동작을 참조하면 안 된다.
- **훅은 결정론적이고 fail-open:** POSIX 셸만 사용하고 jq/python 의존성이 없으며, 어떤 이상 상황에서도 exit 0 한다. brain이 깨져도 세션은 절대 깨지면 안 된다.
- **공유 파일 변경은 원자적으로:** 인덱스 재생성은 `mktemp` + `mv`로 쓴다.
- **정직한 시딩:** 아직 배우지 않은 교훈으로 brain 노트를 지어내지 않는다. `codebase/`는 출처 노트 하나로 시작한다.

## 구조

```
sobaya/                        # git 저장소 (하네스만)
├── CLAUDE.md                  # 하네스 계약 (EN)
├── README.md                  # 가이드 (KO), 배너 우선 양식
├── banner.svg                 # README 배너, 저장소에서 직접 제작
├── .gitignore                 # apps/* (단 !apps/.gitkeep), references/, OS 잡파일
├── .claude/
│   ├── settings.json          # 훅 연결
│   ├── hooks/
│   │   ├── inject-brain.sh    # SessionStart(startup|resume)
│   │   └── auto-index-brain.sh# PostToolUse(Edit|Write), 경로 필터
│   └── skills/
│       ├── sobaya/SKILL.md  (+ references/dispatch-patterns.md)
│       ├── new-app/SKILL.md
│       ├── reflect/SKILL.md
│       └── meditate/SKILL.md
├── brain/
│   ├── index.md               # 자동 재생성; wikilink만, 본문 없음
│   ├── vision.md
│   ├── principles.md          # 원칙들의 분류별 wikilink 인덱스
│   ├── principles/            # 시딩된 원칙 파일 10종
│   ├── codebase/noodle-reference.md
│   ├── apps.md                # 앱 레지스트리: 앱당 한 줄
│   ├── todos.md               # 번호 영구, <!-- next-id -->
│   ├── plans/
│   │   ├── index.md           # 플랜 체크박스 목록 (컨벤션으로 수동 관리)
│   │   └── 01-sobaya-harness/ # 이 플랜
│   └── archive/
│       ├── completed_todos.md
│       └── plans/             # 완료된 플랜 디렉토리는 여기로 이동
├── apps/                      # 독립 git 저장소들, 루트에서 gitignore
│   └── .gitkeep
├── tests/
│   └── hooks-test.sh          # 훅용 POSIX 테스트 스위트
├── references/
│   └── noodle/                # 참조용 poteto/noodle 작업 클론 (gitignore됨)
└── docs/
    └── guide.md               # KO 사용 가이드
```

## 컴포넌트 명세

### CLAUDE.md (전문 초안 — 번역)

> 실제 파일은 영어로 작성한다. 아래는 검토용 번역.

```markdown
# Sobaya

멀티 프로젝트 에이전트 작업을 위한 오케스트레이션 워크스페이스.
프로젝트는 `apps/<이름>`에 — 각자 독립 git 저장소다. 이 루트 저장소는
하네스만 추적한다: `CLAUDE.md`, `.claude/`, `brain/`, `docs/`.

## Brain

`brain/`은 Obsidian 호환 볼트다 — 세션을 넘어 지속되는 메모리.
세션 시작 시 훅이 인덱스를 주입한다.

- **먼저 읽어라.** 행동 전에 작업과 관련된 brain 파일을 읽는다.
- **써라.** 실수, 교정, 의미 있는 학습 후에 — Skill(reflect)을 사용한다.
- **구조:** 주제당 한 파일. `brain/index.md`는 훅이 재생성하므로
  직접 수정하지 않는다. `brain/plans/index.md`는 컨벤션으로 관리한다.
- **유지보수:** 낡은 노트는 삭제한다. 완료된 플랜은 `brain/archive/plans/`로 옮긴다.

## 워크플로

- **앱:** `apps/` 밖에 프로젝트를 만들지 않는다. 각 앱은 자기 git
  저장소를 갖고, 앱을 가로지르는 변경은 앱별로 따로 커밋한다.
- **서브에이전트 우선:** 여러 파일을 만지거나 탐색하는 작업은 서브에이전트에
  맡긴다(읽기는 Explore, 변경은 general-purpose) — 이 컨텍스트를 깨끗하게
  유지한다. 디스패치 패턴은 Skill(sobaya) 참고.
- **앱당 작성자 1명:** 같은 체크아웃에 변경 에이전트 둘을 동시에 돌리지
  않는다. 병렬 변경에는 워크트리 격리가 필요하다.
- **맹목 재시도 금지:** 위임한 작업이 실패하면 출력을 읽고 진단한 뒤
  재디스패치한다.
- **플랜과 스펙은 `brain/plans/NN-slug/`에 둔다** (overview.md = 스펙,
  phase-*.md = 플랜). 이것이 사용자 선호 위치이며 플러그인 기본값을
  오버라이드한다.

## 스킬

개발 수명주기(brainstorming, writing-plans, TDD, systematic-debugging,
코드 리뷰)는 superpowers가 소유한다. Sobaya 스킬은 워크스페이스를 소유한다:
`sobaya`(오케스트레이션), `new-app`(스캐폴드), `reflect`(학습 기록),
`meditate`(볼트 감사 + 스킬 정제).

## 언어

에이전트용 텍스트(이 파일, 스킬, brain)는 영어. 사람용 문서(README.md,
docs/)는 한국어.
```

### Brain 시딩

**`vision.md`** — 한 페이지: Sobaya가 무엇인지(소바 가게: 워크스페이스는 주방, 앱은 요리, 오케스트레이션 세션은 헤드 쿡), 좋은 모습은 어떤 것인지(brain을 읽고, 잘 브리핑된 서브에이전트를 디스패치하고, 볼트를 들어올 때보다 똑똑하게 만들어 놓고 나가는 세션).

**`principles.md`** — 분류별 wikilink 인덱스: Core / Delegation / State / Verification / Meta.

**`principles/` — 10개 파일**, noodle에서 가져와 각색 (출처는 파일별이 아니라 `codebase/noodle-reference.md`에 기록):

| 파일 | 핵심 규칙 (각색) |
|---|---|
| `prove-it-works` | 결과물은 실물을 직접 확인해서 검증한다 — 프록시나 서브에이전트의 자기 보고로 검증하지 않는다. |
| `fix-root-causes` | 증상을 덮지 않는다. 근본 원인까지 추적해서 거기서 고친다. |
| `subtract-before-you-add` | 먼저 복잡도를 제거하고, 그다음 만든다. |
| `guard-the-context-window` | 오케스트레이터 컨텍스트에 들어오는 모든 토큰은 제값을 해야 한다. 대량 읽기는 서브에이전트로 보낸다. |
| `cost-aware-delegation` | 모든 디스패치에 예산과 명확한 범위 상한을 준다. 긴 브리핑이 재발견 턴보다 싸다. |
| `serialize-shared-state-mutations` | 공유 상태의 동시 변경은 구조적으로 직렬화한다(앱당 작성자 1명, 워크트리, 순차 머지) — 지시만으로는 부족하다. |
| `make-operations-idempotent` | 스크립트와 컨벤션은 몇 번을 실행해도 올바른 상태로 수렴해야 한다(훅, 스캐폴드, 인덱스 재생성). |
| `encode-lessons-in-structure` | 반복되는 수정은 텍스트 지시가 아니라 메커니즘(훅, 규칙, 스캐폴드)이 된다. |
| `never-block-on-the-human` | 승인된 실행 중에는 합리적으로 결정하고 진행하며, 사람이 사후에 교정하게 한다. 설계 승인 게이트(brainstorming)는 다른 단계의 일이고 여전히 적용된다. |
| `foundational-thinking` | 구조적 결정은 선택지 가치를, 코드 수준 결정은 단순함을 최적화한다. |

**`codebase/noodle-reference.md`** — 출처 노트: 소스 저장소 URL, 분석한 커밋, 빌린 것(볼트 구조, reflect/meditate, 훅, 컨벤션 표), 의도적으로 버린 것, 더 이식할 때 어디를 봐야 하는지. 작업 클론은 `references/noodle/`에 있다(커밋 `82d2921` 기준으로 분석).

**`apps.md`** — 레지스트리 헤더 + 표(이름 | 목적 | 스택 | 상태), 본문은 비움.

**`todos.md`** — noodle 포맷: `priority` frontmatter, `<!-- next-id: 2 -->`, 1번 항목 = 이 하네스 빌드, `[[plans/01-sobaya-harness/overview]]` 링크.

**`plans/index.md`** — `- [ ] [[plans/01-sobaya-harness/overview]]`.

**`archive/completed_todos.md`** — 빈 골격.

### 스킬

4종 모두 구현 시 superpowers:writing-skills 컨벤션을 따른다(frontmatter `name` + 트리거를 담은 `description`, 본문 500줄 미만, 상세는 references/로).

**`sobaya`** — *트리거: 앱을 가로지르는 작업 오케스트레이션, 앱 작업용 서브에이전트 디스패치, 어떤 앱에서든 굵직한 다단계 작업 시작.*
1. **사전점검 (mise):** 관련 brain 인덱스 링크 읽기 → `apps.md` + 대상 앱 git 상태 → `todos.md` + 진행 중인 플랜. 한 문단 브리프로 정리: 무엇이 돌고 있고, 범위가 뭐고, 여유가 얼마나 되는지.
2. **디스패치 규칙:** 탐색 → Explore 에이전트(읽기 전용, 파일 덤프가 아니라 결론을 반환). 구현 → general-purpose 에이전트에 앱 경로, 작업, 제약, 보고 형식을 브리핑(`references/dispatch-patterns.md`의 템플릿). 리뷰 → 확인이 아니라 반박하도록 프롬프트한 독립 에이전트.
3. **파이프라인 규율:** 굵직한 작업은 execute → review → reflect로 진행한다. 각 단계의 산출물을 먼저 선언한다. 서브에이전트는 진행 산출물을 파일로 남겨서 중단돼도 작업이 살아남게 한다.
4. **동시성:** 앱당 작성자 1명. 병렬 변경 → 워크트리 격리. 머지는 순차. 동시 에이전트 수 상한. 실패 시 진단 후 재디스패치.
5. **디스패치 전 영속화:** 긴 작업은 디스패치 전에 플랜/진행 파일이 `brain/plans/`에 존재하게 해서, 세션이 끊겨도 다음 세션이 이어받게 한다.

**`new-app`** — *트리거: `apps/` 아래 새 프로젝트 생성.*
1. kebab-case 이름 검증. `apps/<이름>`이 이미 있으면 거부.
2. 새 제품/기능 설계라면 superpowers:brainstorming을 먼저 호출(스킬이 위임한다. 사용자가 명시적으로 스캐폴드만 원하면 생략).
3. `mkdir apps/<이름> && git init -b main`. 앱 수준 `CLAUDE.md`(워크스페이스 컨벤션 참조 + 앱 고유 사실)와 최소 README 작성.
4. `brain/apps.md`에 한 줄 등록. 앱의 첫 마일스톤을 `brain/plans/`에 만들 것을 제안.

**`reflect`** — *트리거: 굵직한 세션의 마무리, 마일스톤 완료 후, 사용자 교정 직후.*
1. 세션 스캔: 실수/교정, 사용자 선호, gotcha, 마찰, 반복된 수동 단계.
2. 발견마다 내구성 테스트: "다른 작업에서도 중요한가?" — 아니면 버린다.
3. 우선순위대로 라우팅: 구조적 인코딩(훅/규칙/스캐폴드 변경) > 스킬 수정 > brain 노트(`codebase/`, 주제당 한 파일) > todo. 워크스페이스·앱 지식 → `brain/`, 사용자 선호와 크로스 프로젝트 사실 → Claude auto-memory.
4. 보고: Brain / Skills / Structural / Todos 요약. (인덱스는 훅이 알아서 갱신한다.)

**`meditate`** — *트리거: reflect가 수차례 누적된 후, 또는 사용자의 명시적 요청.*
1. 볼트 스냅샷(파일 목록 + 크기 + 수정 시각).
2. **auditor** 서브에이전트 디스패치: 낡음, 중복, 고아(링크 없음), 저가치 노트 → 제안 목록.
3. 조기 종료 게이트: 발견이 3건 미만이면 보고하고 멈춘다.
4. **reviewer** 서브에이전트 디스패치: 노트 2개 이상이 뒷받침하는 패턴 → 원칙 후보. brain 내용과 모순되는 스킬 → 수정 제안.
5. 통합 보고서 제시. 승인된 변경 적용. 완료 플랜 아카이브. todo 정리.

### 훅

**`.claude/settings.json`**

```json
{
  "hooks": {
    "SessionStart": [
      { "matcher": "startup|resume", "hooks": [
        { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/inject-brain.sh" } ] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write", "hooks": [
        { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/auto-index-brain.sh" } ] }
    ]
  }
}
```

**`inject-brain.sh`** — 헤더 출력 + `cat brain/index.md`. 파일이 없으면 조용히 `exit 0`.

**`auto-index-brain.sh`** — stdin JSON을 읽고, grep/sed로 `file_path` 추출(jq 없음). 경로에 `/brain/`이 없으면 exit 0. `find`로 볼트의 `.md` 파일 전체 수집(`index.md`와 플랜 디렉토리 내부 파일 제외). 현재 `index.md`의 wikilink와 비교해서 같으면 종료(fast path). 다르면 섹션(Vision / Principles / Apps / Codebase / Backlog / Plans / Archive / 기타 catch-all)을 재생성하고 `mktemp` + `mv`로 원자적으로 쓴다. 모든 실패 경로는 exit 0.

### noodle Go 내부에서 차용한 컨벤션

| noodle 메커니즘 | Sobaya에서의 형태 | 인코딩 위치 |
|---|---|---|
| `WriteFileAtomic` (tmp+rename) | 공유 파일의 원자적 쓰기 | 훅 스크립트; `make-operations-idempotent` |
| busy-target 추적 | 앱당 작성자 1명 | CLAUDE.md; `sobaya` |
| 워크트리 수명주기 + 머지 락 | 병렬 변경은 워크트리 격리, 머지는 순차 | CLAUDE.md; `sobaya`; `serialize-shared-state-mutations` |
| 디스패치 전 영속화 + 세션 입양 | 긴 디스패치 전에 플랜/진행 파일부터; 다음 세션이 `brain/plans`로 이어받음 | `sobaya` |
| `stage_yield` (산출물 ≠ 프로세스 종료) | 서브에이전트가 파일 산출물을 점진적으로 기록 | `sobaya` 디스패치 템플릿 |
| 스케줄러 주도 복구 (자동 재시도 없음) | 실패 시 진단 후 결정 | CLAUDE.md; `sobaya` |
| mise 브리프 | 사전점검 체크리스트 | `sobaya` 1단계 |
| 동시성 상한 + 역압 | 동시 에이전트 수 제한, 실패 작업 반복 디스패치 금지 | `sobaya`; `cost-aware-delegation` |

### README.md (한국어)

양식은 사용자가 제시한 참조 저장소 [coctostan/pi-superpowers-plus](https://github.com/coctostan/pi-superpowers-plus)를 따른다: H1 제목, 바로 아래 전폭 배너 이미지(`![Sobaya banner](banner.svg)` — 루트 상대 경로, 외부 이미지 의존이 없도록 SVG를 저장소에서 직접 제작), 한 줄 소개, 그 아래로 이어지는 섹션:

1. **무엇이 들어있나** — 스킬 4종, 훅 2종, brain 볼트, apps 구조 (불릿)
2. **시작하기** — 세션을 열면 일어나는 일(brain 인덱스 주입), 새 앱 만들기(new-app), 일상 워크플로
3. **워크플로** — ASCII 파이프라인 다이어그램(execute → review → reflect, meditate 루프) + 참조 스타일의 보조 표
4. **구조** — 디렉토리 트리 (코드 블록)
5. **noodle과 superpowers의 관계** — 출처 명시: noodle에서 온 것(커밋 `82d2921`), superpowers가 소유하는 것

표와 코드 블록 스타일은 참조 저장소를 따른다. 배너 모티프: 소바 가게(그릇/면/등롱), 다크 모드 친화 팔레트, "Sobaya" 워드마크.

## 검증

- **훅 단위 테스트:** 합성 stdin 페이로드로 각 스크립트 실행 — brain 경로(재생성 기대), brain 외 경로(no-op), 깨진 JSON(exit 0), brain 디렉토리 없음(exit 0). 시딩된 볼트에 대해 인덱스 내용이 golden 기대값과 일치하는지, 두 번째 실행이 fast-path no-op인지(멱등성) 확인.
- **훅 e2e:** 다음 세션 시작 시 인덱스 주입이 보이는지 확인. README에 문서화.
- **스킬:** frontmatter 유효성 + 트리거 문구를 superpowers:writing-skills 기준으로 리뷰. 리로드 후 세션 스킬 목록에 나타나는지 확인.
- **new-app 스모크 테스트:** `apps/_smoke` 생성 → git 저장소 + CLAUDE.md + 레지스트리 줄 확인 → 삭제하고 등록 해제.
- **인덱스 규율:** 시딩 후 `index.md`의 wikilink가 디스크의 파일과 정확히 일치(훅의 비교 로직 자체가 검사를 겸한다).

## 오류 처리

- 훅은 fail-open: 파일 없음, 파싱 불가, 쓰기 실패 — 전부 exit 0. 깨진 볼트가 세션을 깨는 일은 없다.
- 인덱스 재생성은 원자적으로 쓴다. 쓰기 도중 크래시해도 기존 인덱스가 남는다.
- `new-app`은 기존 디렉토리를 거부하고 기존 앱을 건드리지 않는다.
- `meditate`는 발견이 기준치 미만이면 조기 종료해서 볼트를 휘젓지 않는다.
- 실패한 서브에이전트 디스패치는 절대 맹목적으로 재시도하지 않는다(진단 후 결정).

## 단계 (Phases)

구현 플랜은 단계당 한 파일이다 (태스크는 체크박스로 추적, 순서대로 실행):

- [[plans/01-sobaya-harness/phase-1-skeleton-and-hooks]] — 골격 디렉토리, inject-brain + auto-index-brain 훅 (TDD, POSIX 테스트 스위트), settings 연결
- [[plans/01-sobaya-harness/phase-2-brain-seeding]] — vision, 원칙 10종, 출처/레지스트리/todos/플랜 인덱스, golden 검증 인덱스 생성
- [[plans/01-sobaya-harness/phase-3-skills]] — sobaya(+디스패치 패턴), new-app, reflect, meditate, new-app 스모크 테스트
- [[plans/01-sobaya-harness/phase-4-identity-and-docs]] — CLAUDE.md, banner.svg, 한국어 README/가이드, 최종 점검 + 플랜 마감

## 이후 작업 (빌드 후 todos로 추적)

ruminate 스킬, unslop 스킬, 두 번째 프로바이더 CLI가 생기면 교차 프로바이더 적대적 리뷰, `/loop` 또는 `/schedule` 기반 자율 사이클(선택), 두 번째 하네스 채택 시 `.agents/` 간접 구조.
