# 뚝딱 Hub UX Renewal — Phase C Implementation Plan (작업 공간 + 하드닝 + 다크모드)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild 작업 공간 (chat workspace) to the prompt-kit grammar with request binding, wire export downloads end-to-end (one explicit backend addition), apply the Phase A/B hardening carryovers, enable dark mode, and delete the last legacy CSS.

**Architecture:** New `static/workspace.js` owns the chat session (ported out of app.js, rewritten with ui.js builders). One backend addition — `GET /session/{sid}/export/{filename}` FileResponse with traversal guard + pytest coverage; everything else stays UI-only. After Task 5, `static/styles.css` is deleted and every screen runs on tokens.

**Tech Stack:** Vanilla JS + CSS custom properties; FastAPI (one new route); pytest for the new route.

## Global Constraints

- Repo: `apps/office-automation-hub-design/app`, branch `ux/phase-a` (continue; Phase C base = current HEAD `cc0dc02`).
- **Backend: only Task 3's download endpoint may touch `hub/`** — everything else zero-backend. Existing 156 tests stay green throughout; Task 3 adds new tests (suite grows, no existing test modified).
- Status strings and all API values byte-exact. NO innerHTML in any JS. Accent `#10a37f` discipline (running/current/evidence markers).
- UI copy Korean exactly as written here. `node --check` every touched JS file.
- User server may run on port 8000 — NEVER `pkill -f uvicorn`; use `OFFICE_HUB_DB=/tmp/hub-<task>.db OPENAI_API_KEY= OFFICE_HUB_LLM_BACKEND=codex ./.venv/bin/python -m uvicorn hub.api:create_app --factory --port 8765` and kill only that PID.
- Real-LLM chat (ask) is NOT exercised by implementers (no codex calls in verification) — deferred to human.

## Adjudicated deviations from overview.md

1. **Requesters KEEP workspace access** via 창구's "결과 채팅 열기" — overview said FDE-only, but 05's chat-answer contract makes the session the requester's deliverable (검수 대기 → requester reviews = uses the chat). Overview amended after this phase.
2. **Evidence chips expand to locator detail** (파일·위치 정보), not source excerpts — `/ask` citations carry only `{filename, locator}` (verified `hub/api/chat.py:81-83`); a true excerpt endpoint is a future backend candidate.
3. **One backend addition** (export download route) — `/export` returns a server filesystem path unreachable from a browser; without a download route the spec's export button cannot work. Explicit per overview's API-mapping rule.
4. **Standalone chat is removed**: the workspace requires an attached session (segment disabled until one exists). Phase-1's free upload+ask flow is superseded by request binding.

## API contract used (verified in `hub/api/chat.py` — Task 3 adds one route)

- `POST /session` → `{session_id}`; `GET /session/{sid}/sources` → `{sources: [{source_id, filename, kind, status, sheets?: [{name, columns, …}]}]}` (tabular sources have `sheets`; doc sources don't).
- `POST /session/{sid}/files` (multipart) → same sources shape; 400 on unsupported ext.
- `POST /session/{sid}/ask` `{question}` → `{answer, citations: [{filename, locator}], tool_calls: [name…], usage}`.
- `POST /session/{sid}/export` `{source_id, sheet?, format: "csv"|"xlsx"}` → `{path, note}`; `path` is a server path whose basename is `<source_id>.<format>` in `runs/<sid>/export/`.
- Errors `{detail}`; 404 unknown session/source.

---

### Task 1: 작업 공간 rebuild — markup, styles, workspace.js core

**Files:**
- Modify: `static/index.html` (replace the whole `<section id="v-work" hidden>…</section>`; `seg-work` button gets `disabled` + `title`; add `<script src="/static/workspace.js"></script>` after console.js)
- Modify: `static/app.js` (delete ALL chat code — moved to workspace.js)
- Modify: `static/counter.js`, `static/console.js` (one call-site each: pass request context to `attachSession`)
- Create: `static/workspace.js`
- Modify: `static/ui.css` (append workspace styles)

**Interfaces:**
- Produces: `attachSession(sid, req)` now defined in **workspace.js** (was app.js) — `req` = the request object (`{id, title, template_id, status, created_at, …}`) or `null`; `loadWorkspace()` no-op hook for `go('work')`.
- app.js after surgery keeps ONLY: `currentUser`, `SEGS`/`go`. Delete: `let sessionId`, `attachSession`, `ensureSession`, `addMsg`, the `uploadBtn`/`askBtn` handler blocks.
- `go('work')` line becomes: `if (name === 'work' && typeof loadWorkspace === 'function') loadWorkspace();`

- [ ] **Step 1: `static/index.html`** — `seg-work` button becomes:

```html
      <button id="seg-work" onclick="go('work')" disabled title="실행 중인 작업이 없어요">작업 공간</button>
```

Replace the whole v-work section with:

```html
  <!-- 작업 공간: 요청에 묶인 채팅 -->
  <section id="v-work" class="work" hidden>
    <div class="ctx" id="wCtx"></div>
    <div class="src-panel" id="wSources" hidden></div>
    <div class="thread" id="wThread"></div>
    <div class="work-composer">
      <div class="wc-inner">
        <input type="file" id="wFiles" multiple hidden>
        <button class="icon-btn" id="wAttach" title="파일 첨부">＋</button>
        <textarea id="wText" placeholder="이 작업의 파일에 대해 물어보세요"></textarea>
        <button class="send" id="wSend" title="보내기" disabled>↑</button>
      </div>
      <p class="composer-err" id="wErr" hidden></p>
    </div>
  </section>
```

And add `<script src="/static/workspace.js"></script>` after the console.js tag.

- [ ] **Step 2: `static/app.js` surgery** — delete `let sessionId = null;`, `attachSession`, `ensureSession`, `addMsg`, and the two bottom handler blocks (`document.getElementById("uploadBtn").onclick…` and `document.getElementById("askBtn").onclick…`). Change the work line in `go()` to `if (name === 'work' && typeof loadWorkspace === 'function') loadWorkspace();`. Keep `currentUser` and everything else byte-identical.

- [ ] **Step 3: Append workspace styles to `static/ui.css`**

```css
/* ---------- 작업 공간 ---------- */
.work { max-width: 760px; margin: 0 auto; padding: 0 24px 24px; display: flex; flex-direction: column; min-height: calc(100vh - 57px); }
.ctx {
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
  padding: 14px 2px; margin-bottom: 18px;
  border-bottom: 1px solid var(--line-soft);
  font-size: 12.5px; color: var(--text-2);
}
.ctx .no { font-family: var(--font-num); color: var(--text-3); }
.ctx b { color: var(--text); font-weight: 600; }
.ctx .tplchip {
  font-family: var(--font-num); font-size: 11px;
  padding: 3px 9px; border-radius: 999px;
  background: var(--bg-sub); border: 1px solid var(--line-soft);
}
.ctx .spacer { margin-left: auto; }
.src-panel { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 16px; }
.src-chip {
  display: inline-flex; align-items: center; gap: 8px;
  font-size: 12px; font-weight: 500;
  padding: 6px 12px; border-radius: 10px;
  background: var(--bg-sub); border: 1px solid var(--line-soft);
}
.src-chip .st { font-family: var(--font-num); font-size: 10.5px; color: var(--text-3); }
.src-chip button {
  font-family: inherit; font-size: 11px; font-weight: 600; color: var(--text-2);
  border: 1px solid var(--line); background: var(--bg); border-radius: 999px;
  padding: 3px 9px; cursor: pointer;
}
.src-chip button:hover { color: var(--text); border-color: var(--text-3); }
.thread { flex: 1; display: flex; flex-direction: column; gap: 20px; padding-bottom: 24px; }
.thread .empty { text-align: center; padding-top: 48px; }
.msg-user {
  align-self: flex-end; max-width: 78%;
  background: var(--bg-sub);
  padding: 11px 16px; border-radius: 20px;
  font-size: 14.5px; white-space: pre-wrap;
}
.msg-ai { max-width: 100%; font-size: 14.5px; line-height: 1.65; white-space: pre-wrap; }
.msg-meta { font-family: var(--font-num); font-size: 10.5px; color: var(--text-3); margin-top: 6px; }
.evidence { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 10px; }
.ev-chip {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 11.5px; font-weight: 500; color: var(--text-2);
  padding: 5px 11px; border-radius: 999px;
  border: 1px solid var(--line); cursor: pointer; background: var(--bg);
  font-family: var(--font-num);
}
.ev-chip:hover { border-color: var(--text); color: var(--text); }
.ev-chip i { font-style: normal; color: var(--accent); }
.ev-detail {
  width: 100%; font-size: 12px; color: var(--text-2);
  border: 1px solid var(--line-soft); border-radius: 10px;
  padding: 8px 12px; background: var(--bg-sub);
}
.work-composer { position: sticky; bottom: 0; background: var(--bg); padding: 8px 0 16px; }
.wc-inner {
  display: flex; align-items: flex-end; gap: 10px;
  border: 1px solid var(--line); border-radius: 26px;
  padding: 10px 10px 10px 8px;
  box-shadow: 0 2px 12px rgba(13, 13, 13, .05);
  background: var(--bg);
}
.wc-inner textarea {
  flex: 1; border: none; outline: none; resize: none;
  font-family: inherit; font-size: 14.5px; color: var(--text);
  background: transparent; height: 24px; padding: 6px 0; letter-spacing: inherit;
}
.wc-inner ::placeholder { color: var(--text-3); }
```

- [ ] **Step 4: Create `static/workspace.js`**

```js
// workspace.js — 작업 공간: 요청에 묶인 채팅. 서버 문자열은 el()/textContent로만.

let _wsSession = null;
let _wsReq = null;
let _wsAsking = false;

function wsError(msg) {
  const e = document.getElementById('wErr');
  e.hidden = !msg;
  e.textContent = msg || '';
}

function loadWorkspace() {
  renderCtx();
}

function renderCtx() {
  const box = document.getElementById('wCtx');
  box.replaceChildren();
  if (!_wsSession) {
    box.appendChild(el('span', 'empty', '열린 작업이 없어요. 관제실이나 창구에서 작업을 열어주세요.'));
    return;
  }
  if (_wsReq) {
    box.appendChild(el('span', 'no', receiptNo(_wsReq)));
    box.appendChild(el('b', null, _wsReq.title));
    if (_wsReq.template_id) box.appendChild(el('span', 'tplchip', _wsReq.template_id));
    const sp = el('span', 'spacer');
    sp.appendChild(statusPill(_wsReq.status));
    box.appendChild(sp);
  } else {
    box.appendChild(el('b', null, '작업 세션'));
  }
}

async function attachSession(sid, req) {
  _wsSession = sid;
  _wsReq = req || null;
  const seg = document.getElementById('seg-work');
  seg.disabled = false;
  seg.title = '';
  document.getElementById('wThread').replaceChildren(
    el('div', 'empty', '파일 근거로 질문하면 답과 근거 위치를 함께 드려요.'));
  wsError('');
  renderCtx();
  syncWsSend();
  await loadWsSources();
  go('work');
}

async function loadWsSources() {
  const panel = document.getElementById('wSources');
  if (!_wsSession) { panel.hidden = true; return; }
  let data;
  try {
    const r = await fetch('/session/' + _wsSession + '/sources');
    if (!r.ok) throw new Error('HTTP ' + r.status);
    data = await r.json();
  } catch (e) {
    console.error(e);
    wsError('파일 목록을 불러오지 못했어요.');
    return;
  }
  panel.hidden = data.sources.length === 0;
  panel.replaceChildren();
  data.sources.forEach(function (s) {
    const chip = el('span', 'src-chip', s.filename + ' ');
    chip.appendChild(el('span', 'st', s.status));
    if (s.sheets && s.sheets.length) {
      const b = el('button', null, 'xlsx로 내보내기');
      b.onclick = function () { exportSource(s.source_id); };
      chip.appendChild(b);
    }
    panel.appendChild(chip);
  });
}

async function exportSource(sourceId) {
  wsError('');
  try {
    const r = await fetch('/session/' + _wsSession + '/export', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ source_id: sourceId, format: 'xlsx' }),
    });
    if (!r.ok) {
      let detail = '';
      try { detail = (await r.json()).detail || ''; } catch (e) { /* not json */ }
      wsError('내보내기에 실패했어요' + (detail ? ': ' + detail : ' (' + r.status + ')'));
      return;
    }
    const out = await r.json();
    const name = out.path.split('/').pop();
    const a = document.createElement('a');
    a.href = '/session/' + _wsSession + '/export/' + encodeURIComponent(name);
    a.download = name;
    document.body.appendChild(a);
    a.click();
    a.remove();
  } catch (e) {
    console.error(e);
    wsError('네트워크 오류로 내보내지 못했어요.');
  }
}

function wsUserMsg(text) {
  const thread = document.getElementById('wThread');
  const empty = thread.querySelector('.empty');
  if (empty) empty.remove();
  thread.appendChild(el('div', 'msg-user', text));
}

function wsAiMsg(body) {
  const thread = document.getElementById('wThread');
  const box = el('div', 'msg-ai', body.answer);
  if (body.citations && body.citations.length) {
    const ev = el('div', 'evidence');
    body.citations.forEach(function (c) {
      const chip = el('span', 'ev-chip');
      chip.appendChild(el('i', null, '▸'));
      chip.appendChild(document.createTextNode(c.filename + ' · ' + c.locator));
      chip.onclick = function () { toggleEvDetail(ev, c); };
      ev.appendChild(chip);
    });
    box.appendChild(ev);
  }
  if (body.tool_calls && body.tool_calls.length) {
    box.appendChild(el('div', 'msg-meta', '도구: ' + body.tool_calls.join(' · ')));
  }
  thread.appendChild(box);
  return box;
}

function toggleEvDetail(evBox, c) {
  const existing = evBox.querySelector('.ev-detail');
  if (existing) { existing.remove(); return; }
  const d = el('div', 'ev-detail',
    '파일: ' + c.filename + '\n위치: ' + c.locator +
    '\n(모든 수치는 이 위치의 데이터에서 결정론 코드로 계산됐어요. 원문은 파일을 내보내 확인할 수 있어요.)');
  d.style.whiteSpace = 'pre-wrap';
  evBox.appendChild(d);
}

function syncWsSend() {
  document.getElementById('wSend').disabled =
    _wsAsking || !_wsSession || document.getElementById('wText').value.trim() === '';
}

async function wsAsk() {
  const input = document.getElementById('wText');
  const q = input.value.trim();
  if (!q || !_wsSession || _wsAsking) return;
  _wsAsking = true;
  syncWsSend();
  wsError('');
  wsUserMsg(q);
  input.value = '';
  const thread = document.getElementById('wThread');
  const wait = el('div', 'msg-ai', '…');
  thread.appendChild(wait);
  wait.scrollIntoView({ behavior: 'auto', block: 'end' });
  try {
    const r = await fetch('/session/' + _wsSession + '/ask', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ question: q }),
    });
    wait.remove();
    if (!r.ok) {
      let detail = '';
      try { detail = (await r.json()).detail || ''; } catch (e) { /* not json */ }
      wsError('답변을 받지 못했어요' + (detail ? ': ' + detail : ' (' + r.status + ')'));
      return;
    }
    const body = await r.json();
    const box = wsAiMsg(body);
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    box.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'end' });
  } catch (e) {
    console.error(e);
    wait.remove();
    wsError('네트워크 오류가 발생했어요. 잠시 후 다시 시도해 주세요.');
  } finally {
    _wsAsking = false;
    syncWsSend();
  }
}

document.getElementById('wAttach').onclick = function () {
  if (!_wsSession) { wsError('먼저 관제실이나 창구에서 작업을 열어주세요.'); return; }
  document.getElementById('wFiles').click();
};
document.getElementById('wFiles').onchange = async function (ev) {
  const files = Array.from(ev.target.files);
  ev.target.value = '';
  wsError('');
  for (const f of files) {
    const fd = new FormData();
    fd.append('file', f);
    try {
      const r = await fetch('/session/' + _wsSession + '/files', { method: 'POST', body: fd });
      if (!r.ok) {
        let detail = '';
        try { detail = (await r.json()).detail || ''; } catch (e) { /* not json */ }
        wsError(f.name + ' 업로드 실패' + (detail ? ': ' + detail : ''));
      }
    } catch (e) {
      console.error(e);
      wsError(f.name + ' 업로드 중 네트워크 오류가 발생했어요.');
    }
  }
  loadWsSources();
};
document.getElementById('wText').oninput = syncWsSend;
document.getElementById('wSend').onclick = wsAsk;
document.getElementById('wText').onkeydown = function (ev) {
  if (ev.key === 'Enter' && !ev.shiftKey && !ev.isComposing) {
    ev.preventDefault();
    wsAsk();
  }
};

renderCtx();
```

- [ ] **Step 5: Caller updates.**
  - `static/counter.js` `toggleCardDetail`: the `결과 채팅 열기` button's onclick becomes `function () { attachSession(sid, d.request); }`.
  - `static/console.js` `renderJobs`: the `작업 공간 열기` button's onclick becomes `function () { attachSession(sid, d.request); }` — note `renderJobs(d, box)` already receives `d`; use `d.request`.

- [ ] **Step 6: Verify** — `node --check` on app.js/workspace.js/counter.js/console.js; pytest 156; server: `curl -s http://127.0.0.1:8765/ | grep -c 'wThread'` → 1, `grep -c 'uploadBtn'` → 0; grep `-n 'sessionId\|ensureSession\|addMsg' static/app.js` → empty. Dangling ids: every getElementById in workspace.js exists in the new markup.

- [ ] **Step 7: Commit** — `git commit -m "feat(ui): workspace rebuilt — request-bound chat, prompt-kit thread, sources panel"`

---

### Task 2: Export download endpoint (backend, TDD)

**Files:**
- Test: `tests/test_api_chat_export_download.py` (new)
- Modify: `hub/api/chat.py` (one route)

**Interfaces:**
- Produces: `GET /session/{session_id}/export/{filename}` → FileResponse (Content-Disposition attachment) / 404 unknown session, missing file, or traversal attempt. Consumed by Task 1's `exportSource`.

- [ ] **Step 1: Write the failing tests** (follow the existing chat API test file's fixture pattern — find it via `grep -rln "def test.*export" tests/` and mirror its client/session setup; no LLM, no network):

```python
def test_export_download_roundtrip(client_with_csv_session):
    client, sid, source_id = client_with_csv_session
    r = client.post(f"/session/{sid}/export", json={"source_id": source_id, "format": "csv"})
    assert r.status_code == 200
    name = r.json()["path"].rsplit("/", 1)[-1]
    dl = client.get(f"/session/{sid}/export/{name}")
    assert dl.status_code == 200
    assert "attachment" in dl.headers["content-disposition"]
    assert dl.content  # non-empty file body


def test_export_download_missing_file_404(client_with_csv_session):
    client, sid, _ = client_with_csv_session
    assert client.get(f"/session/{sid}/export/nope.csv").status_code == 404


def test_export_download_unknown_session_404(client_with_csv_session):
    client, _, _ = client_with_csv_session
    assert client.get("/session/no-such/export/a.csv").status_code == 404


def test_export_download_traversal_404(client_with_csv_session):
    client, sid, source_id = client_with_csv_session
    client.post(f"/session/{sid}/export", json={"source_id": source_id, "format": "csv"})
    assert client.get(f"/session/{sid}/export/..%2F..%2Finput%2Fanything").status_code == 404
```

(`client_with_csv_session` — build it in this file as a fixture mirroring the existing chat test setup: create app with tmp runs dir + stub LLM factory, POST /session, upload a small csv via POST files. Adapt names to whatever the existing tests use; the four behaviors above are the requirement.)

- [ ] **Step 2: Run to verify they fail** — `./.venv/bin/python -m pytest tests/test_api_chat_export_download.py -q` → 4 failed (404 route missing → likely 404 vs 405 differences; the roundtrip test MUST fail).

- [ ] **Step 3: Implement the route** in `hub/api/chat.py` (after the `export` route; `FileResponse` is already imported in `hub/api/__init__.py` — import it here from `fastapi.responses`):

```python
    @r.get("/session/{session_id}/export/{filename}")
    def export_download(session_id: str, filename: str):
        _require_session(session_id)
        out_dir = (Path(runs_dir) / session_id / "export").resolve()
        target = (out_dir / filename).resolve()
        if target.parent != out_dir or not target.is_file():
            raise HTTPException(404, "내보낸 파일을 찾을 수 없습니다")
        return FileResponse(target, filename=filename)
```

- [ ] **Step 4: Run the new tests then the whole suite** — new file 4 passed; `./.venv/bin/python -m pytest -q` → 160 passed (156 + 4).

- [ ] **Step 5: Commit** — `git commit -m "feat(api): export file download route with traversal guard"`

---

### Task 3: Hardening sweep (Phase A/B carryovers)

**Files:**
- Modify: `static/counter.js`, `static/console.js`

All changes below, exactly:

- [ ] **Step 1: counter.js fetch-rejection handling.** Wrap the network calls in `loadMyRequests`, `toggleCardDetail`, `confirmMine`, `reworkMine` in try/catch: catch does `console.error(e)` and (for loadMyRequests) renders the existing retry empty-state; for the other three calls `composerError('네트워크 오류가 발생했어요. 잠시 후 다시 시도해 주세요.')`. Keep bodies otherwise identical.

- [ ] **Step 2: counter.js 이름없음 gate.** `syncSend` becomes:

```js
function syncSend() {
  document.getElementById('cSend').disabled =
    _submitting || currentUser() === '이름없음'
    || document.getElementById('cText').value.trim() === '';
}
```

And the top-bar name input must re-sync it: in `static/index.html` the `#userName` onchange becomes:

```html
             onchange="if (typeof loadMyRequests === 'function') loadMyRequests(); if (typeof syncSend === 'function') syncSend()">
```

Add under the composer hint (index.html, after the `.hint` p): nothing — instead change the hint text itself to:

```html
    <p class="hint">오른쪽 위에 이름을 입력하고 제출하면 접수번호가 발급돼요. 담당자 검토 후 진행 상황을 알려드려요.</p>
```

- [ ] **Step 3: In-flight guards for detail toggles.** In `counter.js` `toggleCardDetail` and `console.js` `toggleSkillDetail`: add a busy-marker so a second click during fetch is ignored —

```js
  if (card.dataset.busy) return;
  card.dataset.busy = '1';
```

right after the `existing` early-return, and `delete card.dataset.busy;` in a `finally` (wrap the fetch/render part in try/finally; on fetch failure also `console.error(e)` and, for toggleSkillDetail, set `document.getElementById('catalog-msg').textContent = '상세를 불러오지 못했어요.';`).

- [ ] **Step 4: console.js `getTemplates` shape guard.** After parsing: `if (r.ok) { const body = await r.json(); if (Array.isArray(body.templates)) _tmplCache = body.templates; }` (replaces the current assignment).

- [ ] **Step 5: console.js conErr recovery clear.** In `loadConsole`, after a successful fetch+parse (right before `renderStats(items);`) add `consoleError('');` — clears a stale fetch-failure banner once the queue recovers (action-entry clears remain as-is).

- [ ] **Step 6: runReq error routing.** In `runReq`, replace both `consoleError(...)` calls with:

```js
      (_selReq === id ? wbError : consoleError)(…same message…);
```

(the run may be triggered from the queue row of an unselected request — keep console banner for that case).

- [ ] **Step 7: Verify** — `node --check` both files; pytest 160; manual-level curl impossible for these — instead grep-verify each change landed (`grep -c 'dataset.busy' static/counter.js static/console.js` → 1 each; `grep -c "이름없음" static/counter.js` → 2) and report. Browser checks deferred-to-human.

- [ ] **Step 8: Commit** — `git commit -m "fix(ui): hardening sweep — fetch rejections, name gate, double-click guards, template shape, error routing"`

---

### Task 4: Dark mode + styles.css deletion + docs

**Files:**
- Modify: `static/tokens.css` (dark block), `static/index.html` (drop styles.css link), `README.md`, `CLAUDE.md`
- Delete: `static/styles.css`

- [ ] **Step 1: Delete `static/styles.css`** and its `<link>` from index.html. First verify nothing needs it: `grep -o 'class="[^"]*"' static/index.html | sort -u` plus each JS file's class strings — every class must exist in ui.css (the chat view was rebuilt in Task 1; `.wrap/.uploader/.chat/.msg/.cites/.chip/.askbar/.warn/.sources` must be GONE from markup/JS — if any remains, STOP and report).

- [ ] **Step 2: Dark tokens.** In `static/tokens.css` replace the header comment (drop "Light only in Phase A" note) and append:

```css
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #212121;
    --bg-sub: #2a2a2e;
    --bg-hover: #313136;
    --line: #3a3a40;
    --line-soft: #333338;
    --text: #ececec;
    --text-2: #b4b4bd;
    --text-3: #7c7c86;
    --btn: #ececec;
    --btn-text: #212121;
    --ok-bg: #1d3630;
    --warn: #d99a4e;
    --warn-bg: #3a2f1c;
    --bad: #e08b8b;
    --bad-bg: #3d2626;
    --shadow-seg: 0 1px 3px rgba(0, 0, 0, .4);
  }
}
```

And add `color-scheme: light dark;` to the base `:root` block.

- [ ] **Step 3: Docs.** `README.md`: title → `# 뚝딱 Hub — 부서 업무자동화 허브`; update 한계 section — export UI는 이제 동작(다운로드 라우트 추가), 근거 칩은 위치 정보 표시(원문 발췌·스트리밍·비용 기록은 미지원). `CLAUDE.md`(app): 구조 줄에 `hub/api(라우터)` 뒤 static 구성 한 줄 추가 — `static: tokens/ui.css + ui/app/counter/console/workspace.js (빌드 없음, 서버문자열은 createElement/textContent)`.

- [ ] **Step 4: Verify** — pytest 160; server: `curl -s http://127.0.0.1:8765/ | grep -c 'styles.css'` → 0; `curl -s http://127.0.0.1:8765/static/tokens.css | grep -c 'prefers-color-scheme'` → 1. Dark rendering itself → deferred-to-human (macOS 다크모드 토글).

- [ ] **Step 5: Commit** — `git commit -m "feat(ui): dark theme tokens; drop legacy styles.css; docs refreshed"`

---

### Task 5: Phase E2E

No file changes expected (fixes only if E2E exposes a defect — report first).

- [ ] **Step 1: Full walk on throwaway DB** (`/tmp/hub-c-e2e.db`, port 8765): intake(컴포저 payload, PII) → review 중간 chat-answer → run → job 성공 `session:<sid>` → `GET /session/<sid>/sources` shows the request's files → `POST export` (csv) → `GET /session/<sid>/export/<name>` → 200 attachment → confirm → 완료. Include snippets.
- [ ] **Step 2: Markup sanity** — `curl -s http://127.0.0.1:8765/` contains `wThread`/`뚝딱 Hub`, NOT `styles.css`/`uploadBtn`/`ops.js`. `node --check` all 5 JS files. pytest 160.
- [ ] **Step 3: Commit only if fixes were needed** (message per fix), else record "no changes".

---

## Self-review notes

- Overview 작업 공간 section coverage: context strip (T1 renderCtx), prompt-kit thread (T1), evidence chips clickable (T1 — locator detail per deviation #2), export button wired end-to-end (T1 UI + T2 backend), composer pill sticky + attach (T1), segment disabled until session (T1), requester access kept (deviation #1). Carryover hardening (T3) covers every item named in phase-B.md's amendments. Dark mode + tokens-only CSS (T4) closes Phase A deviation #1 and #4.
- 05 phase-3 divergence status after this phase: export ✅, catalog detail ✅ (B), evidence chips ✅ (as locator detail — excerpt endpoint stays open). SSE streaming stays out (05 decision).
- Enter-to-send uses `isComposing` guard for Korean IME — deliberate.
- Type consistency: `attachSession(sid, req)` new signature — both callers updated in T1 Step 5; `loadWorkspace` guarded in go() same pattern as loadMyRequests/loadConsole.
- Task 2 is genuine TDD (failing tests first); suite grows 156→160, existing tests untouched.
