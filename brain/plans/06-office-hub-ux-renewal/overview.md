# 06 · office-hub-ux-renewal — Design Spec

Status: **ALL PHASES A+B+C implemented (2026-07-05) — branch `ux/phase-a` (25 commits off renewal/phase-1, 161 tests green, all three final reviews: Ready to merge=Yes). Phase C record: phase-C.md execution amendments. Remaining for user: browser visual check (light+dark), one real-LLM /ask smoke, merge decision (stack: main ← renewal/phase-1 ← ux/phase-a). Brand: 뚝딱 Hub.**
Date: 2026-07-05
App: `apps/office-automation-hub-design/app/`
Base: branch off `renewal/phase-1` (unmerged; merge to main deferred by user)
Concept mockup: [artifact](https://claude.ai/code/artifact/444dcc1b-eee8-4da1-af7f-b78e017a44f7) · local copy `concept-mockup.html` (v2, approved 2026-07-05)

## Goal

Rebuild the hub's UI to the approved "OpenAI minimal" concept and define the
target UX for every hub screen — 창구 (requester), 관제실 (FDE console),
작업 공간 (request-bound chat), catalog drawer, and the 지표 screen's visual
frame. Backend behavior from phase 1 is preserved; this renewal is UI/UX
plus the three phase-3 UI divergence fixes (export button, clickable
evidence chips, catalog card detail) which land naturally with the new
workspace screen.

## Decisions (user-confirmed this session)

- **Baseline**: work on a new branch on top of `renewal/phase-1`; merging
  phase-1 to main stays a separate, later decision.
- **Scope**: full target UX designed now; implementation staged (A/B/C below).
- **Paradigm**: role hybrid. Requester gets a document-based entry
  (composer = the request form), FDE gets a dense console. One request
  journey shared by both.
- **Stack**: vanilla JS, no build step. `static/` stays FastAPI-served
  files, split per screen.
- **Visual concept**: OpenAI minimal. References chosen by user:
  21st.dev "ChatGPT Prompt Input" (easemize), prompt-kit.com (ibelick),
  21st.dev "Form Layout" (ephraimduncan). These are visual references only
  (they're React/Tailwind); we translate the aesthetic into our own CSS.
- **Rejected**: liquidGL / full liquid-glass concept (mockup v1 built,
  user rejected: legibility + "too glassy"); paper/stamp "창구와 관제실"
  concept (superseded by OpenAI minimal); React migration.

## Visual system

Design tokens (CSS custom properties on `:root`, dark theme via
`@media (prefers-color-scheme: dark)` plus `[data-theme]` overrides):

| token | light | dark | role |
|---|---|---|---|
| `--bg` | `#ffffff` | `#212121` | page ground |
| `--bg-sub` | `#f7f7f8` | `#2a2a2e` | table heads, chips, user bubbles |
| `--line` / `--line-soft` | `#e6e6e6` / `#ececec` | `#3a3a40` / `#333338` | hairlines |
| `--text` / `--text-2` / `--text-3` | `#0d0d0d` / `#6e6e80` / `#a6a6b0` | `#ececec` / `#b4b4bd` / `#7c7c86` | text hierarchy |
| `--btn` | black pill, white text | inverted | primary actions |
| `--accent` = `--ok` | `#10a37f` | same | THE single accent |
| `--warn` / `--bad` | `#b45309` / `#c53030` (+ soft bgs) | darker bgs | semantic only |

- **Accent discipline**: `#10a37f` appears only on running state, current
  step, and evidence markers. Risk/status colors are semantic dots/pills,
  never decorative.
- **Type**: KR system stack (`Apple SD Gothic Neo` / Pretendard fallback);
  `ui-monospace` for request numbers, timestamps, template names, tabular
  data. Scale: greeting 30/600, console h1 20/700, body 14, table 13,
  labels 11–12. `tabular-nums` on stat digits.
- **Density is the role signal**: 창구 720px single column, large type,
  generous whitespace; 관제실 1080px, hairline-separated stats, dense table;
  작업 공간 760px thread.
- Buttons: pill-shaped. Solid black = primary, ghost bordered = secondary,
  round icon buttons (＋ attach, ↑ submit).

## IA

Top bar: brand · segmented control (창구 / 관제실 / 작업 공간) · identity
label. The segmented control replaces the old tab row and the old role
switcher (role = screen, as in phase 1).

1. **창구** — requester home: greeting, composer, 내 요청 cards.
2. **관제실** — FDE console: stat row, queue table, request workbench,
   audit log, catalog drawer.
3. **작업 공간** — chat bound to one request (FDE-side execution surface
   for chat-answer; replaces the standalone 채팅 tab). Its segment is
   disabled with a tooltip until a session is active.
4. **지표** — phase 2 (05 plan); will join as a 4th segment then; adopts
   these tokens; not implemented here.

## Screen behavior

### 창구 (requester)

- **Composer = request form.** One free-text textarea ("예: 학과별 성적
  파일을 하나로 정리하고…"), attach button producing file chips (name +
  size, removable), 개인정보 포함 toggle, round ↑ submit.
- Submit → POST existing intake endpoint → request `접수됨`, receipt number
  rendered as `제 YYYY-NNN 호`. Title auto-derived client-side from the
  first line (≈40 chars, ellipsized); FDE can edit the title at review.
  PII toggle sets `contains_personal_data` (backend already forces
  risk ≥ 중간).
- Validation: empty text disables submit; submit failure keeps the text
  and shows an inline error line under the composer (no modal).
- Hint line under composer states what happens next (접수번호 발급 → 검토).
- **내 요청 cards** (grid 2-col, 1-col <640px): receipt number (mono),
  title, status pill, 4-step stepper 접수→검토→실행→완료. Filled steps
  black, current step accent. 보류/실패 shown as status pill (stepper
  freezes at last reached step).
- Card actions by state: `검수 대기` → [결과 확인하고 완료] (primary; opens
  result summary + downloads, confirm transitions to 완료 per risk rules)
  and [수정 요청] (increments rework_count, returns to 자동화 가능 per
  phase-1 semantics). `완료` → results download. Card click expands detail:
  request text, files, result files, status timeline.
- Empty state: "아직 요청이 없어요" + one-line how-to.

### 관제실 (FDE)

- **Stat row** (counts derived from request list): 대기 · 실행 중 ·
  검수 대기 · 오늘 완료. Hairline-separated, no cards.
- **Queue table**: No.(mono) · 요청(title + template mono sub-line) ·
  요청자 · 위험도(colored square dot + label) · 상태(pill) · action.
  Action button reflects the gate: `실행` enabled only when state and risk
  gates allow; `승인 필요` rows disabled until an approval exists.
  Row click opens the **workbench**.
- **Workbench** (detail view of one request): request text + files;
  review controls — risk level, editable title, template assignment,
  reviewer memo (`manual_minutes_estimate` only if the field already exists
  in the phase-1 schema; otherwise it stays 05-phase-2 scope); approval
  form (approver +
  comment) shown when risk = 높음; run button; result files; job history
  with error messages on failure; per-request audit trail.
- **Audit log panel**: recent events, mono timestamps, bold actors,
  ok/warn colored verbs. Read-only.
- **Catalog drawer**: side sheet listing k-skill catalog cards; card click
  expands detail via existing `/skills/{name}` (phase-3 divergence fix).
- API errors (409 illegal transition etc.) surface as an inline banner in
  the workbench, never silent.

### 작업 공간 (chat workspace)

- Entered by running a `chat-answer` job from the workbench (and from the
  segmented control while a session is active). Requesters never see this
  screen — they receive exported results on their receipt.
- **Context strip** pinned on top: receipt number, title, template chip,
  live status pill. Makes "chat is bound to a request" visible.
- Thread follows prompt-kit grammar: user messages in `--bg-sub` bubbles
  (right), assistant messages as plain text (left, no bubble).
- **Evidence chips** under assistant answers (mono: file · sheet!range or
  tool · summary). Click opens the source excerpt (popover/expand) —
  phase-3 divergence fix; data already exists in the answer payload
  (plan verifies exact shape).
- **Result blocks**: bordered, mono preview, header with row summary and
  [xlsx로 내보내기] wiring the existing unreachable `/export` — phase-3
  divergence fix.
- Composer pill at bottom (attach ＋, textarea, ↑), sticky.

## Code structure

```
static/
  index.html        # shell: top bar, segmented control, view mounts
  tokens.css        # design tokens (light + dark)
  styles.css        # components (pills, steppers, tables, composer…)
  counter.js        # 창구
  console.js        # 관제실 (queue + workbench + audit + catalog drawer)
  workspace.js      # 작업 공간 (chat)
  ui.js             # shared DOM builders (pill, stepper, table row…)
```

- All server strings rendered via `createElement`/`textContent` — keeps the
  XSS discipline established in phase 1 (no innerHTML with server data).
- No framework, no build. Shared components are plain functions in `ui.js`.

## API mapping

Phase-1 endpoints cover the flows; this renewal is mostly a re-skin.
Known UI-side additions with existing backends: `/export` (workspace),
`/skills/{name}` (catalog drawer), evidence excerpts (payload reuse).
If planning uncovers a real gap (e.g. requester-visible result summary
endpoint), it goes into the phase plan explicitly — no silent API growth.

## Error handling

- Composer/workbench actions: inline error text near the control, request
  state re-fetched after failure.
- Job failure: status pill `실패` + error message in workbench; request
  returns to 자동화 가능 (phase-1 contract).
- Illegal transitions (409): inline banner with the server message.

## Testing

- Backend untouched → existing 156 tests must stay green (regression proof).
- Any endpoint touched or added gets pytest coverage per app discipline
  (stubbed LLM, tmp_path DB, no network).
- UI: manual verification against this spec per phase checkpoint (vanilla
  static, no JS test framework introduced).

## Implementation phases

Each phase gets its own `phase-N.md` via writing-plans:

- **Phase A** — tokens + shell + 창구 (composer, cards, stepper, states).
- **Phase B** — 관제실 (stat row, queue, workbench, approval/run, audit,
  catalog drawer).
- **Phase C** — 작업 공간 (chat rebind, evidence chips, export, context
  strip) — absorbs 05 plan phase-3 UI divergence fixes.

Relationship to `05-office-hub-renewal`: 05's phase 2 (templates + metrics)
remains functional scope owned by 05 and will adopt these tokens; 05's
phase 3 UI items are absorbed here (Phase C). 05's static/ UI description
is superseded by this spec.

## Out of scope (YAGNI)

- SSE streaming, 지표 detail spec (phase 2), excel-cleanup/file-merge
  runners (phase 2), 학칙챗봇 tab, auth, mobile, React/Tailwind migration,
  liquidGL/WebGL effects.

## Success criteria

1. A non-developer teacher can submit a request and read its progress from
   the 창구 without instruction.
2. Every phase-1 flow (intake → review → risk → approval → run → confirm)
   is reachable and legible in the new UI.
3. Export, evidence chips, and catalog card detail work (three phase-3
   divergences closed).
4. Existing 156 tests green throughout; no backend behavior change.
