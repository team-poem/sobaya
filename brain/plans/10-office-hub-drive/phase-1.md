# Drive Phase 1 Implementation Plan — 내 드라이브 + 폴더 채팅 + 열람 뷰어

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per-user drive (folders + files) with folder-scoped chat and a read-only viewer for 한글/엑셀 files, as Phase 1 of spec `10-office-hub-drive/overview.md`.

**Architecture:** New `hub/drive/` package (path safety + conversion cache) and a `drive_router` in `hub/api/drive.py`, mounted by `create_app` alongside the existing chat/ops routers. Drive contents are plain filesystem under `drives/{owner}/…` (env `OFFICE_HUB_DRIVES`); chat reuses the existing `SourceRegistry` + `/session/{sid}/ask` engine — the drive endpoint only creates a session and syncs the folder's files into it. Frontend adds a 4th nav segment 드라이브 with a file browser, chat panel, and viewer panel in `static/drive.js`.

**Tech Stack:** FastAPI, SQLite (audit via existing OpsStore), openpyxl, kordoc pipeline (existing), vanilla JS (no build), pytest + TestClient.

**Branch:** `drive/phase-1` off `ux/phase-a` (`git checkout ux/phase-a && git checkout -b drive/phase-1`)

## Global Constraints

- Operational strings byte-exact; this phase must not touch them: 접수됨/검토 중/자동화 가능/실행 중/검수 대기/완료/보류, 낮음/중간/높음, 승인/반려, 성공/실패.
- Server strings enter the DOM only via `el()`/`textContent`/`createTextNode` — **no innerHTML** in any new JS.
- Design tokens per spec 06: use existing `tokens.css` variables only; accent `#10a37f` reserved for running state/current step/evidence markers — do not introduce new accent uses.
- Original drive files are **never mutated** by the server.
- All path-taking endpoints guard traversal + null bytes with the established pattern (resolve → parent/ancestor check → 404 with Korean message).
- Uploads accept only supported formats (reuse `read_validated`): `.xlsx .xlsm .csv .hwp .hwpx .hwpml .pdf .docx`.
- Tests: always inject tmp `db_path`, `runs_dir`/`OFFICE_HUB_RUNS`, and tmp `drives_dir`; zero real LLM/network/kordoc calls (stub converter).
- The user's live server on port 8000 is managed by PID only — never `pkill -f uvicorn`. Test servers use ports 8765/8766/8767/8877 with throwaway DB, runs dir, and drives dir.
- Run tests with `./.venv/bin/python -m pytest -q` (venv required).
- Folder chat scope (open question resolved for Phase 1): **current folder only**, subfolders excluded.
- Known accepted limitation (record, don't fix): re-uploading a changed file with the same name does not refresh an already-created chat session's source (registry has no source replacement; Phase 2 workdoc addresses live state).
- Spec's "Metadata in SQLite" is satisfied by AUDIT records only (drive_file_uploaded/…via OpsStore); folder/file structure itself lives on the filesystem with no DB mirror — one source of truth, no sync bugs. (Deliberate narrowing of the spec sentence; recorded here so reviewers don't flag a missing table.)

## File Structure

- Create: `hub/drive/__init__.py` — empty package marker
- Create: `hub/drive/paths.py` — owner sanitizing + within-root path resolution (the one place traversal safety lives)
- Create: `hub/drive/convert.py` — cached kordoc conversion for the viewer (`ensure_converted`)
- Create: `hub/api/drive.py` — `drive_router(reg, cfg, store, drives_dir, doc_converter)` with list/folders/files/entry/move/chat/view endpoints
- Modify: `hub/api/__init__.py` — mount drive router; `drives_dir` param + `OFFICE_HUB_DRIVES` env; `doc_converter` passthrough
- Modify: `static/index.html` — 드라이브 segment + `v-drive` section + `drive.js` script tag
- Modify: `static/app.js` — add `'drive'` to SEGS + `loadDrive` hook
- Create: `static/drive.js` — file browser + folder chat + viewer
- Modify: `static/ui.css` — `.drive` styles appended
- Test: `tests/test_drive_paths.py`, `tests/test_api_drive_fs.py`, `tests/test_api_drive_chat.py`, `tests/test_api_drive_view.py`, `tests/e2e_drive_playwright.mjs` (manual-run E2E)

---

### Task 1: Path safety helpers (`hub/drive/paths.py`)

**Files:**
- Create: `hub/drive/__init__.py`
- Create: `hub/drive/paths.py`
- Test: `tests/test_drive_paths.py`

**Interfaces:**
- Produces: `safe_owner(owner: str) -> str` (raises `HTTPException(400)`), `resolve_within(root: Path, rel: str) -> Path` (raises `HTTPException(404)`). Every later task routes ALL user-supplied paths through these.

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_drive_paths.py
"""드라이브 경로 안전장치 — 모든 드라이브 엔드포인트가 지나는 관문."""
from pathlib import Path

import pytest
from fastapi import HTTPException

from hub.drive.paths import resolve_within, safe_owner


def test_safe_owner_passes_korean_name():
    assert safe_owner("김민지") == "김민지"
    assert safe_owner("  김민지  ") == "김민지"


@pytest.mark.parametrize("bad", ["", "  ", ".", "..", "a/b", "a\\b", "a\x00b"])
def test_safe_owner_rejects(bad):
    with pytest.raises(HTTPException) as e:
        safe_owner(bad)
    assert e.value.status_code == 400


def test_resolve_within_normal(tmp_path):
    (tmp_path / "폴더").mkdir()
    assert resolve_within(tmp_path, "폴더") == (tmp_path / "폴더").resolve()


def test_resolve_within_root_itself(tmp_path):
    assert resolve_within(tmp_path, "") == tmp_path.resolve()


@pytest.mark.parametrize("bad", ["../밖", "a/../../밖", "a\x00b"])
def test_resolve_within_escape_404(tmp_path, bad):
    with pytest.raises(HTTPException) as e:
        resolve_within(tmp_path, bad)
    assert e.value.status_code == 404
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./.venv/bin/python -m pytest tests/test_drive_paths.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'hub.drive'`

- [ ] **Step 3: Implement**

```python
# hub/drive/__init__.py
```

```python
# hub/drive/paths.py
from __future__ import annotations

from pathlib import Path

from fastapi import HTTPException


def safe_owner(owner: str) -> str:
    """드라이브 소유자 이름 → 디렉터리명으로 안전한 형태. 아니면 400."""
    o = owner.strip()
    if not o or o in {".", ".."} or "/" in o or "\\" in o or "\x00" in o:
        raise HTTPException(400, "잘못된 사용자 이름입니다")
    return o


def resolve_within(root: Path, rel: str) -> Path:
    """root 아래로만 경로 해석. 탈출·널바이트는 404 (존재 여부는 호출자가 판정)."""
    try:
        target = (root / rel.lstrip("/")).resolve()
        root_r = root.resolve()
    except (ValueError, OSError):
        raise HTTPException(404, "경로를 찾을 수 없습니다")
    if target != root_r and root_r not in target.parents:
        raise HTTPException(404, "경로를 찾을 수 없습니다")
    return target
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./.venv/bin/python -m pytest tests/test_drive_paths.py -q`
Expected: 8 passed

- [ ] **Step 5: Commit**

```bash
git add hub/drive/__init__.py hub/drive/paths.py tests/test_drive_paths.py
git commit -m "feat(drive): path safety helpers (safe_owner, resolve_within)"
```

---

### Task 2: Drive router skeleton — list + create folder + app wiring

**Files:**
- Create: `hub/api/drive.py`
- Modify: `hub/api/__init__.py`
- Test: `tests/test_api_drive_fs.py`

**Interfaces:**
- Consumes: `safe_owner`, `resolve_within` (Task 1).
- Produces: `drive_router(reg, cfg, store, drives_dir: str, doc_converter=None) -> APIRouter`; `create_app(..., drives_dir=None, doc_converter=None)`; `GET /drive/{owner}/list?path=` → `{"path", "folders": [str], "files": [{"name","size","modified"}]}`; `POST /drive/{owner}/folders` body `{"path","name"}` → list response of parent. Names starting with `.` or `_` are hidden from listings (kordoc cache lives in `_kordoc_out`).

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_api_drive_fs.py
"""내 드라이브 파일시스템 API — 목록/폴더/업로드/다운로드/삭제/이동."""
import pytest
from fastapi.testclient import TestClient

from hub.api import create_app


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("OFFICE_HUB_RUNS", str(tmp_path / "runs"))
    app = create_app(llm_factory=lambda cfg: None,
                     db_path=str(tmp_path / "hub.db"),
                     drives_dir=str(tmp_path / "drives"))
    return TestClient(app)


def test_list_empty_drive_returns_empty(client):
    r = client.get("/drive/김민지/list")
    assert r.status_code == 200
    assert r.json() == {"path": "", "folders": [], "files": []}


def test_list_missing_subfolder_404(client):
    assert client.get("/drive/김민지/list", params={"path": "없는폴더"}).status_code == 404


def test_create_folder_and_list(client):
    r = client.post("/drive/김민지/folders", json={"path": "", "name": "학사"})
    assert r.status_code == 201
    assert "학사" in r.json()["folders"]
    r2 = client.post("/drive/김민지/folders", json={"path": "학사", "name": "2026"})
    assert r2.status_code == 201
    assert client.get("/drive/김민지/list", params={"path": "학사"}).json()["folders"] == ["2026"]


@pytest.mark.parametrize("bad", ["..", "a/b", ".", "", "_kordoc_out"])
def test_create_folder_bad_name_400(client, bad):
    assert client.post("/drive/김민지/folders", json={"path": "", "name": bad}).status_code == 400


def test_owner_traversal_400(client):
    assert client.get("/drive/../list").status_code in (400, 404)


def test_list_path_traversal_404(client):
    assert client.get("/drive/김민지/list", params={"path": "../다른사람"}).status_code == 404
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./.venv/bin/python -m pytest tests/test_api_drive_fs.py -q`
Expected: FAIL — `create_app() got an unexpected keyword argument 'drives_dir'`

- [ ] **Step 3: Implement router skeleton**

```python
# hub/api/drive.py
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel

from hub.api.uploads import read_validated
from hub.core import tools
from hub.core.ingest import DOC_EXT, TABULAR_EXT, load_document, load_tabular
from hub.drive.convert import ensure_converted
from hub.drive.paths import resolve_within, safe_owner
from hub.session import SessionNotFound


class FolderBody(BaseModel):
    path: str = ""
    name: str


class MoveBody(BaseModel):
    src: str
    dst: str


class ChatBody(BaseModel):
    path: str = ""


def _visible(p: Path) -> bool:
    return not p.name.startswith(".") and not p.name.startswith("_")


def _entry_name_ok(name: str) -> bool:
    return bool(name) and name == Path(name).name and name not in {".", ".."} \
        and not name.startswith(".") and not name.startswith("_")


def drive_router(reg, cfg, store, drives_dir: str, doc_converter=None) -> APIRouter:
    r = APIRouter()
    # (owner, path) -> {"sid": str, "files": {filename: source_id}}
    _chats: dict[tuple[str, str], dict] = {}

    def _root(owner: str) -> Path:
        return Path(drives_dir) / safe_owner(owner)

    def _listing(root: Path, path: str) -> dict:
        d = resolve_within(root, path)
        if not d.is_dir():
            if path:
                raise HTTPException(404, "폴더를 찾을 수 없습니다")
            return {"path": "", "folders": [], "files": []}
        folders = sorted(p.name for p in d.iterdir() if p.is_dir() and _visible(p))
        files = sorted((
            {"name": p.name, "size": p.stat().st_size,
             "modified": datetime.fromtimestamp(p.stat().st_mtime, tz=timezone.utc).isoformat()}
            for p in d.iterdir() if p.is_file() and _visible(p)
        ), key=lambda f: f["name"])
        return {"path": path, "folders": folders, "files": files}

    @r.get("/drive/{owner}/list")
    def list_dir(owner: str, path: str = ""):
        return _listing(_root(owner), path)

    @r.post("/drive/{owner}/folders", status_code=201)
    def create_folder(owner: str, body: FolderBody):
        if not _entry_name_ok(body.name):
            raise HTTPException(400, "폴더 이름이 올바르지 않습니다")
        root = _root(owner)
        parent = resolve_within(root, body.path)
        if body.path and not parent.is_dir():
            raise HTTPException(404, "폴더를 찾을 수 없습니다")
        (parent / body.name).mkdir(parents=True, exist_ok=True)
        return _listing(root, body.path)

    return r
```

- [ ] **Step 4: Wire into `create_app`**

In `hub/api/__init__.py` add the import and mount. After the existing `runs_dir` line insert:

```python
    # 명시 인자 > OFFICE_HUB_DRIVES > 기본 "drives" (드라이브도 runs와 같은 격리 규칙)
    drives_dir = drives_dir or os.environ.get("OFFICE_HUB_DRIVES", "drives")
```

Change the signature to:

```python
def create_app(llm_factory=None, text_factory=None, catalog_path=None,
               runs_dir: str | None = None, db_path: str | None = None,
               runners: dict | None = None, drives_dir: str | None = None,
               doc_converter=None) -> FastAPI:
```

And after the ops router include add:

```python
    from hub.api.drive import drive_router
    app.include_router(drive_router(reg, cfg, store, drives_dir, doc_converter))
```

(Place the import at the top with the other `hub.api.*` imports; shown inline here only for locality.)

- [ ] **Step 5: Run tests**

Run: `./.venv/bin/python -m pytest tests/test_api_drive_fs.py -q`
Expected: all pass. Note: `hub/drive/convert.py` doesn't exist yet — for this task create it as a stub so the import resolves:

```python
# hub/drive/convert.py  (Task 5 replaces this stub with the real implementation)
from __future__ import annotations

from pathlib import Path

from fastapi import HTTPException


def ensure_converted(path: Path, converter=None) -> Path:
    raise HTTPException(501, "문서 뷰어는 아직 준비 중입니다")
```

Then run the full suite: `./.venv/bin/python -m pytest -q` — Expected: 169 + new tests, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add hub/api/drive.py hub/api/__init__.py hub/drive/convert.py tests/test_api_drive_fs.py
git commit -m "feat(drive): router skeleton — list + create folder, app wiring (OFFICE_HUB_DRIVES)"
```

---

### Task 3: File upload / download / delete / move (+ audit)

**Files:**
- Modify: `hub/api/drive.py`
- Test: `tests/test_api_drive_fs.py` (append)

**Interfaces:**
- Consumes: `read_validated` (existing), `store.add_audit(actor, action, target_type, target_id, detail)` (existing OpsStore).
- Produces: `POST /drive/{owner}/files?path=` (multipart `file`) → listing; `GET /drive/{owner}/file?path=` → FileResponse; `DELETE /drive/{owner}/entry?path=` → listing of parent (file: unlink; folder: only when no *visible* entries — hidden `_kordoc_out`/dotfiles are disposable and removed with it; otherwise 409); `POST /drive/{owner}/move` body `{"src","dst"}` → 200. Audit actions: `drive_file_uploaded`, `drive_entry_deleted`, `drive_entry_moved`, target_type `"drive"`, target_id `0`, detail `f"{owner}:{경로}"`.

- [ ] **Step 1: Append failing tests**

```python
# append to tests/test_api_drive_fs.py

def _upload(client, owner, path, name, data=b"a,b\n1,2\n"):
    return client.post(f"/drive/{owner}/files", params={"path": path},
                       files={"file": (name, data, "text/csv")})


def test_upload_download_roundtrip(client):
    r = _upload(client, "김민지", "", "성적.csv")
    assert r.status_code == 200
    assert [f["name"] for f in r.json()["files"]] == ["성적.csv"]
    dl = client.get("/drive/김민지/file", params={"path": "성적.csv"})
    assert dl.status_code == 200
    assert dl.content == b"a,b\n1,2\n"
    assert "attachment" in dl.headers["content-disposition"]


def test_upload_unsupported_ext_400(client):
    r = client.post("/drive/김민지/files", params={"path": ""},
                    files={"file": ("악성.exe", b"x", "application/octet-stream")})
    assert r.status_code == 400


def test_upload_into_missing_folder_404(client):
    assert _upload(client, "김민지", "없는폴더", "a.csv").status_code == 404


def test_download_traversal_404(client):
    _upload(client, "김민지", "", "성적.csv")
    assert client.get("/drive/김민지/file", params={"path": "../김민지/성적.csv"}).status_code == 404
    assert client.get("/drive/김민지/file", params={"path": "a\x00b.csv"}).status_code == 404


def test_delete_file(client):
    _upload(client, "김민지", "", "성적.csv")
    r = client.delete("/drive/김민지/entry", params={"path": "성적.csv"})
    assert r.status_code == 200
    assert r.json()["files"] == []


def test_delete_folder_only_when_visibly_empty(client):
    client.post("/drive/김민지/folders", json={"path": "", "name": "학사"})
    _upload(client, "김민지", "학사", "a.csv")
    assert client.delete("/drive/김민지/entry", params={"path": "학사"}).status_code == 409
    client.delete("/drive/김민지/entry", params={"path": "학사/a.csv"})
    assert client.delete("/drive/김민지/entry", params={"path": "학사"}).status_code == 200


def test_delete_root_rejected(client):
    assert client.delete("/drive/김민지/entry", params={"path": ""}).status_code == 400


def test_move_file(client):
    client.post("/drive/김민지/folders", json={"path": "", "name": "보관"})
    _upload(client, "김민지", "", "성적.csv")
    r = client.post("/drive/김민지/move", json={"src": "성적.csv", "dst": "보관/성적.csv"})
    assert r.status_code == 200
    assert client.get("/drive/김민지/list", params={"path": "보관"}).json()["files"][0]["name"] == "성적.csv"


def test_move_onto_existing_409(client):
    _upload(client, "김민지", "", "a.csv")
    _upload(client, "김민지", "", "b.csv")
    assert client.post("/drive/김민지/move", json={"src": "a.csv", "dst": "b.csv"}).status_code == 409
```

- [ ] **Step 2: Run to verify failures**

Run: `./.venv/bin/python -m pytest tests/test_api_drive_fs.py -q`
Expected: new tests FAIL with 404/405 (routes missing)

- [ ] **Step 3: Implement (add inside `drive_router`, after `create_folder`)**

```python
    @r.post("/drive/{owner}/files")
    async def upload(owner: str, path: str = "", file: UploadFile = File(...)):
        root = _root(owner)
        d = resolve_within(root, path)
        if path and not d.is_dir():
            raise HTTPException(404, "폴더를 찾을 수 없습니다")
        safe_name, data = await read_validated(file, cfg.max_upload_mb)
        d.mkdir(parents=True, exist_ok=True)
        (d / safe_name).write_bytes(data)
        store.add_audit(safe_owner(owner), "drive_file_uploaded", "drive", 0,
                        f"{safe_owner(owner)}:{path}/{safe_name}".replace("//", "/"))
        return _listing(root, path)

    @r.get("/drive/{owner}/file")
    def download(owner: str, path: str = ""):
        target = resolve_within(_root(owner), path)
        if not target.is_file():
            raise HTTPException(404, "파일을 찾을 수 없습니다")
        return FileResponse(target, filename=target.name)

    @r.delete("/drive/{owner}/entry")
    def delete_entry(owner: str, path: str = ""):
        if not path.strip("/"):
            raise HTTPException(400, "드라이브 최상위는 삭제할 수 없습니다")
        root = _root(owner)
        target = resolve_within(root, path)
        parent_rel = "/".join(path.strip("/").split("/")[:-1])
        if target.is_file():
            target.unlink()
        elif target.is_dir():
            if any(_visible(p) for p in target.iterdir()):
                raise HTTPException(409, "폴더가 비어 있지 않습니다")
            import shutil
            shutil.rmtree(target)  # 남은 항목은 숨김(_kordoc_out 등) — 같이 정리
        else:
            raise HTTPException(404, "경로를 찾을 수 없습니다")
        store.add_audit(safe_owner(owner), "drive_entry_deleted", "drive", 0,
                        f"{safe_owner(owner)}:{path}")
        return _listing(root, parent_rel)

    @r.post("/drive/{owner}/move")
    def move(owner: str, body: MoveBody):
        root = _root(owner)
        src = resolve_within(root, body.src)
        dst = resolve_within(root, body.dst)
        if not src.exists():
            raise HTTPException(404, "원본 경로를 찾을 수 없습니다")
        if not _entry_name_ok(dst.name):
            raise HTTPException(400, "대상 이름이 올바르지 않습니다")
        if dst.exists():
            raise HTTPException(409, "대상 경로에 이미 항목이 있습니다")
        if not dst.parent.is_dir():
            raise HTTPException(404, "대상 폴더를 찾을 수 없습니다")
        src.rename(dst)
        store.add_audit(safe_owner(owner), "drive_entry_moved", "drive", 0,
                        f"{safe_owner(owner)}:{body.src} → {body.dst}")
        return {"ok": True}
```

Move `import shutil` to the module top with the other imports.

- [ ] **Step 4: Run tests**

Run: `./.venv/bin/python -m pytest tests/test_api_drive_fs.py -q` then full `./.venv/bin/python -m pytest -q`
Expected: all pass

- [ ] **Step 5: Commit**

```bash
git add hub/api/drive.py tests/test_api_drive_fs.py
git commit -m "feat(drive): file upload/download/delete/move with traversal guards + audit"
```

---

### Task 4: Folder chat — create-or-sync session from folder files

**Files:**
- Modify: `hub/api/drive.py`
- Test: `tests/test_api_drive_chat.py`

**Interfaces:**
- Consumes: `reg.create_session/next_source_id/add_source/get_sources`, `load_tabular`, `load_document(path, sid, converter=…)`, `tools.list_sources`.
- Produces: `POST /drive/{owner}/chat` body `{"path"}` → `{"session_id", "sources": …, "skipped": [str]}`. Idempotent: same folder returns same session; files added later are ingested on next call; current folder only (no subfolders). The returned `session_id` is used with the EXISTING `/session/{sid}/ask` — no new ask endpoint.

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_api_drive_chat.py
"""폴더 채팅 — 폴더 파일을 소스로 하는 세션 생성·동기화."""
import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from hub.api import create_app


def _stub_converter(input_path: str) -> str:
    """kordoc 대역: document.md/blocks.json을 파일 옆 _kordoc_out에 만들어 준다."""
    src = Path(input_path)
    out = src.parent / "_kordoc_out" / src.name / "doc"
    out.mkdir(parents=True, exist_ok=True)
    (out / "document.md").write_text("# 제목\n\n본문 문단입니다.", encoding="utf-8")
    (out / "blocks.json").write_text(json.dumps([
        {"type": "heading", "text": "제목", "pageNumber": 1, "style": {"fontSize": 150}},
        {"type": "paragraph", "text": "본문 문단입니다.", "pageNumber": 1, "style": {"fontSize": 100}},
    ], ensure_ascii=False), encoding="utf-8")
    return str(out)


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("OFFICE_HUB_RUNS", str(tmp_path / "runs"))
    app = create_app(llm_factory=lambda cfg: None,
                     db_path=str(tmp_path / "hub.db"),
                     drives_dir=str(tmp_path / "drives"),
                     doc_converter=_stub_converter)
    return TestClient(app)


def _upload(client, path, name, data=b"a,b\n1,2\n"):
    return client.post("/drive/김민지/files", params={"path": path},
                       files={"file": (name, data, "text/csv")})


def test_chat_creates_session_with_folder_sources(client):
    client.post("/drive/김민지/folders", json={"path": "", "name": "학사"})
    _upload(client, "학사", "성적.csv")
    r = client.post("/drive/김민지/chat", json={"path": "학사"})
    assert r.status_code == 200
    body = r.json()
    assert body["session_id"]
    names = [s["filename"] for s in body["sources"]["sources"]]
    assert names == ["성적.csv"]


def test_chat_is_idempotent_and_syncs_new_files(client):
    _upload(client, "", "a.csv")
    r1 = client.post("/drive/김민지/chat", json={"path": ""})
    _upload(client, "", "b.csv")
    r2 = client.post("/drive/김민지/chat", json={"path": ""})
    assert r1.json()["session_id"] == r2.json()["session_id"]
    names = [s["filename"] for s in r2.json()["sources"]["sources"]]
    assert sorted(names) == ["a.csv", "b.csv"]


def test_chat_excludes_subfolder_files(client):
    client.post("/drive/김민지/folders", json={"path": "", "name": "하위"})
    _upload(client, "", "루트.csv")
    _upload(client, "하위", "하위.csv")
    r = client.post("/drive/김민지/chat", json={"path": ""})
    names = [s["filename"] for s in r.json()["sources"]["sources"]]
    assert names == ["루트.csv"]


def test_chat_ingests_documents_via_converter(client):
    _upload(client, "", "공문.hwpx", data=b"HWPX-BYTES")
    r = client.post("/drive/김민지/chat", json={"path": ""})
    src = r.json()["sources"]["sources"][0]
    assert src["filename"] == "공문.hwpx"
    assert src["kind"] == "document"


def test_chat_missing_folder_404(client):
    assert client.post("/drive/김민지/chat", json={"path": "없는폴더"}).status_code == 404


def test_chat_session_usable_with_existing_ask_contract(client):
    _upload(client, "", "a.csv")
    sid = client.post("/drive/김민지/chat", json={"path": ""}).json()["session_id"]
    r = client.get(f"/session/{sid}/sources")
    assert r.status_code == 200
```

(Shape verified against `hub/core/tools.py`: `list_sources` returns `{"sources": [{"source_id","filename","kind","status",…}]}` — the assertions above match it.)

- [ ] **Step 2: Run to verify failures**

Run: `./.venv/bin/python -m pytest tests/test_api_drive_chat.py -q`
Expected: FAIL 404 (route missing)

- [ ] **Step 3: Implement (add inside `drive_router`)**

```python
    @r.post("/drive/{owner}/chat")
    def folder_chat(owner: str, body: ChatBody):
        o = safe_owner(owner)
        root = _root(owner)
        d = resolve_within(root, body.path)
        if not d.is_dir():
            raise HTTPException(404, "폴더를 찾을 수 없습니다")
        key = (o, body.path.strip("/"))
        ent = _chats.get(key)
        if ent is not None:
            try:
                reg.get_sources(ent["sid"])
            except SessionNotFound:
                ent = None
        if ent is None:
            ent = {"sid": reg.create_session(), "files": {}}
            _chats[key] = ent
        skipped: list[str] = []
        for p in sorted(x for x in d.iterdir() if x.is_file() and _visible(x)):
            ext = p.suffix.lower()
            if ext not in TABULAR_EXT and ext not in DOC_EXT:
                continue
            if p.name in ent["files"]:
                continue
            src_id = reg.next_source_id(ent["sid"])
            try:
                if ext in TABULAR_EXT:
                    reg.add_source(ent["sid"], load_tabular(str(p), src_id))
                else:
                    reg.add_source(ent["sid"], load_document(str(p), src_id,
                                                             converter=doc_converter))
            except Exception:
                skipped.append(p.name)
                continue
            ent["files"][p.name] = src_id
        return {"session_id": ent["sid"],
                "sources": tools.list_sources(reg, ent["sid"]),
                "skipped": skipped}
```

- [ ] **Step 4: Run tests**

Run: `./.venv/bin/python -m pytest tests/test_api_drive_chat.py -q` then full suite `-q`
Expected: all pass

- [ ] **Step 5: Commit**

```bash
git add hub/api/drive.py tests/test_api_drive_chat.py
git commit -m "feat(drive): folder chat — create-or-sync session from folder files"
```

---

### Task 5: Viewer API — tabular grid + document blocks with conversion cache

**Files:**
- Modify: `hub/drive/convert.py` (replace Task 2 stub)
- Modify: `hub/api/drive.py`
- Test: `tests/test_api_drive_view.py`

**Interfaces:**
- Consumes: `KORDOC_PIPELINE` (from `hub.core.ingest`), `load_tabular`.
- Produces: `ensure_converted(path: Path, converter=None) -> Path` (out dir containing blocks.json; caches under `<parent>/_kordoc_out/<filename>/`, reconverts when the source file is newer); `GET /drive/{owner}/view?path=&offset=0&limit=500` →
  - tabular: `{"kind":"tabular","filename",…,"sheets":[{"name","columns":[str],"rows":[[cell,…]],"total_rows":int}]}` (rows capped at 200 per sheet)
  - document: `{"kind":"document","filename","total":int,"offset":int,"blocks":[…kordoc block objects…]}` (slice `offset:offset+limit`)

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_api_drive_view.py
"""열람 뷰어 API — 표 그리드와 kordoc 블록."""
import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from hub.api import create_app
from hub.drive.convert import ensure_converted

CONVERT_CALLS = []


def _stub_converter(input_path: str) -> str:
    CONVERT_CALLS.append(input_path)
    src = Path(input_path)
    out = src.parent / "_kordoc_out" / src.name / "doc"
    out.mkdir(parents=True, exist_ok=True)
    blocks = [{"type": "heading", "text": "표지", "pageNumber": 1, "style": {"fontSize": 150}}] + [
        {"type": "paragraph", "text": f"문단 {i}", "pageNumber": 1 + i // 5,
         "style": {"fontSize": 100}} for i in range(30)
    ] + [{"type": "table", "pageNumber": 9, "table": {"rows": 1, "cols": 2, "cells": [[
        {"text": "가", "colSpan": 1, "rowSpan": 1}, {"text": "나", "colSpan": 1, "rowSpan": 1}]]}}]
    (out / "blocks.json").write_text(json.dumps(blocks, ensure_ascii=False), encoding="utf-8")
    (out / "document.md").write_text("표지\n\n문단", encoding="utf-8")
    return str(out)


@pytest.fixture
def client(tmp_path, monkeypatch):
    CONVERT_CALLS.clear()
    monkeypatch.setenv("OFFICE_HUB_RUNS", str(tmp_path / "runs"))
    app = create_app(llm_factory=lambda cfg: None,
                     db_path=str(tmp_path / "hub.db"),
                     drives_dir=str(tmp_path / "drives"),
                     doc_converter=_stub_converter)
    return TestClient(app)


def test_view_tabular_grid(client):
    client.post("/drive/김민지/files", params={"path": ""},
                files={"file": ("성적.csv", "이름,점수\n민지,90\n하나,85\n".encode(), "text/csv")})
    r = client.get("/drive/김민지/view", params={"path": "성적.csv"})
    assert r.status_code == 200
    b = r.json()
    assert b["kind"] == "tabular"
    sheet = b["sheets"][0]
    assert sheet["columns"] == ["이름", "점수"]
    assert sheet["rows"][0] == ["민지", 90]
    assert sheet["total_rows"] == 2


def test_view_document_blocks_paged(client):
    client.post("/drive/김민지/files", params={"path": ""},
                files={"file": ("공문.hwpx", b"HWPX", "application/octet-stream")})
    r = client.get("/drive/김민지/view", params={"path": "공문.hwpx", "offset": 0, "limit": 10})
    assert r.status_code == 200
    b = r.json()
    assert b["kind"] == "document"
    assert b["total"] == 32
    assert len(b["blocks"]) == 10
    assert b["blocks"][0]["type"] == "heading"
    r2 = client.get("/drive/김민지/view", params={"path": "공문.hwpx", "offset": 30, "limit": 10})
    assert [x["type"] for x in r2.json()["blocks"]] == ["paragraph", "table"]


def test_view_document_conversion_cached(client):
    client.post("/drive/김민지/files", params={"path": ""},
                files={"file": ("공문.hwpx", b"HWPX", "application/octet-stream")})
    client.get("/drive/김민지/view", params={"path": "공문.hwpx"})
    client.get("/drive/김민지/view", params={"path": "공문.hwpx"})
    assert len(CONVERT_CALLS) == 1


def test_view_missing_file_404(client):
    assert client.get("/drive/김민지/view", params={"path": "없음.hwpx"}).status_code == 404


def test_view_unsupported_ext_400(client, tmp_path):
    drive = tmp_path / "drives" / "김민지"
    drive.mkdir(parents=True, exist_ok=True)
    (drive / "메모.txt").write_text("x", encoding="utf-8")
    assert client.get("/drive/김민지/view", params={"path": "메모.txt"}).status_code == 400


def test_ensure_converted_reconverts_when_source_newer(tmp_path):
    calls = []

    def conv(p):
        calls.append(p)
        out = Path(p).parent / "_kordoc_out" / Path(p).name / "doc"
        out.mkdir(parents=True, exist_ok=True)
        (out / "blocks.json").write_text("[]", encoding="utf-8")
        return str(out)

    f = tmp_path / "a.hwpx"
    f.write_bytes(b"1")
    ensure_converted(f, conv)
    ensure_converted(f, conv)
    assert len(calls) == 1
    import os as _os
    blocks = tmp_path / "_kordoc_out" / "a.hwpx" / "doc" / "blocks.json"
    old = blocks.stat().st_mtime - 100
    _os.utime(blocks, (old, old))  # 캐시를 과거로 → 원본이 더 새로움
    f.write_bytes(b"22")
    ensure_converted(f, conv)
    assert len(calls) == 2
```

- [ ] **Step 2: Run to verify failures**

Run: `./.venv/bin/python -m pytest tests/test_api_drive_view.py -q`
Expected: FAIL (route missing, stub raises 501)

- [ ] **Step 3: Implement `ensure_converted` (replace stub)**

```python
# hub/drive/convert.py
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from fastapi import HTTPException

from hub.core.ingest import KORDOC_PIPELINE


def _run_kordoc(input_path: str, out_root: Path) -> str:
    subprocess.run([sys.executable, KORDOC_PIPELINE, input_path, "-o", str(out_root)],
                   check=True, capture_output=True)
    subdirs = [d for d in out_root.iterdir() if d.is_dir()]
    if not subdirs:
        raise RuntimeError("변환 산출물 폴더 없음")
    return str(max(subdirs, key=lambda d: d.stat().st_mtime))


def ensure_converted(path: Path, converter=None) -> Path:
    """뷰어용 kordoc 변환 (파일별 캐시). 반환: blocks.json이 있는 산출물 폴더."""
    out_root = path.parent / "_kordoc_out" / path.name
    if out_root.is_dir():
        fresh = [d for d in out_root.iterdir()
                 if d.is_dir() and (d / "blocks.json").is_file()
                 and (d / "blocks.json").stat().st_mtime >= path.stat().st_mtime]
        if fresh:
            return max(fresh, key=lambda d: (d / "blocks.json").stat().st_mtime)
    try:
        if converter is not None:
            return Path(converter(str(path)))
        out_root.mkdir(parents=True, exist_ok=True)
        return Path(_run_kordoc(str(path), out_root))
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(502, "문서 변환에 실패했습니다. 파일이 손상되지 않았는지 확인해 주세요")
```

- [ ] **Step 4: Implement the view endpoint (add inside `drive_router`)**

```python
    @r.get("/drive/{owner}/view")
    def view(owner: str, path: str = "", offset: int = 0, limit: int = 500):
        target = resolve_within(_root(owner), path)
        if not target.is_file():
            raise HTTPException(404, "파일을 찾을 수 없습니다")
        ext = target.suffix.lower()
        if ext in TABULAR_EXT:
            src = load_tabular(str(target), "view")
            sheets = [{"name": s.name,
                       "columns": [c.name for c in s.columns],
                       "rows": [[row.get(c.name) for c in s.columns]
                                for row in s.rows[:200]],
                       "total_rows": len(s.rows)}
                      for s in src.sheets]
            return {"kind": "tabular", "filename": target.name, "sheets": sheets}
        if ext not in DOC_EXT:
            raise HTTPException(400, "뷰어가 지원하지 않는 형식입니다")
        out_dir = ensure_converted(target, doc_converter)
        blocks_path = out_dir / "blocks.json"
        blocks = []
        if blocks_path.is_file():
            import json as _json
            try:
                blocks = _json.loads(blocks_path.read_text(encoding="utf-8"))
            except _json.JSONDecodeError:
                blocks = []
        offset = max(0, offset)
        limit = max(1, min(limit, 1000))
        return {"kind": "document", "filename": target.name,
                "total": len(blocks), "offset": offset,
                "blocks": blocks[offset:offset + limit]}
```

Move `import json` to the module top with the other imports.

- [ ] **Step 5: Run tests**

Run: `./.venv/bin/python -m pytest tests/test_api_drive_view.py -q` then full suite `-q`
Expected: all pass

- [ ] **Step 6: Commit**

```bash
git add hub/drive/convert.py hub/api/drive.py tests/test_api_drive_view.py
git commit -m "feat(drive): viewer API — tabular grid + kordoc block view with per-file cache"
```

---

### Task 6: Shell + drive file browser UI

**Files:**
- Modify: `static/index.html`
- Modify: `static/app.js`
- Create: `static/drive.js`
- Modify: `static/ui.css` (append)

**Interfaces:**
- Consumes: `el(tag, cls, text)`, `currentUser()`, `go(name)` from ui.js/app.js; Task 2/3 endpoints.
- Produces: view `v-drive`, segment `seg-drive`, `loadDrive()` global (called by `go('drive')`), module state `_dPath` (current folder), `_dRefresh()` used by Tasks 7–8. DOM ids: `dCrumbs dNewFolder dUpload dFilesInput dErr dList dSide dViewer dChatWrap dThread dText dSend dChatHint`.

- [ ] **Step 1: index.html — nav segment**

In the `<nav class="seg">` add after the 작업 공간 button:

```html
      <button id="seg-drive" onclick="go('drive')">드라이브</button>
```

- [ ] **Step 2: index.html — view section** (before the drawer overlay, after `v-work`):

```html
  <!-- 드라이브: 폴더 베이스 파일 공간 + 폴더 채팅 + 뷰어 (plan 10 phase 1) -->
  <section id="v-drive" class="drive" hidden>
    <div class="drive-head">
      <div class="crumbs" id="dCrumbs"></div>
      <div class="drive-acts">
        <input type="file" id="dFilesInput" multiple hidden>
        <button class="b-ghost" id="dNewFolder">새 폴더</button>
        <button class="b-ghost" id="dUpload">파일 올리기</button>
      </div>
    </div>
    <p class="composer-err" id="dErr" hidden></p>
    <div class="drive-grid">
      <div class="dlist" id="dList"></div>
      <div class="dside" id="dSide">
        <div class="dviewer" id="dViewer" hidden></div>
        <div class="dchat" id="dChatWrap">
          <div class="thread" id="dThread"></div>
          <div class="work-composer">
            <div class="wc-inner">
              <textarea id="dText" placeholder="이 폴더의 파일에 대해 물어보거나 문서작업을 요청하세요"></textarea>
              <button class="send" id="dSend" title="보내기" disabled>↑</button>
            </div>
            <p class="hint" id="dChatHint">채팅을 보내면 이 폴더의 파일들을 읽고 답해요.</p>
          </div>
        </div>
      </div>
    </div>
  </section>
```

And add `<script src="/static/drive.js"></script>` after the workspace.js tag.

- [ ] **Step 3: app.js — register the segment**

```js
const SEGS = ['counter', 'console', 'work', 'drive'];
```

and in `go(...)` add:

```js
  if (name === 'drive' && typeof loadDrive === 'function') loadDrive();
```

- [ ] **Step 4: drive.js — file browser core**

```js
// drive.js — 내 드라이브 (plan 10 phase 1). 폴더 브라우저 + 폴더 채팅 + 뷰어.

let _dPath = '';
let _dOwner = '';

function driveError(msg) {
  const e = document.getElementById('dErr');
  e.hidden = !msg;
  e.textContent = msg || '';
}

function _dUrl(route, params) {
  const q = new URLSearchParams(params || {});
  return '/drive/' + encodeURIComponent(_dOwner) + '/' + route +
    (q.toString() ? '?' + q.toString() : '');
}

function fmtSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return Math.round(bytes / 1024) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

function loadDrive() {
  const name = currentUser();
  if (name === '이름없음') {
    document.getElementById('dList').replaceChildren(
      el('div', 'empty', '오른쪽 위에 이름을 입력하면 내 드라이브가 열려요.'));
    document.getElementById('dCrumbs').replaceChildren();
    return;
  }
  if (name !== _dOwner) { _dOwner = name; _dPath = ''; dResetChat(); }
  _dRefresh();
}

async function _dRefresh() {
  driveError('');
  let data;
  try {
    const r = await fetch(_dUrl('list', { path: _dPath }));
    if (!r.ok) {
      if (r.status === 404 && _dPath) { _dPath = ''; return _dRefresh(); }
      driveError('목록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.');
      return;
    }
    data = await r.json();
  } catch (e) {
    console.error(e);
    driveError('네트워크 오류가 발생했어요. 잠시 후 다시 시도해 주세요.');
    return;
  }
  renderCrumbs();
  renderList(data);
}

function renderCrumbs() {
  const box = document.getElementById('dCrumbs');
  box.replaceChildren();
  const segs = _dPath ? _dPath.split('/') : [];
  const rootBtn = el('button', 'crumb', '내 드라이브');
  rootBtn.onclick = function () { dGo(''); };
  box.appendChild(rootBtn);
  segs.forEach(function (seg, i) {
    box.appendChild(el('span', 'crumb-sep', '/'));
    const b = el('button', 'crumb', seg);
    b.onclick = function () { dGo(segs.slice(0, i + 1).join('/')); };
    box.appendChild(b);
  });
}

function dGo(path) {
  if (path !== _dPath) { _dPath = path; dResetChat(); closeViewer(); }
  _dRefresh();
}

function renderList(data) {
  const box = document.getElementById('dList');
  box.replaceChildren();
  if (!data.folders.length && !data.files.length) {
    box.appendChild(el('div', 'empty',
      '비어 있어요. “파일 올리기”로 파일을 얹으면 채팅과 뷰어에서 바로 쓸 수 있어요.'));
    return;
  }
  data.folders.forEach(function (name) {
    const row = el('div', 'drow folder');
    const open = el('button', 'dname', '📁 ' + name);
    open.onclick = function () { dGo(_dPath ? _dPath + '/' + name : name); };
    row.appendChild(open);
    row.appendChild(dDeleteBtn(name, true));
    box.appendChild(row);
  });
  data.files.forEach(function (f) {
    const row = el('div', 'drow');
    const open = el('button', 'dname', f.name);
    open.title = '뷰어로 열기';
    open.onclick = function () { openViewer(f.name); };
    row.appendChild(open);
    row.appendChild(el('span', 'dmeta', fmtSize(f.size)));
    const dl = el('a', 'file-link', '내려받기');
    dl.href = _dUrl('file', { path: _dPath ? _dPath + '/' + f.name : f.name });
    dl.setAttribute('download', f.name);
    row.appendChild(dl);
    row.appendChild(dDeleteBtn(f.name, false));
    box.appendChild(row);
  });
}

function dDeleteBtn(name, isFolder) {
  const x = el('button', 'icon-btn ddel', '✕');
  x.title = isFolder ? '폴더 삭제 (비어 있을 때만)' : '파일 삭제';
  x.onclick = async function () {
    if (!confirm('"' + name + '" 을(를) 삭제할까요?')) return;
    try {
      const p = _dPath ? _dPath + '/' + name : name;
      const r = await fetch(_dUrl('entry', { path: p }), { method: 'DELETE' });
      if (!r.ok) {
        let detail = '';
        try { detail = (await r.json()).detail || ''; } catch (e) { /* not json */ }
        driveError('삭제하지 못했어요' + (detail ? ': ' + detail : ''));
      }
    } catch (e) {
      console.error(e);
      driveError('네트워크 오류가 발생했어요. 잠시 후 다시 시도해 주세요.');
    }
    _dRefresh();
  };
  return x;
}

document.getElementById('dNewFolder').onclick = async function () {
  if (currentUser() === '이름없음') { driveError('오른쪽 위에 이름을 먼저 입력해 주세요.'); return; }
  const name = (prompt('새 폴더 이름을 입력하세요') || '').trim();
  if (!name) return;
  try {
    const r = await fetch(_dUrl('folders', {}), {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ path: _dPath, name: name }),
    });
    if (!r.ok) {
      let detail = '';
      try { detail = (await r.json()).detail || ''; } catch (e) { /* not json */ }
      driveError('폴더를 만들지 못했어요' + (detail ? ': ' + detail : ''));
    }
  } catch (e) {
    console.error(e);
    driveError('네트워크 오류가 발생했어요. 잠시 후 다시 시도해 주세요.');
  }
  _dRefresh();
};

document.getElementById('dUpload').onclick = function () {
  if (currentUser() === '이름없음') { driveError('오른쪽 위에 이름을 먼저 입력해 주세요.'); return; }
  document.getElementById('dFilesInput').click();
};

document.getElementById('dFilesInput').onchange = async function (ev) {
  const files = Array.from(ev.target.files);
  ev.target.value = '';
  const failed = [];
  for (const f of files) {
    const fd = new FormData();
    fd.append('file', f);
    try {
      const r = await fetch(_dUrl('files', { path: _dPath }), { method: 'POST', body: fd });
      if (!r.ok) failed.push(f.name);
    } catch (e) { console.error(e); failed.push(f.name); }
  }
  if (failed.length) driveError('일부 파일을 올리지 못했어요: ' + failed.join(', '));
  _dRefresh();
};
```

(`dResetChat`/`closeViewer`/`openViewer` are defined in Tasks 7–8; for THIS task's commit define placeholders so the file parses:)

```js
function dResetChat() {}
function closeViewer() {}
function openViewer(name) {}
```

- [ ] **Step 5: ui.css — append drive styles**

```css
/* ── 드라이브 (plan 10 phase 1) ─────────────────────────── */
.drive { max-width: 1200px; margin: 0 auto; padding: 24px 20px; }
.drive-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.crumbs { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; }
.crumb { background: none; border: none; color: var(--text); cursor: pointer;
  font-size: 14px; padding: 4px 6px; border-radius: 6px; }
.crumb:hover { background: var(--bg-hover); }
.crumb-sep { color: var(--text-3); }
.drive-acts { display: flex; gap: 8px; }
.drive-grid { display: grid; grid-template-columns: minmax(280px, 1fr) minmax(360px, 1.2fr);
  gap: 20px; margin-top: 16px; align-items: start; }
.dlist { display: flex; flex-direction: column; gap: 2px; }
.drow { display: flex; align-items: center; gap: 10px; padding: 8px 10px;
  border-radius: 8px; }
.drow:hover { background: var(--bg-hover); }
.dname { background: none; border: none; color: var(--text); cursor: pointer;
  font-size: 14px; text-align: left; flex: 1; padding: 0;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.dmeta { color: var(--text-2); font-size: 12px; font-variant-numeric: tabular-nums; }
.ddel { opacity: 0; }
.drow:hover .ddel { opacity: 1; }
.dside { display: flex; flex-direction: column; gap: 12px; min-height: 400px; }
.dchat .thread { max-height: 50vh; overflow-y: auto; }
@media (max-width: 900px) { .drive-grid { grid-template-columns: 1fr; } }
```

(Token names verified against `tokens.css`: `--bg-hover`, `--line`, `--line-soft`, `--text`, `--text-2`, `--text-3` all exist — use exactly these; do not invent new tokens.)

- [ ] **Step 6: Verify + commit**

```bash
node --check static/drive.js && node --check static/app.js
# 격리 스모크 서버 (throwaway everything)
OFFICE_HUB_DB=/tmp/drive-t6.db OFFICE_HUB_RUNS=/tmp/drive-t6-runs OFFICE_HUB_DRIVES=/tmp/drive-t6-drives \
  OPENAI_API_KEY= OFFICE_HUB_LLM_BACKEND=codex ./.venv/bin/python -m uvicorn hub.api:create_app --factory --port 8765 &
sleep 2 && curl -s localhost:8765/ | grep -q 'seg-drive' && curl -s "localhost:8765/drive/%EA%B9%80%EB%AF%BC%EC%A7%80/list" && kill %1
git add static/index.html static/app.js static/drive.js static/ui.css
git commit -m "feat(drive): 드라이브 화면 — 파일 브라우저 (목록/폴더/업로드/삭제/내려받기)"
```

---

### Task 7: Folder chat UI

**Files:**
- Modify: `static/drive.js` (replace `dResetChat` placeholder, add chat wiring)

**Interfaces:**
- Consumes: `POST /drive/{owner}/chat` (Task 4), existing `POST /session/{sid}/ask` → `{"answer","citations":[{"filename","locator"}],"tool_calls","usage"}`.
- Produces: `dResetChat()` (clears thread + session), chat send flow with the same double-submit/error discipline as counter/workspace.

- [ ] **Step 1: Implement (replace the `dResetChat` placeholder)**

```js
// ── 폴더 채팅 ──────────────────────────────────────────────
let _dSession = null;
let _dAsking = false;

function dResetChat() {
  _dSession = null;
  document.getElementById('dThread').replaceChildren();
  document.getElementById('dChatHint').textContent = '채팅을 보내면 이 폴더의 파일들을 읽고 답해요.';
}

function dSyncSend() {
  const hasText = document.getElementById('dText').value.trim() !== '';
  document.getElementById('dSend').disabled = _dAsking || !hasText ||
    currentUser() === '이름없음';
}

// workspace.js와 같은 클래스(msg-user/msg-ai/evidence/ev-chip)를 그대로 재사용 —
// ui.css의 기존 채팅 스타일이 그대로 적용된다.
function dUserMsg(text) {
  const thread = document.getElementById('dThread');
  thread.appendChild(el('div', 'msg-user', text));
  thread.scrollTop = thread.scrollHeight;
}

function dAiMsg(body) {
  const thread = document.getElementById('dThread');
  const box = el('div', 'msg-ai', body.answer);
  if (body.citations && body.citations.length) {
    const ev = el('div', 'evidence');
    body.citations.forEach(function (c) {
      const chip = el('span', 'ev-chip');
      chip.appendChild(el('i', null, '▸'));
      chip.appendChild(document.createTextNode(c.filename + ' · ' + c.locator));
      chip.onclick = function () { toggleEvDetail(ev, c); };  // workspace.js 전역 재사용
      ev.appendChild(chip);
    });
    box.appendChild(ev);
  }
  if (body.tool_calls && body.tool_calls.length) {
    box.appendChild(el('div', 'msg-meta', '도구: ' + body.tool_calls.join(' · ')));
  }
  thread.appendChild(box);
  thread.scrollTop = thread.scrollHeight;
  return box;
}

async function dEnsureSession() {
  if (_dSession) return _dSession;
  const r = await fetch(_dUrl('chat', {}), {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ path: _dPath }),
  });
  if (!r.ok) throw new Error('chat session ' + r.status);
  const body = await r.json();
  _dSession = body.session_id;
  const n = (body.sources.sources || []).length;
  document.getElementById('dChatHint').textContent =
    n ? '이 폴더의 파일 ' + n + '개를 읽고 답해요.'
      : '이 폴더에 읽을 수 있는 파일이 없어요. 파일을 올린 뒤 물어보세요.';
  if (body.skipped && body.skipped.length) {
    driveError('읽지 못한 파일이 있어요: ' + body.skipped.join(', '));
  }
  return _dSession;
}

async function dAsk() {
  const ta = document.getElementById('dText');
  const q = ta.value.trim();
  if (!q || _dAsking) return;
  _dAsking = true;
  dSyncSend();
  driveError('');
  dUserMsg(q);
  ta.value = '';
  const thread = document.getElementById('dThread');
  const waiting = el('div', 'msg-ai', '…');
  thread.appendChild(waiting);
  try {
    const sid = await dEnsureSession();
    const r = await fetch('/session/' + sid + '/ask', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ question: q }),
    });
    waiting.remove();
    if (!r.ok) {
      let detail = '';
      try { detail = (await r.json()).detail || ''; } catch (e) { /* not json */ }
      thread.appendChild(el('div', 'msg-ai',
        '답변에 실패했어요' + (detail ? ': ' + detail : ' (' + r.status + ')')));
      return;
    }
    dAiMsg(await r.json());
  } catch (e) {
    console.error(e);
    waiting.remove();
    thread.appendChild(el('div', 'msg-ai', '네트워크 오류가 발생했어요. 잠시 후 다시 시도해 주세요.'));
  } finally {
    _dAsking = false;
    dSyncSend();
  }
}

document.getElementById('dText').oninput = dSyncSend;
document.getElementById('dText').onkeydown = function (ev) {
  if (ev.key === 'Enter' && !ev.shiftKey) { ev.preventDefault(); dAsk(); }
};
document.getElementById('dSend').onclick = dAsk;
```

(Class names verified against `static/workspace.js`: `msg-user`, `msg-ai`, `evidence`, `ev-chip`, `msg-meta`, and the global `toggleEvDetail(evBox, c)` — reuse them exactly; ui.css already styles them. `toggleEvDetail` is safe to call directly since workspace.js loads before drive.js in index.html.)

- [ ] **Step 2: Verify + commit**

```bash
node --check static/drive.js
./.venv/bin/python -m pytest -q   # 회귀 없음 확인
git add static/drive.js
git commit -m "feat(drive): 폴더 채팅 — 폴더 파일을 읽는 세션 생성·질문"
```

---

### Task 8: Viewer panel UI (document blocks + sheet grid)

**Files:**
- Modify: `static/drive.js` (replace `openViewer`/`closeViewer` placeholders)
- Modify: `static/ui.css` (append)

**Interfaces:**
- Consumes: `GET /drive/{owner}/view` (Task 5).
- Produces: `openViewer(name)` — fetches view data, renders into `#dViewer`, shows it above the chat; `closeViewer()`. Document render: heading→`h3`, paragraph→`p` (fontSize ≥ 120 → class `big`), page change → divider `— N쪽 —`, table→`<table>` with row/colSpan. Long docs: "더 보기" button loads the next 500 blocks. Tabular render: sheet name tabs + grid, truncation note when `rows.length < total_rows`.

- [ ] **Step 1: Implement (replace placeholders)**

```js
// ── 뷰어 ──────────────────────────────────────────────────
let _dViewFile = null;

function closeViewer() {
  _dViewFile = null;
  const v = document.getElementById('dViewer');
  v.hidden = true;
  v.replaceChildren();
}

function _viewerFrame(title) {
  const v = document.getElementById('dViewer');
  v.replaceChildren();
  v.hidden = false;
  const head = el('div', 'dv-head');
  head.appendChild(el('strong', null, title));
  const x = el('button', 'icon-btn', '✕');
  x.title = '뷰어 닫기';
  x.onclick = closeViewer;
  head.appendChild(x);
  v.appendChild(head);
  const body = el('div', 'dv-body');
  v.appendChild(body);
  return body;
}

async function openViewer(name) {
  const path = _dPath ? _dPath + '/' + name : name;
  _dViewFile = path;
  const body = _viewerFrame(name);
  body.appendChild(el('div', 'empty', '불러오는 중… (문서는 첫 열람 때 변환에 시간이 걸릴 수 있어요)'));
  let data;
  try {
    const r = await fetch(_dUrl('view', { path: path, offset: 0, limit: 500 }));
    if (_dViewFile !== path) return; // 다른 파일로 이동함
    if (!r.ok) {
      let detail = '';
      try { detail = (await r.json()).detail || ''; } catch (e) { /* not json */ }
      body.replaceChildren(el('div', 'empty', '열 수 없어요' + (detail ? ': ' + detail : '')));
      return;
    }
    data = await r.json();
  } catch (e) {
    console.error(e);
    body.replaceChildren(el('div', 'empty', '네트워크 오류가 발생했어요. 잠시 후 다시 시도해 주세요.'));
    return;
  }
  body.replaceChildren();
  if (data.kind === 'tabular') renderSheetView(body, data);
  else renderDocView(body, data, path);
}

function renderDocBlocks(container, blocks, state) {
  blocks.forEach(function (b) {
    if (b.pageNumber && b.pageNumber !== state.page) {
      state.page = b.pageNumber;
      container.appendChild(el('div', 'dv-page', '— ' + b.pageNumber + '쪽 —'));
    }
    if (b.type === 'heading') {
      container.appendChild(el('h3', 'dv-h', b.text || ''));
    } else if (b.type === 'table' && b.table) {
      const t = el('table', 'dv-table');
      (b.table.cells || []).forEach(function (row) {
        const tr = el('tr');
        row.forEach(function (c) {
          const td = el('td', null, c.text || '');
          if (c.colSpan > 1) td.colSpan = c.colSpan;
          if (c.rowSpan > 1) td.rowSpan = c.rowSpan;
          tr.appendChild(td);
        });
        t.appendChild(tr);
      });
      const wrap = el('div', 'dv-twrap');
      wrap.appendChild(t);
      container.appendChild(wrap);
    } else {
      const size = b.style && b.style.fontSize;
      container.appendChild(el('p', 'dv-p' + (size >= 120 ? ' big' : ''), b.text || ''));
    }
  });
}

function renderDocView(body, data, path) {
  const state = { page: 0 };
  const blocksBox = el('div', 'dv-doc');
  body.appendChild(blocksBox);
  renderDocBlocks(blocksBox, data.blocks, state);
  let loaded = data.offset + data.blocks.length;
  if (loaded < data.total) {
    const more = el('button', 'b-ghost', '더 보기 (' + loaded + '/' + data.total + ' 블록)');
    more.onclick = async function () {
      more.disabled = true;
      try {
        const r = await fetch(_dUrl('view', { path: path, offset: loaded, limit: 500 }));
        if (!r.ok || _dViewFile !== path) return;
        const next = await r.json();
        renderDocBlocks(blocksBox, next.blocks, state);
        loaded += next.blocks.length;
        if (loaded >= next.total) more.remove();
        else more.textContent = '더 보기 (' + loaded + '/' + next.total + ' 블록)';
      } catch (e) { console.error(e); }
      more.disabled = false;
    };
    body.appendChild(more);
  }
}

function renderSheetView(body, data) {
  let current = 0;
  const tabs = el('div', 'dv-tabs');
  const grid = el('div', 'dv-twrap');
  function show(i) {
    current = i;
    Array.from(tabs.children).forEach(function (b, j) { b.classList.toggle('on', j === i); });
    grid.replaceChildren();
    const s = data.sheets[i];
    const t = el('table', 'dv-table');
    const hr = el('tr');
    s.columns.forEach(function (c) { hr.appendChild(el('th', null, c)); });
    t.appendChild(hr);
    s.rows.forEach(function (row) {
      const tr = el('tr');
      row.forEach(function (cell) {
        tr.appendChild(el('td', null, cell === null || cell === undefined ? '' : String(cell)));
      });
      t.appendChild(tr);
    });
    grid.appendChild(t);
    if (s.rows.length < s.total_rows) {
      grid.appendChild(el('p', 'dv-note',
        '전체 ' + s.total_rows + '행 중 ' + s.rows.length + '행 표시 — 전체는 내려받아 확인하세요.'));
    }
  }
  if (data.sheets.length > 1) {
    data.sheets.forEach(function (s, i) {
      const b = el('button', 'dv-tab', s.name);
      b.onclick = function () { show(i); };
      tabs.appendChild(b);
    });
    body.appendChild(tabs);
  }
  body.appendChild(grid);
  if (data.sheets.length) show(0);
  else body.appendChild(el('div', 'empty', '표시할 시트가 없어요.'));
}
```

- [ ] **Step 2: ui.css — viewer styles (append)**

```css
.dviewer { border: 1px solid var(--line); border-radius: 12px; overflow: hidden; }
.dv-head { display: flex; align-items: center; justify-content: space-between;
  padding: 10px 14px; border-bottom: 1px solid var(--line); }
.dv-body { padding: 14px; max-height: 60vh; overflow-y: auto; }
.dv-page { text-align: center; color: var(--text-3); font-size: 12px; margin: 14px 0 6px; }
.dv-h { font-size: 16px; margin: 12px 0 6px; }
.dv-p { font-size: 14px; line-height: 1.6; margin: 6px 0; white-space: pre-wrap; }
.dv-p.big { font-size: 15px; font-weight: 600; }
.dv-twrap { overflow-x: auto; margin: 8px 0; }
.dv-table { border-collapse: collapse; font-size: 13px; }
.dv-table th, .dv-table td { border: 1px solid var(--line); padding: 4px 8px; text-align: left; }
.dv-tabs { display: flex; gap: 6px; margin-bottom: 8px; flex-wrap: wrap; }
.dv-tab { border: 1px solid var(--line); background: none; color: var(--text);
  border-radius: 999px; padding: 4px 12px; cursor: pointer; font-size: 13px; }
.dv-tab.on { border-color: var(--text); font-weight: 600; }
.dv-note { color: var(--text-2); font-size: 12px; }
```

(Token names verified against `tokens.css` — same set as Task 6.)

- [ ] **Step 3: Verify + commit**

```bash
node --check static/drive.js
./.venv/bin/python -m pytest -q
git add static/drive.js static/ui.css
git commit -m "feat(drive): 뷰어 패널 — kordoc 블록 문서뷰 + 시트 그리드"
```

---

### Task 9: Playwright E2E + docs

**Files:**
- Create: `tests/e2e_drive_playwright.mjs` (manual-run script, not pytest-collected)
- Modify: `README.md` (드라이브 section, 3–4 lines)

**Interfaces:**
- Consumes: everything above; Playwright at `NODE_PATH=/Users/amazon/.npm/_npx/e41f203b7505f1fb/node_modules`.

- [ ] **Step 1: E2E script** — real browser against an ISOLATED server (port 8766, throwaway DB/runs/drives, codex backend so no API key). Flow: set name 김민지 → 드라이브 segment → create folder 학사 → enter → upload a CSV (via `input#dFilesInput` `setInputFiles`) → file appears → click file → viewer shows grid with 이름/점수 headers → close viewer → send a chat question (stub: only assert the request POSTs and a bubble appears — answer content depends on LLM backend, so with codex-CLI absent assert the error bubble renders gracefully instead) → screenshots to the scratchpad. `waitForFunction(fn, null, {timeout})` — options are the THIRD argument.

```js
// tests/e2e_drive_playwright.mjs — 수동 실행: NODE_PATH=... node tests/e2e_drive_playwright.mjs
// 서버는 미리 격리로 띄워 둘 것:
//   OFFICE_HUB_DB=/tmp/drive-e2e.db OFFICE_HUB_RUNS=/tmp/drive-e2e-runs \
//   OFFICE_HUB_DRIVES=/tmp/drive-e2e-drives OPENAI_API_KEY= OFFICE_HUB_LLM_BACKEND=codex \
//   ./.venv/bin/python -m uvicorn hub.api:create_app --factory --port 8766
import { chromium } from 'playwright';
import { writeFileSync } from 'fs';

const BASE = 'http://localhost:8766';
const results = [];
const ok = (name, cond) => results.push([cond ? 'PASS' : 'FAIL', name]);

const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto(BASE);
await page.fill('#userName', '김민지');
await page.click('#seg-drive');
await page.waitForFunction(() => !document.getElementById('v-drive').hidden, null, { timeout: 5000 });
ok('드라이브 화면 진입', true);

page.on('dialog', d => d.accept('학사'));
await page.click('#dNewFolder');
await page.waitForFunction(() => document.querySelector('#dList .drow.folder'), null, { timeout: 5000 });
ok('폴더 생성', true);
await page.click('#dList .drow.folder .dname');

writeFileSync('/tmp/drive-e2e.csv', '이름,점수\n민지,90\n하나,85\n');
await page.setInputFiles('#dFilesInput', '/tmp/drive-e2e.csv');
await page.waitForFunction(() =>
  Array.from(document.querySelectorAll('#dList .drow .dname')).some(n => n.textContent.includes('drive-e2e.csv')),
  null, { timeout: 5000 });
ok('파일 업로드', true);

await page.click('#dList .drow:not(.folder) .dname');
await page.waitForFunction(() => {
  const v = document.getElementById('dViewer');
  return v && !v.hidden && v.querySelector('.dv-table');
}, null, { timeout: 10000 });
const headers = await page.$$eval('#dViewer th', ths => ths.map(t => t.textContent));
ok('뷰어 그리드 (이름/점수)', headers.includes('이름') && headers.includes('점수'));
await page.screenshot({ path: process.env.SHOT_DIR ? process.env.SHOT_DIR + '/drive-viewer.png' : '/tmp/drive-viewer.png', fullPage: true });

await page.fill('#dText', '점수 평균이 얼마야?');
await page.click('#dSend');
await page.waitForFunction(() =>
  document.querySelectorAll('#dThread .msg-user').length >= 1 &&
  document.querySelectorAll('#dThread .msg-ai').length >= 1, null, { timeout: 30000 });
ok('채팅 왕복 (질문 + 응답/오류 버블)', true);
await page.screenshot({ path: process.env.SHOT_DIR ? process.env.SHOT_DIR + '/drive-chat.png' : '/tmp/drive-chat.png', fullPage: true });

await browser.close();
results.forEach(([s, n]) => console.log(s, n));
if (results.some(([s]) => s === 'FAIL')) process.exit(1);
```

- [ ] **Step 2: Run E2E**

```bash
# 터미널 1 (또는 & 백그라운드): 격리 서버 기동 (위 주석의 명령)
NODE_PATH=/Users/amazon/.npm/_npx/e41f203b7505f1fb/node_modules node tests/e2e_drive_playwright.mjs
```
Expected: all PASS lines, exit 0. Kill the isolated server by PID afterwards (`lsof -ti :8766 -sTCP:LISTEN`).

- [ ] **Step 3: README — add under the flow section**

```markdown
## 내 드라이브 (phase 1)

- 상단 "드라이브" 탭: 사람마다 하나씩 갖는 파일 공간 (`drives/<이름>/`, `OFFICE_HUB_DRIVES`로 재지정).
- 폴더 안에서 채팅하면 그 폴더의 파일들을 읽고 답한다 (하위 폴더 제외).
- 파일을 클릭하면 뷰어: 엑셀/CSV는 시트 그리드, 한글/PDF/DOCX는 kordoc 변환 문서뷰.
- 원본은 절대 수정하지 않는다 — 작업 결과물은 새 파일로 (phase 2/3).
```

- [ ] **Step 4: Full suite + commit**

```bash
./.venv/bin/python -m pytest -q
git add tests/e2e_drive_playwright.mjs README.md
git commit -m "test(drive): playwright E2E + README 드라이브 안내"
```

---

## Final whole-branch review

Dispatch per superpowers:requesting-code-review with the review package `scripts/review-package $(git merge-base ux/phase-a HEAD) HEAD`. Constraints block for the reviewer: the Global Constraints section above, verbatim.

## Execution amendments

(record deviations here during execution)

Execution record (2026-07-06): all 9 tasks complete on `drive/phase-1` (4515659..5a90e9e, 18 commits), 230 tests green, E2E 5/5. Final review Ready-to-merge=Yes; its two conditions (CP949 tabular 500→422, move/delete `_view` cache invalidation) fixed in 5a90e9e. Notable amendments vs plan text: folder-create file-collision → 409; hidden-name guards on upload/move; download's manual ".." pre-check removed as false-positive (resolve_within suffices); viewer cache namespaced `_kordoc_out/_view/` to stay out of ingest's converter scan; `_dChatGen` guard added against cross-folder chat contamination; `.work[hidden]` pre-existing layout bug fixed. Deferred decisions and minors: see app `.superpowers/sdd/progress.md` drive section.
