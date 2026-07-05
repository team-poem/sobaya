# Office Hub UX Renewal — Phase A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Design tokens + new app shell (segmented nav) + fully re-skinned 창구 (requester) screen per `overview.md`, with 관제실/작업 공간/카탈로그 still running on the legacy UI underneath the new shell.

**Architecture:** Pure static re-skin — zero backend changes. New files `tokens.css`, `ui.css`, `ui.js`, `counter.js`; `index.html` rebuilt as a shell that mounts the new 창구 view and hosts the legacy ops/chat/catalog markup under new segments (they get re-skinned in Phases B/C). Legacy requester UI code is deleted from `ops.js`.

**Tech Stack:** Vanilla JS + CSS custom properties, FastAPI static serving. No build step, no new dependencies.

## Global Constraints

- Repo: `apps/office-automation-hub-design/app/` (its own git repo). Branch: `ux/phase-a` off `renewal/phase-1`.
- Backend untouched: **all 156 existing tests must stay green after every task** — run `./.venv/bin/python -m pytest -q` (venv, not global python).
- Status strings (`접수됨/검토 중/자동화 가능/실행 중/검수 대기/완료/보류`) and risk strings (`낮음/중간/높음`) are API values — never change or translate them.
- XSS discipline: server strings only via `createElement`/`textContent`. Never interpolate server data into `innerHTML` or attribute strings (established in phase-1 commits f6d4aa2/76cf7d1).
- Accent `#10a37f` only on: running state, current stepper step, (later) evidence markers. Everything else monochrome or semantic (`--warn`, `--bad`).
- UI copy is Korean, exactly as written in the code blocks below.
- No JS test framework. Verification per task = pytest regression + `curl` checks + a manual browser checklist with expected observations.
- Server for manual checks: `OPENAI_API_KEY= OFFICE_HUB_LLM_BACKEND=codex ./.venv/bin/python -m uvicorn hub.api:create_app --factory --port 8765` → http://127.0.0.1:8765
- Transitional deviations from overview.md (intentional, resolved in later phases):
  1. Dark theme tokens deferred to Phase C (legacy views aren't dark-capable; shipping dark now would render a half-dark app).
  2. 카탈로그 is a temporary 4th segment (becomes a console drawer in Phase B).
  3. 작업 공간 segment stays always-enabled with the legacy chat UI (session-binding + context strip land in Phase C).
  4. New component CSS lives in `ui.css`; legacy `styles.css` remains for old views and is folded/deleted in Phase C.

## API contract used (verified against `hub/api/ops.py`, no changes)

- `POST /requests` — `{requester_name: str (required), title: str (required), description?: str, contains_personal_data?: bool}` → request JSON with `id`, `created_at`, `status: "접수됨"`.
- `POST /requests/{id}/files` — multipart `file` → `{files: [...]}`.
- `GET /requests?requester=<name>` → `{requests: [{id, title, status, risk_level, created_at, contains_personal_data, ...}]}`.
- `GET /requests/{id}` → `{request, files, jobs, approvals, audit}`; job: `{id, status, result_location, error_message, detail}`; audit row: `{created_at, actor, action, detail}`.
- `POST /requests/{id}/confirm` / `.../rework` — `{actor}` / `{actor, comment}`.

---

### Task 1: Branch + design tokens

**Files:**
- Create: `static/tokens.css`
- Modify: `static/index.html` (stylesheet link only, full rebuild comes in Task 2)

**Interfaces:**
- Produces: CSS custom properties (`--bg`, `--bg-sub`, `--bg-hover`, `--line`, `--line-soft`, `--text`, `--text-2`, `--text-3`, `--btn`, `--btn-text`, `--accent`, `--ok`, `--ok-bg`, `--warn`, `--warn-bg`, `--bad`, `--bad-bg`, `--font-kr`, `--font-num`, `--shadow-seg`) consumed by every later task.

- [ ] **Step 1: Create the branch**

```bash
cd /Users/amazon/lunch.cancelled/sobaya/apps/office-automation-hub-design/app
git checkout renewal/phase-1
git checkout -b ux/phase-a
```

Expected: `Switched to a new branch 'ux/phase-a'`

- [ ] **Step 2: Write `static/tokens.css`**

```css
/* Design tokens — 06-office-hub-ux-renewal (OpenAI-minimal concept).
   Light only in Phase A; dark tokens land in Phase C with the full re-skin. */
:root {
  --bg: #ffffff;
  --bg-sub: #f7f7f8;
  --bg-hover: #f0f0f1;
  --line: #e6e6e6;
  --line-soft: #ececec;
  --text: #0d0d0d;
  --text-2: #6e6e80;
  --text-3: #a6a6b0;
  --btn: #0d0d0d;
  --btn-text: #ffffff;
  --accent: #10a37f;
  --ok: #10a37f;
  --ok-bg: #e7f6f1;
  --warn: #b45309;
  --warn-bg: #fef3e2;
  --bad: #c53030;
  --bad-bg: #fdeaea;
  --font-kr: -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo",
    Pretendard, "Pretendard Variable", "Noto Sans KR", sans-serif;
  --font-num: ui-monospace, "SF Mono", SFMono-Regular, Menlo, monospace;
  --shadow-seg: 0 1px 3px rgba(13, 13, 13, .08);
}
```

- [ ] **Step 3: Link it in `static/index.html`**

In the current `<head>`, before the existing stylesheet:

```html
  <link rel="stylesheet" href="/static/tokens.css">
  <link rel="stylesheet" href="/static/styles.css">
```

- [ ] **Step 4: Verify**

```bash
./.venv/bin/python -m pytest -q
```
Expected: `156 passed`

```bash
OPENAI_API_KEY= OFFICE_HUB_LLM_BACKEND=codex ./.venv/bin/python -m uvicorn hub.api:create_app --factory --port 8765 &
sleep 2 && curl -s http://127.0.0.1:8765/static/tokens.css | grep -c -- '--accent: #10a37f'
```
Expected: `1`

- [ ] **Step 5: Commit**

```bash
git add static/tokens.css static/index.html
git commit -m "feat(ui): design tokens for OpenAI-minimal renewal (phase A)"
```

---

### Task 2: Shell — segmented nav, new header, legacy views re-mounted

**Files:**
- Create: `static/ui.css`
- Modify: `static/index.html` (full rebuild, content below)
- Modify: `static/app.js:3-27` (replace `TABS`/`showTab`/`onRoleChange` with segments) and `static/app.js:29-38` (`attachSession` target)

**Interfaces:**
- Consumes: tokens from Task 1.
- Produces: `go(name)` with `name ∈ {'counter','console','work','catalog'}` (global nav, used by counter.js and ops.js); view mounts `#v-counter` `#v-console` `#v-work` `#v-catalog`; `currentUser(): string` (unchanged signature, now reads the top-bar input); legacy globals `loadQueue()`, `loadCatalog()`, `attachSession(sid)` keep working.
- `loadMyRequests()` is called by `go('counter')` but defined in Task 4's `counter.js`; until Task 4 lands, a stub in `counter.js` does not exist yet — so `index.html` loads `counter.js` only from Task 4 on, and `go()` guards with `typeof loadMyRequests === 'function'`.

- [ ] **Step 1: Rewrite `static/index.html`**

```html
<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Office Hub — 부서 업무자동화</title>
  <link rel="stylesheet" href="/static/tokens.css">
  <link rel="stylesheet" href="/static/styles.css">
  <link rel="stylesheet" href="/static/ui.css">
</head>
<body>
  <div class="topbar">
    <div class="brand"><strong>Office Hub</strong><span>부서 업무자동화</span></div>
    <nav class="seg" aria-label="화면 전환">
      <button id="seg-counter" class="on" onclick="go('counter')">창구</button>
      <button id="seg-console" onclick="go('console')">관제실</button>
      <button id="seg-work" onclick="go('work')">작업 공간</button>
      <button id="seg-catalog" onclick="go('catalog')">카탈로그</button>
    </nav>
    <div class="who">
      <input type="text" id="userName" placeholder="이름" autocomplete="name"
             onchange="if (typeof loadMyRequests === 'function') loadMyRequests()">
    </div>
  </div>

  <!-- 창구: new view, populated by Task 4 -->
  <main id="v-counter" class="counter"></main>

  <!-- 관제실: legacy markup, re-skinned in Phase B -->
  <section id="v-console" hidden>
    <main class="wrap two-col">
      <section class="panel">
        <h2>요청 큐</h2>
        <div id="queue"></div>
      </section>
      <section class="panel">
        <h2>상세</h2>
        <div id="opsDetail">왼쪽 큐에서 요청을 선택하세요.</div>
      </section>
    </main>
  </section>

  <!-- 작업 공간: legacy chat, rebuilt in Phase C -->
  <section id="v-work" hidden>
    <main class="wrap">
      <section class="uploader">
        <input type="file" id="file" multiple>
        <button id="uploadBtn">업로드</button>
        <div class="warn">⚠️ 개인정보가 포함된 파일은 주의해서 올려주세요. 파일 발췌가 외부 AI로 전송됩니다.</div>
        <div class="sources" id="sources">아직 올린 파일이 없습니다.</div>
      </section>
      <section class="chat" id="chat"></section>
      <div class="askbar">
        <input type="text" id="q" placeholder="예: 디자인 학과 신청자 몇 명? 중복자는?">
        <button id="askBtn">질문</button>
      </div>
    </main>
  </section>

  <!-- 카탈로그: legacy, becomes console drawer in Phase B -->
  <section id="v-catalog" hidden>
    <div class="catalog-controls">
      <input id="skill-q" type="search" placeholder="스킬 검색(이름·설명)" oninput="onCatalogChange()">
      <span id="login-filters"></span>
    </div>
    <div id="skill-list" class="skill-grid"></div>
    <p id="catalog-msg"></p>
  </section>

  <script src="/static/app.js"></script>
  <script src="/static/ops.js"></script>
</body>
</html>
```

Note: the old `요청` tab's form/panel markup is gone (replaced by Task 4's counter view); the old `<header>`, role `<select>`, and `.tabs` nav are gone.

- [ ] **Step 2: Write `static/ui.css`** (shell part; counter component styles are appended in Task 4)

```css
/* ui.css — new design-system components (06-ux-renewal).
   Legacy styles.css keeps styling the not-yet-renewed views (console/work/catalog). */

body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font-family: var(--font-kr);
  font-size: 14px;
  line-height: 1.55;
  letter-spacing: -.011em;
}
button { font-family: inherit; letter-spacing: inherit; }

/* ---------- top bar ---------- */
.topbar {
  position: sticky; top: 0; z-index: 10;
  display: flex; align-items: center; justify-content: space-between;
  gap: 12px;
  padding: 10px 22px;
  background: var(--bg);
  border-bottom: 1px solid var(--line-soft);
}
.brand { display: flex; align-items: baseline; gap: 8px; min-width: 170px; }
.brand strong { font-size: 15px; font-weight: 700; }
.brand span { font-size: 11.5px; color: var(--text-3); }
.seg {
  display: flex; gap: 2px; padding: 3px;
  background: var(--bg-sub); border-radius: 999px;
}
.seg button {
  font-size: 13px; font-weight: 600; color: var(--text-2);
  border: none; background: transparent; cursor: pointer;
  padding: 6px 16px; border-radius: 999px;
  transition: color .2s, background .2s;
}
.seg button.on { color: var(--text); background: var(--bg); box-shadow: var(--shadow-seg); }
.who { min-width: 170px; display: flex; justify-content: flex-end; }
.who input {
  width: 120px; font-family: inherit; font-size: 12.5px; color: var(--text);
  padding: 6px 12px; border: 1px solid var(--line); border-radius: 999px;
  background: var(--bg); outline: none; text-align: right;
}
.who input:focus { border-color: var(--text-3); }
.who ::placeholder { color: var(--text-3); }
@media (prefers-reduced-motion: reduce) { * { transition: none !important; animation: none !important; } }
```

- [ ] **Step 3: Replace nav logic in `static/app.js`**

Delete lines 3–27 (`const TABS…` through the whole `showTab` function, including `onRoleChange`) and insert:

```js
const SEGS = ['counter', 'console', 'work', 'catalog'];

function go(name) {
  for (const s of SEGS) {
    const view = document.getElementById('v-' + s);
    const seg = document.getElementById('seg-' + s);
    if (view) view.hidden = s !== name;
    if (seg) seg.classList.toggle('on', s === name);
  }
  if (name === 'catalog' && !window._catalogLoaded) { window._catalogLoaded = true; loadCatalog(); }
  if (name === 'counter' && typeof loadMyRequests === 'function') loadMyRequests();
  if (name === 'console') loadQueue();
}
```

In `attachSession` (app.js:29-38) change the last line `showTab('chat');` to `go('work');`.

`currentUser()` and `currentRole()` — keep `currentUser()` unchanged; delete `currentRole()` and `onRoleChange()` (no callers remain after this task).

- [ ] **Step 4: Verify**

```bash
./.venv/bin/python -m pytest -q
```
Expected: `156 passed`

```bash
curl -s http://127.0.0.1:8765/ | grep -c 'seg-counter'   # → 1
curl -s http://127.0.0.1:8765/ | grep -c 'onRoleChange'  # → 0
```

Manual browser checklist (http://127.0.0.1:8765):
1. Top bar shows brand · 4-segment pill control · name input. No dark legacy header.
2. Clicking 관제실 shows the legacy queue panels; 작업 공간 shows legacy chat; 카탈로그 loads skill cards. 창구 is empty (Task 4 fills it).
3. Console flow still works: submit is impossible now (form removed — expected until Task 4), but selecting an existing request in 관제실 renders detail.
4. No JS errors in the browser console on load or when switching segments.

- [ ] **Step 5: Commit**

```bash
git add static/index.html static/ui.css static/app.js
git commit -m "feat(ui): shell with segmented nav; legacy views mounted under new segments"
```

---

### Task 3: Shared DOM builders (`ui.js`)

**Files:**
- Create: `static/ui.js`
- Modify: `static/index.html` (script tag)

**Interfaces:**
- Produces (globals, used by `counter.js` in Task 4 and by Phase B):
  - `el(tag, className?, text?) → HTMLElement`
  - `statusPill(status: string) → HTMLElement` — pill with dot; `실행 중` green/pulsing, `검수 대기` amber, `보류` red, others neutral.
  - `stepper(status: string) → HTMLElement | null` — 4-step 접수→검토→실행→완료; returns `null` for `보류` (pill carries the state; last-reached step is unknowable from status alone — documented decision).
  - `receiptNo(req: {id, created_at?}) → string` — `제 YYYY-NNN 호`.

- [ ] **Step 1: Write `static/ui.js`**

```js
// ui.js — shared DOM builders. Server strings go through textContent only.

function el(tag, className, text) {
  const n = document.createElement(tag);
  if (className) n.className = className;
  if (text != null) n.textContent = text;
  return n;
}

const PILL_KIND = {
  '실행 중': 'run',
  '검수 대기': 'wait',
  '보류': 'hold',
  '완료': 'done',
};

function statusPill(status) {
  const kind = PILL_KIND[status] || 'neutral';
  const pill = el('span', 'pill pill-' + kind);
  pill.appendChild(el('i'));
  pill.appendChild(document.createTextNode(status));
  return pill;
}

const STEP_LABELS = ['접수', '검토', '실행', '완료'];
// fill = steps filled from the left; now = index drawn in accent (−1: none).
const STEP_MAP = {
  '접수됨':      { fill: 1, now: -1 },
  '검토 중':     { fill: 1, now: 1 },
  '자동화 가능': { fill: 2, now: -1 },
  '실행 중':     { fill: 2, now: 2 },
  '검수 대기':   { fill: 3, now: -1 },
  '완료':        { fill: 4, now: -1 },
};

function stepper(status) {
  const m = STEP_MAP[status];
  if (!m) return null; // '보류' 등: 필이 상태를 전달, 스텝퍼는 숨김
  const box = el('div', 'steps');
  STEP_LABELS.forEach(function (label, i) {
    if (i > 0) box.appendChild(el('div', 'step-line' + (i < m.fill ? ' fill' : '')));
    const step = el('div', 'step' + (i < m.fill ? ' fill' : '') + (i === m.now ? ' now' : ''));
    step.appendChild(el('i'));
    step.appendChild(el('span', null, label));
    box.appendChild(step);
  });
  return box;
}

function receiptNo(req) {
  const year = (req.created_at || '').slice(0, 4) || String(new Date().getFullYear());
  return '제 ' + year + '-' + String(req.id).padStart(3, '0') + ' 호';
}
```

- [ ] **Step 2: Load it in `static/index.html`** (before app.js)

```html
  <script src="/static/ui.js"></script>
  <script src="/static/app.js"></script>
  <script src="/static/ops.js"></script>
```

- [ ] **Step 3: Verify**

```bash
./.venv/bin/python -m pytest -q     # 156 passed
curl -s http://127.0.0.1:8765/static/ui.js | grep -c 'function receiptNo'   # → 1
```
Browser console spot-check on http://127.0.0.1:8765:
`receiptNo({id: 7, created_at: '2026-07-05T10:00:00'})` → `"제 2026-007 호"`; `stepper('보류')` → `null`; `statusPill('실행 중').className` → `"pill pill-run"`.

- [ ] **Step 4: Commit**

```bash
git add static/ui.js static/index.html
git commit -m "feat(ui): shared DOM builders — pill, stepper, receipt number"
```

---

### Task 4: 창구 — composer (request intake)

**Files:**
- Create: `static/counter.js`
- Modify: `static/index.html` (`#v-counter` content + script tag)
- Modify: `static/ui.css` (append counter styles)

**Interfaces:**
- Consumes: `el/statusPill/stepper/receiptNo` (Task 3), `go`, `currentUser` (Task 2), API `POST /requests`, `POST /requests/{id}/files`.
- Produces: `loadMyRequests()` global (already wired to `go('counter')` and the name input); `firstLine(text): string` (title derivation, also used by tests-by-hand).

- [ ] **Step 1: Fill `#v-counter` in `static/index.html`**

Replace `<main id="v-counter" class="counter"></main>` with:

```html
  <main id="v-counter" class="counter">
    <h1 class="greet">무엇을 도와드릴까요?</h1>
    <p class="greet-sub">업무 내용과 파일을 남겨주시면 접수부터 완료까지 여기서 확인할 수 있어요.</p>

    <div class="composer">
      <div class="attach-row" id="cChips" hidden></div>
      <textarea id="cText" placeholder="예: 학과별 성적 파일을 하나로 정리하고, 누락된 학생이 있는지 확인해 주세요."></textarea>
      <div class="composer-foot">
        <div class="foot-left">
          <input type="file" id="cFiles" multiple hidden>
          <button class="icon-btn" id="cAttach" title="파일 첨부">＋</button>
          <label class="pii-toggle"><input type="checkbox" id="cPii">개인정보 포함</label>
        </div>
        <button class="send" id="cSend" title="요청 제출" disabled>↑</button>
      </div>
    </div>
    <p class="composer-err" id="cErr" hidden></p>
    <p class="hint">제출하면 접수번호가 발급되고, 담당자 검토 후 진행 상황을 알려드려요.</p>

    <div class="my-requests">
      <div class="sec-label" id="myLabel">내 요청</div>
      <div class="rcards" id="myCards"></div>
    </div>
  </main>
```

And add `<script src="/static/counter.js"></script>` after the ops.js tag.

- [ ] **Step 2: Append counter styles to `static/ui.css`**

```css
/* ---------- 창구 ---------- */
.counter { max-width: 720px; margin: 0 auto; padding: 56px 24px 80px; }
.greet {
  font-size: 30px; font-weight: 600; letter-spacing: -.025em;
  text-align: center; margin: 0 0 6px; text-wrap: balance;
}
.greet-sub { text-align: center; color: var(--text-2); margin: 0 0 32px; font-size: 14.5px; }

.composer {
  border: 1px solid var(--line); border-radius: 26px; background: var(--bg);
  box-shadow: 0 2px 12px rgba(13, 13, 13, .04);
  padding: 16px 18px 12px;
}
.composer textarea {
  width: 100%; border: none; outline: none; resize: none;
  font-family: inherit; font-size: 15px; color: var(--text);
  background: transparent; height: 72px; letter-spacing: inherit;
  box-sizing: border-box;
}
.composer ::placeholder { color: var(--text-3); }
.attach-row { display: flex; gap: 8px; margin-bottom: 10px; flex-wrap: wrap; }
.file-chip {
  display: inline-flex; align-items: center; gap: 7px;
  font-size: 12.5px; font-weight: 500;
  padding: 6px 12px; border-radius: 10px;
  background: var(--bg-sub); border: 1px solid var(--line-soft);
}
.file-chip i { font-style: normal; font-size: 11px; color: var(--text-3); font-family: var(--font-num); }
.file-chip button {
  border: none; background: none; cursor: pointer;
  color: var(--text-3); font-size: 13px; padding: 0 0 0 2px;
}
.file-chip button:hover { color: var(--bad); }
.composer-foot { display: flex; align-items: center; justify-content: space-between; margin-top: 4px; }
.foot-left { display: flex; align-items: center; gap: 14px; }
.icon-btn {
  width: 34px; height: 34px; border-radius: 50%;
  border: 1px solid var(--line); background: var(--bg);
  color: var(--text-2); font-size: 17px; cursor: pointer;
  display: inline-flex; align-items: center; justify-content: center;
}
.icon-btn:hover { background: var(--bg-sub); }
.pii-toggle { display: inline-flex; align-items: center; gap: 7px; font-size: 12.5px; color: var(--text-2); cursor: pointer; }
.pii-toggle input { accent-color: var(--accent); }
.send {
  width: 36px; height: 36px; border-radius: 50%;
  border: none; background: var(--btn); color: var(--btn-text);
  font-size: 16px; cursor: pointer;
  display: inline-flex; align-items: center; justify-content: center;
  transition: opacity .2s;
}
.send:hover:not([disabled]) { opacity: .85; }
.send[disabled] { opacity: .3; cursor: default; }
.composer-err { color: var(--bad); font-size: 12.5px; margin: 10px 4px 0; }
.hint { text-align: center; font-size: 12px; color: var(--text-3); margin-top: 12px; }
```

- [ ] **Step 3: Write `static/counter.js`** (composer half; card rendering is Task 5)

```js
// counter.js — 창구 (requester view). Composer = the request form.

let _pendingFiles = [];

function firstLine(text) {
  const line = text.split('\n').map(function (s) { return s.trim(); }).filter(Boolean)[0] || '';
  return line.length > 40 ? line.slice(0, 40) + '…' : line;
}

function renderChips() {
  const box = document.getElementById('cChips');
  box.hidden = _pendingFiles.length === 0;
  box.replaceChildren();
  _pendingFiles.forEach(function (f, idx) {
    const chip = el('span', 'file-chip', f.name + ' ');
    chip.appendChild(el('i', null, Math.round(f.size / 1024) + ' KB'));
    const x = el('button', null, '✕');
    x.title = '첨부 취소';
    x.onclick = function () { _pendingFiles.splice(idx, 1); renderChips(); };
    chip.appendChild(x);
    box.appendChild(chip);
  });
}

function composerError(msg) {
  const e = document.getElementById('cErr');
  e.hidden = !msg;
  e.textContent = msg || '';
}

function syncSend() {
  document.getElementById('cSend').disabled =
    document.getElementById('cText').value.trim() === '';
}

async function submitComposer() {
  const textEl = document.getElementById('cText');
  const text = textEl.value.trim();
  if (!text) return;
  composerError('');
  const body = {
    requester_name: currentUser(),
    title: firstLine(text),
    description: text,
    contains_personal_data: document.getElementById('cPii').checked,
  };
  const r = await fetch('/requests', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!r.ok) {
    let detail = '';
    try { detail = (await r.json()).detail || ''; } catch (e) { /* body not json */ }
    composerError('제출에 실패했어요' + (detail ? ': ' + detail : ' (' + r.status + ')') + '. 내용은 지워지지 않았어요.');
    return; // composer keeps text + files
  }
  const req = await r.json();

  const failed = [];
  for (const f of _pendingFiles) {
    const fd = new FormData();
    fd.append('file', f);
    const up = await fetch('/requests/' + req.id + '/files', { method: 'POST', body: fd });
    if (!up.ok) failed.push(f.name);
  }
  if (failed.length) {
    composerError(receiptNo(req) + '로 접수됐지만 일부 파일 첨부에 실패했어요: ' + failed.join(', '));
  }

  textEl.value = '';
  document.getElementById('cPii').checked = false;
  _pendingFiles = [];
  renderChips();
  syncSend();
  loadMyRequests();
}

document.getElementById('cAttach').onclick = function () {
  document.getElementById('cFiles').click();
};
document.getElementById('cFiles').onchange = function (ev) {
  _pendingFiles = _pendingFiles.concat(Array.from(ev.target.files));
  ev.target.value = '';
  renderChips();
};
document.getElementById('cText').oninput = syncSend;
document.getElementById('cSend').onclick = submitComposer;

// Task 5 replaces this stub with the card renderer.
function loadMyRequests() {}

go('counter');
```

- [ ] **Step 4: Verify**

```bash
./.venv/bin/python -m pytest -q     # 156 passed
```

API smoke (proves the composer payload shape is accepted):
```bash
curl -s -X POST http://127.0.0.1:8765/requests -H 'Content-Type: application/json' \
  -d '{"requester_name":"테스트","title":"컴포저 스모크","description":"본문","contains_personal_data":true}'
```
Expected: JSON with `"status": "접수됨"` and an `id`.

Manual browser checklist:
1. 창구 shows greeting + composer. Send(↑) is disabled until text is typed.
2. ＋ opens the file picker; chosen files appear as chips with size; ✕ removes a chip.
3. Submitting with server stopped (kill uvicorn briefly) shows the inline error and keeps text/chips.
4. Submitting normally clears the composer (no card list yet — Task 5).
5. In 관제실, the submitted request appears in the queue with the first line as title, PII flag when checked.

- [ ] **Step 5: Commit**

```bash
git add static/index.html static/ui.css static/counter.js
git commit -m "feat(ui): counter composer — free-text intake with file chips and PII toggle"
```

---

### Task 5: 창구 — 내 요청 cards (stepper, actions, detail expand)

**Files:**
- Modify: `static/counter.js` (replace the `loadMyRequests` stub)
- Modify: `static/ui.css` (append card styles)

**Interfaces:**
- Consumes: `el/statusPill/stepper/receiptNo`, `attachSession(sid)` (legacy, opens 작업 공간), API `GET /requests?requester=`, `GET /requests/{id}`, `POST /requests/{id}/confirm|rework`.
- Produces: working `loadMyRequests()`; per-card `toggleCardDetail(card, reqId)`.

- [ ] **Step 1: Append card styles to `static/ui.css`**

```css
/* ---------- 내 요청 cards ---------- */
.my-requests { margin-top: 48px; }
.sec-label { font-size: 12px; font-weight: 600; color: var(--text-2); margin-bottom: 12px; }
.rcards { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
@media (max-width: 640px) { .rcards { grid-template-columns: 1fr; } }
.rcard {
  border: 1px solid var(--line); border-radius: 16px;
  padding: 16px 18px 14px; cursor: pointer;
  transition: border-color .2s, box-shadow .2s;
}
.rcard:hover { border-color: var(--text-3); box-shadow: 0 2px 10px rgba(13, 13, 13, .05); }
.rcard.done { opacity: .72; }
.rcard .head { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 2px; gap: 8px; }
.rcard .no { font-family: var(--font-num); font-size: 11px; color: var(--text-3); }
.rcard h3 { font-size: 14.5px; font-weight: 600; margin: 0 0 14px; letter-spacing: -.015em; }

.pill {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 11.5px; font-weight: 600;
  padding: 3px 9px; border-radius: 999px; white-space: nowrap;
}
.pill i { font-style: normal; width: 6px; height: 6px; border-radius: 50%; }
.pill-run { color: var(--ok); background: var(--ok-bg); }
.pill-run i { background: var(--ok); animation: pillpulse 1.6s infinite; }
.pill-wait { color: var(--warn); background: var(--warn-bg); }
.pill-wait i { background: var(--warn); }
.pill-hold { color: var(--bad); background: var(--bad-bg); }
.pill-hold i { background: var(--bad); }
.pill-done, .pill-neutral { color: var(--text-2); background: var(--bg-sub); }
.pill-done i, .pill-neutral i { background: var(--text-3); }
@keyframes pillpulse { 50% { opacity: .3; } }

.steps { display: flex; align-items: center; }
.step { display: flex; flex-direction: column; align-items: center; gap: 5px; }
.step i {
  font-style: normal; width: 9px; height: 9px; border-radius: 50%;
  background: var(--bg); border: 1.5px solid var(--line); box-sizing: border-box;
}
.step.fill i { background: var(--text); border-color: var(--text); }
.step.now i { background: var(--accent); border-color: var(--accent); }
.step span { font-size: 10px; color: var(--text-3); }
.step.fill span, .step.now span { color: var(--text-2); font-weight: 600; }
.step-line { flex: 1; height: 1.5px; background: var(--line); margin: 0 4px 15px; min-width: 22px; }
.step-line.fill { background: var(--text); }

.rcard .acts { display: flex; gap: 8px; margin-top: 14px; flex-wrap: wrap; }
.b-solid {
  font-size: 12.5px; font-weight: 600; color: var(--btn-text);
  background: var(--btn); border: none; cursor: pointer;
  padding: 8px 14px; border-radius: 999px;
}
.b-solid:hover { opacity: .85; }
.b-ghost {
  font-size: 12.5px; font-weight: 600; color: var(--text);
  background: var(--bg); border: 1px solid var(--line); cursor: pointer;
  padding: 8px 14px; border-radius: 999px;
}
.b-ghost:hover { background: var(--bg-sub); }

.rcard .detail { margin-top: 14px; padding-top: 12px; border-top: 1px solid var(--line-soft); cursor: auto; }
.rcard .detail p { margin: 0 0 8px; font-size: 13px; color: var(--text-2); white-space: pre-wrap; }
.rcard .detail .files { font-size: 12px; color: var(--text-2); margin-bottom: 8px; }
.rcard .detail ul { margin: 0; padding-left: 16px; font-size: 11.5px; color: var(--text-3); }
.rcard .detail li { font-family: var(--font-num); }
.empty { color: var(--text-3); font-size: 13px; padding: 18px 4px; }
```

- [ ] **Step 2: Replace the `loadMyRequests` stub in `static/counter.js`**

Delete `function loadMyRequests() {}` and insert:

```js
async function loadMyRequests() {
  const cards = document.getElementById('myCards');
  const label = document.getElementById('myLabel');
  const name = currentUser();
  if (name === '이름없음') {
    label.textContent = '내 요청';
    cards.replaceChildren(el('div', 'empty', '오른쪽 위에 이름을 입력하면 내 요청이 표시돼요.'));
    return;
  }
  const r = await fetch('/requests?requester=' + encodeURIComponent(name));
  if (!r.ok) {
    cards.replaceChildren(el('div', 'empty', '목록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.'));
    return;
  }
  const items = (await r.json()).requests;
  label.textContent = '내 요청 ' + items.length + '건';
  if (!items.length) {
    cards.replaceChildren(el('div', 'empty', '아직 요청이 없어요. 위 입력창에 업무 내용을 적고 ↑를 눌러 제출해 보세요.'));
    return;
  }
  cards.replaceChildren();
  items.forEach(function (q) { cards.appendChild(requestCard(q)); });
}

function requestCard(q) {
  const card = el('div', 'rcard' + (q.status === '완료' ? ' done' : ''));

  const head = el('div', 'head');
  head.appendChild(el('span', 'no', receiptNo(q)));
  head.appendChild(statusPill(q.status));
  card.appendChild(head);
  card.appendChild(el('h3', null, q.title));

  const steps = stepper(q.status);
  if (steps) card.appendChild(steps);

  if (q.status === '검수 대기') {
    const acts = el('div', 'acts');
    const ok = el('button', 'b-solid', '결과 확인하고 완료');
    ok.onclick = function (ev) { ev.stopPropagation(); confirmMine(q.id); };
    acts.appendChild(ok);
    const rw = el('button', 'b-ghost', '수정 요청');
    rw.onclick = function (ev) { ev.stopPropagation(); reworkMine(q.id); };
    acts.appendChild(rw);
    card.appendChild(acts);
  }

  card.onclick = function () { toggleCardDetail(card, q.id); };
  return card;
}

async function toggleCardDetail(card, reqId) {
  const existing = card.querySelector('.detail');
  if (existing) { existing.remove(); return; }
  const r = await fetch('/requests/' + reqId);
  if (!r.ok) return;
  const d = await r.json();
  const box = el('div', 'detail');
  box.onclick = function (ev) { ev.stopPropagation(); };
  if (d.request.description) box.appendChild(el('p', null, d.request.description));
  if (d.files.length) box.appendChild(el('div', 'files', '첨부: ' + d.files.join(', ')));

  const lastJob = d.jobs.filter(function (j) { return j.status === '성공'; }).pop();
  if (lastJob && typeof lastJob.result_location === 'string'
      && lastJob.result_location.startsWith('session:')) {
    const sid = lastJob.result_location.slice(8);
    const open = el('button', 'b-ghost', '결과 채팅 열기');
    open.onclick = function () { attachSession(sid); };
    box.appendChild(open);
  }

  const timeline = el('ul');
  d.audit.slice(-5).forEach(function (a) {
    timeline.appendChild(el('li', null, a.created_at + ' · ' + a.action + (a.detail ? ' — ' + a.detail : '')));
  });
  box.appendChild(timeline);
  card.appendChild(box);
}

async function confirmMine(reqId) {
  const r = await fetch('/requests/' + reqId + '/confirm', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ actor: currentUser() }),
  });
  if (!r.ok) {
    let detail = '';
    try { detail = (await r.json()).detail || ''; } catch (e) { /* not json */ }
    composerError('완료 처리에 실패했어요' + (detail ? ': ' + detail : ''));
  }
  loadMyRequests();
}

async function reworkMine(reqId) {
  const comment = prompt('어떤 부분을 고치면 좋을까요?') || '';
  const r = await fetch('/requests/' + reqId + '/rework', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ actor: currentUser(), comment: comment }),
  });
  if (!r.ok) {
    let detail = '';
    try { detail = (await r.json()).detail || ''; } catch (e) { /* not json */ }
    composerError('수정 요청에 실패했어요' + (detail ? ': ' + detail : ''));
  }
  loadMyRequests();
}
```

- [ ] **Step 3: Verify**

```bash
./.venv/bin/python -m pytest -q     # 156 passed
```

Manual browser checklist (enter name `테스트` in the top bar first):
1. Cards render for `테스트`'s requests: receipt number `제 2026-0NN 호`, title, status pill, 4-step stepper. `접수됨` card: 1 filled step; no accent.
2. Card click expands: request text, 첨부, recent audit lines (mono). Second click collapses.
3. Drive one request through the console (관제실: 검토 → 위험도 낮음 → chat-answer → 실행) and back on 창구: status pill turns `실행 중` (green pulsing dot, step 3 accent) → after the run, `검수 대기` (amber pill, [결과 확인하고 완료] [수정 요청] buttons appear).
4. `수정 요청` with a comment → status returns to `자동화 가능` (buttons disappear). Re-run, then `결과 확인하고 완료` → `완료`, card dims, all 4 steps filled.
5. Empty name → hint card. Unknown name → "아직 요청이 없어요…" empty state.

- [ ] **Step 4: Commit**

```bash
git add static/counter.js static/ui.css
git commit -m "feat(ui): counter request cards — receipt stepper, confirm/rework, detail expand"
```

---

### Task 6: Legacy requester code removal + phase E2E

**Files:**
- Modify: `static/ops.js:15-124` (delete dead requester functions)

**Interfaces:**
- Consumes: everything above.
- Produces: `ops.js` containing only FDE code (`loadQueue`, `openDetail`, `renderJobRow`, `doReview`, `doApprove`, `doRun`, `doSimple`, `_post`, `esc`, `statusChip`) until Phase B replaces it.

- [ ] **Step 1: Delete dead code from `static/ops.js`**

Remove these now-unreferenced functions (their DOM ids no longer exist): `submitRequest`, `uploadRequestFiles`, `loadMyRequests` (the legacy one — the live one is in counter.js), `renderRequesterActions`, `confirmRequest`, `requestRework`, and the `_lastRequestId` variable.

Keep: `esc`, `STATUS_CLASS`/`statusChip`, `_selectedRequest`, `_templates`, `loadQueue`, `getTemplates`, `renderJobRow`, `openDetail`, `_post`, `doReview`, `doApprove`, `doRun`, `doSimple`.

- [ ] **Step 2: Grep for dangling references**

```bash
grep -n 'submitRequest\|uploadRequestFiles\|renderRequesterActions\|confirmRequest\|requestRework\|_lastRequestId\|reqSubmitMsg\|reqFileBox\|onRoleChange\|showTab' static/*.js static/index.html
```
Expected: no output.

- [ ] **Step 3: Full phase E2E (manual, fresh DB optional via `OFFICE_HUB_DB=/tmp/hub-a.db`)**

1. 창구: type name `김선영`, submit a two-line request with one xlsx attached and PII checked.
2. 관제실: request appears (title = first line, 개인정보 marker). 검토 → 위험도 중간, template chat-answer → 실행.
3. 창구: card shows `검수 대기` → open detail → `결과 채팅 열기` opens 작업 공간 with the session → back to 창구 → `결과 확인하고 완료` → `완료`.
4. 카탈로그 segment still lists skills; no JS console errors anywhere.

```bash
./.venv/bin/python -m pytest -q     # 156 passed — final regression proof
```

- [ ] **Step 4: Commit**

```bash
git add static/ops.js
git commit -m "refactor(ui): drop legacy requester UI code superseded by counter view"
```

---

## Self-review notes

- Spec coverage (overview.md 창구 section): composer w/ chips+PII+↑ (T4), receipt number + title derivation (T3/T4), inline error keeping text (T4), hint line (T4), cards grid + stepper + accent rules (T5), 검수 대기 actions incl. rework (T5), detail expand w/ text/files/timeline (T5), empty states (T5). Shell/segments/identity (T2). 보류 stepper-freeze relaxed to pill-only — documented in T3 (status alone can't reconstruct the last reached step; revisit in Phase B where audit data is already loaded).
- Deliberate deviations from overview.md are listed under Global Constraints (dark theme → C, catalog segment → B, workspace gating → C, ui.css vs styles.css → C).
- Type consistency: `go/currentUser/el/statusPill/stepper/receiptNo/loadMyRequests/attachSession` names match across tasks; `composerError` defined in T4, used in T5.
