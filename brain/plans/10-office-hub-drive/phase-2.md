# Drive Phase 2 Implementation Plan — 작업본(workdoc) + 실시간 중계 + 재업로드 확인

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Server-held block-structured workdocs per drive file, LLM document editing via deterministic patch tools, live SSE relay of patches into the viewer, plus the approved re-upload overwrite confirmation.

**Architecture:** New `hub/drive/workdoc.py` (build/apply/persist) and `hub/drive/workhub.py` (registry + locks + pub/sub). New `hub/core/edit_tools.py` gives the LLM read/edit tools bound to one workdoc; `run_turn` gains injectable tool schemas/dispatch (default unchanged). Three new endpoints on the drive router: workdoc snapshot, edit-ask, SSE events. Viewer switches its data source to the workdoc snapshot and applies SSE patches with highlight; chat routes to edit-ask while a file is open in the viewer.

**Tech Stack:** FastAPI StreamingResponse (SSE, no WebSocket), queue.Queue pub/sub (sync endpoints run in threadpool), vanilla JS EventSource, pytest + ScriptedLLM stubs.

**Branch:** continue on `drive/phase-1` (stacked work; user merges the stack when ready). Current tip 5a90e9e, 230 tests green.

## Global Constraints

- Everything from phase 1 still binds: operational strings byte-exact; no innerHTML (el()/textContent only); existing tokens.css variables only; traversal/null-byte guards via `resolve_within`/`safe_owner` (Korean 404/400); uploads restricted to `.xlsx .xlsm .csv .hwp .hwpx .hwpml .pdf .docx`; tests fully isolated (tmp db/runs/drives, zero real LLM/kordoc/network); port 8000 managed by PID only; venv pytest (`./.venv/bin/python -m pytest -q`).
- **Original drive files are NEVER mutated.** All edits live in the workdoc; the source file on disk stays byte-identical. Export back to files is phase 3.
- **Deterministic-edit invariant** (extends the app's core invariant): the LLM only *requests* edits by calling tools with explicit targets; `apply_patch` (deterministic code) validates and mutates. The EDITOR prompt forbids the LLM from inventing computed numbers: cell values come from the user's instruction or from what read tools returned, and any stated limitation must be exactly what a tool reported (no fabricated reasons — this codifies the kordoc "OCR 필요" incident lesson).
- Workdoc persistence lives under the hidden `<folder>/_workdoc/` namespace ("_"-prefixed → invisible in listings, excluded from ingest's converter scan, unreachable by move; same isolation argument as `_kordoc_out/_view`). **Persist only when edits exist**: a merely-viewed file must not create `_workdoc/` entries.
- Accent `#10a37f` (`--accent`) is allowed here ONLY for the live-change highlight in the viewer — that is a "running state" marker, which spec 06 reserves the accent for. No other new accent uses.
- SSE: heartbeat comment every ≤15s; client reconnect is EventSource-native; on seq gap the client refetches the snapshot rather than trying to repair.
- Phase-2 editing scope: document workdocs edit paragraph/heading TEXT blocks only (table-block editing inside documents is out of scope — record, don't build); tabular workdocs edit cells/rows. `_chats`-style unbounded in-memory growth remains accepted prototype behavior.
- Re-upload semantics change (user-approved 2026-07-06): uploading onto an existing same-name FILE returns 409 unless `overwrite=1`; overwrite invalidates that file's `_view` cache AND its workdoc (memory + `_workdoc/` files). The UI asks "덮어쓸까요?" and retries with the flag.

## File Structure

- Create: `hub/drive/workdoc.py` — Workdoc dataclass, `build_workdoc`, `apply_patch`, `save_workdoc`/`load_workdoc`, `workdoc_dir`
- Create: `hub/drive/workhub.py` — `WorkdocHub`: get-or-load registry, per-doc `threading.Lock`, subscribe/publish/unsubscribe, invalidate
- Create: `hub/core/edit_tools.py` — `EDIT_TOOL_SCHEMAS`, `make_edit_dispatch(hub_entry)` (read_workdoc + 6 edit ops)
- Modify: `hub/llm/orchestrator.py` — `run_turn(..., tool_schemas=None, dispatch=None)` (defaults preserve behavior)
- Modify: `hub/llm/prompts.py` — add `EDITOR` prompt
- Modify: `hub/api/drive.py` — endpoints: `GET /drive/{owner}/workdoc`, `POST /drive/{owner}/workdoc/ask`, `GET /drive/{owner}/workdoc/events`; upload overwrite gate + invalidation
- Modify: `hub/api/__init__.py` — construct one `WorkdocHub`, pass into `drive_router`
- Modify: `static/drive.js` — viewer reads workdoc snapshot; EventSource patch application + highlight; edit-mode chat routing; upload 409→confirm→retry
- Modify: `static/ui.css` — `.dv-changed` highlight, edit-mode chip
- Modify: `README.md` — 드라이브 편집 3–4 lines
- Test: `tests/test_workdoc.py`, `tests/test_workhub.py`, `tests/test_edit_tools.py`, `tests/test_api_workdoc.py`, `tests/test_api_drive_fs.py` (overwrite cases appended), `tests/e2e_drive_playwright.mjs` (extended)

---

### Task 1: Workdoc core (`hub/drive/workdoc.py`)

**Files:**
- Create: `hub/drive/workdoc.py`
- Test: `tests/test_workdoc.py`

**Interfaces:**
- Produces (consumed by Tasks 2–4):
  - `@dataclass Workdoc: kind: str` (`"document"`|`"tabular"`), `filename: str`, `seq: int`, `blocks: list[dict]` (document) , `sheets: list[dict]` (tabular; each `{"name","columns":[str],"rows":[[Any,…],…]}`)
  - `build_workdoc(path: Path, doc_converter=None) -> Workdoc` — tabular via `load_tabular` (raises → caller maps to HTTP), document via `ensure_converted` blocks.json (non-list → `[]`)
  - `apply_patch(wd: Workdoc, patch: dict) -> dict` — validates, mutates, bumps `wd.seq`, returns the normalized patch (with `seq` filled). Raises `PatchError(msg)` (subclass of `ValueError`, Korean msg) on bad target/op.
  - ops: document `replace_block {index, text}` / `insert_block {index, text}` / `delete_block {index}`; tabular `set_cell {sheet, row, col, value}` / `insert_row {sheet, row, values}` / `delete_row {sheet, row}`
  - `workdoc_dir(path: Path) -> Path` = `path.parent / "_workdoc"`; `save_workdoc(wd, path)` writes `<dir>/<filename>.json` and appends each patch to `<dir>/<filename>.patches.jsonl` (append happens in `append_patch(path, patch)`); `load_workdoc(path) -> Workdoc | None`

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_workdoc.py
"""작업본 — 블록 구조 상태 + 결정론 패치 적용 + 지속화."""
import json
from pathlib import Path

import pytest

from hub.drive.workdoc import (PatchError, Workdoc, append_patch, apply_patch,
                               build_workdoc, load_workdoc, save_workdoc, workdoc_dir)


def _doc_stub_converter(input_path: str) -> str:
    src = Path(input_path)
    out = src.parent / "_kordoc_out" / "_view" / src.name / "doc"
    out.mkdir(parents=True, exist_ok=True)
    (out / "blocks.json").write_text(json.dumps([
        {"type": "heading", "text": "제목", "pageNumber": 1, "style": {"fontSize": 150}},
        {"type": "paragraph", "text": "첫 문단", "pageNumber": 1, "style": {"fontSize": 100}},
        {"type": "paragraph", "text": "둘째 문단", "pageNumber": 2, "style": {"fontSize": 100}},
    ], ensure_ascii=False), encoding="utf-8")
    return str(out)


@pytest.fixture
def doc_wd(tmp_path):
    f = tmp_path / "공문.hwpx"
    f.write_bytes(b"HWPX")
    return build_workdoc(f, doc_converter=_doc_stub_converter), f


@pytest.fixture
def tab_wd(tmp_path):
    f = tmp_path / "성적.csv"
    f.write_text("이름,점수\n민지,90\n하나,85\n", encoding="utf-8")
    return build_workdoc(f), f


def test_build_document_workdoc(doc_wd):
    wd, _ = doc_wd
    assert wd.kind == "document" and wd.seq == 0
    assert [b["text"] for b in wd.blocks] == ["제목", "첫 문단", "둘째 문단"]


def test_build_tabular_workdoc(tab_wd):
    wd, _ = tab_wd
    assert wd.kind == "tabular"
    assert wd.sheets[0]["columns"] == ["이름", "점수"]
    assert wd.sheets[0]["rows"][0] == ["민지", 90]


def test_replace_block(doc_wd):
    wd, _ = doc_wd
    p = apply_patch(wd, {"op": "replace_block", "index": 1, "text": "고친 문단"})
    assert wd.blocks[1]["text"] == "고친 문단"
    assert wd.blocks[1]["pageNumber"] == 1          # 스타일·페이지 보존
    assert p["seq"] == 1 and wd.seq == 1


def test_insert_and_delete_block(doc_wd):
    wd, _ = doc_wd
    apply_patch(wd, {"op": "insert_block", "index": 1, "text": "끼운 문단"})
    assert [b["text"] for b in wd.blocks] == ["제목", "끼운 문단", "첫 문단", "둘째 문단"]
    assert wd.blocks[1]["type"] == "paragraph"
    apply_patch(wd, {"op": "delete_block", "index": 1})
    assert [b["text"] for b in wd.blocks] == ["제목", "첫 문단", "둘째 문단"]
    assert wd.seq == 2


def test_set_cell_and_rows(tab_wd):
    wd, _ = tab_wd
    apply_patch(wd, {"op": "set_cell", "sheet": "성적", "row": 0, "col": "점수", "value": 95})
    assert wd.sheets[0]["rows"][0][1] == 95
    apply_patch(wd, {"op": "insert_row", "sheet": "성적", "row": 2, "values": ["지수", 88]})
    assert wd.sheets[0]["rows"][2] == ["지수", 88]
    apply_patch(wd, {"op": "delete_row", "sheet": "성적", "row": 1})
    assert [r[0] for r in wd.sheets[0]["rows"]] == ["민지", "지수"]


@pytest.mark.parametrize("patch", [
    {"op": "replace_block", "index": 99, "text": "x"},
    {"op": "delete_block", "index": -1},
    {"op": "set_cell", "sheet": "없는시트", "row": 0, "col": "점수", "value": 1},
    {"op": "set_cell", "sheet": "성적", "row": 0, "col": "없는열", "value": 1},
    {"op": "set_cell", "sheet": "성적", "row": 99, "col": "점수", "value": 1},
    {"op": "이상한op"},
])
def test_bad_patch_raises_korean(doc_wd, tab_wd, patch):
    wd = doc_wd[0] if "block" in patch.get("op", "") else tab_wd[0]
    before = wd.seq
    with pytest.raises(PatchError):
        apply_patch(wd, patch)
    assert wd.seq == before                          # 실패는 seq를 올리지 않는다


def test_kind_mismatch_raises(doc_wd):
    wd, _ = doc_wd
    with pytest.raises(PatchError):
        apply_patch(wd, {"op": "set_cell", "sheet": "s", "row": 0, "col": "c", "value": 1})


def test_persist_roundtrip_and_patch_log(tab_wd, tmp_path):
    wd, f = tab_wd
    p = apply_patch(wd, {"op": "set_cell", "sheet": "성적", "row": 0, "col": "점수", "value": 95})
    save_workdoc(wd, f)
    append_patch(f, p)
    assert workdoc_dir(f).name == "_workdoc"         # 숨김 네임스페이스
    loaded = load_workdoc(f)
    assert loaded.seq == 1 and loaded.sheets[0]["rows"][0][1] == 95
    lines = (workdoc_dir(f) / "성적.csv.patches.jsonl").read_text(encoding="utf-8").splitlines()
    assert json.loads(lines[0])["op"] == "set_cell"


def test_load_missing_returns_none(tmp_path):
    f = tmp_path / "없음.csv"
    assert load_workdoc(f) is None
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./.venv/bin/python -m pytest tests/test_workdoc.py -q`
Expected: FAIL `ModuleNotFoundError: No module named 'hub.drive.workdoc'`

- [ ] **Step 3: Implement**

```python
# hub/drive/workdoc.py
from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

from hub.core.ingest import TABULAR_EXT, load_tabular
from hub.drive.convert import ensure_converted


class PatchError(ValueError):
    pass


@dataclass
class Workdoc:
    kind: str                      # "document" | "tabular"
    filename: str
    seq: int = 0
    blocks: list = field(default_factory=list)   # document 전용
    sheets: list = field(default_factory=list)   # tabular 전용 {"name","columns","rows"}

    def as_dict(self) -> dict:
        d = {"kind": self.kind, "filename": self.filename, "seq": self.seq}
        if self.kind == "document":
            d["blocks"] = self.blocks
        else:
            d["sheets"] = self.sheets
        return d


def build_workdoc(path: Path, doc_converter=None) -> Workdoc:
    ext = path.suffix.lower()
    if ext in TABULAR_EXT:
        src = load_tabular(str(path), "workdoc")
        sheets = [{"name": s.name,
                   "columns": [c.name for c in s.columns],
                   "rows": [[row.get(c.name) for c in s.columns] for row in s.rows]}
                  for s in src.sheets]
        return Workdoc(kind="tabular", filename=path.name, sheets=sheets)
    out_dir = ensure_converted(path, doc_converter)
    blocks = []
    bp = out_dir / "blocks.json"
    if bp.is_file():
        try:
            blocks = json.loads(bp.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            blocks = []
    if not isinstance(blocks, list):
        blocks = []
    return Workdoc(kind="document", filename=path.name, blocks=blocks)


def _sheet(wd: Workdoc, name: str) -> dict:
    for s in wd.sheets:
        if s["name"] == name:
            return s
    raise PatchError(f"시트를 찾을 수 없습니다: {name}")


def _check_index(seq_len: int, index, *, allow_end: bool = False) -> int:
    if not isinstance(index, int) or index < 0 or index >= seq_len + (1 if allow_end else 0):
        raise PatchError(f"대상 위치가 올바르지 않습니다: {index}")
    return index


def apply_patch(wd: Workdoc, patch: dict) -> dict:
    """검증 후 작업본을 변형하고 seq를 올린다. 실패 시 PatchError, 상태 불변."""
    op = patch.get("op")
    doc_ops = {"replace_block", "insert_block", "delete_block"}
    tab_ops = {"set_cell", "insert_row", "delete_row"}
    if op in doc_ops and wd.kind != "document":
        raise PatchError("문서 작업본이 아닙니다")
    if op in tab_ops and wd.kind != "tabular":
        raise PatchError("표 작업본이 아닙니다")

    if op == "replace_block":
        i = _check_index(len(wd.blocks), patch.get("index"))
        wd.blocks[i] = {**wd.blocks[i], "text": str(patch.get("text", ""))}
    elif op == "insert_block":
        i = _check_index(len(wd.blocks), patch.get("index"), allow_end=True)
        neighbor = wd.blocks[i - 1] if i > 0 and wd.blocks else {}
        wd.blocks.insert(i, {"type": "paragraph", "text": str(patch.get("text", "")),
                             "pageNumber": neighbor.get("pageNumber"),
                             "style": {"fontSize": 100}})
    elif op == "delete_block":
        i = _check_index(len(wd.blocks), patch.get("index"))
        del wd.blocks[i]
    elif op == "set_cell":
        s = _sheet(wd, patch.get("sheet"))
        r = _check_index(len(s["rows"]), patch.get("row"))
        col = patch.get("col")
        if col not in s["columns"]:
            raise PatchError(f"열을 찾을 수 없습니다: {col}")
        s["rows"][r][s["columns"].index(col)] = patch.get("value")
    elif op == "insert_row":
        s = _sheet(wd, patch.get("sheet"))
        r = _check_index(len(s["rows"]), patch.get("row"), allow_end=True)
        values = list(patch.get("values") or [])
        if len(values) != len(s["columns"]):
            raise PatchError(f"값 개수가 열 수({len(s['columns'])})와 다릅니다")
        s["rows"].insert(r, values)
    elif op == "delete_row":
        s = _sheet(wd, patch.get("sheet"))
        r = _check_index(len(s["rows"]), patch.get("row"))
        del s["rows"][r]
    else:
        raise PatchError(f"알 수 없는 편집 동작입니다: {op}")

    wd.seq += 1
    return {**patch, "seq": wd.seq,
            "ts": datetime.now(timezone.utc).isoformat()}


def workdoc_dir(path: Path) -> Path:
    # "_workdoc"은 숨김("_" 접두) — 목록·ingest 스캔·move에서 제외되는 불변식을 공유한다.
    return path.parent / "_workdoc"


def save_workdoc(wd: Workdoc, path: Path) -> None:
    d = workdoc_dir(path)
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{path.name}.json").write_text(
        json.dumps(wd.as_dict(), ensure_ascii=False), encoding="utf-8")


def append_patch(path: Path, patch: dict) -> None:
    d = workdoc_dir(path)
    d.mkdir(parents=True, exist_ok=True)
    with (d / f"{path.name}.patches.jsonl").open("a", encoding="utf-8") as f:
        f.write(json.dumps(patch, ensure_ascii=False) + "\n")


def load_workdoc(path: Path) -> Workdoc | None:
    p = workdoc_dir(path) / f"{path.name}.json"
    if not p.is_file():
        return None
    try:
        d = json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    return Workdoc(kind=d.get("kind", "document"), filename=d.get("filename", path.name),
                   seq=int(d.get("seq", 0)), blocks=d.get("blocks", []) or [],
                   sheets=d.get("sheets", []) or [])
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./.venv/bin/python -m pytest tests/test_workdoc.py -q` then full `-q`
Expected: all pass, 230 prior green

- [ ] **Step 5: Commit**

```bash
git add hub/drive/workdoc.py tests/test_workdoc.py
git commit -m "feat(workdoc): 작업본 코어 — 빌드/결정론 패치/지속화"
```

---

### Task 2: Workdoc hub — registry, locks, pub/sub (`hub/drive/workhub.py`)

**Files:**
- Create: `hub/drive/workhub.py`
- Test: `tests/test_workhub.py`

**Interfaces:**
- Produces (consumed by Tasks 3–5):
  - `class WorkdocHub:` `get(path: Path, doc_converter=None) -> Workdoc` (memory → `_workdoc/` file → build from source; caches in memory), `lock(path) -> threading.Lock` (one per abs path), `subscribe(path) -> queue.Queue`, `unsubscribe(path, q)`, `publish(path, event: dict)` (put on every subscriber queue, never blocks — drop into unbounded queues), `invalidate(path)` (drop memory entry AND delete `_workdoc/<name>.json` + `.patches.jsonl`), `edited(path) -> bool` (persisted json exists or memory seq > 0)

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_workhub.py
"""작업본 허브 — 레지스트리/락/구독·발행/무효화."""
from pathlib import Path

from hub.drive.workdoc import apply_patch, save_workdoc
from hub.drive.workhub import WorkdocHub


def _csv(tmp_path, name="성적.csv"):
    f = tmp_path / name
    f.write_text("이름,점수\n민지,90\n", encoding="utf-8")
    return f


def test_get_builds_and_caches(tmp_path):
    hub = WorkdocHub()
    f = _csv(tmp_path)
    wd1 = hub.get(f)
    wd2 = hub.get(f)
    assert wd1 is wd2 and wd1.kind == "tabular"


def test_get_prefers_persisted(tmp_path):
    f = _csv(tmp_path)
    hub = WorkdocHub()
    wd = hub.get(f)
    apply_patch(wd, {"op": "set_cell", "sheet": "성적", "row": 0, "col": "점수", "value": 77})
    save_workdoc(wd, f)
    hub2 = WorkdocHub()                      # 재시작 시뮬레이션
    assert hub2.get(f).sheets[0]["rows"][0][1] == 77


def test_pubsub_roundtrip(tmp_path):
    hub = WorkdocHub()
    f = _csv(tmp_path)
    q = hub.subscribe(f)
    hub.publish(f, {"event": "patch", "seq": 1})
    assert q.get(timeout=1)["seq"] == 1
    hub.unsubscribe(f, q)
    hub.publish(f, {"event": "patch", "seq": 2})
    assert q.empty()


def test_publish_without_subscribers_is_noop(tmp_path):
    WorkdocHub().publish(_csv(tmp_path), {"event": "patch"})   # 예외 없음


def test_invalidate_drops_memory_and_files(tmp_path):
    hub = WorkdocHub()
    f = _csv(tmp_path)
    wd = hub.get(f)
    apply_patch(wd, {"op": "set_cell", "sheet": "성적", "row": 0, "col": "점수", "value": 1})
    save_workdoc(wd, f)
    assert hub.edited(f)
    hub.invalidate(f)
    assert not hub.edited(f)
    assert hub.get(f).sheets[0]["rows"][0][1] == 90            # 원본에서 재구성


def test_locks_are_per_path(tmp_path):
    hub = WorkdocHub()
    a, b = _csv(tmp_path, "a.csv"), _csv(tmp_path, "b.csv")
    assert hub.lock(a) is hub.lock(a)
    assert hub.lock(a) is not hub.lock(b)
```

- [ ] **Step 2: Run to verify failures**

Run: `./.venv/bin/python -m pytest tests/test_workhub.py -q` — expect ModuleNotFoundError

- [ ] **Step 3: Implement**

```python
# hub/drive/workhub.py
from __future__ import annotations

import queue
import threading
from pathlib import Path

from hub.drive.workdoc import Workdoc, build_workdoc, load_workdoc, workdoc_dir


class WorkdocHub:
    """작업본 인메모리 레지스트리 + 경로별 락 + 구독/발행.
    (프로토타입 일관성: 무한 증가 수용 — SourceRegistry와 같은 성질)"""

    def __init__(self) -> None:
        self._docs: dict[str, Workdoc] = {}
        self._locks: dict[str, threading.Lock] = {}
        self._subs: dict[str, list[queue.Queue]] = {}
        self._meta = threading.Lock()

    @staticmethod
    def _key(path: Path) -> str:
        return str(path.resolve())

    def lock(self, path: Path) -> threading.Lock:
        with self._meta:
            return self._locks.setdefault(self._key(path), threading.Lock())

    def get(self, path: Path, doc_converter=None) -> Workdoc:
        k = self._key(path)
        with self._meta:
            if k in self._docs:
                return self._docs[k]
        wd = load_workdoc(path) or build_workdoc(path, doc_converter)
        with self._meta:
            return self._docs.setdefault(k, wd)

    def edited(self, path: Path) -> bool:
        k = self._key(path)
        with self._meta:
            wd = self._docs.get(k)
        if wd is not None and wd.seq > 0:
            return True
        return (workdoc_dir(path) / f"{path.name}.json").is_file()

    def invalidate(self, path: Path) -> None:
        k = self._key(path)
        with self._meta:
            self._docs.pop(k, None)
        for suffix in (".json", ".patches.jsonl"):
            p = workdoc_dir(path) / f"{path.name}{suffix}"
            if p.is_file():
                p.unlink()

    def subscribe(self, path: Path) -> queue.Queue:
        q: queue.Queue = queue.Queue()
        with self._meta:
            self._subs.setdefault(self._key(path), []).append(q)
        return q

    def unsubscribe(self, path: Path, q: queue.Queue) -> None:
        with self._meta:
            subs = self._subs.get(self._key(path), [])
            if q in subs:
                subs.remove(q)

    def publish(self, path: Path, event: dict) -> None:
        with self._meta:
            subs = list(self._subs.get(self._key(path), []))
        for q in subs:
            q.put(event)
```

- [ ] **Step 4: Run tests** — module + full suite green.

- [ ] **Step 5: Commit**

```bash
git add hub/drive/workhub.py tests/test_workhub.py
git commit -m "feat(workdoc): 허브 — 레지스트리/락/구독·발행/무효화"
```

---

### Task 3: Edit tools + orchestrator injection + EDITOR prompt

**Files:**
- Create: `hub/core/edit_tools.py`
- Modify: `hub/llm/orchestrator.py` (run_turn signature)
- Modify: `hub/llm/prompts.py` (EDITOR)
- Test: `tests/test_edit_tools.py`

**Interfaces:**
- Consumes: `Workdoc`, `apply_patch`, `PatchError` (Task 1).
- Produces:
  - `EDIT_TOOL_SCHEMAS: list[dict]` — `read_workdoc {offset?, limit?, sheet?}`, `replace_block {index, text}`, `insert_block {index, text}`, `delete_block {index}`, `set_cell {sheet, row, col, value}`, `insert_row {sheet, row, values}`, `delete_row {sheet, row}` (descriptions in Korean; edit descriptions say 실패 시 error 필드로 이유가 온다)
  - `make_edit_dispatch(wd: Workdoc, on_patch) -> callable` with signature `(reg, session_id, name, args, max_sample_rows=50) -> dict` (reg/session ignored; signature matches `tools.dispatch_tool` so `run_turn` can take either). Successful edit → `apply_patch`, then `on_patch(normalized_patch)`, returns `{"ok": True, "seq": n}`. `PatchError` → `{"error": msg}` (turn continues; LLM sees the reason). `read_workdoc` returns a window: document `{"kind","total","offset","blocks":[{index,type,text,pageNumber},…]}` (limit default 100, max 200, text truncated to 500 chars each); tabular `{"kind","sheets":[names]}` +, for the chosen sheet (default first), `{"columns","total_rows","offset","rows":[[…],…]}` (limit default 50, max 200)
  - `run_turn(question, reg, session_id, llm, *, max_iters=8, max_sample_rows=50, tool_schemas=None, dispatch=None, system=None)` — all three default to current behavior (`tools.TOOL_SCHEMAS`, `tools.dispatch_tool`, `prompts.ORCHESTRATOR`)
  - `prompts.EDITOR` — Korean system prompt: 작업 대상은 열린 문서 하나; 먼저 read_workdoc으로 확인; 편집은 반드시 도구로(자유 텍스트로 편집 결과를 지어내지 말 것); 숫자 값은 사용자가 준 값 또는 read_workdoc이 보여준 값만 (스스로 계산한 집계 금지); 할 수 없는 일은 도구가 보고한 오류/상태 그대로만 설명하고 이유를 지어내지 말 것; 끝나면 무엇을 어떻게 바꿨는지 한국어로 요약.

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_edit_tools.py
"""편집 도구 — LLM은 요청만, 변형은 결정론 코드."""
from pathlib import Path

from hub.core.edit_tools import EDIT_TOOL_SCHEMAS, make_edit_dispatch
from hub.drive.workdoc import build_workdoc
from hub.llm import prompts
from hub.llm.orchestrator import LLMResponse, ToolCall, run_turn


def _tab(tmp_path):
    f = tmp_path / "성적.csv"
    f.write_text("이름,점수\n민지,90\n하나,85\n", encoding="utf-8")
    return build_workdoc(f)


class ScriptedLLM:
    def __init__(self, responses):
        self._r = list(responses)
        self.seen_system = None

    def respond(self, system, messages, tools):
        self.seen_system = system
        self.seen_tools = tools
        return self._r.pop(0)


def test_schema_names():
    names = {t["name"] for t in EDIT_TOOL_SCHEMAS}
    assert names == {"read_workdoc", "replace_block", "insert_block", "delete_block",
                     "set_cell", "insert_row", "delete_row"}


def test_read_workdoc_tabular_window(tmp_path):
    wd = _tab(tmp_path)
    dispatch = make_edit_dispatch(wd, on_patch=lambda p: None)
    out = dispatch(None, None, "read_workdoc", {})
    assert out["kind"] == "tabular"
    assert out["columns"] == ["이름", "점수"] and out["total_rows"] == 2


def test_edit_applies_and_notifies(tmp_path):
    wd = _tab(tmp_path)
    seen = []
    dispatch = make_edit_dispatch(wd, on_patch=seen.append)
    out = dispatch(None, None, "set_cell",
                   {"sheet": "성적", "row": 0, "col": "점수", "value": 95})
    assert out == {"ok": True, "seq": 1}
    assert wd.sheets[0]["rows"][0][1] == 95
    assert seen[0]["op"] == "set_cell" and seen[0]["seq"] == 1


def test_patch_error_becomes_error_field(tmp_path):
    wd = _tab(tmp_path)
    dispatch = make_edit_dispatch(wd, on_patch=lambda p: None)
    out = dispatch(None, None, "set_cell",
                   {"sheet": "성적", "row": 99, "col": "점수", "value": 1})
    assert "error" in out and "올바르지" in out["error"]
    assert wd.seq == 0


def test_run_turn_with_injected_tools(tmp_path):
    wd = _tab(tmp_path)
    patches = []
    dispatch = make_edit_dispatch(wd, on_patch=patches.append)
    llm = ScriptedLLM([
        LLMResponse(tool_calls=[ToolCall(id="t1", name="set_cell",
                    args={"sheet": "성적", "row": 1, "col": "점수", "value": 100})],
                    text=None, usage={}),
        LLMResponse(tool_calls=[], text="하나의 점수를 100으로 고쳤어요.", usage={}),
    ])
    result = run_turn("하나 점수를 100으로", None, None, llm,
                      tool_schemas=EDIT_TOOL_SCHEMAS, dispatch=dispatch,
                      system=prompts.EDITOR)
    assert result.text.startswith("하나의 점수")
    assert wd.sheets[0]["rows"][1][1] == 100
    assert llm.seen_system == prompts.EDITOR
    assert {t["name"] for t in llm.seen_tools} == {t["name"] for t in EDIT_TOOL_SCHEMAS}
    assert len(patches) == 1


def test_run_turn_default_behavior_unchanged(tmp_path):
    # 기존 호출(주입 없음)은 기존 스키마·프롬프트를 그대로 쓴다 — 회귀 방지의 핵심
    from hub.core import tools as core_tools
    from hub.core.ingest import load_tabular
    from hub.session import SourceRegistry
    reg = SourceRegistry()
    sid = reg.create_session()
    f = tmp_path / "a.csv"
    f.write_text("x\n1\n", encoding="utf-8")
    reg.add_source(sid, load_tabular(str(f), reg.next_source_id(sid)))
    llm = ScriptedLLM([LLMResponse(tool_calls=[], text="답", usage={})])
    run_turn("질문", reg, sid, llm)
    assert llm.seen_system == prompts.ORCHESTRATOR
    assert {t["name"] for t in llm.seen_tools} == {t["name"] for t in core_tools.TOOL_SCHEMAS}


def test_editor_prompt_guardrails():
    for must in ["도구", "지어내지", "계산"]:
        assert must in prompts.EDITOR
```

- [ ] **Step 2: Run to verify failures** — ModuleNotFoundError / TypeError on run_turn kwargs.

- [ ] **Step 3: Implement `hub/core/edit_tools.py`**

```python
# hub/core/edit_tools.py
from __future__ import annotations

from typing import Any, Callable

from hub.drive.workdoc import PatchError, Workdoc, apply_patch

EDIT_TOOL_SCHEMAS: list[dict[str, Any]] = [
    {
        "name": "read_workdoc",
        "description": ("열린 작업본의 내용을 창(window) 단위로 읽는다. 편집 전 반드시 호출해 "
                        "대상 위치(index/row)를 확인하라. 표면 sheet를 지정할 수 있다."),
        "parameters": {"type": "object", "properties": {
            "offset": {"type": "integer"}, "limit": {"type": "integer"},
            "sheet": {"type": "string"}}, "required": []},
    },
    {
        "name": "replace_block",
        "description": "문서 작업본의 index번째 블록 텍스트를 교체한다. 실패하면 error에 이유가 온다.",
        "parameters": {"type": "object", "properties": {
            "index": {"type": "integer"}, "text": {"type": "string"}},
            "required": ["index", "text"]},
    },
    {
        "name": "insert_block",
        "description": "문서 작업본의 index 위치에 새 문단을 끼운다(index는 0..블록수).",
        "parameters": {"type": "object", "properties": {
            "index": {"type": "integer"}, "text": {"type": "string"}},
            "required": ["index", "text"]},
    },
    {
        "name": "delete_block",
        "description": "문서 작업본의 index번째 블록을 삭제한다.",
        "parameters": {"type": "object", "properties": {
            "index": {"type": "integer"}}, "required": ["index"]},
    },
    {
        "name": "set_cell",
        "description": ("표 작업본의 셀 값을 바꾼다. 값은 사용자가 지시한 값 또는 read_workdoc이 "
                        "보여준 값만 사용하라(직접 계산한 집계값 금지)."),
        "parameters": {"type": "object", "properties": {
            "sheet": {"type": "string"}, "row": {"type": "integer"},
            "col": {"type": "string"}, "value": {}},
            "required": ["sheet", "row", "col", "value"]},
    },
    {
        "name": "insert_row",
        "description": "표 작업본의 row 위치에 행을 끼운다. values는 열 순서와 개수를 정확히 맞춘다.",
        "parameters": {"type": "object", "properties": {
            "sheet": {"type": "string"}, "row": {"type": "integer"},
            "values": {"type": "array", "items": {}}},
            "required": ["sheet", "row", "values"]},
    },
    {
        "name": "delete_row",
        "description": "표 작업본의 row번째 행을 삭제한다.",
        "parameters": {"type": "object", "properties": {
            "sheet": {"type": "string"}, "row": {"type": "integer"}},
            "required": ["sheet", "row"]},
    },
]

_EDIT_OPS = {"replace_block", "insert_block", "delete_block",
             "set_cell", "insert_row", "delete_row"}


def _read(wd: Workdoc, args: dict) -> dict:
    if wd.kind == "document":
        offset = max(0, int(args.get("offset") or 0))
        limit = max(1, min(int(args.get("limit") or 100), 200))
        window = [{"index": offset + i, "type": b.get("type"),
                   "text": str(b.get("text", ""))[:500],
                   "pageNumber": b.get("pageNumber")}
                  for i, b in enumerate(wd.blocks[offset:offset + limit])]
        return {"kind": "document", "total": len(wd.blocks),
                "offset": offset, "blocks": window}
    names = [s["name"] for s in wd.sheets]
    if not names:
        return {"kind": "tabular", "sheets": [], "error": "시트가 없습니다"}
    name = args.get("sheet") or names[0]
    try:
        s = next(x for x in wd.sheets if x["name"] == name)
    except StopIteration:
        return {"error": f"시트를 찾을 수 없습니다: {name}"}
    offset = max(0, int(args.get("offset") or 0))
    limit = max(1, min(int(args.get("limit") or 50), 200))
    return {"kind": "tabular", "sheets": names, "sheet": name,
            "columns": s["columns"], "total_rows": len(s["rows"]),
            "offset": offset, "rows": s["rows"][offset:offset + limit]}


def make_edit_dispatch(wd: Workdoc, on_patch: Callable[[dict], None]):
    """tools.dispatch_tool과 같은 시그니처의 편집 디스패처(reg/session 무시)."""

    def dispatch(reg, session_id, name: str, args: dict,
                 max_sample_rows: int = 50) -> dict:
        try:
            if name == "read_workdoc":
                return _read(wd, args or {})
            if name in _EDIT_OPS:
                patch = apply_patch(wd, {"op": name, **(args or {})})
                on_patch(patch)
                return {"ok": True, "seq": patch["seq"]}
            return {"error": f"알 수 없는 툴: {name}"}
        except PatchError as exc:
            return {"error": str(exc)}
        except Exception as exc:
            return {"error": f"{type(exc).__name__}: {exc}"}

    return dispatch
```

- [ ] **Step 4: Orchestrator + prompt changes**

In `hub/llm/orchestrator.py` change the signature and the two hardcoded uses:

```python
def run_turn(question: str, reg: SourceRegistry, session_id: str, llm: LLMClient, *,
             max_iters: int = 8, max_sample_rows: int = 50,
             tool_schemas: list[dict] | None = None,
             dispatch=None, system: str | None = None) -> AnswerResult:
    schemas = tool_schemas if tool_schemas is not None else tools.TOOL_SCHEMAS
    _dispatch = dispatch if dispatch is not None else tools.dispatch_tool
    _system = system if system is not None else prompts.ORCHESTRATOR
```

and use `llm.respond(_system, messages, schemas)` / `_dispatch(reg, session_id, tc.name, tc.args, max_sample_rows=max_sample_rows)` in the loop body. Nothing else changes.

Append to `hub/llm/prompts.py`:

```python
EDITOR = """너는 뚝딱 Hub의 문서 편집 도우미다. 지금 열려 있는 작업본 하나만 편집한다.

규칙:
- 편집 전에 read_workdoc으로 대상 위치(index/row/col)를 반드시 확인한다.
- 모든 편집은 반드시 편집 도구 호출로만 수행한다. 자유 텍스트로 편집 결과를 지어내지 않는다.
- 셀에 넣는 숫자는 사용자가 지시한 값 또는 read_workdoc이 보여준 값만 쓴다.
  스스로 계산한 합계·평균 같은 집계값을 만들어 넣지 않는다.
- 도구가 error를 돌려주면 그 이유를 그대로 전하고, 할 수 없는 이유를 지어내지 않는다.
  도구가 보고하지 않은 한계(예: 변환 품질, 파일 손상)를 추정해서 말하지 않는다.
- 끝나면 무엇을 어떻게 바꿨는지 한국어로 짧게 요약한다. 원본 파일은 바뀌지 않고
  작업본에만 반영된다는 사실을 사용자가 물으면 알려준다."""
```

- [ ] **Step 5: Run tests** — `tests/test_edit_tools.py` green, then FULL suite (existing orchestrator/chat tests prove default-path regression safety).

- [ ] **Step 6: Commit**

```bash
git add hub/core/edit_tools.py hub/llm/orchestrator.py hub/llm/prompts.py tests/test_edit_tools.py
git commit -m "feat(workdoc): 편집 도구 + run_turn 주입 지점 + EDITOR 프롬프트"
```

---

### Task 4: Workdoc API — snapshot, edit-ask, SSE events

**Files:**
- Modify: `hub/api/drive.py`, `hub/api/__init__.py`
- Test: `tests/test_api_workdoc.py`

**Interfaces:**
- Consumes: `WorkdocHub` (Task 2), `make_edit_dispatch`/`EDIT_TOOL_SCHEMAS`/`prompts.EDITOR` (Task 3), `save_workdoc`/`append_patch` (Task 1), existing `factory`/`cfg` from create_app.
- Produces:
  - `create_app` builds `work_hub = WorkdocHub()` and passes it: `drive_router(reg, cfg, store, drives_dir, doc_converter, factory, work_hub)` (drive_router signature grows `llm_factory` and `work_hub`; existing arg order preserved, new args appended).
  - `GET /drive/{owner}/workdoc?path=&offset=0&limit=500` → snapshot, SAME shape as `/view` plus `"seq"` (document: kind/filename/seq/total/offset/blocks; tabular: kind/filename/seq/sheets with rows capped 200 + total_rows). Missing file 404; unsupported ext 400 "뷰어가 지원하지 않는 형식입니다"; tabular load failure 422 (reuse the /view wording).
  - `POST /drive/{owner}/workdoc/ask` body `{"path","question"}` → runs the edit turn under `work_hub.lock(file)`; per patch: `append_patch` + `work_hub.publish(file, {"event":"patch","patch":p})`; after the turn, if any patch was made: `save_workdoc` + `store.add_audit(owner,"workdoc_edited","drive",0,f"{owner}:{path} {n}건")` + publish `{"event":"turn_done","seq":wd.seq}`. Response `{"answer","tool_calls":[names],"usage","seq","patched":n}`.
  - `GET /drive/{owner}/workdoc/events?path=` → `text/event-stream`. First event `event: hello\ndata: {"seq": n}\n\n`; then per published dict `event: <event>\ndata: <json>\n\n`; on 15s idle a comment `: ping\n\n`. Unsubscribe in `finally`. (Endpoint returns StreamingResponse from a sync generator; a module-level `_sse_format(event: dict) -> str` helper is unit-testable.)

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_api_workdoc.py
"""작업본 API — 스냅샷/편집 턴/SSE 이벤트."""
import json
import threading
from pathlib import Path

import pytest

from fastapi.testclient import TestClient

from hub.api import create_app
from hub.api.drive import _sse_format
from hub.llm.orchestrator import LLMResponse, ToolCall


class ScriptedLLM:
    def __init__(self, responses):
        self._r = list(responses)

    def respond(self, system, messages, tools):
        return self._r.pop(0)


def _edit_llm():
    return ScriptedLLM([
        LLMResponse(tool_calls=[ToolCall(id="t1", name="set_cell",
                    args={"sheet": "성적", "row": 0, "col": "점수", "value": 95})],
                    text=None, usage={"total_tokens": 5}),
        LLMResponse(tool_calls=[], text="민지 점수를 95로 고쳤어요.", usage={"total_tokens": 7}),
    ])


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("OFFICE_HUB_RUNS", str(tmp_path / "runs"))
    app = create_app(llm_factory=lambda cfg: _edit_llm(),
                     db_path=str(tmp_path / "hub.db"),
                     drives_dir=str(tmp_path / "drives"))
    c = TestClient(app)
    c.post("/drive/김민지/files", params={"path": ""},
           files={"file": ("성적.csv", "이름,점수\n민지,90\n하나,85\n".encode(), "text/csv")})
    return c, tmp_path


def test_workdoc_snapshot(client):
    c, _ = client
    r = c.get("/drive/김민지/workdoc", params={"path": "성적.csv"})
    assert r.status_code == 200
    b = r.json()
    assert b["kind"] == "tabular" and b["seq"] == 0
    assert b["sheets"][0]["rows"][0] == ["민지", 90]


def test_snapshot_does_not_persist(client):
    c, tmp = client
    c.get("/drive/김민지/workdoc", params={"path": "성적.csv"})
    assert not (tmp / "drives" / "김민지" / "_workdoc").exists()


def test_edit_ask_applies_and_persists(client):
    c, tmp = client
    r = c.post("/drive/김민지/workdoc/ask",
               json={"path": "성적.csv", "question": "민지 점수를 95로"})
    assert r.status_code == 200
    b = r.json()
    assert b["patched"] == 1 and b["seq"] == 1
    assert "95" in b["answer"]
    snap = c.get("/drive/김민지/workdoc", params={"path": "성적.csv"}).json()
    assert snap["sheets"][0]["rows"][0][1] == 95 and snap["seq"] == 1
    wdir = tmp / "drives" / "김민지" / "_workdoc"
    assert (wdir / "성적.csv.json").is_file()
    line = json.loads((wdir / "성적.csv.patches.jsonl").read_text().splitlines()[0])
    assert line["op"] == "set_cell" and line["seq"] == 1


def test_edit_ask_audits(client):
    c, tmp = client
    c.post("/drive/김민지/workdoc/ask", json={"path": "성적.csv", "question": "고쳐"})
    import sqlite3
    con = sqlite3.connect(tmp / "hub.db")
    rows = con.execute(
        "SELECT actor, detail FROM audit_log WHERE action='workdoc_edited'").fetchall()
    con.close()
    assert len(rows) == 1
    assert rows[0][0] == "김민지" and "성적.csv" in rows[0][1]


def test_workdoc_missing_file_404(client):
    c, _ = client
    assert c.get("/drive/김민지/workdoc", params={"path": "없음.csv"}).status_code == 404
    assert c.post("/drive/김민지/workdoc/ask",
                  json={"path": "없음.csv", "question": "x"}).status_code == 404


def test_original_file_untouched(client):
    c, tmp = client
    before = (tmp / "drives" / "김민지" / "성적.csv").read_bytes()
    c.post("/drive/김민지/workdoc/ask", json={"path": "성적.csv", "question": "민지 95로"})
    assert (tmp / "drives" / "김민지" / "성적.csv").read_bytes() == before


def test_sse_format_helper():
    s = _sse_format({"event": "patch", "patch": {"op": "set_cell", "seq": 3}})
    assert s.startswith("event: patch\n")
    assert json.loads(s.split("data: ", 1)[1].strip())["patch"]["seq"] == 3


def test_sse_stream_hello_and_patch(client):
    c, _ = client
    events = []
    done = threading.Event()

    def reader():
        with c.stream("GET", "/drive/김민지/workdoc/events",
                      params={"path": "성적.csv"}) as r:
            buf = []
            for line in r.iter_lines():
                if line:
                    buf.append(line)
                    continue
                if buf:
                    events.append(list(buf)); buf = []
                if len(events) >= 2:
                    done.set(); return

    t = threading.Thread(target=reader, daemon=True)
    t.start()
    import time
    time.sleep(0.3)                                    # hello 수신 대기
    c.post("/drive/김민지/workdoc/ask", json={"path": "성적.csv", "question": "민지 95로"})
    assert done.wait(timeout=5), f"이벤트 2개 미수신: {events}"
    assert any("hello" in l for l in events[0])
    assert any("patch" in l for l in events[1])
```

Note to implementer on `test_edit_ask_audits`: finish it properly — have the fixture also return the db path, open sqlite3, and assert one `audit_log` row with `action='workdoc_edited'` and `'성적.csv'` in detail. The sketch is deliberately incomplete on mechanics but the assertion target is binding.

- [ ] **Step 2: Run to verify failures** — 404s (routes missing), ImportError `_sse_format`.

- [ ] **Step 3: Implement in `hub/api/drive.py`**

Signature: `def drive_router(reg, cfg, store, drives_dir: str, doc_converter=None, llm_factory=None, work_hub=None) -> APIRouter:` (with `work_hub = work_hub or WorkdocHub()` fallback so old tests keep working). New imports at top: `queue`, `from fastapi.responses import StreamingResponse`, `from hub.core.edit_tools import EDIT_TOOL_SCHEMAS, make_edit_dispatch`, `from hub.drive.workdoc import append_patch, save_workdoc`, `from hub.drive.workhub import WorkdocHub`, `from hub.llm import prompts`, `from hub.llm.orchestrator import run_turn`.

```python
    class WorkAskBody(BaseModel):
        path: str
        question: str

    def _workdoc_target(owner: str, path: str) -> Path:
        target = resolve_within(_root(owner), path)
        if not target.is_file():
            raise HTTPException(404, "파일을 찾을 수 없습니다")
        ext = target.suffix.lower()
        if ext not in TABULAR_EXT and ext not in DOC_EXT:
            raise HTTPException(400, "뷰어가 지원하지 않는 형식입니다")
        return target

    def _get_workdoc(target: Path):
        try:
            return work_hub.get(target, doc_converter)
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(
                422, "파일을 읽지 못했어요. 인코딩(UTF-8)이나 파일 손상 여부를 확인해 주세요")

    @r.get("/drive/{owner}/workdoc")
    def workdoc_snapshot(owner: str, path: str = "", offset: int = 0, limit: int = 500):
        target = _workdoc_target(owner, path)
        wd = _get_workdoc(target)
        if wd.kind == "tabular":
            sheets = [{"name": s["name"], "columns": s["columns"],
                       "rows": s["rows"][:200], "total_rows": len(s["rows"])}
                      for s in wd.sheets]
            return {"kind": "tabular", "filename": wd.filename, "seq": wd.seq,
                    "sheets": sheets}
        offset = max(0, offset)
        limit = max(1, min(limit, 1000))
        return {"kind": "document", "filename": wd.filename, "seq": wd.seq,
                "total": len(wd.blocks), "offset": offset,
                "blocks": wd.blocks[offset:offset + limit]}

    @r.post("/drive/{owner}/workdoc/ask")
    def workdoc_ask(owner: str, body: WorkAskBody):
        o = safe_owner(owner)
        target = _workdoc_target(owner, body.path)
        if llm_factory is None:
            raise HTTPException(500, "LLM이 구성되지 않았습니다")
        llm = llm_factory(cfg)
        with work_hub.lock(target):
            wd = _get_workdoc(target)
            patches: list[dict] = []

            def on_patch(p: dict) -> None:
                patches.append(p)
                append_patch(target, p)
                work_hub.publish(target, {"event": "patch", "patch": p})

            dispatch = make_edit_dispatch(wd, on_patch)
            result = run_turn(body.question, reg, "", llm,
                              max_iters=cfg.max_tool_iters,
                              tool_schemas=EDIT_TOOL_SCHEMAS,
                              dispatch=dispatch, system=prompts.EDITOR)
            if patches:
                save_workdoc(wd, target)
                store.add_audit(o, "workdoc_edited", "drive", 0,
                                f"{o}:{body.path} {len(patches)}건")
                work_hub.publish(target, {"event": "turn_done", "seq": wd.seq})
        return {"answer": result.text,
                "tool_calls": [t["name"] for t in result.trace],
                "usage": result.usage, "seq": wd.seq, "patched": len(patches)}

    @r.get("/drive/{owner}/workdoc/events")
    def workdoc_events(owner: str, path: str = ""):
        target = _workdoc_target(owner, path)
        wd = _get_workdoc(target)

        def gen():
            q = work_hub.subscribe(target)
            try:
                yield _sse_format({"event": "hello", "seq": wd.seq})
                while True:
                    try:
                        ev = q.get(timeout=15)
                    except queue.Empty:
                        yield ": ping\n\n"
                        continue
                    yield _sse_format(ev)
            finally:
                work_hub.unsubscribe(target, q)

        return StreamingResponse(gen(), media_type="text/event-stream",
                                 headers={"Cache-Control": "no-cache"})
```

Module-level helper (top of file, after models):

```python
def _sse_format(event: dict) -> str:
    name = event.get("event", "message")
    return f"event: {name}\ndata: {json.dumps(event, ensure_ascii=False)}\n\n"
```

- [ ] **Step 4: Wire in `hub/api/__init__.py`**

```python
    from hub.drive.workhub import WorkdocHub
    work_hub = WorkdocHub()
    app.include_router(drive_router(reg, cfg, store, drives_dir, doc_converter,
                                    factory, work_hub))
```

(import at top; replaces the existing drive_router call args.)

- [ ] **Step 5: Run tests** — module green, full suite green.

- [ ] **Step 6: Commit**

```bash
git add hub/api/drive.py hub/api/__init__.py tests/test_api_workdoc.py
git commit -m "feat(workdoc): API — 스냅샷/편집 턴(락·감사·지속화)/SSE 이벤트"
```

---

### Task 5: Re-upload confirmation (409 + overwrite=1) + invalidation coherence

**Files:**
- Modify: `hub/api/drive.py` (upload endpoint)
- Modify: `static/drive.js` (upload handler confirm/retry)
- Test: `tests/test_api_drive_fs.py` (append)

**Interfaces:**
- Consumes: `work_hub.invalidate` (Task 2).
- Produces: `POST /drive/{owner}/files?path=&overwrite=` — if target exists as a FILE and `overwrite != "1"` → `409 {"detail": "같은 이름의 파일이 이미 있어요. 덮어쓰려면 다시 확인해 주세요."}`. With `overwrite=1`: writes, then invalidates `_view` cache (already there) AND `work_hub.invalidate(target)`. UI: on that 409, `confirm('"<이름>" 파일이 이미 있어요. 덮어쓸까요?')` → retry with `overwrite: '1'`; decline → count as skipped with reason "덮어쓰기 취소".
- **Invalidation coherence (phase-1 I2와 같은 계열, 선제 차단)**: `move` invalidates the workdoc for BOTH src and dst paths (`work_hub.invalidate(src_target)` before rename — the workdoc keyed by the old path is orphaned; `work_hub.invalidate(dst)` after rename — dst must not inherit a previous same-named file's workdoc); `delete_entry` on a FILE also calls `work_hub.invalidate(target)`. Covering test: persist a fake edited workdoc for a file (save_workdoc, like the overwrite test), move the file, assert the old `_workdoc/<이름>.json` is gone and `GET /workdoc` at the new path returns the ORIGINAL content (seq 0).

- [ ] **Step 1: Append failing tests to `tests/test_api_drive_fs.py`**

```python
def test_reupload_requires_overwrite_flag(client):
    _upload(client, "김민지", "", "성적.csv")
    r = _upload(client, "김민지", "", "성적.csv")
    assert r.status_code == 409
    assert "덮어쓰" in r.json()["detail"]


def test_reupload_with_flag_overwrites_and_invalidates_workdoc(client, tmp_path):
    _upload(client, "김민지", "", "성적.csv", data=b"a,b\n1,2\n")
    # 작업본을 편집된 상태로 지속화 (재업로드가 지워야 할 대상)
    from hub.drive.workdoc import Workdoc, save_workdoc
    f = tmp_path / "drives" / "김민지" / "성적.csv"
    save_workdoc(Workdoc(kind="tabular", filename="성적.csv", seq=3,
                         sheets=[{"name": "s", "columns": ["a"], "rows": [[1]]}]), f)
    r = client.post("/drive/김민지/files", params={"path": "", "overwrite": "1"},
                    files={"file": ("성적.csv", b"a,b\n9,9\n", "text/csv")})
    assert r.status_code == 200
    assert not (tmp_path / "drives" / "김민지" / "_workdoc" / "성적.csv.json").exists()
    dl = client.get("/drive/김민지/file", params={"path": "성적.csv"})
    assert dl.content == b"a,b\n9,9\n"
```

(Adjust the fixture if it doesn't currently expose `tmp_path`; the existing `client` fixture already builds from `tmp_path` — give the test both via the fixture's params or request the fixture value. Implementer resolves mechanically.)

- [ ] **Step 2: Run to verify failures** — second upload currently 200.

- [ ] **Step 3: Implement server side** (in `upload`, after the folder-collision 409 and before writing):

```python
        target = d / safe_name
        if target.is_file() and overwrite != "1":
            raise HTTPException(409, "같은 이름의 파일이 이미 있어요. 덮어쓰려면 다시 확인해 주세요.")
```

with `overwrite: str = ""` added to the endpoint's query params, and after `write_bytes` add `work_hub.invalidate(target)` next to the existing `_view` rmtree.

- [ ] **Step 4: Implement client side** (upload onchange in drive.js): on `r.status === 409` and the detail contains "덮어쓰", `confirm(...)` → re-POST with `overwrite: '1'` in `_dUrl('files', { path: _dPath, overwrite: '1' })`; if declined push `f.name + ' — 덮어쓰기 취소'` to failed. Keep per-file loop behavior.

- [ ] **Step 5: Run tests + node --check + full suite. Commit**

```bash
git add hub/api/drive.py static/drive.js tests/test_api_drive_fs.py
git commit -m "feat(drive): 재업로드 덮어쓰기 확인(409+overwrite=1) + 작업본/뷰어 캐시 무효화"
```

---

### Task 6: Viewer live mode — workdoc snapshot + SSE patches + edit-chat routing

**Files:**
- Modify: `static/drive.js`
- Modify: `static/ui.css`

**Interfaces:**
- Consumes: Task 4 endpoints. Existing viewer internals: `openViewer(name)`, `_viewerFrame`, `renderDocBlocks(container, blocks, state)`, `renderDocView`, `renderSheetView`, `_dViewFile`; chat internals: `dAsk`, `dEnsureSession`, `_dChatGen`.
- Produces:
  1. `openViewer` fetches `/drive/{owner}/workdoc?path=…` instead of `/view` (same response shape + seq) and remembers `_dViewSeq`. Document blocks get `data-bi` (block index) on each rendered block element (pass base index into `renderDocBlocks`; page dividers excluded from indexing). Sheet grid: `<td>` gets `data-r`/`data-c` (row index, column name) for the ACTIVE sheet.
  2. After a successful snapshot render, open `new EventSource(_dUrl('workdoc/events', { path: path }))` stored in `_dES`; `closeViewer()` closes it. Handlers:
     - `hello`: if `data.seq !== _dViewSeq` → full re-open (stale snapshot).
     - `patch`: apply live:
       - `replace_block`: find `[data-bi="<index>"]` in the doc container → set its textContent to patch.text, add class `dv-changed`, remove after 1.5s (setTimeout). If the node isn't rendered (paged out), ignore.
       - `set_cell`: if patch.sheet is the active sheet, find `td[data-r][data-c]` and update textContent + `dv-changed`.
       - `insert_block`/`delete_block`/`insert_row`/`delete_row`: structural — set `_dViewSeq` stale and re-open the viewer (simple + correct; per plan this is the accepted phase-2 behavior for structural ops).
       - Every patch updates `_dViewSeq = patch.seq`; if `patch.seq !== _dViewSeq_prev + 1` (gap) → re-open viewer instead of applying.
     - `turn_done`: no-op beyond seq bookkeeping (kept for future).
     - `onerror`: EventSource auto-reconnects; nothing to do (hello handles resync).
  3. Edit-mode chat routing: when the viewer is open (`_dViewFile` non-null), `dAsk` POSTs to `_dUrl('workdoc/ask', {})` with body `{path: _dViewFile, question: q}` instead of the session ask; response `{answer, tool_calls}` renders through the same `dAiMsg({answer: …, citations: [], tool_calls: …})`. A mode chip above the composer shows `편집: <파일명>` while the viewer is open (`#dChatHint` gains the text "지금 보내는 지시는 이 문서 작업본을 편집해요 — 원본 파일은 그대로예요."); closing the viewer restores folder-chat mode and the original hint. The `_dChatGen` staleness guard applies to this path identically (closeViewer does NOT bump chat gen; navigating does — verify no new race: capture `const askPath = _dViewFile` at dAsk start and use it in the body).
  4. CSS append: `.dv-changed { background: color-mix(in srgb, var(--accent) 18%, transparent); transition: background .6s ease; }` — with a fallback for older engines: also add `outline: 1px solid var(--accent);` on `.dv-changed`. Mode chip style `.dchip { display:inline-block; border:1px solid var(--line); border-radius:999px; padding:2px 10px; font-size:12px; color:var(--text-2); margin-bottom:6px; }` (accent use here is the running-state highlight ONLY — the chip uses neutral tokens).

- [ ] **Step 1: Implement** per above, following the existing drive.js style (el() only, staleness guards, driveError policy). Core sketch — adapt indices/naming to the real code you find:

```js
let _dViewSeq = 0;
let _dES = null;

function _openEvents(path) {
  if (_dES) { _dES.close(); _dES = null; }
  const es = new EventSource(_dUrl('workdoc/events', { path: path }));
  _dES = es;
  es.addEventListener('hello', function (ev) {
    const d = JSON.parse(ev.data);
    if (_dViewFile === path && d.seq !== _dViewSeq) openViewer(path.split('/').pop());
  });
  es.addEventListener('patch', function (ev) {
    if (_dViewFile !== path) return;
    const p = JSON.parse(ev.data).patch;
    if (p.seq !== _dViewSeq + 1) { openViewer(path.split('/').pop()); return; }
    _dViewSeq = p.seq;
    if (p.op === 'replace_block') {
      const node = document.querySelector('#dViewer [data-bi="' + p.index + '"]');
      if (node) { node.textContent = p.text; flashChanged(node); }
    } else if (p.op === 'set_cell') {
      const td = document.querySelector(
        '#dViewer td[data-r="' + p.row + '"][data-c="' + CSS.escape(p.col) + '"]');
      if (td) { td.textContent = p.value === null || p.value === undefined ? '' : String(p.value); flashChanged(td); }
    } else {
      openViewer(path.split('/').pop());   // 구조 변경은 재열람 (phase 2 확정 동작)
    }
  });
}

function flashChanged(node) {
  node.classList.add('dv-changed');
  setTimeout(function () { node.classList.remove('dv-changed'); }, 1500);
}
```

`closeViewer()` gains `if (_dES) { _dES.close(); _dES = null; }` and restores `#dChatHint`. `openViewer` sets `_dViewSeq = data.seq` after a successful snapshot render, calls `_openEvents(path)`, and swaps `#dChatHint` to the edit-mode text. `dAsk` routing (guarded by the existing `_dChatGen`):

```js
    const askPath = _dViewFile;             // 편집 모드 여부를 전송 시점에 고정
    // ... 기존 흐름에서 fetch 부분만 분기:
    const r = askPath
      ? await fetch(_dUrl('workdoc/ask', {}), {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ path: askPath, question: q }),
        })
      : await fetch('/session/' + sid + '/ask', { /* 기존 그대로 */ });
    // 성공 시: askPath면 dAiMsg({ answer: body.answer, citations: [], tool_calls: body.tool_calls })
```

(`dEnsureSession()`은 askPath가 있으면 건너뛴다 — 편집 턴은 세션이 필요 없다.)

- [ ] **Step 2: Verify**

```bash
node --check static/drive.js
./.venv/bin/python -m pytest -q     # 정적 변경만 — 전체 green 유지
```

Playwright live check on an isolated server (port 8765, throwaway env, codex backend — but for DETERMINISM inject nothing: instead run the server with `OFFICE_HUB_LLM_BACKEND=codex` and drive the patch path via curl `POST /drive/{owner}/workdoc/ask`? No — that still needs a real LLM. Correct approach: start the isolated server with a TINY scripted-LLM app factory instead: create a scratch python file that builds `create_app(llm_factory=<scripted set_cell llm>, …)` and uvicorn-runs it (see tests/test_api_workdoc.py's ScriptedLLM), then in the browser: upload csv → open viewer → send "민지 점수를 95로" in chat → assert the cell td updates to "95" and gets .dv-changed, without a page reload. Screenshot to the scratchpad. Kill by PID.)

- [ ] **Step 3: Commit**

```bash
git add static/drive.js static/ui.css
git commit -m "feat(drive): 뷰어 라이브 모드 — 작업본 스냅샷 + SSE 패치 반영 + 편집 채팅 라우팅"
```

---

### Task 7: E2E extension + README + ledger

**Files:**
- Modify: `tests/e2e_drive_playwright.mjs` (add a live-edit scene using the scripted-LLM server from Task 6's verification — document the required server-start command in the header comment, including teardown by PID)
- Modify: `README.md` (3 lines: 편집 모드, 원본 불변+작업본, 실시간 반영)

- [ ] **Step 1: E2E scene** — after the existing chat scene: open viewer on the csv → send edit instruction → wait for td[data-r="0"] update + `.dv-changed` observed → assert `#dChatHint` shows edit-mode text → close viewer → assert hint restored. Keep existing 5 scenes passing.
- [ ] **Step 2: Run E2E (7/7 expected), full pytest suite, README update.**
- [ ] **Step 3: Commit**

```bash
git add tests/e2e_drive_playwright.mjs README.md
git commit -m "test(drive): 라이브 편집 E2E + README 편집 모드 안내"
```

---

## Final whole-branch review

`scripts/review-package 5a90e9e HEAD` (phase-2 commits only — phase 1 already reviewed) on the most capable model. Constraints block: this plan's Global Constraints verbatim. Ask it to specifically verify: original-file immutability under every new endpoint, `_workdoc` hidden-namespace isolation (listings/move/ingest scan), SSE generator cleanup (unsubscribe on disconnect), lock coverage of every workdoc mutation, and the deterministic-edit invariant (no code path lets LLM text mutate state directly).

## Execution amendments

(record deviations here during execution)

Execution record (2026-07-06): all 7 tasks complete on `drive/phase-1` (5a90e9e..76bbbad, 13 commits), 278 tests green, E2E 12/12 (deterministic scripted-LLM server `tests/e2e_server.py`). Final review conditional-Yes; all four conditions (upload event-loop freeze, invalidated-event viewer resync, folder-move prefix purge, multi-sheet patch coherence) fixed in f69af20, I1 regression test strengthened with proven revert-fails bystander check in 76bbbad. Notable amendments: mode chip (.dchip) replaced by hint-text signal (reviewer-adjudicated stronger); on_patch failure separated from edit failure (double-apply prevention); mid-turn exception still persists+audits applied patches (finally); load_workdoc hardened to converge all corruption to None. Deferred/known limits in app ledger (.superpowers/sdd/progress.md drive/phase-2 section).
