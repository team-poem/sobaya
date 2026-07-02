# Office Hub Renewal — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the operational hub domain (request intake → FDE review → risk-gated execution → requester confirm, all persisted and audited) around the existing chat-answer engine, restructured into `hub/core` + `hub/llm` + `hub/api` + `hub/ops`.

**Architecture:** The proven deterministic engine moves (behavior-preserving) under `hub/core/` and `hub/llm/`; the monolithic `api.py` becomes an `api/` package of routers. A new `hub/ops/` domain owns Request/Job/Approval/AuditLog dataclasses, a stdlib-`sqlite3` store, a pure status state machine, and a template runner registry whose first runner wraps the existing chat slice. The static UI is rebuilt with 요청/운영/채팅/카탈로그 tabs and a role switcher (no auth).

**Tech Stack:** Python 3.12, FastAPI, stdlib sqlite3 (no ORM), openpyxl/pandas (existing), vanilla JS/CSS (existing token system).

## Global Constraints

- Working directory for ALL commands: `/Users/amazon/lunch.cancelled/sobaya/apps/office-automation-hub-design/app` (own git repo — commit there, not in sobaya root).
- Test command (venv REQUIRED, never global python): `./.venv/bin/python -m pytest -q`
- Tests make ZERO real LLM/network/subprocess calls — stub injection only (existing convention).
- All numbers/values come from deterministic code; LLM decides structure/interpretation only (core invariant — do not weaken).
- Exact Korean domain strings (copy verbatim, these are API values, not just labels):
  - Request statuses: `접수됨` `검토 중` `자동화 가능` `실행 중` `검수 대기` `완료` `보류`
  - Risk levels: `낮음` `중간` `높음`
  - Job statuses: `실행 중` `성공` `실패`
  - Approval statuses: `승인` `반려`
- `data/catalog.json` is generated — never hand-edit.
- UI copy is Korean; code identifiers/comments follow existing style (Korean comments OK).
- The existing ~90 tests must pass after every task.

---

### Task 1: Package restructure — engine → `hub/core` + `hub/llm`, api.py → `hub/api/`

Everything moves with `git mv`; only import paths and one `Path` depth change. Two zero-risk cleanups ride along (dead `group_by` param, stale comment). Table-heading context threading and dispatcher changes are explicitly DEFERRED to phase 3 (needs kordoc output structure verification first, per app CLAUDE.md).

**Files:**
- Move: `hub/{models,ingest,tools,raw_extract,normalize_spec,exporter,fanout,dispatcher}.py` → `hub/core/`
- Move: `hub/workers/` → `hub/core/workers/`
- Move: `hub/{orchestrator,codex_client,text_llm,prompts}.py` → `hub/llm/`
- Move: `hub/api.py` → `hub/api/__init__.py`
- Create: `hub/core/__init__.py`, `hub/llm/__init__.py` (empty)
- Stay put: `hub/session.py`, `hub/runlog.py`, `hub/config.py`, `hub/catalog.py`
- Modify: every `hub/**.py`, `tests/**.py`, `scripts/**.py` that imports moved modules
- Test: existing suite (no new tests except one strengthened assertion)

**Interfaces:**
- Consumes: current module layout.
- Produces: import paths `hub.core.models`, `hub.core.ingest`, `hub.core.tools`, `hub.core.raw_extract`, `hub.core.normalize_spec`, `hub.core.exporter`, `hub.core.fanout`, `hub.core.dispatcher`, `hub.core.workers.*`, `hub.llm.orchestrator`, `hub.llm.codex_client`, `hub.llm.text_llm`, `hub.llm.prompts`. `hub.api.create_app`, `hub.session`, `hub.runlog`, `hub.config`, `hub.catalog` unchanged. All later tasks import via these paths.

- [ ] **Step 1: Baseline — confirm suite is green before touching anything**

Run: `./.venv/bin/python -m pytest -q`
Expected: all pass (≈90 tests). If not, STOP and report — do not restructure on a red base.

- [ ] **Step 2: Strengthen the index test (it currently can't catch a broken STATIC_DIR)**

In `tests/test_api.py`, replace `test_index_served`:

```python
def test_index_served():
    app = create_app(llm_factory=_factory)
    client = TestClient(app)
    r = client.get("/")
    assert r.status_code == 200
    assert b"<!doctype" in r.content.lower()  # 실제 index.html이 서빙되는지 (JSON 폴백이면 실패)
```

Run: `./.venv/bin/python -m pytest -q tests/test_api.py::test_index_served`
Expected: PASS (static exists today; this guards Step 4's path change).

- [ ] **Step 3: Move files with git mv**

```bash
mkdir -p hub/core hub/llm hub/api
git mv hub/models.py hub/ingest.py hub/tools.py hub/raw_extract.py hub/normalize_spec.py hub/exporter.py hub/fanout.py hub/dispatcher.py hub/core/
git mv hub/workers hub/core/workers
git mv hub/orchestrator.py hub/codex_client.py hub/text_llm.py hub/prompts.py hub/llm/
git mv hub/api.py hub/api/__init__.py
touch hub/core/__init__.py hub/llm/__init__.py
git add hub/core/__init__.py hub/llm/__init__.py
```

- [ ] **Step 4: Rewrite import paths everywhere (BSD sed on macOS)**

```bash
LC_ALL=C find hub tests scripts -name '*.py' -print0 | xargs -0 sed -i '' \
  -e 's/hub\.models/hub.core.models/g' \
  -e 's/hub\.ingest/hub.core.ingest/g' \
  -e 's/hub\.tools/hub.core.tools/g' \
  -e 's/hub\.raw_extract/hub.core.raw_extract/g' \
  -e 's/hub\.normalize_spec/hub.core.normalize_spec/g' \
  -e 's/hub\.exporter/hub.core.exporter/g' \
  -e 's/hub\.fanout/hub.core.fanout/g' \
  -e 's/hub\.dispatcher/hub.core.dispatcher/g' \
  -e 's/hub\.workers/hub.core.workers/g' \
  -e 's/hub\.orchestrator/hub.llm.orchestrator/g' \
  -e 's/hub\.codex_client/hub.llm.codex_client/g' \
  -e 's/hub\.text_llm/hub.llm.text_llm/g' \
  -e 's/hub\.prompts/hub.llm.prompts/g' \
  -e 's/from hub import tools/from hub.core import tools/g'
```

Then in `hub/api/__init__.py` fix the base-dir depth (file moved one level deeper):

```python
BASE_DIR = Path(__file__).resolve().parent.parent.parent   # was .parent.parent
```

Sanity grep — expect ZERO hits:

```bash
grep -rn "hub\.\(models\|ingest\|tools\|raw_extract\|normalize_spec\|exporter\|fanout\|dispatcher\|workers\|orchestrator\|codex_client\|text_llm\|prompts\)\b" hub tests scripts | grep -v "hub\.core\|hub\.llm"
grep -rn "from hub import" hub tests scripts
```

- [ ] **Step 5: Zero-risk cleanups**

In `hub/core/tools.py` — `query_rows` signature: delete the `group_by: list[str] | None = None,` parameter (it is referenced nowhere in the function body and not exposed in TOOL_SCHEMAS). In `dispatch_tool`, delete the line `group_by=args.get("group_by"),`. Verify: `grep -n group_by hub/core/tools.py` → 0 hits.

In `hub/core/normalize_spec.py` delete the stale comment line (the function below it is fully implemented):

```python
    # row_ops 는 Task 4에서 추가됨 (지금은 통과만)
```

- [ ] **Step 6: Full suite green**

Run: `./.venv/bin/python -m pytest -q`
Expected: all pass, same count as Step 1. `test_index_served` proves STATIC_DIR still resolves.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: restructure engine into hub/core + hub/llm, api.py -> hub/api pkg"
```

---

### Task 2: Split `hub/api/__init__.py` into routers + shared upload helper + `GET /session/{id}/sources`

**Files:**
- Create: `hub/api/uploads.py`, `hub/api/chat.py`, `hub/api/catalog.py`
- Modify: `hub/api/__init__.py` (becomes thin `create_app`), `hub/core/ingest.py` (gains `TABULAR_EXT`)
- Test: `tests/test_api_sources.py` (new); existing `tests/test_api.py`, `tests/test_api_skills.py` unchanged and passing

**Interfaces:**
- Consumes: Task 1 paths; `SourceRegistry`, `load_config`, `tools.list_sources`.
- Produces:
  - `hub.core.ingest.TABULAR_EXT: set[str]` = `{".xlsx", ".xlsm", ".csv"}` (moved from api)
  - `hub.api.uploads.read_validated(file: UploadFile, max_mb: int) -> tuple[str, bytes]` — returns (safe_name, data) or raises HTTPException(400/413); validates basename, extension against `TABULAR_EXT | DOC_EXT`, size.
  - `hub.api.chat.chat_router(reg, cfg, factory, text_factory, runs_dir) -> APIRouter` — all `/session*` routes incl. new `GET /session/{session_id}/sources` returning `tools.list_sources(...)`.
  - `hub.api.catalog.catalog_router(catalog) -> APIRouter` — `/skills`, `/skills/{name}`.
  - `hub.api.create_app(llm_factory=None, text_factory=None, catalog_path=None, runs_dir="runs")` — same signature/behavior as today.

- [ ] **Step 1: Write the failing test**

`tests/test_api_sources.py`:

```python
import io

from fastapi.testclient import TestClient
from openpyxl import Workbook

from hub.api import create_app


def _xlsx_bytes():
    wb = Workbook(); ws = wb.active; ws.title = "신청"
    ws.append(["학번", "학과"]); ws.append([1, "디자인"])
    buf = io.BytesIO(); wb.save(buf); return buf.getvalue()


def test_get_sources_lists_uploaded_files(tmp_path):
    app = create_app(llm_factory=lambda cfg: None, runs_dir=str(tmp_path),
                     text_factory=lambda cfg: (lambda system, user: "{}"))
    client = TestClient(app)
    sid = client.post("/session").json()["session_id"]
    client.post(f"/session/{sid}/files",
                files={"file": ("a.xlsx", _xlsx_bytes(),
                       "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")})
    r = client.get(f"/session/{sid}/sources")
    assert r.status_code == 200
    assert r.json()["sources"][0]["filename"] == "a.xlsx"


def test_get_sources_unknown_session():
    app = create_app(llm_factory=lambda cfg: None,
                     text_factory=lambda cfg: (lambda system, user: "{}"))
    client = TestClient(app)
    assert client.get("/session/nope/sources").status_code == 404
```

- [ ] **Step 2: Run it — expect FAIL**

Run: `./.venv/bin/python -m pytest -q tests/test_api_sources.py`
Expected: FAIL (405/404 — route doesn't exist).

- [ ] **Step 3: Implement the split**

Add to `hub/core/ingest.py` (top, near `DOC_EXT`):

```python
TABULAR_EXT = {".xlsx", ".xlsm", ".csv"}
```

`hub/api/uploads.py`:

```python
from __future__ import annotations

from pathlib import Path

from fastapi import HTTPException, UploadFile

from hub.core.ingest import DOC_EXT, TABULAR_EXT


async def read_validated(file: UploadFile, max_mb: int) -> tuple[str, bytes]:
    """파일명/확장자/크기 검증 후 (안전한 파일명, 내용) 반환. 실패 시 HTTPException."""
    safe_name = Path(file.filename or "").name
    if not safe_name or safe_name in {".", ".."}:
        raise HTTPException(400, "잘못된 파일명")
    ext = Path(safe_name).suffix.lower()
    if ext not in TABULAR_EXT and ext not in DOC_EXT:
        raise HTTPException(400, f"지원하지 않는 형식: {ext}")
    limit = max_mb * 1024 * 1024
    if file.size is not None and file.size > limit:
        raise HTTPException(413, f"파일이 너무 큽니다 (최대 {max_mb}MB)")
    data = await file.read()
    if len(data) > limit:
        raise HTTPException(413, f"파일이 너무 큽니다 (최대 {max_mb}MB)")
    return safe_name, data
```

`hub/api/chat.py` — move the `/session*` endpoints verbatim from `__init__.py` into a router factory, replacing the inline validation with the helper and adding the sources route:

```python
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from hub.api.uploads import read_validated
from hub.core.exporter import export_csv, export_xlsx
from hub.core.fanout import normalize_session
from hub.core.ingest import DOC_EXT, TABULAR_EXT, UnsupportedFile, load_document, load_tabular
from hub.core import tools
from hub.llm.orchestrator import run_turn
from hub.runlog import log_turn
from hub.session import SessionNotFound, SourceNotFound


class AskBody(BaseModel):
    question: str


class ExportBody(BaseModel):
    source_id: str
    sheet: str | None = None
    format: str = "csv"


def chat_router(reg, cfg, factory, text_factory, runs_dir: str) -> APIRouter:
    r = APIRouter()
    turn_counter: dict[str, int] = {}

    def _require_session(session_id: str):
        try:
            return reg.get_sources(session_id)
        except SessionNotFound:
            raise HTTPException(404, "세션을 찾을 수 없습니다")

    @r.post("/session")
    def create_session():
        return {"session_id": reg.create_session()}

    @r.get("/session/{session_id}/sources")
    def sources(session_id: str):
        _require_session(session_id)
        return tools.list_sources(reg, session_id)

    @r.post("/session/{session_id}/files")
    async def upload(session_id: str, file: UploadFile = File(...)):
        _require_session(session_id)
        safe_name, data = await read_validated(file, cfg.max_upload_mb)
        in_dir = Path(runs_dir) / session_id / "input"
        in_dir.mkdir(parents=True, exist_ok=True)
        dest = in_dir / safe_name
        dest.write_bytes(data)
        sid = reg.next_source_id(session_id)
        ext = dest.suffix.lower()
        try:
            if ext in TABULAR_EXT:
                reg.add_source(session_id, load_tabular(str(dest), sid))
            elif ext in DOC_EXT:
                reg.add_source(session_id, load_document(str(dest), sid))
            else:
                raise UnsupportedFile(ext)  # 방어적; read_validated에서 이미 걸러짐
        except UnsupportedFile as exc:
            raise HTTPException(400, f"지원하지 않는 형식: {exc}")
        return tools.list_sources(reg, session_id)

    @r.post("/session/{session_id}/ask")
    def ask(session_id: str, body: AskBody):
        srcs = _require_session(session_id)
        if any(reg.get_status(session_id, s.source_id) == "raw" for s in srcs):
            normalize_session(reg, session_id, text_factory(cfg))
        llm = factory(cfg)
        result = run_turn(body.question, reg, session_id, llm,
                          max_iters=cfg.max_tool_iters, max_sample_rows=cfg.max_sample_rows)
        turn_counter[session_id] = turn_counter.get(session_id, 0) + 1
        log_turn(runs_dir, session_id, turn_counter[session_id], body.question, result,
                 model=cfg.openai_model, ts=datetime.now(timezone.utc).isoformat())
        return JSONResponse({"answer": result.text, "citations": result.citations,
                             "tool_calls": [t["name"] for t in result.trace],
                             "usage": result.usage})

    @r.post("/session/{session_id}/normalize")
    def normalize(session_id: str):
        srcs = _require_session(session_id)
        if any(reg.get_status(session_id, s.source_id) == "raw" for s in srcs):
            normalize_session(reg, session_id, text_factory(cfg))
        return {"statuses": {s.source_id: reg.get_status(session_id, s.source_id)
                             for s in reg.get_sources(session_id)}}

    @r.post("/session/{session_id}/export")
    def export(session_id: str, body: ExportBody):
        try:
            tsrc = reg.resolve_tabular(session_id, body.source_id)
        except (SessionNotFound, SourceNotFound):
            raise HTTPException(404, "소스를 찾을 수 없습니다")
        status = reg.get_status(session_id, body.source_id)
        note = "정규화 안 됨/원본 그대로" if status == "raw_fallback" else ""
        out_dir = Path(runs_dir) / session_id / "export"
        out_dir.mkdir(parents=True, exist_ok=True)
        sheets = (tsrc.sheets if body.sheet is None
                  else [s for s in tsrc.sheets if s.name == body.sheet])
        if not sheets:
            raise HTTPException(400, "대상 시트 없음")
        if body.format == "xlsx":
            path = export_xlsx(sheets, str(out_dir / f"{body.source_id}.xlsx"), note=note)
        else:
            path = export_csv(sheets[0], str(out_dir / f"{body.source_id}.csv"), note=note)
        return {"path": path, "note": note}

    return r
```

`hub/api/catalog.py`:

```python
from __future__ import annotations

from fastapi import APIRouter, HTTPException

from hub.catalog import facets, filter_skills, get_skill


def catalog_router(catalog) -> APIRouter:
    r = APIRouter()

    @r.get("/skills")
    def list_skills(q: str | None = None, login: str | None = None):
        if catalog is None:
            raise HTTPException(500, "카탈로그가 준비되지 않았습니다")
        items = filter_skills(catalog, q=q, login=login)
        return {**facets(catalog),
                "skill_count": len(items), "total": len(catalog["skills"]),
                "skills": items}

    @r.get("/skills/{name}")
    def skill_detail(name: str):
        if catalog is None:
            raise HTTPException(500, "카탈로그가 준비되지 않았습니다")
        s = get_skill(catalog, name)
        if s is None:
            raise HTTPException(404, "스킬을 찾을 수 없습니다")
        return s

    return r
```

`hub/api/__init__.py` becomes:

```python
from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from hub.api.catalog import catalog_router
from hub.api.chat import chat_router
from hub.catalog import load_catalog
from hub.config import load_config
from hub.llm.orchestrator import OpenAIClient
from hub.llm.text_llm import text_llm_factory
from hub.session import SourceRegistry

BASE_DIR = Path(__file__).resolve().parent.parent.parent
STATIC_DIR = BASE_DIR / "static"


def _default_factory(cfg):
    backend = cfg.llm_backend
    use_openai = backend == "openai" or (backend == "auto" and cfg.openai_api_key)
    if use_openai:
        if not cfg.openai_api_key:
            raise HTTPException(500, "OPENAI_API_KEY가 설정되지 않았습니다")
        return OpenAIClient(cfg.openai_model, cfg.openai_api_key)
    from hub.llm.codex_client import CodexCliClient
    return CodexCliClient(model=cfg.openai_model)


def create_app(llm_factory=None, text_factory=None, catalog_path=None,
               runs_dir: str = "runs") -> FastAPI:
    app = FastAPI(title="업무자동화 허브")
    cfg = load_config()
    reg = SourceRegistry()
    factory = llm_factory or _default_factory
    _text_factory = text_factory or text_llm_factory

    try:
        _catalog = load_catalog(catalog_path or "data/catalog.json")
    except Exception:
        _catalog = None

    app.include_router(chat_router(reg, cfg, factory, _text_factory, runs_dir))
    app.include_router(catalog_router(_catalog))

    @app.get("/")
    def index():
        idx = STATIC_DIR / "index.html"
        if idx.exists():
            return FileResponse(idx)
        return JSONResponse({"status": "ok"})

    if STATIC_DIR.exists():
        app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
    return app
```

- [ ] **Step 4: Full suite green**

Run: `./.venv/bin/python -m pytest -q`
Expected: all pass including the 2 new tests. Existing test_api.py must pass UNCHANGED (proves the split preserved behavior).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: split api into chat/catalog routers, shared upload validation, GET /session/{id}/sources"
```

---

### Task 3: `hub/ops` domain models + SQLite store

**Files:**
- Create: `hub/ops/__init__.py` (empty), `hub/ops/models.py`, `hub/ops/store.py`
- Test: `tests/test_ops_store.py`

**Interfaces:**
- Consumes: nothing app-specific (stdlib only).
- Produces (later tasks depend on these exact names):
  - `hub.ops.models`: `REQUEST_STATUSES: list[str]`, `RISK_LEVELS: list[str]`, `JOB_STATUSES: list[str]`, `APPROVAL_STATUSES: list[str]`, dataclasses `Request`, `Job`, `Approval`, `AuditEntry` (fields as in code below), each with `.as_dict()`.
  - `hub.ops.store`: `RequestNotFound(Exception)`, `JobNotFound(Exception)`, class `OpsStore(db_path, now=None)` with methods `create_request(Request) -> Request`, `get_request(int) -> Request`, `list_requests(requester=None, status=None) -> list[Request]`, `update_request(request_id, **fields) -> Request`, `create_job(Job) -> Job`, `get_job(int) -> Job`, `update_job(job_id, **fields) -> Job`, `list_jobs(request_id) -> list[Job]`, `create_approval(Approval) -> Approval`, `list_approvals(request_id) -> list[Approval]`, `add_audit(actor, action, target_type, target_id, detail="") -> AuditEntry`, `list_audit(target_type=None, target_id=None) -> list[AuditEntry]`.

- [ ] **Step 1: Write the failing tests**

`tests/test_ops_store.py`:

```python
import pytest

from hub.ops.models import Approval, Job, Request
from hub.ops.store import JobNotFound, OpsStore, RequestNotFound


def _store(tmp_path):
    ticks = iter(f"2026-07-02T00:00:{i:02d}+00:00" for i in range(60))
    return OpsStore(tmp_path / "hub.db", now=lambda: next(ticks))


def _req(**kw):
    base = dict(requester_name="김선생", title="신청자 취합", contains_personal_data=True)
    base.update(kw)
    return Request(**base)


def test_request_roundtrip_and_defaults(tmp_path):
    st = _store(tmp_path)
    r = st.create_request(_req())
    assert r.id == 1 and r.status == "접수됨" and r.created_at and r.updated_at
    got = st.get_request(1)
    assert got.title == "신청자 취합"
    assert got.contains_personal_data is True          # sqlite 0/1 -> bool 복원
    assert got.requires_external_login is False


def test_get_request_not_found(tmp_path):
    with pytest.raises(RequestNotFound):
        _store(tmp_path).get_request(99)


def test_list_requests_filters_and_order(tmp_path):
    st = _store(tmp_path)
    st.create_request(_req(requester_name="김선생", title="a"))
    st.create_request(_req(requester_name="박선생", title="b"))
    st.update_request(2, status="검토 중")
    assert [r.title for r in st.list_requests()] == ["b", "a"]      # 최신 먼저
    assert [r.title for r in st.list_requests(requester="김선생")] == ["a"]
    assert [r.title for r in st.list_requests(status="검토 중")] == ["b"]


def test_update_request_stamps_updated_at_and_rejects_bad_field(tmp_path):
    st = _store(tmp_path)
    r = st.create_request(_req())
    r2 = st.update_request(r.id, status="검토 중", risk_level="중간")
    assert r2.status == "검토 중" and r2.risk_level == "중간"
    assert r2.updated_at > r.updated_at
    with pytest.raises(ValueError):
        st.update_request(r.id, evil="1; DROP TABLE requests")


def test_job_roundtrip(tmp_path):
    st = _store(tmp_path)
    r = st.create_request(_req())
    j = st.create_job(Job(request_id=r.id, template_id="chat-answer", status="실행 중",
                          started_at="t0"))
    j2 = st.update_job(j.id, status="성공", finished_at="t1", result_location="session:abc")
    assert st.get_job(j.id).result_location == "session:abc"
    assert [x.id for x in st.list_jobs(r.id)] == [j2.id]
    with pytest.raises(JobNotFound):
        st.get_job(999)


def test_approvals_and_audit(tmp_path):
    st = _store(tmp_path)
    r = st.create_request(_req())
    st.create_approval(Approval(request_id=r.id, approver="부장", status="승인", comment="ok"))
    assert st.list_approvals(r.id)[0].status == "승인"
    st.add_audit("김선생", "request_submitted", "request", r.id)
    st.add_audit("FDE", "request_reviewed", "request", r.id, detail="위험도 중간")
    rows = st.list_audit(target_type="request", target_id=r.id)
    assert [a.action for a in rows] == ["request_submitted", "request_reviewed"]
```

- [ ] **Step 2: Run — expect FAIL**

Run: `./.venv/bin/python -m pytest -q tests/test_ops_store.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'hub.ops'`.

- [ ] **Step 3: Implement models**

`hub/ops/models.py`:

```python
from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any

REQUEST_STATUSES = ["접수됨", "검토 중", "자동화 가능", "실행 중", "검수 대기", "완료", "보류"]
RISK_LEVELS = ["낮음", "중간", "높음"]
JOB_STATUSES = ["실행 중", "성공", "실패"]
APPROVAL_STATUSES = ["승인", "반려"]


@dataclass
class Request:
    requester_name: str
    title: str
    id: int | None = None
    department: str = ""
    description: str = ""
    input_location: str = ""
    output_format: str = ""
    repeat_cycle: str = ""
    due_at: str = ""
    contains_personal_data: bool = False
    requires_external_login: bool = False
    human_check_point: str = ""
    status: str = "접수됨"
    risk_level: str | None = None
    template_id: str | None = None
    created_at: str = ""
    updated_at: str = ""

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class Job:
    request_id: int
    template_id: str
    status: str
    id: int | None = None
    started_at: str = ""
    finished_at: str = ""
    result_location: str = ""
    error_message: str = ""
    detail: str = ""

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class Approval:
    request_id: int
    approver: str
    status: str
    id: int | None = None
    comment: str = ""
    created_at: str = ""

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class AuditEntry:
    actor: str
    action: str
    target_type: str
    target_id: int
    id: int | None = None
    detail: str = ""
    created_at: str = ""

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)
```

- [ ] **Step 4: Implement store**

`hub/ops/store.py`:

```python
from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

from hub.ops.models import Approval, AuditEntry, Job, Request

_SCHEMA = """
CREATE TABLE IF NOT EXISTS requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  requester_name TEXT NOT NULL,
  title TEXT NOT NULL,
  department TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  input_location TEXT NOT NULL DEFAULT '',
  output_format TEXT NOT NULL DEFAULT '',
  repeat_cycle TEXT NOT NULL DEFAULT '',
  due_at TEXT NOT NULL DEFAULT '',
  contains_personal_data INTEGER NOT NULL DEFAULT 0,
  requires_external_login INTEGER NOT NULL DEFAULT 0,
  human_check_point TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT '접수됨',
  risk_level TEXT,
  template_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  request_id INTEGER NOT NULL REFERENCES requests(id),
  template_id TEXT NOT NULL,
  status TEXT NOT NULL,
  started_at TEXT NOT NULL DEFAULT '',
  finished_at TEXT NOT NULL DEFAULT '',
  result_location TEXT NOT NULL DEFAULT '',
  error_message TEXT NOT NULL DEFAULT '',
  detail TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS approvals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  request_id INTEGER NOT NULL REFERENCES requests(id),
  approver TEXT NOT NULL,
  status TEXT NOT NULL,
  comment TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT NOT NULL,
  action TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id INTEGER NOT NULL,
  detail TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);
"""

_REQUEST_FIELDS = ["requester_name", "title", "department", "description",
                   "input_location", "output_format", "repeat_cycle", "due_at",
                   "contains_personal_data", "requires_external_login",
                   "human_check_point", "status", "risk_level", "template_id"]
_JOB_FIELDS = ["request_id", "template_id", "status", "started_at", "finished_at",
               "result_location", "error_message", "detail"]
_BOOL_FIELDS = {"contains_personal_data", "requires_external_login"}


class RequestNotFound(Exception):
    pass


class JobNotFound(Exception):
    pass


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


class OpsStore:
    """운영 도메인 영속 계층. 호출마다 연결을 열고 닫는다(파일럿 규모에 충분)."""

    def __init__(self, db_path, now: Callable[[], str] | None = None) -> None:
        self._db = str(db_path)
        self._now = now or _utc_now
        Path(self._db).parent.mkdir(parents=True, exist_ok=True)
        with self._conn() as c:
            c.executescript(_SCHEMA)

    def _conn(self) -> sqlite3.Connection:
        c = sqlite3.connect(self._db)
        c.row_factory = sqlite3.Row
        return c

    # --- Request ---

    def create_request(self, req: Request) -> Request:
        ts = self._now()
        cols = _REQUEST_FIELDS + ["created_at", "updated_at"]
        vals = [self._to_db(f, getattr(req, f)) for f in _REQUEST_FIELDS] + [ts, ts]
        with self._conn() as c:
            cur = c.execute(
                f"INSERT INTO requests ({','.join(cols)}) VALUES ({','.join('?' * len(cols))})",
                vals)
            return self._get_request(c, cur.lastrowid)

    def get_request(self, request_id: int) -> Request:
        with self._conn() as c:
            return self._get_request(c, request_id)

    def _get_request(self, c: sqlite3.Connection, request_id: int) -> Request:
        row = c.execute("SELECT * FROM requests WHERE id=?", (request_id,)).fetchone()
        if row is None:
            raise RequestNotFound(request_id)
        return self._row_to_request(row)

    def list_requests(self, requester: str | None = None,
                      status: str | None = None) -> list[Request]:
        q, args = "SELECT * FROM requests", []
        conds = []
        if requester is not None:
            conds.append("requester_name=?"); args.append(requester)
        if status is not None:
            conds.append("status=?"); args.append(status)
        if conds:
            q += " WHERE " + " AND ".join(conds)
        q += " ORDER BY id DESC"
        with self._conn() as c:
            return [self._row_to_request(r) for r in c.execute(q, args)]

    def update_request(self, request_id: int, **fields) -> Request:
        bad = set(fields) - set(_REQUEST_FIELDS)
        if bad:
            raise ValueError(f"수정 불가 필드: {sorted(bad)}")
        sets = ", ".join(f"{k}=?" for k in fields) + ", updated_at=?"
        vals = [self._to_db(k, v) for k, v in fields.items()] + [self._now(), request_id]
        with self._conn() as c:
            cur = c.execute(f"UPDATE requests SET {sets} WHERE id=?", vals)
            if cur.rowcount == 0:
                raise RequestNotFound(request_id)
            return self._get_request(c, request_id)

    # --- Job ---

    def create_job(self, job: Job) -> Job:
        vals = [getattr(job, f) for f in _JOB_FIELDS]
        with self._conn() as c:
            cur = c.execute(
                f"INSERT INTO jobs ({','.join(_JOB_FIELDS)}) VALUES ({','.join('?' * len(_JOB_FIELDS))})",
                vals)
            return self._get_job(c, cur.lastrowid)

    def get_job(self, job_id: int) -> Job:
        with self._conn() as c:
            return self._get_job(c, job_id)

    def _get_job(self, c: sqlite3.Connection, job_id: int) -> Job:
        row = c.execute("SELECT * FROM jobs WHERE id=?", (job_id,)).fetchone()
        if row is None:
            raise JobNotFound(job_id)
        return Job(**dict(row))

    def update_job(self, job_id: int, **fields) -> Job:
        bad = set(fields) - set(_JOB_FIELDS)
        if bad:
            raise ValueError(f"수정 불가 필드: {sorted(bad)}")
        sets = ", ".join(f"{k}=?" for k in fields)
        vals = list(fields.values()) + [job_id]
        with self._conn() as c:
            cur = c.execute(f"UPDATE jobs SET {sets} WHERE id=?", vals)
            if cur.rowcount == 0:
                raise JobNotFound(job_id)
            return self._get_job(c, job_id)

    def list_jobs(self, request_id: int) -> list[Job]:
        with self._conn() as c:
            rows = c.execute("SELECT * FROM jobs WHERE request_id=? ORDER BY id",
                             (request_id,))
            return [Job(**dict(r)) for r in rows]

    # --- Approval / Audit ---

    def create_approval(self, ap: Approval) -> Approval:
        with self._conn() as c:
            cur = c.execute(
                "INSERT INTO approvals (request_id, approver, status, comment, created_at)"
                " VALUES (?,?,?,?,?)",
                (ap.request_id, ap.approver, ap.status, ap.comment, self._now()))
            row = c.execute("SELECT * FROM approvals WHERE id=?", (cur.lastrowid,)).fetchone()
            return Approval(**dict(row))

    def list_approvals(self, request_id: int) -> list[Approval]:
        with self._conn() as c:
            rows = c.execute("SELECT * FROM approvals WHERE request_id=? ORDER BY id",
                             (request_id,))
            return [Approval(**dict(r)) for r in rows]

    def add_audit(self, actor: str, action: str, target_type: str, target_id: int,
                  detail: str = "") -> AuditEntry:
        with self._conn() as c:
            cur = c.execute(
                "INSERT INTO audit_log (actor, action, target_type, target_id, detail, created_at)"
                " VALUES (?,?,?,?,?,?)",
                (actor, action, target_type, target_id, detail, self._now()))
            row = c.execute("SELECT * FROM audit_log WHERE id=?", (cur.lastrowid,)).fetchone()
            return AuditEntry(**dict(row))

    def list_audit(self, target_type: str | None = None,
                   target_id: int | None = None) -> list[AuditEntry]:
        q, args = "SELECT * FROM audit_log", []
        conds = []
        if target_type is not None:
            conds.append("target_type=?"); args.append(target_type)
        if target_id is not None:
            conds.append("target_id=?"); args.append(target_id)
        if conds:
            q += " WHERE " + " AND ".join(conds)
        q += " ORDER BY id"
        with self._conn() as c:
            return [AuditEntry(**dict(r)) for r in c.execute(q, args)]

    # --- helpers ---

    @staticmethod
    def _to_db(field: str, value):
        if field in _BOOL_FIELDS:
            return 1 if value else 0
        return value

    @staticmethod
    def _row_to_request(row: sqlite3.Row) -> Request:
        d = dict(row)
        for f in _BOOL_FIELDS:
            d[f] = bool(d[f])
        return Request(**d)
```

Also create empty `hub/ops/__init__.py`.

- [ ] **Step 5: Run — expect PASS**

Run: `./.venv/bin/python -m pytest -q tests/test_ops_store.py`
Expected: 6 passed.

- [ ] **Step 6: Full suite + commit**

```bash
./.venv/bin/python -m pytest -q
git add hub/ops tests/test_ops_store.py
git commit -m "feat(ops): domain models + sqlite store (requests/jobs/approvals/audit)"
```

---

### Task 4: Request lifecycle service — state machine, review, confirm, rework, hold

**Files:**
- Create: `hub/ops/requests.py`
- Test: `tests/test_ops_requests.py`

**Interfaces:**
- Consumes: `OpsStore`, `Request`, `RISK_LEVELS` from Task 3.
- Produces (Task 5/6 depend on):
  - Exceptions: `IllegalTransition(Exception)`, `ReviewRejected(Exception)`, `NotYourRequest(Exception)`
  - `ALLOWED_TRANSITIONS: dict[str, set[str]]`
  - `validate_transition(current: str, new: str) -> None` (raises IllegalTransition)
  - `submit(store, req: Request, actor: str) -> Request`
  - `review(store, request_id, actor, risk_level, template_id, known_templates: set[str]) -> Request`
  - `confirm(store, request_id, actor) -> Request` (중간/높음 → actor must equal requester_name, else NotYourRequest)
  - `rework(store, request_id, actor, comment="") -> Request` (검수 대기 → 자동화 가능)
  - `hold(store, request_id, actor) -> Request`, `resume(store, request_id, actor) -> Request` (보류 → 검토 중)

- [ ] **Step 1: Write the failing tests**

`tests/test_ops_requests.py`:

```python
import pytest

from hub.ops.models import Request, REQUEST_STATUSES
from hub.ops.requests import (ALLOWED_TRANSITIONS, IllegalTransition, NotYourRequest,
                              ReviewRejected, confirm, hold, resume, review, rework,
                              submit, validate_transition)
from hub.ops.store import OpsStore

TEMPLATES = {"chat-answer"}


def _store(tmp_path):
    return OpsStore(tmp_path / "hub.db")


def _submitted(st, **kw):
    base = dict(requester_name="김선생", title="취합")
    base.update(kw)
    return submit(st, Request(**base), actor="김선생")


def test_transition_matrix_is_exhaustive_and_enforced():
    assert set(ALLOWED_TRANSITIONS) == set(REQUEST_STATUSES)
    for cur in REQUEST_STATUSES:
        for new in REQUEST_STATUSES:
            if new in ALLOWED_TRANSITIONS[cur]:
                validate_transition(cur, new)          # 예외 없어야 함
            else:
                with pytest.raises(IllegalTransition):
                    validate_transition(cur, new)


def test_submit_creates_접수됨_with_audit(tmp_path):
    st = _store(tmp_path)
    r = _submitted(st)
    assert r.status == "접수됨"
    assert st.list_audit(target_id=r.id)[0].action == "request_submitted"


def test_review_sets_risk_template_and_status(tmp_path):
    st = _store(tmp_path)
    r = _submitted(st)
    r2 = review(st, r.id, actor="FDE", risk_level="낮음", template_id="chat-answer",
                known_templates=TEMPLATES)
    assert (r2.status, r2.risk_level, r2.template_id) == ("자동화 가능", "낮음", "chat-answer")


def test_review_rejects_low_risk_when_pii(tmp_path):
    st = _store(tmp_path)
    r = _submitted(st, contains_personal_data=True)
    with pytest.raises(ReviewRejected):
        review(st, r.id, "FDE", "낮음", "chat-answer", TEMPLATES)
    review(st, r.id, "FDE", "중간", "chat-answer", TEMPLATES)   # 중간부터 허용


def test_review_rejects_unknown_template_and_bad_risk(tmp_path):
    st = _store(tmp_path)
    r = _submitted(st)
    with pytest.raises(ReviewRejected):
        review(st, r.id, "FDE", "낮음", "no-such", TEMPLATES)
    with pytest.raises(ReviewRejected):
        review(st, r.id, "FDE", "매우높음", "chat-answer", TEMPLATES)


def test_confirm_requires_requester_for_medium_risk(tmp_path):
    st = _store(tmp_path)
    r = _submitted(st)
    review(st, r.id, "FDE", "중간", "chat-answer", TEMPLATES)
    st.update_request(r.id, status="검수 대기")               # 실행 완료 상태 시뮬레이션
    with pytest.raises(NotYourRequest):
        confirm(st, r.id, actor="FDE")
    assert confirm(st, r.id, actor="김선생").status == "완료"


def test_confirm_low_risk_by_anyone_and_rework_cycle(tmp_path):
    st = _store(tmp_path)
    r = _submitted(st)
    review(st, r.id, "FDE", "낮음", "chat-answer", TEMPLATES)
    st.update_request(r.id, status="검수 대기")
    r2 = rework(st, r.id, actor="김선생", comment="열 이름 수정")
    assert r2.status == "자동화 가능"
    st.update_request(r.id, status="검수 대기")
    assert confirm(st, r.id, actor="FDE").status == "완료"     # 낮음은 FDE 확인으로 종결


def test_confirm_illegal_from_접수됨(tmp_path):
    st = _store(tmp_path)
    r = _submitted(st)
    with pytest.raises(IllegalTransition):
        confirm(st, r.id, actor="김선생")


def test_hold_and_resume(tmp_path):
    st = _store(tmp_path)
    r = _submitted(st)
    assert hold(st, r.id, actor="FDE").status == "보류"
    assert resume(st, r.id, actor="FDE").status == "검토 중"
```

- [ ] **Step 2: Run — expect FAIL**

Run: `./.venv/bin/python -m pytest -q tests/test_ops_requests.py`
Expected: FAIL with `ModuleNotFoundError` (hub.ops.requests).

- [ ] **Step 3: Implement**

`hub/ops/requests.py`:

```python
from __future__ import annotations

from hub.ops.models import RISK_LEVELS, Request
from hub.ops.store import OpsStore

# MVP §9 상태 흐름. 보류는 실행 중이 아닌 미완료 상태에서만 진입 가능.
ALLOWED_TRANSITIONS: dict[str, set[str]] = {
    "접수됨": {"검토 중", "자동화 가능", "보류"},
    "검토 중": {"자동화 가능", "보류"},
    "자동화 가능": {"실행 중", "보류"},
    "실행 중": {"검수 대기", "자동화 가능"},
    "검수 대기": {"완료", "자동화 가능", "보류"},
    "보류": {"검토 중"},
    "완료": set(),
}


class IllegalTransition(Exception):
    pass


class ReviewRejected(Exception):
    pass


class NotYourRequest(Exception):
    pass


def validate_transition(current: str, new: str) -> None:
    if new not in ALLOWED_TRANSITIONS.get(current, set()):
        raise IllegalTransition(f"{current} → {new} 전이는 허용되지 않습니다")


def _transition(store: OpsStore, request_id: int, new: str, actor: str,
                action: str, detail: str = "", **extra) -> Request:
    req = store.get_request(request_id)
    validate_transition(req.status, new)
    updated = store.update_request(request_id, status=new, **extra)
    store.add_audit(actor, action, "request", request_id, detail)
    return updated


def submit(store: OpsStore, req: Request, actor: str) -> Request:
    created = store.create_request(req)
    store.add_audit(actor, "request_submitted", "request", created.id, created.title)
    return created


def review(store: OpsStore, request_id: int, actor: str, risk_level: str,
           template_id: str, known_templates: set[str]) -> Request:
    req = store.get_request(request_id)
    if risk_level not in RISK_LEVELS:
        raise ReviewRejected(f"위험도는 {RISK_LEVELS} 중 하나여야 합니다")
    if template_id not in known_templates:
        raise ReviewRejected(f"알 수 없는 템플릿: {template_id}")
    if req.contains_personal_data and risk_level == "낮음":
        raise ReviewRejected("개인정보 포함 요청은 위험도 중간 이상이어야 합니다")
    return _transition(store, request_id, "자동화 가능", actor, "request_reviewed",
                       detail=f"위험도 {risk_level} · 템플릿 {template_id}",
                       risk_level=risk_level, template_id=template_id)


def confirm(store: OpsStore, request_id: int, actor: str) -> Request:
    req = store.get_request(request_id)
    validate_transition(req.status, "완료")
    if req.risk_level in ("중간", "높음") and actor != req.requester_name:
        raise NotYourRequest("위험도 중간 이상은 요청자 본인만 완료 확인할 수 있습니다")
    return _transition(store, request_id, "완료", actor, "request_confirmed")


def rework(store: OpsStore, request_id: int, actor: str, comment: str = "") -> Request:
    return _transition(store, request_id, "자동화 가능", actor, "rework_requested",
                       detail=comment)


def hold(store: OpsStore, request_id: int, actor: str) -> Request:
    return _transition(store, request_id, "보류", actor, "request_held")


def resume(store: OpsStore, request_id: int, actor: str) -> Request:
    return _transition(store, request_id, "검토 중", actor, "request_resumed")
```

Note: `rework` from `검수 대기` and (by matrix) `실행 중→자동화 가능` are both legal; `rework`'s own legality is enforced by `validate_transition` inside `_transition` — calling it from `접수됨` raises `IllegalTransition`.

- [ ] **Step 4: Run — expect PASS**

Run: `./.venv/bin/python -m pytest -q tests/test_ops_requests.py`
Expected: 9 passed.

- [ ] **Step 5: Full suite + commit**

```bash
./.venv/bin/python -m pytest -q
git add hub/ops/requests.py tests/test_ops_requests.py
git commit -m "feat(ops): request lifecycle state machine (review/confirm/rework/hold)"
```

---

### Task 5: Template registry + chat-answer runner + risk-gated job execution

**Files:**
- Create: `hub/ops/templates/__init__.py`, `hub/ops/templates/base.py`, `hub/ops/templates/chat_answer.py`, `hub/ops/jobs.py`
- Test: `tests/test_ops_jobs.py`

**Interfaces:**
- Consumes: Task 3/4 (`OpsStore`, `Job`, `requests.validate_transition`), `hub.session.SourceRegistry`, `hub.core.ingest.{TABULAR_EXT, DOC_EXT, load_tabular, load_document}`.
- Produces:
  - `hub.ops.templates.base`: `@dataclass RunContext(registry, cfg, text_factory, runs_dir: str)`, `@dataclass RunResult(result_location: str, detail: str = "")`. Runner = `Callable[[Request, RunContext], RunResult]`.
  - `hub.ops.templates`: `RUNNERS: dict[str, Runner]` (key `"chat-answer"`), `TEMPLATE_INFO: list[dict]` (id/name/description for UI).
  - `hub.ops.jobs`: `ApprovalRequired(Exception)`, `execute(store, request_id, actor, runners, ctx) -> Job` — full gate + run + status bookkeeping. Request input files live at `{runs_dir}/request-{id}/input/` (Task 6 uploads there).

- [ ] **Step 1: Write the failing tests**

`tests/test_ops_jobs.py`:

```python
from pathlib import Path

import pytest
from openpyxl import Workbook

from hub.ops.jobs import ApprovalRequired, execute
from hub.ops.models import Approval, Request
from hub.ops.requests import IllegalTransition, review, submit
from hub.ops.store import OpsStore
from hub.ops.templates import RUNNERS, TEMPLATE_INFO
from hub.ops.templates.base import RunContext, RunResult
from hub.ops.templates.chat_answer import run as chat_answer_run
from hub.session import SourceRegistry

TEMPLATES = {"chat-answer", "stub", "boom"}


def _ctx(tmp_path, registry=None):
    return RunContext(registry=registry or SourceRegistry(), cfg=None,
                      text_factory=None, runs_dir=str(tmp_path / "runs"))


def _ready_request(st, risk="낮음", template="stub", **kw):
    base = dict(requester_name="김선생", title="취합")
    base.update(kw)
    r = submit(st, Request(**base), actor="김선생")
    review(st, r.id, "FDE", risk, template, TEMPLATES)
    return st.get_request(r.id)


def _stub_runners():
    return {"stub": lambda req, ctx: RunResult(result_location="out.txt", detail="ok"),
            "boom": lambda req, ctx: (_ for _ in ()).throw(RuntimeError("실행 폭발"))}


def test_execute_success_moves_to_검수대기_and_records(tmp_path):
    st = OpsStore(tmp_path / "hub.db")
    r = _ready_request(st)
    job = execute(st, r.id, "FDE", _stub_runners(), _ctx(tmp_path))
    assert job.status == "성공" and job.result_location == "out.txt"
    assert job.started_at and job.finished_at
    assert st.get_request(r.id).status == "검수 대기"
    actions = [a.action for a in st.list_audit(target_type="job", target_id=job.id)]
    assert actions == ["job_started", "job_succeeded"]


def test_execute_failure_returns_to_자동화가능_with_error(tmp_path):
    st = OpsStore(tmp_path / "hub.db")
    r = _ready_request(st, template="boom")
    job = execute(st, r.id, "FDE", _stub_runners(), _ctx(tmp_path))
    assert job.status == "실패" and "실행 폭발" in job.error_message
    assert st.get_request(r.id).status == "자동화 가능"


def test_execute_blocked_unless_자동화가능(tmp_path):
    st = OpsStore(tmp_path / "hub.db")
    r = submit(st, Request(requester_name="김선생", title="t"), actor="김선생")
    with pytest.raises(IllegalTransition):
        execute(st, r.id, "FDE", _stub_runners(), _ctx(tmp_path))


def test_high_risk_requires_approval(tmp_path):
    st = OpsStore(tmp_path / "hub.db")
    r = _ready_request(st, risk="높음")
    with pytest.raises(ApprovalRequired):
        execute(st, r.id, "FDE", _stub_runners(), _ctx(tmp_path))
    st.create_approval(Approval(request_id=r.id, approver="부장", status="반려"))
    with pytest.raises(ApprovalRequired):                      # 반려만으로는 부족
        execute(st, r.id, "FDE", _stub_runners(), _ctx(tmp_path))
    st.create_approval(Approval(request_id=r.id, approver="부장", status="승인"))
    assert execute(st, r.id, "FDE", _stub_runners(), _ctx(tmp_path)).status == "성공"


def test_chat_answer_runner_builds_session_from_request_files(tmp_path):
    st = OpsStore(tmp_path / "hub.db")
    r = _ready_request(st, template="chat-answer")
    in_dir = Path(str(tmp_path / "runs")) / f"request-{r.id}" / "input"
    in_dir.mkdir(parents=True)
    wb = Workbook(); ws = wb.active; ws.title = "명단"
    ws.append(["이름"]); ws.append(["김"])
    wb.save(in_dir / "a.xlsx")

    reg = SourceRegistry()
    result = chat_answer_run(st.get_request(r.id), _ctx(tmp_path, registry=reg))
    assert result.result_location.startswith("session:")
    sid = result.result_location.split(":", 1)[1]
    assert reg.get_sources(sid)[0].filename == "a.xlsx"


def test_chat_answer_runner_fails_without_files(tmp_path):
    st = OpsStore(tmp_path / "hub.db")
    r = _ready_request(st, template="chat-answer")
    with pytest.raises(ValueError):
        chat_answer_run(st.get_request(r.id), _ctx(tmp_path))


def test_registry_exposes_chat_answer():
    assert "chat-answer" in RUNNERS
    assert any(t["id"] == "chat-answer" for t in TEMPLATE_INFO)
```

- [ ] **Step 2: Run — expect FAIL**

Run: `./.venv/bin/python -m pytest -q tests/test_ops_jobs.py`
Expected: FAIL with ModuleNotFoundError (hub.ops.jobs / hub.ops.templates).

- [ ] **Step 3: Implement**

`hub/ops/templates/base.py`:

```python
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable

from hub.ops.models import Request


@dataclass
class RunContext:
    registry: Any          # hub.session.SourceRegistry
    cfg: Any               # hub.config.Config (러너가 필요 시 사용)
    text_factory: Any      # 정규화 LLM 팩토리 (phase 1 러너는 미사용)
    runs_dir: str


@dataclass
class RunResult:
    result_location: str
    detail: str = ""


Runner = Callable[[Request, RunContext], RunResult]
```

`hub/ops/templates/chat_answer.py`:

```python
from __future__ import annotations

from pathlib import Path

from hub.core.ingest import DOC_EXT, TABULAR_EXT, load_document, load_tabular
from hub.ops.models import Request
from hub.ops.templates.base import RunContext, RunResult


def run(request: Request, ctx: RunContext) -> RunResult:
    """요청에 올라온 파일들로 채팅 세션을 만들어 연결한다. 계산은 세션의 결정론 툴이 담당."""
    in_dir = Path(ctx.runs_dir) / f"request-{request.id}" / "input"
    files = sorted(p for p in in_dir.glob("*") if p.is_file()) if in_dir.exists() else []
    if not files:
        raise ValueError("입력 파일이 없습니다 — 요청에 파일을 먼저 올려주세요")
    sid = ctx.registry.create_session()
    loaded = 0
    for p in files:
        ext = p.suffix.lower()
        src_id = ctx.registry.next_source_id(sid)
        if ext in TABULAR_EXT:
            ctx.registry.add_source(sid, load_tabular(str(p), src_id))
            loaded += 1
        elif ext in DOC_EXT:
            ctx.registry.add_source(sid, load_document(str(p), src_id))
            loaded += 1
    if loaded == 0:
        raise ValueError("지원되는 형식의 입력 파일이 없습니다")
    return RunResult(result_location=f"session:{sid}",
                     detail=f"파일 {loaded}개로 채팅 세션 생성")
```

`hub/ops/templates/__init__.py`:

```python
from hub.ops.templates import chat_answer
from hub.ops.templates.base import Runner, RunContext, RunResult

RUNNERS: dict[str, Runner] = {
    "chat-answer": chat_answer.run,
}

TEMPLATE_INFO: list[dict] = [
    {"id": "chat-answer", "name": "채팅 답변",
     "description": "요청 파일로 채팅 세션을 만들어 근거 있는 질의응답을 제공 (파일 생성 없음)"},
]
```

`hub/ops/jobs.py`:

```python
from __future__ import annotations

from datetime import datetime, timezone

from hub.ops.models import Job
from hub.ops.requests import validate_transition
from hub.ops.store import OpsStore
from hub.ops.templates.base import RunContext, Runner


class ApprovalRequired(Exception):
    pass


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def execute(store: OpsStore, request_id: int, actor: str,
            runners: dict[str, Runner], ctx: RunContext) -> Job:
    req = store.get_request(request_id)
    validate_transition(req.status, "실행 중")          # 자동화 가능에서만 실행
    if not req.template_id or req.template_id not in runners:
        raise ValueError(f"실행할 템플릿이 없습니다: {req.template_id}")
    if req.risk_level == "높음":
        if not any(a.status == "승인" for a in store.list_approvals(request_id)):
            raise ApprovalRequired("위험도 높음 요청은 승인 기록이 있어야 실행할 수 있습니다")

    job = store.create_job(Job(request_id=request_id, template_id=req.template_id,
                               status="실행 중", started_at=_now()))
    store.update_request(request_id, status="실행 중")
    store.add_audit(actor, "job_started", "job", job.id, req.template_id)
    try:
        result = runners[req.template_id](req, ctx)
    except Exception as exc:
        job = store.update_job(job.id, status="실패", finished_at=_now(),
                               error_message=f"{type(exc).__name__}: {exc}")
        store.update_request(request_id, status="자동화 가능")
        store.add_audit(actor, "job_failed", "job", job.id, job.error_message)
        return job
    job = store.update_job(job.id, status="성공", finished_at=_now(),
                           result_location=result.result_location, detail=result.detail)
    store.update_request(request_id, status="검수 대기")
    store.add_audit(actor, "job_succeeded", "job", job.id, result.result_location)
    return job
```

- [ ] **Step 4: Run — expect PASS**

Run: `./.venv/bin/python -m pytest -q tests/test_ops_jobs.py`
Expected: 7 passed. (chat_answer test uses real `load_tabular` on a fixture xlsx — deterministic, no LLM/subprocess.)

- [ ] **Step 5: Full suite + commit**

```bash
./.venv/bin/python -m pytest -q
git add hub/ops tests/test_ops_jobs.py
git commit -m "feat(ops): template registry, chat-answer runner, risk-gated job execution"
```

---

### Task 6: `/requests` API router + app wiring (`db_path`, runners)

**Files:**
- Create: `hub/api/ops.py`
- Modify: `hub/api/__init__.py` (wire store/router; new params), `hub/config.py` (add `db_path`), `.gitignore` (add `data/hub.db`), `.env.example` (add `OFFICE_HUB_DB=data/hub.db`)
- Test: `tests/test_api_ops.py`

**Interfaces:**
- Consumes: everything from Tasks 2–5.
- Produces:
  - `hub.config.Config.db_path: str` (env `OFFICE_HUB_DB`, default `"data/hub.db"`).
  - `hub.api.create_app(llm_factory=None, text_factory=None, catalog_path=None, runs_dir="runs", db_path=None, runners=None)` — `db_path=None` → `cfg.db_path`; `runners=None` → `hub.ops.templates.RUNNERS`.
  - HTTP API (all bodies JSON unless noted; actor fields are free-text names — no auth by design):
    - `POST /requests` (RequestCreate) → 201 request dict
    - `GET /requests?requester=&status=` → `{"requests": [...]}`
    - `GET /requests/{id}` → `{"request", "jobs", "approvals", "files", "audit"}`
    - `POST /requests/{id}/files` (multipart) → `{"files": [...]}` — saved to `{runs_dir}/request-{id}/input/`
    - `POST /requests/{id}/review` `{actor, risk_level, template_id}`
    - `POST /requests/{id}/approvals` `{approver, status, comment}` (status ∈ 승인/반려)
    - `POST /requests/{id}/jobs` `{actor}` → job dict (synchronous execution)
    - `POST /requests/{id}/confirm` `{actor}` / `POST /requests/{id}/rework` `{actor, comment}` / `POST /requests/{id}/hold` `{actor}` / `POST /requests/{id}/resume` `{actor}`
    - `GET /templates` → `{"templates": TEMPLATE_INFO}`
  - Error mapping: `RequestNotFound`→404, `IllegalTransition`/`ApprovalRequired`→409, `ReviewRejected`→422, `NotYourRequest`→403, unknown template at run→422.

- [ ] **Step 1: Write the failing tests**

`tests/test_api_ops.py`:

```python
import io

from fastapi.testclient import TestClient
from openpyxl import Workbook

from hub.api import create_app
from hub.ops.templates.base import RunResult


def _xlsx_bytes():
    wb = Workbook(); ws = wb.active; ws.title = "명단"
    ws.append(["이름"]); ws.append(["김"])
    buf = io.BytesIO(); wb.save(buf); return buf.getvalue()


def _client(tmp_path, runners=None):
    app = create_app(llm_factory=lambda cfg: None,
                     text_factory=lambda cfg: (lambda system, user: "{}"),
                     runs_dir=str(tmp_path / "runs"),
                     db_path=str(tmp_path / "hub.db"),
                     runners=runners)
    return TestClient(app)


def _submit(client, **overrides):
    body = {"requester_name": "김선생", "title": "신청자 취합", "department": "교무",
            "output_format": "채팅 답변", "human_check_point": "명단 확정 전 확인"}
    body.update(overrides)
    r = client.post("/requests", json=body)
    assert r.status_code == 201
    return r.json()


STUB = {"stub": lambda req, ctx: RunResult(result_location="out.txt", detail="ok"),
        "chat-answer": lambda req, ctx: RunResult(result_location="session:s1")}


def test_low_risk_full_flow(tmp_path):
    c = _client(tmp_path, runners=STUB)
    req = _submit(c)
    rid = req["id"]

    up = c.post(f"/requests/{rid}/files",
                files={"file": ("a.xlsx", _xlsx_bytes(),
                       "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")})
    assert up.status_code == 200 and up.json()["files"] == ["a.xlsx"]

    rv = c.post(f"/requests/{rid}/review",
                json={"actor": "FDE", "risk_level": "낮음", "template_id": "stub"})
    assert rv.status_code == 200 and rv.json()["status"] == "자동화 가능"

    job = c.post(f"/requests/{rid}/jobs", json={"actor": "FDE"})
    assert job.status_code == 200 and job.json()["status"] == "성공"

    assert c.get(f"/requests/{rid}").json()["request"]["status"] == "검수 대기"
    done = c.post(f"/requests/{rid}/confirm", json={"actor": "FDE"})   # 낮음: FDE 종결 가능
    assert done.json()["status"] == "완료"

    detail = c.get(f"/requests/{rid}").json()
    assert [j["status"] for j in detail["jobs"]] == ["성공"]
    assert any(a["action"] == "request_confirmed" for a in detail["audit"])


def test_high_risk_needs_approval_and_requester_confirm(tmp_path):
    c = _client(tmp_path, runners=STUB)
    rid = _submit(c, contains_personal_data=True)["id"]
    c.post(f"/requests/{rid}/review",
           json={"actor": "FDE", "risk_level": "높음", "template_id": "stub"})

    assert c.post(f"/requests/{rid}/jobs", json={"actor": "FDE"}).status_code == 409

    ap = c.post(f"/requests/{rid}/approvals",
                json={"approver": "부장", "status": "승인", "comment": "확인"})
    assert ap.status_code == 201

    assert c.post(f"/requests/{rid}/jobs", json={"actor": "FDE"}).status_code == 200
    assert c.post(f"/requests/{rid}/confirm", json={"actor": "FDE"}).status_code == 403
    assert c.post(f"/requests/{rid}/confirm", json={"actor": "김선생"}).status_code == 200


def test_pii_low_risk_review_rejected(tmp_path):
    c = _client(tmp_path, runners=STUB)
    rid = _submit(c, contains_personal_data=True)["id"]
    r = c.post(f"/requests/{rid}/review",
               json={"actor": "FDE", "risk_level": "낮음", "template_id": "stub"})
    assert r.status_code == 422


def test_rework_hold_resume_and_errors(tmp_path):
    c = _client(tmp_path, runners=STUB)
    rid = _submit(c)["id"]
    assert c.post(f"/requests/{rid}/confirm", json={"actor": "김선생"}).status_code == 409
    assert c.get("/requests/999").status_code == 404
    c.post(f"/requests/{rid}/review",
           json={"actor": "FDE", "risk_level": "낮음", "template_id": "stub"})
    c.post(f"/requests/{rid}/jobs", json={"actor": "FDE"})
    rw = c.post(f"/requests/{rid}/rework", json={"actor": "김선생", "comment": "다시"})
    assert rw.json()["status"] == "자동화 가능"
    assert c.post(f"/requests/{rid}/hold", json={"actor": "FDE"}).json()["status"] == "보류"
    assert c.post(f"/requests/{rid}/resume", json={"actor": "FDE"}).json()["status"] == "검토 중"


def test_list_filter_and_templates(tmp_path):
    c = _client(tmp_path, runners=STUB)
    _submit(c); _submit(c, requester_name="박선생", title="b")
    assert len(c.get("/requests").json()["requests"]) == 2
    mine = c.get("/requests", params={"requester": "김선생"}).json()["requests"]
    assert [r["requester_name"] for r in mine] == ["김선생"]
    t = c.get("/templates").json()["templates"]
    assert any(x["id"] == "chat-answer" for x in t)


def test_default_runners_run_chat_answer_end_to_end(tmp_path):
    c = _client(tmp_path)                                  # runners=None → 실제 RUNNERS
    rid = _submit(c)["id"]
    c.post(f"/requests/{rid}/files",
           files={"file": ("a.xlsx", _xlsx_bytes(),
                  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")})
    c.post(f"/requests/{rid}/review",
           json={"actor": "FDE", "risk_level": "낮음", "template_id": "chat-answer"})
    job = c.post(f"/requests/{rid}/jobs", json={"actor": "FDE"}).json()
    assert job["status"] == "성공" and job["result_location"].startswith("session:")
    sid = job["result_location"].split(":", 1)[1]
    src = c.get(f"/session/{sid}/sources")                 # 채팅 탭이 세션에 붙는 경로
    assert src.status_code == 200
    assert src.json()["sources"][0]["filename"] == "a.xlsx"
```

- [ ] **Step 2: Run — expect FAIL**

Run: `./.venv/bin/python -m pytest -q tests/test_api_ops.py`
Expected: FAIL (`create_app` has no `db_path` param; routes missing).

- [ ] **Step 3: Add `db_path` to config**

In `hub/config.py` add field and loader line:

```python
@dataclass
class Config:
    openai_api_key: str | None
    openai_model: str
    max_tool_iters: int
    max_sample_rows: int
    max_upload_mb: int
    llm_backend: str  # "auto" | "openai" | "codex"
    db_path: str
```

and in `load_config()`:

```python
        db_path=os.environ.get("OFFICE_HUB_DB", "data/hub.db"),
```

(If `tests/test_config.py` asserts exact Config fields, extend that test with `db_path` default assertion.)

- [ ] **Step 4: Implement the router**

`hub/api/ops.py`:

```python
from __future__ import annotations

from dataclasses import asdict
from pathlib import Path

from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel

from hub.api.uploads import read_validated
from hub.ops import jobs as ops_jobs
from hub.ops import requests as ops_requests
from hub.ops.models import APPROVAL_STATUSES, Approval, Request
from hub.ops.store import OpsStore, RequestNotFound
from hub.ops.templates import TEMPLATE_INFO
from hub.ops.templates.base import RunContext


class RequestCreate(BaseModel):
    requester_name: str
    title: str
    department: str = ""
    description: str = ""
    input_location: str = ""
    output_format: str = ""
    repeat_cycle: str = ""
    due_at: str = ""
    contains_personal_data: bool = False
    requires_external_login: bool = False
    human_check_point: str = ""


class ReviewBody(BaseModel):
    actor: str
    risk_level: str
    template_id: str


class ActorBody(BaseModel):
    actor: str


class ReworkBody(BaseModel):
    actor: str
    comment: str = ""


class ApprovalBody(BaseModel):
    approver: str
    status: str
    comment: str = ""


def ops_router(store: OpsStore, runners: dict, ctx: RunContext,
               max_upload_mb: int) -> APIRouter:
    r = APIRouter()
    known = set(runners)

    def _get(request_id: int) -> Request:
        try:
            return store.get_request(request_id)
        except RequestNotFound:
            raise HTTPException(404, "요청을 찾을 수 없습니다")

    def _run(fn, *args, **kw):
        """도메인 예외 → HTTP 상태코드 매핑."""
        try:
            return fn(*args, **kw)
        except RequestNotFound:
            raise HTTPException(404, "요청을 찾을 수 없습니다")
        except ops_requests.IllegalTransition as exc:
            raise HTTPException(409, str(exc))
        except ops_jobs.ApprovalRequired as exc:
            raise HTTPException(409, str(exc))
        except ops_requests.ReviewRejected as exc:
            raise HTTPException(422, str(exc))
        except ops_requests.NotYourRequest as exc:
            raise HTTPException(403, str(exc))
        except ValueError as exc:
            raise HTTPException(422, str(exc))

    def _input_dir(request_id: int) -> Path:
        return Path(ctx.runs_dir) / f"request-{request_id}" / "input"

    @r.post("/requests", status_code=201)
    def create(body: RequestCreate):
        req = _run(ops_requests.submit, store, Request(**body.model_dump()),
                   actor=body.requester_name)
        return req.as_dict()

    @r.get("/requests")
    def list_requests(requester: str | None = None, status: str | None = None):
        return {"requests": [x.as_dict() for x in store.list_requests(requester, status)]}

    @r.get("/requests/{request_id}")
    def detail(request_id: int):
        req = _get(request_id)
        d = _input_dir(request_id)
        files = sorted(p.name for p in d.glob("*") if p.is_file()) if d.exists() else []
        return {"request": req.as_dict(),
                "jobs": [j.as_dict() for j in store.list_jobs(request_id)],
                "approvals": [a.as_dict() for a in store.list_approvals(request_id)],
                "files": files,
                "audit": [a.as_dict() for a in store.list_audit(target_type="request",
                                                                target_id=request_id)]}

    @r.post("/requests/{request_id}/files")
    async def upload(request_id: int, file: UploadFile = File(...)):
        req = _get(request_id)
        if req.status == "완료":
            raise HTTPException(409, "완료된 요청에는 파일을 올릴 수 없습니다")
        safe_name, data = await read_validated(file, max_upload_mb)
        d = _input_dir(request_id)
        d.mkdir(parents=True, exist_ok=True)
        (d / safe_name).write_bytes(data)
        store.add_audit(req.requester_name, "file_uploaded", "request", request_id, safe_name)
        return {"files": sorted(p.name for p in d.glob("*") if p.is_file())}

    @r.post("/requests/{request_id}/review")
    def review(request_id: int, body: ReviewBody):
        return _run(ops_requests.review, store, request_id, body.actor,
                    body.risk_level, body.template_id, known).as_dict()

    @r.post("/requests/{request_id}/approvals", status_code=201)
    def approve(request_id: int, body: ApprovalBody):
        _get(request_id)
        if body.status not in APPROVAL_STATUSES:
            raise HTTPException(422, f"승인 상태는 {APPROVAL_STATUSES} 중 하나여야 합니다")
        ap = store.create_approval(Approval(request_id=request_id, approver=body.approver,
                                            status=body.status, comment=body.comment))
        store.add_audit(body.approver, "approval_recorded", "request", request_id,
                        f"{body.status} {body.comment}".strip())
        return ap.as_dict()

    @r.post("/requests/{request_id}/jobs")
    def run_job(request_id: int, body: ActorBody):
        job = _run(ops_jobs.execute, store, request_id, body.actor, runners, ctx)
        return job.as_dict()

    @r.post("/requests/{request_id}/confirm")
    def confirm(request_id: int, body: ActorBody):
        return _run(ops_requests.confirm, store, request_id, body.actor).as_dict()

    @r.post("/requests/{request_id}/rework")
    def rework(request_id: int, body: ReworkBody):
        return _run(ops_requests.rework, store, request_id, body.actor,
                    body.comment).as_dict()

    @r.post("/requests/{request_id}/hold")
    def hold(request_id: int, body: ActorBody):
        return _run(ops_requests.hold, store, request_id, body.actor).as_dict()

    @r.post("/requests/{request_id}/resume")
    def resume(request_id: int, body: ActorBody):
        return _run(ops_requests.resume, store, request_id, body.actor).as_dict()

    @r.get("/templates")
    def templates():
        return {"templates": TEMPLATE_INFO}

    return r
```

- [ ] **Step 5: Wire into `create_app`**

In `hub/api/__init__.py` — new signature and router registration (chat/catalog wiring from Task 2 unchanged):

```python
from hub.api.ops import ops_router
from hub.ops.store import OpsStore
from hub.ops.templates import RUNNERS
from hub.ops.templates.base import RunContext


def create_app(llm_factory=None, text_factory=None, catalog_path=None,
               runs_dir: str = "runs", db_path: str | None = None,
               runners: dict | None = None) -> FastAPI:
    app = FastAPI(title="업무자동화 허브")
    cfg = load_config()
    reg = SourceRegistry()
    factory = llm_factory or _default_factory
    _text_factory = text_factory or text_llm_factory
    _runners = runners or RUNNERS
    store = OpsStore(db_path or cfg.db_path)
    ctx = RunContext(registry=reg, cfg=cfg, text_factory=_text_factory, runs_dir=runs_dir)

    try:
        _catalog = load_catalog(catalog_path or "data/catalog.json")
    except Exception:
        _catalog = None

    app.include_router(chat_router(reg, cfg, factory, _text_factory, runs_dir))
    app.include_router(catalog_router(_catalog))
    app.include_router(ops_router(store, _runners, ctx, cfg.max_upload_mb))
    ...  # 이하 index/static 동일
```

Append to `.gitignore`: `data/hub.db`. Append to `.env.example`: `OFFICE_HUB_DB=data/hub.db`.

- [ ] **Step 6: Run — expect PASS, then full suite**

Run: `./.venv/bin/python -m pytest -q tests/test_api_ops.py`
Expected: 6 passed.
Run: `./.venv/bin/python -m pytest -q`
Expected: all pass. NOTE: other tests construct `create_app(...)` without `db_path` — they would write `data/hub.db` in the repo. Grep `grep -ln "create_app(" tests/*.py` and add `db_path=str(tmp_path / "hub.db")` (and `tmp_path` fixture where missing) to every `create_app` call in tests that lacks it. Keep changes mechanical.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(api): /requests operational endpoints with risk gates, sqlite wiring"
```

---

### Task 7: Frontend — shell rebuild + 요청 tab (requester screen)

No JS test framework exists (project convention: static analysis + manual smoke). Verification is a scripted curl + browser checklist. Keep all copy Korean.

**Files:**
- Modify: `static/index.html` (full rewrite below), `static/styles.css` (append), `static/app.js` (generalize `showTab`, add `attachSession`)
- Create: `static/ops.js`

**Interfaces:**
- Consumes: `POST /requests`, `GET /requests?requester=`, `GET /requests/{id}`, `POST /requests/{id}/files`, `POST /requests/{id}/confirm`, `POST /requests/{id}/rework`, `GET /session/{id}/sources`.
- Produces (Task 8 depends on): global `currentUser()` and `currentRole()` helpers, generalized `showTab(name)` over views `requests|ops|chat|catalog`, `attachSession(sid)` in app.js, `esc(s)` HTML-escape helper in ops.js (reused by Task 8), `loadMyRequests()` in ops.js.

- [ ] **Step 1: Rewrite `static/index.html`**

```html
<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>업무자동화 허브</title>
  <link rel="stylesheet" href="/static/styles.css">
</head>
<body>
  <header>
    <h1>업무자동화 허브</h1>
    <div class="identity">
      <input type="text" id="userName" placeholder="이름" autocomplete="name">
      <select id="role" onchange="onRoleChange()">
        <option value="requester">요청자</option>
        <option value="fde">FDE</option>
      </select>
    </div>
  </header>
  <nav class="tabs">
    <button id="tab-requests" class="tab active" onclick="showTab('requests')">요청</button>
    <button id="tab-ops" class="tab" onclick="showTab('ops')" hidden>운영</button>
    <button id="tab-chat" class="tab" onclick="showTab('chat')">채팅 답변</button>
    <button id="tab-catalog" class="tab" onclick="showTab('catalog')">k-skill 카탈로그</button>
  </nav>

  <section id="requests-view">
    <main class="wrap two-col">
      <section class="panel">
        <h2>새 요청</h2>
        <form id="reqForm" onsubmit="return submitRequest(event)">
          <label>업무 제목 <input name="title" required></label>
          <label>소속/담당 <input name="department"></label>
          <label>업무 목적 <textarea name="description" rows="3"></textarea></label>
          <label>입력 자료 위치 <input name="input_location" placeholder="예: 공유폴더 링크"></label>
          <label>원하는 결과물 <input name="output_format" placeholder="예: 취합 Excel 1개"></label>
          <label>반복 주기 <input name="repeat_cycle" placeholder="예: 학기별"></label>
          <label>마감 <input name="due_at" type="date"></label>
          <label class="check"><input name="contains_personal_data" type="checkbox"> 개인정보 포함</label>
          <label class="check"><input name="requires_external_login" type="checkbox"> 외부 시스템 로그인 필요</label>
          <label>사람이 꼭 확인할 지점 <input name="human_check_point"></label>
          <div class="warn">⚠️ 개인정보가 포함된 파일은 주의해서 올려주세요. 파일 발췌가 외부 AI로 전송될 수 있습니다.</div>
          <button type="submit">요청 제출</button>
        </form>
        <div id="reqSubmitMsg"></div>
        <div id="reqFileBox" hidden>
          <h3>파일 첨부 (요청 #<span id="newReqId"></span>)</h3>
          <input type="file" id="reqFile" multiple>
          <button onclick="uploadRequestFiles()">업로드</button>
          <div id="reqFileList"></div>
        </div>
      </section>
      <section class="panel">
        <h2>내 요청</h2>
        <div id="myRequests">이름을 입력하면 내 요청이 표시됩니다.</div>
      </section>
    </main>
  </section>

  <section id="ops-view" hidden>
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

  <section id="chat-view" hidden>
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

  <section id="catalog-view" hidden>
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

- [ ] **Step 2: Generalize tabs + session attach in `static/app.js`**

Replace the existing `showTab` with, and add helpers at the top of the file:

```js
const TABS = ['requests', 'ops', 'chat', 'catalog'];

function currentUser() {
  return document.getElementById('userName').value.trim() || '이름없음';
}
function currentRole() {
  return document.getElementById('role').value;
}
function onRoleChange() {
  const fde = currentRole() === 'fde';
  document.getElementById('tab-ops').hidden = !fde;
  if (!fde && !document.getElementById('ops-view').hidden) showTab('requests');
}

function showTab(name) {
  for (const t of TABS) {
    const view = document.getElementById(t + '-view');
    const tab = document.getElementById('tab-' + t);
    if (view) view.hidden = name !== t;
    if (tab) tab.classList.toggle('active', name === t);
  }
  if (name === 'catalog' && !window._catalogLoaded) { window._catalogLoaded = true; loadCatalog(); }
  if (name === 'requests') loadMyRequests();
  if (name === 'ops') loadQueue();
}

async function attachSession(sid) {
  sessionId = sid;
  const r = await fetch(`/session/${sid}/sources`);
  if (r.ok) {
    const data = await r.json();
    document.getElementById('sources').textContent =
      '올린 파일: ' + data.sources.map(s => s.filename).join(', ');
  }
  showTab('chat');
}
```

(Delete the old two-tab `showTab`. Everything else in app.js stays.)

- [ ] **Step 3: Create `static/ops.js` — 요청 tab logic (운영 tab stubs land in Task 8)**

```js
function esc(s) {
  const d = document.createElement('span');
  d.textContent = s == null ? '' : String(s);
  return d.innerHTML;
}

const STATUS_CLASS = {
  '접수됨': 'st-new', '검토 중': 'st-review', '자동화 가능': 'st-ready',
  '실행 중': 'st-running', '검수 대기': 'st-check', '완료': 'st-done', '보류': 'st-hold',
};
function statusChip(status) {
  return `<span class="status-chip ${STATUS_CLASS[status] || ''}">${esc(status)}</span>`;
}

let _lastRequestId = null;

async function submitRequest(ev) {
  ev.preventDefault();
  const f = ev.target;
  const body = {
    requester_name: currentUser(),
    title: f.title.value.trim(),
    department: f.department.value.trim(),
    description: f.description.value.trim(),
    input_location: f.input_location.value.trim(),
    output_format: f.output_format.value.trim(),
    repeat_cycle: f.repeat_cycle.value.trim(),
    due_at: f.due_at.value,
    contains_personal_data: f.contains_personal_data.checked,
    requires_external_login: f.requires_external_login.checked,
    human_check_point: f.human_check_point.value.trim(),
  };
  const r = await fetch('/requests', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const msg = document.getElementById('reqSubmitMsg');
  if (!r.ok) { msg.textContent = '제출 실패: ' + ((await r.json()).detail || r.status); return false; }
  const req = await r.json();
  _lastRequestId = req.id;
  msg.textContent = `요청 #${req.id} 접수됨. 필요하면 아래에 파일을 첨부하세요.`;
  document.getElementById('newReqId').textContent = req.id;
  document.getElementById('reqFileBox').hidden = false;
  f.reset();
  loadMyRequests();
  return false;
}

async function uploadRequestFiles(reqId) {
  const rid = reqId || _lastRequestId;
  if (!rid) return;
  const files = document.getElementById('reqFile').files;
  const listEl = document.getElementById('reqFileList');
  for (const file of files) {
    const fd = new FormData();
    fd.append('file', file);
    const r = await fetch(`/requests/${rid}/files`, { method: 'POST', body: fd });
    if (!r.ok) { alert((await r.json()).detail || '업로드 실패'); continue; }
    listEl.textContent = '첨부됨: ' + (await r.json()).files.join(', ');
  }
}

async function loadMyRequests() {
  const box = document.getElementById('myRequests');
  const name = currentUser();
  if (name === '이름없음') { box.textContent = '이름을 입력하면 내 요청이 표시됩니다.'; return; }
  const r = await fetch('/requests?requester=' + encodeURIComponent(name));
  if (!r.ok) { box.textContent = '목록을 불러오지 못했습니다.'; return; }
  const items = (await r.json()).requests;
  if (!items.length) { box.textContent = '요청이 없습니다.'; return; }
  box.innerHTML = items.map(q => `
    <div class="req-row" data-id="${q.id}">
      <div class="req-head">#${q.id} ${esc(q.title)} ${statusChip(q.status)}
        ${q.risk_level ? `<span class="risk">위험도 ${esc(q.risk_level)}</span>` : ''}</div>
      <div class="req-actions" id="actions-${q.id}"></div>
    </div>`).join('');
  for (const q of items) {
    if (q.status === '검수 대기') renderRequesterActions(q.id);
  }
}

async function renderRequesterActions(rid) {
  const el = document.getElementById(`actions-${rid}`);
  const detail = await (await fetch(`/requests/${rid}`)).json();
  const lastJob = detail.jobs.filter(j => j.status === '성공').pop();
  let html = '';
  if (lastJob && lastJob.result_location.startsWith('session:')) {
    html += `<button onclick="attachSession('${esc(lastJob.result_location.slice(8))}')">결과 채팅 열기</button>`;
  }
  html += `<button onclick="confirmRequest(${rid})">확인 완료</button>
           <button onclick="requestRework(${rid})">수정 요청</button>`;
  el.innerHTML = html;
}

async function confirmRequest(rid) {
  const r = await fetch(`/requests/${rid}/confirm`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ actor: currentUser() }),
  });
  if (!r.ok) alert((await r.json()).detail || '실패');
  loadMyRequests();
}

async function requestRework(rid) {
  const comment = prompt('수정 요청 내용') || '';
  const r = await fetch(`/requests/${rid}/rework`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ actor: currentUser(), comment }),
  });
  if (!r.ok) alert((await r.json()).detail || '실패');
  loadMyRequests();
}

// Task 8에서 구현 — 운영 탭 진입 시 no-op 방지용 안전 정의
function loadQueue() {}
```

- [ ] **Step 4: Append styles to `static/styles.css`**

```css
/* --- 운영 허브 셸 --- */
header { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.identity { display: flex; gap: 8px; align-items: center; }
.identity input, .identity select { padding: 6px 8px; }
.two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; align-items: start; }
@media (max-width: 900px) { .two-col { grid-template-columns: 1fr; } }
.panel { border: 1px solid var(--border, #ddd); border-radius: 8px; padding: 16px; }
.panel h2 { margin-top: 0; }
#reqForm label { display: block; margin: 8px 0 4px; }
#reqForm input:not([type=checkbox]), #reqForm textarea, #reqForm select { width: 100%; padding: 6px 8px; box-sizing: border-box; }
#reqForm .check { display: flex; gap: 6px; align-items: center; }
.req-row { border-bottom: 1px solid var(--border, #eee); padding: 8px 0; }
.req-head { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
.req-actions { margin-top: 6px; display: flex; gap: 6px; flex-wrap: wrap; }
.status-chip { font-size: 12px; padding: 2px 8px; border-radius: 999px; border: 1px solid transparent; }
.st-new { background: #eef2ff; color: #3730a3; }
.st-review { background: #fef9c3; color: #854d0e; }
.st-ready { background: #ecfdf5; color: #065f46; }
.st-running { background: #e0f2fe; color: #075985; }
.st-check { background: #fff7ed; color: #9a3412; }
.st-done { background: #f1f5f9; color: #334155; }
.st-hold { background: #fee2e2; color: #991b1b; }
.risk { font-size: 12px; color: #9a3412; }
```

- [ ] **Step 5: Verify — suite + scripted smoke**

```bash
./.venv/bin/python -m pytest -q
OPENAI_API_KEY= OFFICE_HUB_LLM_BACKEND=codex OFFICE_HUB_DB=/tmp/hub-smoke.db \
  ./.venv/bin/python -m uvicorn hub.api:create_app --factory --port 8899 &
sleep 2
curl -s http://127.0.0.1:8899/ | head -3            # <!doctype html ...
curl -s -X POST http://127.0.0.1:8899/requests -H 'Content-Type: application/json' \
  -d '{"requester_name":"김선생","title":"스모크"}'   # {"id":1,...,"status":"접수됨"}
curl -s "http://127.0.0.1:8899/requests?requester=%EA%B9%80%EC%84%A0%EC%83%9D"
kill %1
```

Browser checklist (manual, note results in commit body if anything is off): 요청 폼 제출 → 접수 메시지 + 파일 첨부 박스; 헤더 이름 입력 후 내 요청 목록 갱신; 역할 FDE 선택 시 운영 탭 표시(빈 동작은 Task 8 전까지 정상); 채팅/카탈로그 탭 기존 동작 유지.

- [ ] **Step 6: Commit**

```bash
git add static
git commit -m "feat(ui): hub shell with role switcher + requester tab (form, list, confirm/rework)"
```

---

### Task 8: Frontend — 운영 tab (FDE screen) + chat attach

**Files:**
- Modify: `static/ops.js` (replace the `loadQueue` stub with real implementation below)

**Interfaces:**
- Consumes: `GET /requests`, `GET /requests/{id}`, `GET /templates`, `POST /requests/{id}/review|approvals|jobs|hold|resume`, `attachSession(sid)` from Task 7.
- Produces: working FDE queue/detail screen.

- [ ] **Step 1: Replace the `loadQueue() {}` stub at the bottom of `static/ops.js`**

```js
let _selectedRequest = null;
let _templates = null;

async function loadQueue() {
  const box = document.getElementById('queue');
  const r = await fetch('/requests');
  if (!r.ok) { box.textContent = '큐를 불러오지 못했습니다.'; return; }
  const items = (await r.json()).requests;
  if (!items.length) { box.textContent = '요청이 없습니다.'; return; }
  box.innerHTML = items.map(q => `
    <div class="req-row queue-row" onclick="openDetail(${q.id})">
      <div class="req-head">#${q.id} ${esc(q.title)} ${statusChip(q.status)}
        <span class="muted">${esc(q.requester_name)}</span>
        ${q.risk_level ? `<span class="risk">위험도 ${esc(q.risk_level)}</span>` : ''}
        ${q.contains_personal_data ? '<span class="risk">개인정보</span>' : ''}</div>
    </div>`).join('');
  if (_selectedRequest) openDetail(_selectedRequest);
}

async function getTemplates() {
  if (!_templates) _templates = (await (await fetch('/templates')).json()).templates;
  return _templates;
}

async function openDetail(rid) {
  _selectedRequest = rid;
  const el = document.getElementById('opsDetail');
  const r = await fetch(`/requests/${rid}`);
  if (!r.ok) { el.textContent = '상세를 불러오지 못했습니다.'; return; }
  const d = await r.json();
  const q = d.request;
  const templates = await getTemplates();

  const fields = [
    ['요청자', q.requester_name], ['소속', q.department], ['목적', q.description],
    ['입력 자료', q.input_location], ['결과물', q.output_format],
    ['반복 주기', q.repeat_cycle], ['마감', q.due_at],
    ['개인정보', q.contains_personal_data ? '포함' : '없음'],
    ['외부 로그인', q.requires_external_login ? '필요' : '불필요'],
    ['확인 지점', q.human_check_point],
  ].filter(([, v]) => v).map(([k, v]) => `<div><b>${k}</b> ${esc(v)}</div>`).join('');

  const reviewForm = ['접수됨', '검토 중'].includes(q.status) ? `
    <div class="ops-block"><h3>검토</h3>
      <select id="riskSel">
        ${['낮음', '중간', '높음'].map(x => `<option>${x}</option>`).join('')}
      </select>
      <select id="tmplSel">
        ${templates.map(t => `<option value="${esc(t.id)}">${esc(t.name)}</option>`).join('')}
      </select>
      <button onclick="doReview(${rid})">검토 완료 → 자동화 가능</button>
    </div>` : '';

  const approvalBlock = q.risk_level === '높음' ? `
    <div class="ops-block"><h3>승인 (위험도 높음)</h3>
      ${d.approvals.map(a => `<div>${esc(a.approver)} · ${esc(a.status)} ${esc(a.comment)}</div>`).join('') || '<div>기록 없음</div>'}
      <input id="apComment" placeholder="승인 의견">
      <button onclick="doApprove(${rid}, '승인')">승인</button>
      <button onclick="doApprove(${rid}, '반려')">반려</button>
    </div>` : '';

  const runBlock = q.status === '자동화 가능' ? `
    <div class="ops-block"><button onclick="doRun(${rid})">▶ 실행 (${esc(q.template_id || '')})</button></div>` : '';

  const jobs = d.jobs.length ? d.jobs.map(j => `
    <div class="job-row">작업 #${j.id} · ${esc(j.status)}
      ${j.result_location.startsWith('session:')
        ? `<button onclick="attachSession('${esc(j.result_location.slice(8))}')">채팅 열기</button>`
        : esc(j.result_location)}
      ${j.error_message ? `<div class="err">${esc(j.error_message)}</div>` : ''}
      ${j.detail ? `<div class="muted">${esc(j.detail)}</div>` : ''}
    </div>`).join('') : '<div>없음</div>';

  const holdBlock = q.status === '보류'
    ? `<button onclick="doSimple(${rid}, 'resume')">보류 해제</button>`
    : (['완료', '실행 중'].includes(q.status) ? ''
       : `<button onclick="doSimple(${rid}, 'hold')">보류</button>`);
  const confirmBlock = q.status === '검수 대기'
    ? `<button onclick="doSimple(${rid}, 'confirm')">완료 처리</button>` : '';

  const audit = d.audit.map(a =>
    `<li>${esc(a.created_at)} · ${esc(a.actor)} · ${esc(a.action)} ${esc(a.detail)}</li>`).join('');

  el.innerHTML = `
    <h3>#${q.id} ${esc(q.title)} ${statusChip(q.status)}</h3>
    ${fields}
    <div><b>첨부</b> ${d.files.map(esc).join(', ') || '없음'}</div>
    ${reviewForm}${approvalBlock}${runBlock}
    <div class="ops-block"><h3>작업</h3>${jobs}</div>
    <div class="ops-block">${confirmBlock} ${holdBlock}</div>
    <div class="ops-block"><h3>감사 로그</h3><ul class="audit">${audit}</ul></div>`;
}

async function _post(url, body) {
  const r = await fetch(url, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!r.ok) alert((await r.json()).detail || '실패');
  loadQueue();
}

function doReview(rid) {
  _post(`/requests/${rid}/review`, {
    actor: currentUser(),
    risk_level: document.getElementById('riskSel').value,
    template_id: document.getElementById('tmplSel').value,
  });
}
function doApprove(rid, status) {
  _post(`/requests/${rid}/approvals`, {
    approver: currentUser(), status,
    comment: document.getElementById('apComment').value.trim(),
  });
}
function doRun(rid) { _post(`/requests/${rid}/jobs`, { actor: currentUser() }); }
function doSimple(rid, action) { _post(`/requests/${rid}/${action}`, { actor: currentUser() }); }
```

- [ ] **Step 2: Append styles to `static/styles.css`**

```css
.queue-row { cursor: pointer; }
.queue-row:hover { background: rgba(0, 0, 0, 0.03); }
.muted { color: #64748b; font-size: 12px; }
.err { color: #b91c1c; font-size: 13px; }
.ops-block { margin-top: 12px; padding-top: 8px; border-top: 1px dashed var(--border, #ddd); }
.ops-block h3 { margin: 0 0 6px; font-size: 14px; }
.job-row { padding: 4px 0; }
ul.audit { margin: 0; padding-left: 18px; font-size: 12px; }
```

- [ ] **Step 3: Verify — suite + manual end-to-end walkthrough**

```bash
./.venv/bin/python -m pytest -q
OPENAI_API_KEY= OFFICE_HUB_LLM_BACKEND=codex OFFICE_HUB_DB=/tmp/hub-smoke2.db \
  ./.venv/bin/python -m uvicorn hub.api:create_app --factory --port 8899
```

Browser walkthrough (the phase-1 acceptance scenario — MVP success criteria 1/2/5):
1. 이름 "김선생", 역할 요청자 → 요청 제출(개인정보 체크) + xlsx 첨부.
2. 역할 FDE로 전환 → 운영 탭 → 요청 선택 → 위험도 "낮음" 선택 시 검토가 422로 거부되는지(개인정보), "높음" + 채팅 답변 템플릿으로 검토 완료.
3. 실행 버튼 → 승인 없음 409 알림 확인 → 승인 기록 → 실행 → 작업 성공, 상태 "검수 대기".
4. "채팅 열기" → 채팅 탭에 소스 파일 표시, 질문(codex 로그인 시) 근거 답변.
5. FDE로 "완료 처리" 시 403(위험도 높음) → 역할/이름을 "김선생" 요청자로 바꿔 확인 완료 → 상태 "완료".
6. 감사 로그에 submitted/reviewed/approval/job/confirmed 행이 시간순으로 남는지.

- [ ] **Step 4: Commit**

```bash
git add static
git commit -m "feat(ui): FDE ops tab — queue, review, approval, run, audit; chat attach"
```

---

### Task 9: Docs + wrap-up

**Files:**
- Modify: `README.md`, `CLAUDE.md`

**Interfaces:** none (documentation).

- [ ] **Step 1: Update `README.md`**

Rewrite the title/intro and add an operations section; keep existing 설치/실행/테스트 sections intact (paths unchanged). New intro:

```markdown
# Office Hub — 부서 업무자동화 허브

선생님이 요청서를 제출하면 FDE가 검토·위험도 분류 후 템플릿으로 실행하고,
결과를 요청자가 확인하는 운영 허브. 모든 상태 전이는 SQLite에 영속되고
감사 로그가 남는다. 첫 템플릿은 "채팅 답변"(파일 기반 근거 질의응답)이며,
모든 수치는 결정론적 툴이 계산한다 — LLM은 구조·해석만 담당한다.

## 운영 흐름 (phase 1)

접수됨 → 검토 중 → 자동화 가능 → 실행 중 → 검수 대기 → 완료 (언제든 보류 가능)

- 위험도 낮음: FDE가 실행·완료 처리 가능
- 위험도 중간: 완료 확인은 요청자 본인만
- 위험도 높음: 승인 기록이 있어야 실행 가능
- 개인정보 포함 요청은 위험도 중간 이상 강제

DB: `data/hub.db` (env `OFFICE_HUB_DB`). 요청 파일: `runs/request-<id>/input/`.
```

Also note under 한계: 스트리밍/비용 기록/추가 템플릿(엑셀 정리·파일 취합)/지표 화면은 phase 2-3.

- [ ] **Step 2: Update `CLAUDE.md` (agent notes)**

Add to 알아둘 것:

```markdown
- 구조: hub/core(결정론 엔진) · hub/llm(LLM 어댑터) · hub/ops(운영 도메인: 요청/작업/승인/감사, SQLite) · hub/api(라우터).
- 운영 상태 문자열(접수됨/검토 중/…)과 위험도(낮음/중간/높음)는 API 값 — 임의 변경 금지.
- OFFICE_HUB_DB(기본 data/hub.db). 테스트는 항상 tmp_path db를 주입한다.
```

- [ ] **Step 3: Final verification + commit**

```bash
./.venv/bin/python -m pytest -q          # 전체 green 확인 (기존 ~90 + 신규 ~25)
git add README.md CLAUDE.md
git commit -m "docs: operational hub flow, structure, db config"
```

---

## Plan Self-Review Notes

- Spec coverage (phase 1 scope from overview.md): ops domain+SQLite ✓ (T3-5), request intake ✓ (T6-7), FDE review+risk gates ✓ (T4/T6/T8), chat-answer template wrapper ✓ (T5), 요청/운영 screens ✓ (T7-8), restructure core/llm/api ✓ (T1-2), engine cleanups ✓ (T1, context-threading deferred to phase 3 with reason), audit on every transition ✓ (T4-6). Metrics/cost/extra templates/지표 tab are phase 2 by design.
- MVP success criteria landed: 요청서 제출(1) ✓, FDE 검토·분류(2) ✓, 사람 검수 게이트(5) ✓. (3)(4)(6) are phase 2 per overview.
- Naming consistency verified across tasks: `OpsStore`, `execute`, `RunContext`, `RunResult`, `RUNNERS`, `TEMPLATE_INFO`, `read_validated`, `chat_router`, `catalog_router`, `ops_router`, `attachSession`, `esc`, `loadQueue`, `loadMyRequests`, status strings.
