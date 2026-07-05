# 뚝딱 Hub UX Renewal — Phase B Implementation Plan (관제실)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the 관제실 (FDE console) to the OpenAI-minimal design — stat row, dense queue table, request workbench (review/approval/run/lifecycle/jobs/audit), and the k-skill catalog relocated from a nav segment to a console drawer — deleting legacy `ops.js` entirely.

**Architecture:** UI-only, zero backend changes (the 156-test suite green remains the regression proof, same as Phase A). New `static/console.js` renders everything with the `ui.js` DOM builders (XSS-safe); legacy `ops.js` (innerHTML+esc pattern) is deleted at the end. Catalog code moves out of `app.js` into the drawer section of `console.js`.

**Tech Stack:** Vanilla JS + CSS custom properties (tokens.css from Phase A). No build step, no new dependencies.

## Global Constraints

- Repo: `apps/office-automation-hub-design/app`, branch `ux/phase-a` (continue on it; base for this phase: commit `9852ac0`).
- **Backend untouched. `./.venv/bin/python -m pytest -q` → 156 passed after every task** (venv python).
- Status strings `접수됨/검토 중/자동화 가능/실행 중/검수 대기/완료/보류`, risk `낮음/중간/높음`, approval `승인/반려`, job status `성공/실패` are API values — byte-exact.
- XSS discipline: server strings only via `el()`/`textContent`. `console.js` must not contain `innerHTML` at all.
- Accent `#10a37f` only on running state / current step / live markers. Semantic colors as dots/pills.
- UI copy Korean exactly as written in the code blocks.
- `node --check` on every touched JS file. Server for checks: `OFFICE_HUB_DB=/tmp/hub-<task>.db OPENAI_API_KEY= OFFICE_HUB_LLM_BACKEND=codex ./.venv/bin/python -m uvicorn hub.api:create_app --factory --port 8765` (background, kill after).
- Browser-only visual checks: report as deferred-to-human.

## Adjudicated deviations from overview.md (UI-only phase)

1. **No editable title / reviewer memo in the workbench** — `ReviewBody` is `{actor, risk_level, template_id}` only (verified `hub/api/ops.py:31-34`); adding fields is backend work, deferred to 05-plan phase 2 alongside `manual_minutes_estimate`.
2. **Audit panel is per-selected-request**, not a global feed — no global audit endpoint exists (`store.list_audit` is only exposed through `GET /requests/{id}`). Global feed = future backend candidate.
3. 카탈로그 segment is removed from the nav (드로어로 이동) — resolves Phase A transitional deviation #2.

## API contract used (verified in `hub/api/ops.py`, `hub/api/catalog.py` — no changes)

- `GET /requests` → `{requests: [Request.as_dict()]}`; Request fields: id, requester_name, title, department, description, input_location, output_format, repeat_cycle, due_at, contains_personal_data, requires_external_login, human_check_point, status, risk_level, template_id, created_at, updated_at (**UTC ISO** strings — `store._utc_now()`).
- `GET /requests/{id}` → `{request, jobs, approvals, files, audit}`; job: {id, template_id, status(성공/실패/실행 중), started_at, finished_at, result_location, error_message, detail}; approval: {approver, status, comment, created_at}; audit: {actor, action, detail, created_at} (request+job rows merged, sorted).
- `POST /requests/{id}/review` `{actor, risk_level, template_id}` → 200 / 422 (bad risk, PII+낮음 rejected) / 409.
- `POST /requests/{id}/approvals` `{approver, status(승인|반려), comment}` → 201 / 422.
- `POST /requests/{id}/jobs` `{actor}` → 200 job / 409 `승인 필요` (높음 without 승인) / 409 illegal state.
- `POST /requests/{id}/confirm|rework|hold|resume` — actor bodies; errors 403 (NotYourRequest), 409.
- `GET /templates` → `{templates: [{id, name, description}]}` (currently one: chat-answer / 채팅 답변).
- `GET /skills?q=&login=` → `{skills: [...], logins: [...]}`; `GET /skills/{name}` → single skill object (render generically).
- Error body shape: `{"detail": "..."}`.

---

### Task 1: ui.js additions + nav rewiring

**Files:**
- Modify: `static/ui.js` (append)
- Modify: `static/app.js` (one line in `go()`)

**Interfaces:**
- Produces: `riskDot(level) → HTMLElement` (`<span class="risk-dot risk-{low|mid|high}"><i></i>낮음</span>`; unknown level → plain text span), `fmtTime(iso) → 'MM-DD HH:MM'` local time (invalid → raw string), `isToday(iso) → boolean` (local-date compare of a UTC ISO string).
- `go('console')` now calls `loadConsole()` (guarded by typeof; defined in Task 2) instead of legacy `loadQueue()`.

- [ ] **Step 1: Append to `static/ui.js`**

```js
const RISK_CLASS = { '낮음': 'low', '중간': 'mid', '높음': 'high' };

function riskDot(level) {
  const cls = RISK_CLASS[level];
  if (!cls) return el('span', null, level || '—');
  const s = el('span', 'risk-dot risk-' + cls);
  s.appendChild(el('i'));
  s.appendChild(document.createTextNode(level));
  return s;
}

function fmtTime(iso) {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso || '';
  const p = function (n) { return String(n).padStart(2, '0'); };
  return p(d.getMonth() + 1) + '-' + p(d.getDate()) + ' ' + p(d.getHours()) + ':' + p(d.getMinutes());
}

function isToday(iso) {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return false;
  const n = new Date();
  return d.getFullYear() === n.getFullYear() && d.getMonth() === n.getMonth()
    && d.getDate() === n.getDate();
}
```

- [ ] **Step 2: Rewire `static/app.js`** — in `go()`, replace `if (name === 'console') loadQueue();` with:

```js
  if (name === 'console' && typeof loadConsole === 'function') loadConsole();
```

(Legacy `loadQueue` in ops.js becomes nav-unreachable; ops.js is deleted in Task 6.)

- [ ] **Step 3: Verify** — `node --check static/ui.js static/app.js`(each) clean; `./.venv/bin/python -m pytest -q` → 156; server + `curl -s http://127.0.0.1:8765/static/ui.js | grep -c riskDot` → 2.

- [ ] **Step 4: Commit** — `git commit -m "feat(ui): riskDot/fmtTime/isToday builders; console nav rewired"`

---

### Task 2: 관제실 shell — stat row + queue table

**Files:**
- Modify: `static/index.html` (replace the whole `<section id="v-console" hidden>…</section>` block; add `<script src="/static/console.js"></script>` after counter.js)
- Modify: `static/ui.css` (append console styles)
- Create: `static/console.js`

**Interfaces:**
- Consumes: `el/statusPill/riskDot/isToday/currentUser`, `GET /requests`, `POST /requests/{id}/jobs`.
- Produces: `loadConsole()` (wired in Task 1), `openWorkbench(id)` (stub here; real in Task 3), `runReq(id)`, `consoleError(msg)`, state `_selReq`.

- [ ] **Step 1: Replace `#v-console` in `static/index.html`**

```html
  <section id="v-console" class="console" hidden>
    <div class="console-head">
      <div>
        <h1>오늘의 큐</h1>
        <p class="desc" id="conDesc"></p>
      </div>
      <button class="b-ghost" id="drawerBtn" hidden>카탈로그</button>
    </div>
    <p class="composer-err" id="conErr" hidden></p>
    <div class="statrow" id="statRow"></div>
    <div class="console-grid">
      <div class="qwrap">
        <table>
          <thead>
            <tr><th>No.</th><th>요청</th><th>요청자</th><th>위험도</th><th>상태</th><th></th></tr>
          </thead>
          <tbody id="qBody"></tbody>
        </table>
      </div>
      <div class="workbench" id="workbench"><div class="empty">큐에서 요청을 선택하세요.</div></div>
    </div>
  </section>
```

And add the script tag as the LAST script: `<script src="/static/console.js"></script>`.

- [ ] **Step 2: Append console styles to `static/ui.css`**

```css
/* ---------- 관제실 ---------- */
.console { max-width: 1080px; margin: 0 auto; padding: 40px 24px 80px; }
.console-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; }
.console h1 { font-size: 20px; font-weight: 700; letter-spacing: -.02em; margin: 0 0 4px; }
.console .desc { color: var(--text-2); font-size: 13.5px; margin: 0 0 20px; }

.statrow {
  display: flex; margin-bottom: 28px;
  border-top: 1px solid var(--line-soft); border-bottom: 1px solid var(--line-soft);
}
.stat { flex: 1; padding: 14px 20px; border-left: 1px solid var(--line-soft); }
.stat:first-child { border-left: none; padding-left: 4px; }
.stat .n { font-family: var(--font-num); font-size: 24px; font-weight: 600; font-variant-numeric: tabular-nums; }
.stat.hot .n { color: var(--accent); }
.stat .l { font-size: 12px; color: var(--text-2); margin-top: 2px; }

.console-grid { display: grid; grid-template-columns: 1.6fr 1fr; gap: 24px; align-items: start; }
@media (max-width: 900px) { .console-grid { grid-template-columns: 1fr; } }

.qwrap { overflow-x: auto; border: 1px solid var(--line); border-radius: 14px; }
.qwrap table { border-collapse: collapse; width: 100%; min-width: 520px; font-size: 13px; }
.qwrap th {
  text-align: left; font-size: 11px; font-weight: 600; color: var(--text-3);
  letter-spacing: .03em; padding: 10px 12px;
  border-bottom: 1px solid var(--line); background: var(--bg-sub);
}
.qwrap th:first-child, .qwrap td:first-child { padding-left: 16px; }
.qwrap th:last-child, .qwrap td:last-child { padding-right: 16px; }
.qwrap td { padding: 11px 12px; border-bottom: 1px solid var(--line-soft); vertical-align: middle; }
.qwrap tr:last-child td { border-bottom: none; }
.qwrap tbody tr { cursor: pointer; }
.qwrap tbody tr:hover td { background: var(--bg-sub); }
.qwrap tbody tr.sel td { background: var(--bg-hover); }
.qwrap td.no { font-family: var(--font-num); font-size: 12px; color: var(--text-2); }
.qwrap td .t { font-weight: 600; letter-spacing: -.01em; }
.qwrap td .tpl { font-family: var(--font-num); font-size: 11px; color: var(--text-3); margin-top: 1px; }
.qwrap td.person { color: var(--text-2); }
.pii-mark {
  display: inline-block; font-size: 10.5px; font-weight: 600; color: var(--warn);
  background: var(--warn-bg); border-radius: 6px; padding: 1.5px 6px; margin-left: 6px;
  vertical-align: 1px;
}

.risk-dot { display: inline-flex; align-items: center; gap: 6px; font-size: 12px; font-weight: 600; }
.risk-dot i { font-style: normal; width: 7px; height: 7px; border-radius: 2px; }
.risk-low i  { background: var(--ok); }
.risk-mid i  { background: var(--warn); }
.risk-high i { background: var(--bad); }

.b-run {
  font-size: 12px; font-weight: 600; color: var(--text);
  background: var(--bg); border: 1px solid var(--line); cursor: pointer;
  padding: 6px 12px; border-radius: 999px; white-space: nowrap;
}
.b-run:hover { border-color: var(--text); }

.workbench {
  border: 1px solid var(--line); border-radius: 14px;
  padding: 18px 20px; font-size: 13px;
}
```

- [ ] **Step 3: Write `static/console.js`**

```js
// console.js — 관제실 (FDE view). Everything renders via ui.js builders (textContent only).

let _selReq = null;
let _tmplCache = null;

function consoleError(msg) {
  const e = document.getElementById('conErr');
  e.hidden = !msg;
  e.textContent = msg || '';
}

const STATUS_ORDER = {
  '접수됨': 0, '검토 중': 1, '자동화 가능': 2, '실행 중': 3,
  '검수 대기': 4, '보류': 5, '완료': 6,
};

async function loadConsole() {
  consoleError('');
  let items;
  try {
    const r = await fetch('/requests');
    if (!r.ok) throw new Error('HTTP ' + r.status);
    items = (await r.json()).requests;
  } catch (e) {
    console.error(e);
    consoleError('큐를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.');
    return;
  }
  renderStats(items);
  renderQueue(items);
  if (_selReq !== null) openWorkbench(_selReq);
}

function renderStats(items) {
  const by = function (fn) { return items.filter(fn).length; };
  const stats = [
    ['대기', by(function (q) { return q.status === '접수됨' || q.status === '검토 중'; }), false],
    ['실행 중', by(function (q) { return q.status === '실행 중'; }), true],
    ['검수 대기', by(function (q) { return q.status === '검수 대기'; }), false],
    ['오늘 완료', by(function (q) { return q.status === '완료' && isToday(q.updated_at); }), false],
  ];
  const row = document.getElementById('statRow');
  row.replaceChildren();
  stats.forEach(function (s) {
    const box = el('div', 'stat' + (s[2] && s[1] > 0 ? ' hot' : ''));
    box.appendChild(el('div', 'n', String(s[1])));
    box.appendChild(el('div', 'l', s[0]));
    row.appendChild(box);
  });
  const waiting = stats[0][1];
  document.getElementById('conDesc').textContent =
    waiting > 0 ? '검토를 기다리는 요청이 ' + waiting + '건 있어요.' : '검토 대기 중인 요청이 없어요.';
}

function renderQueue(items) {
  const body = document.getElementById('qBody');
  body.replaceChildren();
  if (!items.length) {
    const tr = el('tr');
    const td = el('td', 'empty', '아직 요청이 없어요.');
    td.colSpan = 6;
    tr.appendChild(td);
    body.appendChild(tr);
    return;
  }
  const sorted = items.slice().sort(function (a, b) {
    const d = (STATUS_ORDER[a.status] ?? 9) - (STATUS_ORDER[b.status] ?? 9);
    return d !== 0 ? d : b.id - a.id;
  });
  sorted.forEach(function (q) {
    const tr = el('tr', q.id === _selReq ? 'sel' : null);
    tr.appendChild(el('td', 'no', String(q.id).padStart(3, '0')));

    const tdReq = el('td');
    const t = el('div', 't', q.title);
    if (q.contains_personal_data) t.appendChild(el('span', 'pii-mark', '개인정보'));
    tdReq.appendChild(t);
    tdReq.appendChild(el('div', 'tpl', q.template_id || '—'));
    tr.appendChild(tdReq);

    tr.appendChild(el('td', 'person', q.requester_name));

    const tdRisk = el('td');
    tdRisk.appendChild(riskDot(q.risk_level));
    tr.appendChild(tdRisk);

    const tdSt = el('td');
    tdSt.appendChild(statusPill(q.status));
    tr.appendChild(tdSt);

    const tdAct = el('td');
    if (q.status === '자동화 가능') {
      const b = el('button', 'b-run', '실행');
      b.onclick = function (ev) { ev.stopPropagation(); runReq(q.id); };
      tdAct.appendChild(b);
    }
    tr.appendChild(tdAct);

    tr.onclick = function () { openWorkbench(q.id); };
    body.appendChild(tr);
  });
}

async function runReq(id) {
  consoleError('');
  try {
    const r = await fetch('/requests/' + id + '/jobs', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ actor: currentUser() }),
    });
    if (!r.ok) {
      let detail = '';
      try { detail = (await r.json()).detail || ''; } catch (e) { /* not json */ }
      consoleError('실행에 실패했어요' + (detail ? ': ' + detail : ' (' + r.status + ')'));
    }
  } catch (e) {
    console.error(e);
    consoleError('네트워크 오류로 실행하지 못했어요.');
  }
  loadConsole();
}

// Task 3 replaces this stub with the real workbench renderer.
function openWorkbench(id) { _selReq = id; }
```

- [ ] **Step 4: Verify** — `node --check static/console.js` clean; pytest 156; server: `curl -s http://127.0.0.1:8765/ | grep -c 'qBody'` → 1; seed one request via curl (`POST /requests` `{"requester_name":"테스트","title":"큐 스모크"}` on the throwaway DB), then confirm `GET /requests` shows it (queue render itself is a browser check — defer visual).

- [ ] **Step 5: Commit** — `git commit -m "feat(ui): console stat row + queue table (openai-minimal)"`

---

### Task 3: Workbench — detail, review form, lifecycle actions

**Files:**
- Modify: `static/console.js` (replace the `openWorkbench` stub; add helpers)
- Modify: `static/ui.css` (append workbench styles)

**Interfaces:**
- Consumes: `GET /requests/{id}`, `GET /templates`, `POST review/confirm/hold/resume`, `el/statusPill/riskDot/receiptNo/fmtTime/currentUser`.
- Produces: real `openWorkbench(id)`; `wbPost(id, path, body)`; `getTemplates()`. Task 4 appends `renderApprovals(d, box)`, `renderJobs(d, box)`, `renderAudit(d, box)` calls — `openWorkbench` here already invokes all three, defined as empty stubs at the bottom (Task 4 replaces them).

- [ ] **Step 1: Append workbench styles to `static/ui.css`**

```css
.workbench h2 { font-size: 15.5px; font-weight: 700; letter-spacing: -.015em; margin: 8px 0 2px; }
.wb-head { display: flex; justify-content: space-between; align-items: baseline; gap: 8px; }
.wb-no { font-family: var(--font-num); font-size: 11px; color: var(--text-3); }
.wb-sec {
  margin-top: 14px; padding-top: 12px;
  border-top: 1px solid var(--line-soft);
}
.wb-sec .sec-label { margin-bottom: 8px; }
.wb-field { display: flex; gap: 8px; font-size: 12.5px; margin: 3px 0; }
.wb-field b { flex: 0 0 72px; font-weight: 600; color: var(--text-2); }
.wb-field span { color: var(--text); white-space: pre-wrap; }
.wb-err { color: var(--bad); font-size: 12.5px; margin-top: 10px; }
.wb-form { display: flex; flex-direction: column; gap: 8px; }
.wb-form select {
  font-family: inherit; font-size: 13px; color: var(--text);
  padding: 8px 10px; border: 1px solid var(--line); border-radius: 10px;
  background: var(--bg);
}
.wb-note { font-size: 11.5px; color: var(--warn); }
.wb-acts { display: flex; gap: 8px; margin-top: 12px; flex-wrap: wrap; }
```

- [ ] **Step 2: In `static/console.js`, delete the stub `function openWorkbench(id) { _selReq = id; }` and append:**

```js
async function getTemplates() {
  if (!_tmplCache) {
    const r = await fetch('/templates');
    _tmplCache = r.ok ? (await r.json()).templates : [];
  }
  return _tmplCache;
}

function wbError(msg) {
  const box = document.getElementById('wbErr');
  if (box) box.textContent = msg || '';
}

async function wbPost(id, path, body) {
  wbError('');
  try {
    const r = await fetch('/requests/' + id + '/' + path, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (!r.ok) {
      let detail = '';
      try { detail = (await r.json()).detail || ''; } catch (e) { /* not json */ }
      wbError('처리하지 못했어요' + (detail ? ': ' + detail : ' (' + r.status + ')'));
      return false;
    }
    return true;
  } catch (e) {
    console.error(e);
    wbError('네트워크 오류가 발생했어요. 잠시 후 다시 시도해 주세요.');
    return false;
  } finally {
    loadConsole();
  }
}

const WB_FIELDS = [
  ['requester_name', '요청자'], ['department', '소속'], ['description', '내용'],
  ['input_location', '입력 자료'], ['output_format', '결과물'],
  ['repeat_cycle', '반복 주기'], ['due_at', '마감'], ['human_check_point', '확인 지점'],
];

async function openWorkbench(id) {
  _selReq = id;
  const wb = document.getElementById('workbench');
  let d;
  try {
    const r = await fetch('/requests/' + id);
    if (!r.ok) throw new Error('HTTP ' + r.status);
    d = await r.json();
  } catch (e) {
    console.error(e);
    wb.replaceChildren(el('div', 'empty', '상세를 불러오지 못했어요.'));
    return;
  }
  const q = d.request;
  wb.replaceChildren();

  const head = el('div', 'wb-head');
  head.appendChild(el('span', 'wb-no', receiptNo(q)));
  head.appendChild(statusPill(q.status));
  wb.appendChild(head);
  wb.appendChild(el('h2', null, q.title));
  if (q.risk_level) wb.appendChild(riskDot(q.risk_level));

  const info = el('div', 'wb-sec');
  WB_FIELDS.forEach(function (f) {
    if (!q[f[0]]) return;
    const row = el('div', 'wb-field');
    row.appendChild(el('b', null, f[1]));
    row.appendChild(el('span', null, String(q[f[0]])));
    info.appendChild(row);
  });
  const flags = [];
  if (q.contains_personal_data) flags.push('개인정보 포함');
  if (q.requires_external_login) flags.push('외부 로그인 필요');
  if (flags.length) {
    const row = el('div', 'wb-field');
    row.appendChild(el('b', null, '주의'));
    row.appendChild(el('span', null, flags.join(' · ')));
    info.appendChild(row);
  }
  if (d.files.length) {
    const row = el('div', 'wb-field');
    row.appendChild(el('b', null, '첨부'));
    row.appendChild(el('span', null, d.files.join(', ')));
    info.appendChild(row);
  }
  wb.appendChild(info);

  if (q.status === '접수됨' || q.status === '검토 중') {
    wb.appendChild(await reviewForm(q));
  }
  renderApprovals(d, wb);

  const acts = el('div', 'wb-acts');
  if (q.status === '자동화 가능') {
    const b = el('button', 'b-solid', '실행');
    b.onclick = function () { runReq(q.id); };
    acts.appendChild(b);
  }
  if (q.status === '검수 대기') {
    const b = el('button', 'b-solid', '완료 처리');
    b.onclick = function () { wbPost(q.id, 'confirm', { actor: currentUser() }); };
    acts.appendChild(b);
  }
  if (q.status === '보류') {
    const b = el('button', 'b-ghost', '보류 해제');
    b.onclick = function () { wbPost(q.id, 'resume', { actor: currentUser() }); };
    acts.appendChild(b);
  } else if (q.status !== '완료' && q.status !== '실행 중') {
    const b = el('button', 'b-ghost', '보류');
    b.onclick = function () { wbPost(q.id, 'hold', { actor: currentUser() }); };
    acts.appendChild(b);
  }
  if (acts.childNodes.length) wb.appendChild(acts);

  renderJobs(d, wb);
  renderAudit(d, wb);
  const errBox = el('div', 'wb-err');
  errBox.id = 'wbErr';
  wb.appendChild(errBox);
}

async function reviewForm(q) {
  const sec = el('div', 'wb-sec');
  sec.appendChild(el('div', 'sec-label', '검토'));
  const form = el('div', 'wb-form');

  const riskSel = el('select');
  ['낮음', '중간', '높음'].forEach(function (lv) {
    const o = el('option', null, lv);
    o.value = lv;
    riskSel.appendChild(o);
  });
  if (q.contains_personal_data) {
    riskSel.value = '중간';
    form.appendChild(el('div', 'wb-note', '개인정보 포함 요청 — 위험도는 중간 이상이어야 해요.'));
  }
  form.appendChild(riskSel);

  const tmplSel = el('select');
  (await getTemplates()).forEach(function (t) {
    const o = el('option', null, t.name);
    o.value = t.id;
    tmplSel.appendChild(o);
  });
  form.appendChild(tmplSel);

  const b = el('button', 'b-solid', '검토 완료 → 자동화 가능');
  b.onclick = function () {
    wbPost(q.id, 'review', {
      actor: currentUser(), risk_level: riskSel.value, template_id: tmplSel.value,
    });
  };
  form.appendChild(b);
  sec.appendChild(form);
  return sec;
}

// Task 4 replaces these stubs.
function renderApprovals(d, box) {}
function renderJobs(d, box) {}
function renderAudit(d, box) {}
```

- [ ] **Step 3: Verify** — `node --check static/console.js`; pytest 156; API walk on throwaway DB: create request → review with 낮음+PII → expect 422 detail surfaced by `wbPost` contract (curl-level: confirm the 422 body has `detail`); review 중간+chat-answer → 자동화 가능.

- [ ] **Step 4: Commit** — `git commit -m "feat(ui): console workbench — detail, review form, lifecycle actions"`

---

### Task 4: Approvals, job history, per-request audit

**Files:**
- Modify: `static/console.js` (replace the three stubs)
- Modify: `static/ui.css` (append log styles)

**Interfaces:**
- Consumes: `POST /requests/{id}/approvals`, `attachSession(sid)` (app.js), `fmtTime`, detail payload `d.approvals/d.jobs/d.audit`.

- [ ] **Step 1: Append to `static/ui.css`**

```css
.logline {
  display: flex; gap: 10px; align-items: baseline;
  padding: 7px 0; font-size: 12.5px;
  border-bottom: 1px solid var(--line-soft);
  color: var(--text-2);
}
.logline:last-child { border-bottom: none; }
.logline time { font-family: var(--font-num); font-size: 11px; color: var(--text-3); white-space: nowrap; }
.logline b { color: var(--text); font-weight: 600; }
.logline .err-text { color: var(--bad); }
.ap-form { display: flex; gap: 8px; margin-top: 8px; }
.ap-form input {
  flex: 1; font-family: inherit; font-size: 12.5px; color: var(--text);
  padding: 8px 10px; border: 1px solid var(--line); border-radius: 10px; background: var(--bg);
}
```

- [ ] **Step 2: Replace the three stubs in `static/console.js`**

```js
function renderApprovals(d, box) {
  const q = d.request;
  if (q.risk_level !== '높음') return;
  const sec = el('div', 'wb-sec');
  sec.appendChild(el('div', 'sec-label', '승인 (위험도 높음)'));
  if (d.approvals.length) {
    d.approvals.forEach(function (a) {
      const line = el('div', 'logline');
      line.appendChild(el('time', null, fmtTime(a.created_at)));
      const body = el('div');
      body.appendChild(el('b', null, a.approver));
      body.appendChild(document.createTextNode(' · ' + a.status + (a.comment ? ' — ' + a.comment : '')));
      line.appendChild(body);
      sec.appendChild(line);
    });
  } else {
    sec.appendChild(el('div', 'empty', '승인 기록이 없어요. 실행하려면 승인이 필요해요.'));
  }
  const form = el('div', 'ap-form');
  const inp = el('input');
  inp.placeholder = '승인 의견';
  form.appendChild(inp);
  const ok = el('button', 'b-solid', '승인');
  ok.onclick = function () {
    wbPost(q.id, 'approvals', { approver: currentUser(), status: '승인', comment: inp.value.trim() });
  };
  form.appendChild(ok);
  const no = el('button', 'b-ghost', '반려');
  no.onclick = function () {
    wbPost(q.id, 'approvals', { approver: currentUser(), status: '반려', comment: inp.value.trim() });
  };
  form.appendChild(no);
  sec.appendChild(form);
  box.appendChild(sec);
}

function renderJobs(d, box) {
  if (!d.jobs.length) return;
  const sec = el('div', 'wb-sec');
  sec.appendChild(el('div', 'sec-label', '작업 이력'));
  d.jobs.forEach(function (j) {
    const line = el('div', 'logline');
    line.appendChild(el('time', null, fmtTime(j.started_at)));
    const body = el('div');
    body.appendChild(el('b', null, '작업 #' + j.id));
    body.appendChild(document.createTextNode(' ' + j.template_id + ' · ' + j.status));
    if (typeof j.result_location === 'string' && j.result_location.startsWith('session:')) {
      const sid = j.result_location.slice(8);
      const b = el('button', 'b-ghost', '작업 공간 열기');
      b.style.marginLeft = '8px';
      b.onclick = function () { attachSession(sid); };
      body.appendChild(b);
    }
    if (j.error_message) body.appendChild(el('div', 'err-text', j.error_message));
    if (j.detail) body.appendChild(el('div', null, j.detail));
    line.appendChild(body);
    sec.appendChild(line);
  });
  box.appendChild(sec);
}

function renderAudit(d, box) {
  if (!d.audit.length) return;
  const sec = el('div', 'wb-sec');
  sec.appendChild(el('div', 'sec-label', '감사 로그'));
  d.audit.slice(-8).forEach(function (a) {
    const line = el('div', 'logline');
    line.appendChild(el('time', null, fmtTime(a.created_at)));
    const body = el('div');
    body.appendChild(el('b', null, a.actor));
    body.appendChild(document.createTextNode(' ' + a.action + (a.detail ? ' — ' + a.detail : '')));
    line.appendChild(body);
    sec.appendChild(line);
  });
  box.appendChild(sec);
}
```

- [ ] **Step 3: Verify** — `node --check`; pytest 156; API walk (throwaway DB): PII request → review 높음 → `POST jobs` → **409 승인 필요** → `POST approvals {승인}` → 201 → `POST jobs` → 200 → detail shows job 성공 + audit rows (intake/review/approval/run) — every response snippet in the report.

- [ ] **Step 4: Commit** — `git commit -m "feat(ui): workbench approvals, job history, per-request audit"`

---

### Task 5: Catalog drawer (segment removed)

**Files:**
- Modify: `static/index.html` (delete `seg-catalog` button + whole `#v-catalog` section; add drawer markup before the scripts; unhide is JS-side)
- Modify: `static/app.js` (remove catalog code + `'catalog'` from SEGS + catalog branch in `go()`)
- Modify: `static/console.js` (append drawer + catalog rendering)
- Modify: `static/ui.css` (append drawer styles)

**Interfaces:**
- Consumes: `GET /skills`, `GET /skills/{name}`.
- Produces: `openDrawer()/closeDrawer()`, catalog render functions now living in console.js. `#drawerBtn` (Task 2 markup) becomes visible.

- [ ] **Step 1: `static/index.html`** — delete the `seg-catalog` button line and the entire `<section id="v-catalog">…</section>`; add before the first `<script>`:

```html
  <div class="drawer-overlay" id="drawerOverlay" hidden></div>
  <aside class="drawer" id="drawer" hidden aria-label="k-skill 카탈로그">
    <div class="drawer-head">
      <strong>k-skill 카탈로그</strong>
      <button class="icon-btn" id="drawerClose" title="닫기">✕</button>
    </div>
    <div class="drawer-controls">
      <input id="skill-q" type="search" placeholder="스킬 검색(이름·설명)">
      <div id="login-filters"></div>
    </div>
    <div id="skill-list"></div>
    <p id="catalog-msg" class="empty"></p>
  </aside>
```

- [ ] **Step 2: `static/app.js`** — change `const SEGS = ['counter', 'console', 'work', 'catalog'];` to `const SEGS = ['counter', 'console', 'work'];`; delete the `if (name === 'catalog' …) loadCatalog();` line from `go()`; delete ALL catalog functions and state from app.js: `_loginFilter`, `_qTimer`, `loadCatalog`, `renderLoginFilters`, `renderSkills`, `onCatalogChange` (they move to console.js, rewritten).

- [ ] **Step 3: Append drawer styles to `static/ui.css`**

```css
/* ---------- 카탈로그 드로어 ---------- */
.drawer-overlay {
  position: fixed; inset: 0; z-index: 20;
  background: rgba(13, 13, 13, .25);
}
.drawer {
  position: fixed; top: 0; right: 0; bottom: 0; z-index: 21;
  width: min(420px, 92vw);
  background: var(--bg);
  border-left: 1px solid var(--line);
  box-shadow: -12px 0 32px rgba(13, 13, 13, .08);
  padding: 18px 20px; overflow-y: auto;
}
.drawer-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; }
.drawer-head strong { font-size: 15px; }
.drawer-controls { display: flex; flex-direction: column; gap: 10px; margin-bottom: 14px; }
.drawer-controls input {
  font-family: inherit; font-size: 13px; color: var(--text);
  padding: 9px 12px; border: 1px solid var(--line); border-radius: 12px;
  background: var(--bg); outline: none; width: 100%; box-sizing: border-box;
}
.drawer-controls input:focus { border-color: var(--text-3); }
#login-filters { display: flex; gap: 6px; flex-wrap: wrap; }
.filter-chip {
  font-family: inherit; font-size: 12px; font-weight: 600; color: var(--text-2);
  background: var(--bg-sub); border: 1px solid var(--line-soft);
  border-radius: 999px; padding: 4px 12px; cursor: pointer;
}
.filter-chip.active { color: var(--btn-text); background: var(--btn); border-color: var(--btn); }
.skill-card {
  border: 1px solid var(--line); border-radius: 12px;
  padding: 12px 14px; margin-bottom: 10px; cursor: pointer;
}
.skill-card:hover { border-color: var(--text-3); }
.skill-title { font-weight: 600; font-size: 13.5px; margin-bottom: 4px; }
.skill-badges { display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 6px; }
.badge {
  font-size: 11px; font-weight: 600; padding: 2px 8px; border-radius: 999px;
  background: var(--bg-sub); color: var(--text-2); border: 1px solid var(--line-soft);
}
.badge.action { color: var(--bad); background: var(--bad-bg); border-color: transparent; }
.skill-desc { font-size: 12.5px; color: var(--text-2); }
.skill-detail { margin-top: 10px; padding-top: 10px; border-top: 1px solid var(--line-soft); }
.skill-detail .wb-field b { flex-basis: 64px; }
.skill-guide { font-size: 12.5px; color: var(--accent); }
```

- [ ] **Step 4: Append to `static/console.js`**

```js
// ---------- 카탈로그 드로어 ----------
let _loginFilter = '';
let _qTimer = null;
let _catalogLoaded = false;

function openDrawer() {
  document.getElementById('drawer').hidden = false;
  document.getElementById('drawerOverlay').hidden = false;
  if (!_catalogLoaded) { _catalogLoaded = true; loadCatalog(); }
}
function closeDrawer() {
  document.getElementById('drawer').hidden = true;
  document.getElementById('drawerOverlay').hidden = true;
}

async function loadCatalog() {
  const q = document.getElementById('skill-q').value.trim();
  const params = new URLSearchParams();
  if (q) params.set('q', q);
  if (_loginFilter) params.set('login', _loginFilter);
  const msg = document.getElementById('catalog-msg');
  msg.textContent = '';
  let data;
  try {
    const r = await fetch('/skills?' + params.toString());
    if (!r.ok) throw new Error('HTTP ' + r.status);
    data = await r.json();
  } catch (e) {
    console.error(e);
    msg.textContent = '카탈로그를 불러오지 못했어요.';
    return;
  }
  renderLoginFilters(data.logins);
  renderSkills(data.skills);
  msg.textContent = data.skills.length ? '' : '결과가 없어요.';
}

function renderLoginFilters(logins) {
  const box = document.getElementById('login-filters');
  box.replaceChildren();
  [''].concat(logins).forEach(function (lv) {
    const b = el('button', 'filter-chip' + (_loginFilter === lv ? ' active' : ''), lv || '전체');
    b.onclick = function () { _loginFilter = lv; loadCatalog(); };
    box.appendChild(b);
  });
}

function renderSkills(skills) {
  const list = document.getElementById('skill-list');
  list.replaceChildren();
  skills.forEach(function (s) {
    const card = el('div', 'skill-card');
    card.appendChild(el('div', 'skill-title', s.title));
    const badges = el('div', 'skill-badges');
    badges.appendChild(el('span', 'badge', s.login));
    if (s.action) badges.appendChild(el('span', 'badge action', '실행 시 실제 동작'));
    card.appendChild(badges);
    card.appendChild(el('div', 'skill-desc', s.description));
    if (/^https?:\/\//.test(s.guide_url || '')) {
      const a = el('a', 'skill-guide', '가이드');
      a.href = s.guide_url;
      a.target = '_blank';
      a.rel = 'noopener';
      a.onclick = function (ev) { ev.stopPropagation(); };
      card.appendChild(a);
    }
    card.onclick = function () { toggleSkillDetail(card, s.name); };
    list.appendChild(card);
  });
}

async function toggleSkillDetail(card, name) {
  const existing = card.querySelector('.skill-detail');
  if (existing) { existing.remove(); return; }
  let s;
  try {
    const r = await fetch('/skills/' + encodeURIComponent(name));
    if (!r.ok) throw new Error('HTTP ' + r.status);
    s = await r.json();
  } catch (e) {
    console.error(e);
    return;
  }
  const box = el('div', 'skill-detail');
  box.onclick = function (ev) { ev.stopPropagation(); };
  Object.keys(s).forEach(function (k) {
    const v = s[k];
    if (v == null || v === '' || typeof v === 'object') return;
    const row = el('div', 'wb-field');
    row.appendChild(el('b', null, k));
    row.appendChild(el('span', null, String(v)));
    box.appendChild(row);
  });
  card.appendChild(box);
}

document.getElementById('drawerBtn').hidden = false;
document.getElementById('drawerBtn').onclick = openDrawer;
document.getElementById('drawerClose').onclick = closeDrawer;
document.getElementById('drawerOverlay').onclick = closeDrawer;
document.getElementById('skill-q').oninput = function () {
  clearTimeout(_qTimer);
  _qTimer = setTimeout(loadCatalog, 250);
};
```

Note: `window._catalogLoaded` (old app.js flag) is gone; the new `_catalogLoaded` is module-local to console.js.

- [ ] **Step 5: Verify** — `node --check static/app.js static/console.js`(each); pytest 156; server: `curl -s http://127.0.0.1:8765/ | grep -c 'seg-catalog'` → 0, `grep -c 'drawer'` ≥ 3; `curl -s 'http://127.0.0.1:8765/skills' | head -c 200` shows skills; `curl -s http://127.0.0.1:8765/skills/$(curl -s http://127.0.0.1:8765/skills | ./.venv/bin/python -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['name'])")` → 200 JSON.

- [ ] **Step 6: Commit** — `git commit -m "feat(ui): catalog drawer in console; catalog nav segment removed"`

---

### Task 6: Delete ops.js + purge dead CSS + phase E2E

**Files:**
- Delete: `static/ops.js` (+ its script tag in index.html)
- Modify: `static/styles.css` (purge rules only the deleted markup used)

**Interfaces:** none new. After this task the JS surface is: ui.js, app.js (shell nav + chat + attachSession), counter.js, console.js.

- [ ] **Step 1: Delete `static/ops.js`** and remove `<script src="/static/ops.js"></script>` from index.html. Then grep for survivors that must NOT reference it: `grep -rn 'statusChip\|loadQueue\|openDetail\|renderJobRow\|doReview\|doApprove\|doRun\|doSimple\|_post\|esc(' static/*.js static/index.html` → expect no output (if `esc(` matches something else, inspect and report).

- [ ] **Step 2: Purge `static/styles.css`.** Delete rules for markup/classes that no longer exist anywhere (verify each with grep across static/*.js and index.html before deleting): `.two-col`, `.panel`, `.req-row`, `.req-head`, `.queue-row`, `.status-chip`, `.st-*` (7 rules), `.risk`, `.muted`, `.err`, `.ops-block`, `.job-row`, `ul.audit`, `.catalog-controls`, `#skill-q`, `.filter-chip` (both rules — re-styled in ui.css), `.skill-grid`, `.skill-card`, `.skill-title`, `.skill-badges`, `.badge*` (3), `.skill-desc`, `.skill-guide`. KEEP: `:root` vars, `*`, `body`, `.wrap`, `.uploader`, `.warn`, `.sources`, `.chat`, `.msg*`, `.cites`, `.chip`, `.askbar*` (2), and the prefers-reduced-motion block — the 작업 공간 (chat) view still uses them until Phase C. If any candidate turns out to still be referenced, keep it and report.

- [ ] **Step 3: Phase E2E (throwaway DB, all snippets in report).**
  a. High-risk path: `POST /requests` (PII true) → review 높음 → `POST jobs` → 409 승인 필요 → `POST approvals` 승인 → `POST jobs` → 200 → detail: 검수 대기, job 성공, result_location `session:` → `POST confirm` with the requester name → 완료.
  b. Hold path: new request → `POST hold` → 보류 → `POST resume` → 접수됨.
  c. 422 path: review with risk 낮음 on a PII request → 422 with Korean detail.
  d. `GET /skills` 200 and one `GET /skills/{name}` 200.
  e. `curl -s http://127.0.0.1:8765/` → contains `qBody`, `drawer`, `뚝딱 Hub`; contains NO `ops.js`, `v-catalog`, `seg-catalog`.
  f. `./.venv/bin/python -m pytest -q` → 156; `node --check` on ui.js/app.js/counter.js/console.js.

- [ ] **Step 4: Commit** — `git commit -m "refactor(ui): delete legacy ops.js; purge dead console/catalog CSS; phase B E2E"`

---

## Self-review notes

- Spec coverage (overview.md 관제실 section): stat row (T2), queue table with risk dots/PII marker/gated action (T2), workbench with review controls minus title/memo (T3 — deviation adjudicated above), approval form for 높음 (T4), job history incl. 작업 공간 열기 (T4), per-request audit (T4 — global feed deviation adjudicated), catalog drawer + card detail via /skills/{name} (T5, closes an 05-phase-3 divergence), 409/422/403 surfaced inline (wbPost/consoleError).
- Phase A deferred item resolved: fetch-rejection handling — all new fetches in console.js are try/catch-wrapped with console.error + Korean inline errors (final-review finding #2 addressed for the console; counter.js retrofit stays Phase C).
- Placeholder scan: T3 Step 2 contains an explicit instruction to omit the marker line — flagged in-text. No TBDs.
- Type consistency: `loadConsole/openWorkbench/runReq/wbPost/getTemplates/consoleError/wbError` names consistent across tasks; `riskDot/fmtTime/isToday` defined in T1 before first use in T2-4; drawer ids (`drawerBtn` in T2 markup, wired in T5) consistent.
