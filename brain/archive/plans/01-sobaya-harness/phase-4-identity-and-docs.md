# Sobaya Harness Implementation Plan — Phase 4: Identity & Docs

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write the harness contract (CLAUDE.md), the banner, the Korean README (banner-first format per spec) and guide, then run the full verification sweep and close out plan 01.

**Architecture:** CLAUDE.md is the only always-loaded text and stays ~30 lines (spec D2 rationale: progressive disclosure). README follows the user's reference layout — H1, banner image, pitch, flowing sections. The banner is hand-authored SVG so the repo has no external image dependency.

**Tech Stack:** Markdown (EN for CLAUDE.md, KO for README/guide), SVG.

**Spec:** `brain/plans/01-sobaya-harness/overview.md` (approved 2026-06-12). Phases: 1 skeleton+hooks → 2 brain seeding → 3 skills → **4 identity & docs**.

**Working directory:** `/Users/amazon/lunch.cancelled/sobaya`. Use `git -C /Users/amazon/lunch.cancelled/sobaya` for git commands.

---

### Task 15: CLAUDE.md (harness contract)

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Write `CLAUDE.md`** with exactly (this is the spec's approved draft, verbatim):

```markdown
# Sobaya

Orchestration workspace for multi-project agent work. Projects live in
`apps/<name>` — each an independent git repository. This root repo tracks
only the harness: `CLAUDE.md`, `.claude/`, `brain/`, `docs/`.

## Brain

`brain/` is an Obsidian-compatible vault — persistent memory across sessions.
A hook injects its index at session start.

- **Read first.** Read brain files relevant to your task before acting.
- **Write** after mistakes, corrections, or notable learnings — use Skill(reflect).
- **Structure:** One topic per file. `brain/index.md` is rebuilt by a hook —
  never hand-edit it. Plan dirs maintain `brain/plans/index.md` by convention.
- **Maintain:** Delete outdated notes. Move completed plans to `brain/archive/plans/`.

## Workflow

- **Apps:** Never create projects outside `apps/`. Each app is its own git
  repo; cross-app changes are separate commits per app.
- **Subagent-first:** For multi-file or exploratory work, dispatch subagents
  (Explore to read, general-purpose to change) — keep this context clean.
  See Skill(sobaya) for dispatch patterns.
- **One writer per app:** Never run two mutating agents against the same
  checkout. Parallel mutation requires worktree isolation.
- **No blind retries:** When delegated work fails, read its output and
  diagnose before re-dispatching.
- **Plans and specs live in `brain/plans/NN-slug/`** (overview.md = spec,
  phase-*.md = plan). This is the user's preferred location and overrides
  plugin defaults.

## Skills

superpowers owns the dev lifecycle (brainstorming, writing-plans, TDD,
systematic-debugging, code review). Sobaya skills own the workspace:
`sobaya` (orchestration), `new-app` (scaffold), `reflect` (capture
learnings), `meditate` (vault audit + skill refinement).

## Language

Agent-facing text (this file, skills, brain) is English. Human-facing docs
(README.md, docs/) are Korean.
```

- [ ] **Step 2: Verify line budget**

Run: `wc -l CLAUDE.md`
Expected: ≤ 45 lines (target ~40 — the contract must stay small; if it grew past 45, cut before committing).

- [ ] **Step 3: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add CLAUDE.md
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(workspace): Add harness contract CLAUDE.md

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 16: banner.svg

**Files:**
- Create: `banner.svg`

- [ ] **Step 1: Write `banner.svg`** with exactly:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="320" viewBox="0 0 1200 320" role="img" aria-label="Sobaya — subagent orchestration workspace">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#15161e"/>
      <stop offset="1" stop-color="#1e2235"/>
    </linearGradient>
    <linearGradient id="bowl" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#33395c"/>
      <stop offset="1" stop-color="#23263c"/>
    </linearGradient>
  </defs>

  <rect width="1200" height="320" fill="url(#bg)"/>

  <!-- noren curtain -->
  <rect x="0" y="0" width="1200" height="14" fill="#c8472e"/>
  <g fill="#c8472e">
    <rect x="70"  y="14" width="120" height="34" rx="3"/>
    <rect x="250" y="14" width="120" height="52" rx="3"/>
    <rect x="430" y="14" width="120" height="34" rx="3"/>
    <rect x="650" y="14" width="120" height="52" rx="3"/>
    <rect x="830" y="14" width="120" height="34" rx="3"/>
    <rect x="1010" y="14" width="120" height="52" rx="3"/>
  </g>

  <!-- lantern -->
  <g>
    <rect x="118" y="86" width="24" height="10" rx="2" fill="#3a3f5c"/>
    <ellipse cx="130" cy="170" rx="46" ry="64" fill="#e8a33d"/>
    <ellipse cx="130" cy="170" rx="46" ry="64" fill="none" stroke="#b97a1e" stroke-width="2"/>
    <path d="M92 140 Q130 132 168 140" stroke="#b97a1e" stroke-width="1.5" fill="none"/>
    <path d="M88 170 Q130 162 172 170" stroke="#b97a1e" stroke-width="1.5" fill="none"/>
    <path d="M92 200 Q130 192 168 200" stroke="#b97a1e" stroke-width="1.5" fill="none"/>
    <text x="130" y="158" font-family="Hiragino Mincho ProN, Yu Mincho, serif" font-size="26" fill="#7a4a12" text-anchor="middle">蕎麦</text>
    <text x="130" y="190" font-family="Hiragino Mincho ProN, Yu Mincho, serif" font-size="26" fill="#7a4a12" text-anchor="middle">屋</text>
    <rect x="118" y="232" width="24" height="8" rx="2" fill="#3a3f5c"/>
  </g>

  <!-- wordmark -->
  <g>
    <text x="240" y="178" font-family="Avenir Next, Futura, Helvetica Neue, Arial, sans-serif" font-size="84" font-weight="700" letter-spacing="6" fill="#f3ede2">SOBAYA</text>
    <rect x="244" y="200" width="396" height="3" fill="#c8472e"/>
    <text x="244" y="238" font-family="Menlo, Consolas, monospace" font-size="20" letter-spacing="2" fill="#9aa3c7">subagent orchestration workspace · そば屋</text>
  </g>

  <!-- bowl of soba -->
  <g>
    <g stroke="#d8b25a" stroke-width="5" fill="none" stroke-linecap="round">
      <path d="M952 248 q18 -34 52 -40"/>
      <path d="M978 248 q22 -28 54 -30"/>
      <path d="M1006 248 q24 -20 54 -18"/>
      <path d="M1032 248 q22 -12 48 -8"/>
    </g>
    <path d="M918 248 h220 q-8 46 -60 58 h-100 q-52 -12 -60 -58 Z" fill="url(#bowl)"/>
    <path d="M918 248 h220" stroke="#4a5178" stroke-width="4"/>
    <rect x="946" y="296" width="164" height="10" rx="4" fill="#2b2f49"/>
    <g stroke="#b9c0e0" stroke-width="4" stroke-linecap="round">
      <line x1="1064" y1="160" x2="1148" y2="236"/>
      <line x1="1082" y1="150" x2="1158" y2="222"/>
    </g>
    <g stroke="#8d96bd" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.8">
      <path d="M986 216 q-10 -16 2 -30 q10 -12 2 -26"/>
      <path d="M1022 212 q-10 -16 2 -30 q10 -12 2 -26"/>
    </g>
  </g>
</svg>
```

- [ ] **Step 2: Validate it is well-formed XML**

Run: `python3 -c "import xml.dom.minidom; xml.dom.minidom.parse('banner.svg'); print('well-formed')"`
Expected: `well-formed`

- [ ] **Step 3: Visual check**

Run: `open banner.svg` (opens in the default viewer) — confirm: dark background, red noren strip on top, amber lantern left with 蕎麦屋, SOBAYA wordmark center, noodle bowl with chopsticks and steam right. If a shape is visibly broken, fix coordinates and re-validate; pixel-perfection is not required.

- [ ] **Step 4: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add banner.svg
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(workspace): Add hand-authored SVG banner

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 17: README.md (Korean, banner-first)

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`** with exactly:

````markdown
# Sobaya

![Sobaya banner](banner.svg)

서브에이전트 오케스트레이션 워크스페이스 — 소바 가게(蕎麦屋)처럼, 주방(워크스페이스)에서 헤드 쿡(Claude 세션)이 브리게이드(서브에이전트들)에게 일을 나눠주고 요리(`apps/`의 프로젝트들)를 완성합니다.

[poteto/noodle](https://github.com/poteto/noodle)의 작업 방식을 Claude Code 네이티브로 옮긴 하네스 환경입니다. 프레임워크가 아니라, max effort 모델(Opus 4.8 / Fable 5)이 일하기 좋은 규칙·스킬·메모리의 집합입니다.

## 무엇이 들어있나

- **스킬 4종** — `sobaya`(오케스트레이션 플레이북), `new-app`(앱 스캐폴드), `reflect`(세션 학습 기록), `meditate`(볼트 감사 + 스킬 자기개선)
- **훅 2종** — 세션 시작 시 brain 인덱스 자동 주입, brain 파일 변경 시 인덱스 자동 재생성 (결정론적 POSIX 셸, 실패해도 세션을 깨지 않는 fail-open)
- **brain/ 볼트** — Obsidian 호환 영속 메모리: 원칙 10종, 지식 노트, 플랜, 백로그
- **apps/ 구조** — 프로젝트마다 독립 git 저장소, 워크스페이스 루트는 하네스만 추적

## 시작하기

```sh
cd sobaya && claude
```

세션이 열리면 훅이 brain 인덱스를 자동으로 주입합니다. 거기서부터:

- **새 앱** — "새 앱 만들어줘" → `new-app` 스킬이 `apps/<이름>` 스캐폴드 + git init + 레지스트리 등록 (새 제품 설계라면 brainstorming부터)
- **앱 작업** — 굵직한 작업을 시키면 `sobaya` 스킬이 사전점검(mise) → 서브에이전트 디스패치 → 파이프라인으로 진행
- **마무리** — 의미 있는 세션 끝에 `reflect`가 배운 것을 brain에 기록하고, 쌓이면 `meditate`가 볼트를 정리합니다

## 워크플로

```
        ┌────────────────── meditate (볼트 감사 · 원칙 추출 · 스킬 정제) ◄─┐
        ▼                                                                  │
mise 사전점검 ─► execute ─► review ─► reflect ─► brain/ ───────────────────┘
(brain·앱 상태)   (cook)    (refuter)  (학습 기록)   (다음 세션이 읽음)
```

| 단계 | 담당 | 산출물 |
|---|---|---|
| 사전점검 | 오케스트레이터 (`sobaya` 스킬) | 한 문단 브리프 |
| execute | general-purpose 서브에이전트 (+워크트리) | 커밋, 진행 보고 파일 |
| review | 독립 서브에이전트 (반박 프롬프트) | 발견 목록 |
| reflect | 오케스트레이터 (`reflect` 스킬) | brain 노트 / 스킬 수정 / todo |

설계·플랜·TDD·디버깅·코드리뷰는 superpowers 플러그인이 담당합니다 — Sobaya는 그 위의 워크스페이스 계층만 맡습니다.

## 구조

```
sobaya/
├── CLAUDE.md          # 하네스 계약 (EN, ~30줄)
├── banner.svg
├── .claude/
│   ├── settings.json  # 훅 와이어링
│   ├── hooks/         # inject-brain, auto-index-brain
│   └── skills/        # sobaya, new-app, reflect, meditate
├── brain/             # 영속 메모리 볼트 (EN)
│   ├── index.md       # 훅이 자동 생성 — 직접 수정 금지
│   ├── principles/    # 의사결정 원칙 10종
│   ├── codebase/      # 지식·gotcha 노트
│   ├── plans/         # NN-slug/ (overview = 스펙, phase-* = 플랜)
│   ├── todos.md       # 영구 번호 백로그
│   └── archive/
├── apps/              # 프로젝트들 — 각자 독립 git 저장소 (루트에서 gitignore)
├── references/        # 참조 클론 (noodle) — gitignore
├── tests/             # 훅 테스트 (sh tests/hooks-test.sh)
└── docs/              # 한국어 문서
```

## noodle과 superpowers의 관계

- **noodle** (커밋 `82d2921` 분석) — brain 볼트 구조, reflect/meditate 자기개선 루프, 결정론적 훅, 그리고 Go 메카닉의 컨벤션화(원자적 쓰기, 앱당 작성자 1명, 워크트리 격리, 진단 후 재시도)를 가져왔습니다. 작업 클론: `references/noodle/`
- **superpowers** — 개발 수명주기(브레인스토밍 → 플랜 → TDD → 디버깅 → 리뷰)는 전부 superpowers 스킬을 따릅니다. Sobaya 스킬은 충돌하지 않도록 워크스페이스 오케스트레이션과 자기개선만 다룹니다

자세한 사용법: [docs/guide.md](docs/guide.md) · 설계 스펙: [brain/plans/01-sobaya-harness/overview.ko.md](brain/plans/01-sobaya-harness/overview.ko.md)
````

- [ ] **Step 2: Verify the banner reference resolves**

Run: `grep -n 'banner.svg' README.md && ls banner.svg`
Expected: the image line `![Sobaya banner](banner.svg)` directly under `# Sobaya`, and the file exists.

- [ ] **Step 3: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add README.md
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "docs(workspace): Add Korean README, banner-first layout

Layout per user reference (coctostan/pi-superpowers-plus).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 18: docs/guide.md (Korean usage guide)

**Files:**
- Create: `docs/guide.md`

- [ ] **Step 1: Write `docs/guide.md`** with exactly:

````markdown
# Sobaya 사용 가이드

README가 "무엇"이라면 이 문서는 "어떻게"입니다. 세션에서 실제로 벌어지는 흐름 중심으로 설명합니다.

## 세션의 시작

`sobaya/`에서 `claude`를 열면 SessionStart 훅이 `brain/index.md`를 주입합니다. 세션은 인덱스에서 **관련 있는 노트만** 골라 읽습니다 — 전부 읽는 것은 컨텍스트 낭비입니다(원칙: guard-the-context-window).

## 시나리오 1 — 새 앱 만들기

1. "todo 앱 하나 만들자" → 새 제품 설계이므로 superpowers **brainstorming**이 먼저 디자인을 잡습니다.
2. 디자인 승인 후 **new-app** 스킬: `apps/todo-app` 생성, `git init -b main`, 앱 CLAUDE.md·README 작성, `brain/apps.md` 등록.
3. 스펙과 플랜은 `brain/plans/02-todo-app/`에 (overview.md + phase-*.md).
4. 구현은 **sobaya** 스킬의 디스패치 규칙대로 서브에이전트가 수행합니다.

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

맹목 재시도 금지. 출력과 산출물을 읽고 → 진단(진짜 버그면 superpowers systematic-debugging) → 브리프 수정 / 분해 변경 / 직접 수행 중 결정합니다.

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
````

- [ ] **Step 2: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add docs/guide.md
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "docs(workspace): Add Korean usage guide

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 19: Final verification sweep + plan close-out

**Files:**
- Modify: `brain/todos.md`
- Modify: `brain/archive/completed_todos.md`
- Modify: `brain/plans/index.md`
- Modify: `brain/plans/01-sobaya-harness/overview.md` (frontmatter `status`)
- Move: `brain/plans/01-sobaya-harness/` → `brain/archive/plans/01-sobaya-harness/`

- [ ] **Step 1: Full test pass**

Run: `sh tests/hooks-test.sh`
Expected: `ALL PASS`, exit 0.

- [ ] **Step 2: Inventory against the spec tree**

Run: `find . -path ./references -prune -o -path ./.git -prune -o -type f -print | sort`
Expected files (exactly these, plus `.git*` internals excluded by the prune):
`./.claude/hooks/auto-index-brain.sh`, `./.claude/hooks/inject-brain.sh`, `./.claude/settings.json`, `./.claude/skills/meditate/SKILL.md`, `./.claude/skills/new-app/SKILL.md`, `./.claude/skills/reflect/SKILL.md`, `./.claude/skills/sobaya/SKILL.md`, `./.claude/skills/sobaya/references/dispatch-patterns.md`, `./.gitignore`, `./CLAUDE.md`, `./README.md`, `./apps/.gitkeep`, `./banner.svg`, `./brain/apps.md`, `./brain/archive/completed_todos.md`, `./brain/codebase/noodle-reference.md`, `./brain/index.md`, `./brain/plans/01-sobaya-harness/overview.md`, `./brain/plans/01-sobaya-harness/overview.ko.md`, `./brain/plans/01-sobaya-harness/phase-1-skeleton-and-hooks.md`, `./brain/plans/01-sobaya-harness/phase-2-brain-seeding.md`, `./brain/plans/01-sobaya-harness/phase-3-skills.md`, `./brain/plans/01-sobaya-harness/phase-4-identity-and-docs.md`, `./brain/principles.md`, `./brain/principles/cost-aware-delegation.md`, `./brain/principles/encode-lessons-in-structure.md`, `./brain/principles/fix-root-causes.md`, `./brain/principles/foundational-thinking.md`, `./brain/principles/guard-the-context-window.md`, `./brain/principles/make-operations-idempotent.md`, `./brain/principles/never-block-on-the-human.md`, `./brain/principles/prove-it-works.md`, `./brain/principles/serialize-shared-state-mutations.md`, `./brain/principles/subtract-before-you-add.md`, `./brain/todos.md`, `./brain/plans/index.md`, `./brain/vision.md`, `./docs/guide.md`, `./tests/hooks-test.sh`.
Any extra or missing file is a failure — resolve before continuing.

- [ ] **Step 3: Working tree clean**

Run: `git -C /Users/amazon/lunch.cancelled/sobaya status --short`
Expected: empty output.

- [ ] **Step 4: Close out todo #1, file future work, and archive the plan**

1. In `brain/todos.md`: move item 1 into `brain/archive/completed_todos.md` as `1. [x] ~~Build the Sobaya harness~~ — done. [[archive/plans/01-sobaya-harness/overview]]`, then file the spec's Future Work section as new items so todos.md becomes exactly:

```markdown
---
priority: []
# nothing ranked yet — 2..5 are backlog candidates from plan 01's Future Work
---

# Todos

<!-- next-id: 7 -->
<!-- completed todos live in archive/completed_todos.md -->
<!-- completed plans live in archive/plans/ -->

## Workspace

2. [ ] ruminate skill — mine past session transcripts for uncaptured
   patterns, batched subagent analysis (port from noodle).
3. [ ] Cross-provider adversarial review — opposite-model reviewers via a
   second provider CLI; blocked until one is installed.
4. [ ] Optional autonomous cycles — schedule/execute loop via /loop or
   /schedule once the harness has proven itself in interactive use.
5. [ ] unslop skill — de-AI writing pass for human-facing docs (port from
   noodle).
6. [ ] .agents/ multi-harness indirection — only if a second harness is
   adopted (migrate-callers, then delete).
```
2. In `brain/plans/index.md`: change the entry to `- [x] [[archive/plans/01-sobaya-harness/overview]]`.
3. In `brain/plans/01-sobaya-harness/overview.md` frontmatter: `status: active` → `status: done`.
4. Move the plan directory:

```bash
git -C /Users/amazon/lunch.cancelled/sobaya mv brain/plans/01-sobaya-harness brain/archive/plans/01-sobaya-harness
```

5. Regenerate the index (hook-equivalent invocation):

```bash
cd /Users/amazon/lunch.cancelled/sobaya
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/brain/todos.md"}}' "$PWD" \
  | CLAUDE_PROJECT_DIR="$PWD" sh .claude/hooks/auto-index-brain.sh
```

Run: `cat brain/index.md`
Expected: identical to the phase-2 golden index — the archived plan's nested files stay excluded and `plans/index` remains the only Plans entry. (`brain/plans/` now contains only `index.md`.)

- [ ] **Step 5: Reflect on the build (orchestrator step — use Skill(reflect))**

Run the reflect skill over the whole build effort. Known candidates observed during planning (verify they still hold, then route per the skill):
- The persistent-shell-cwd gotcha: a `cd` into `references/noodle` made later `git` commands hit the wrong repo → candidate note `brain/codebase/persistent-cwd-and-reference-clones.md` recommending `git -C` + absolute paths.
- Anything the executor hit during phases 1–4 (test flakes, macOS quirks, harness behaviors).

- [ ] **Step 6: Final commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add -A
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "chore(brain): Close out plan 01 — harness built and verified

Todo #1 done and archived; plan moved to archive/plans; index regenerated.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 7: Report e2e residue for the next session**

State in the final report: "SessionStart injection and PostToolUse auto-index must be observed at the next session start (hooks load then). Verify: open a new session in sobaya/ — the brain index should appear; edit any brain file — index should rebuild."
