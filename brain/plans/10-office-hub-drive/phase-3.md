# Drive Phase 3 Implementation Plan — 내보내기 (workdoc → xlsx/docx/pdf/md)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export the current workdoc state to a NEW file in the same drive folder — tabular → xlsx; document → md / docx / pdf — with collision-free naming, an export control in the viewer, audit, and E2E coverage.

**Architecture:** New `hub/drive/export.py` (pure functions: workdoc → bytes/file per format + `dedup_name`). One new endpoint `POST /drive/{owner}/workdoc/export` on the drive router (reads the workdoc via `work_hub.get`, writes the new file, audits `workdoc_exported`). Viewer gains an export control in `.dv-head`; the file list refreshes to show the new file.

**Tech Stack:** openpyxl (present), **python-docx and reportlab (NEW dependencies** — added to requirements.txt and installed into .venv; reportlab's `UnicodeCIDFont("HYGothic-Medium")` renders Korean without bundling font files).

**Branch:** continue on `drive/phase-1` (stacked; user merges the stack when ready). Current tip 76bbbad, 278 tests green.

## Global Constraints

- Everything from phases 1–2 still binds: original drive files never mutated (export CREATES new files only, never overwrites — collision → ` (편집본 2)`, ` (편집본 3)`…); no innerHTML; existing tokens.css only, no new accent uses; traversal/null-byte guards; Korean errors; tests isolated (tmp everything, zero real LLM/kordoc/network); port 8000 by PID only; venv pytest.
- Format rules: tabular workdoc → `xlsx` only; document workdoc → `md` | `docx` | `pdf`. Wrong format for kind → 400 "이 문서 형식으로는 내보낼 수 없습니다".
- Exported filename: `{원본 stem} (편집본).{ext}`, deduped with a counter; lands in the SAME folder as the source file; must appear in the next listing (visible, not hidden).
- Export writes the CURRENT workdoc state (edited or not — exporting an unedited view is allowed and equals a format conversion). Export itself must NOT persist the workdoc to `_workdoc/` (read-only operation on the workdoc; `test_snapshot_does_not_persist` discipline extends here).
- Document table blocks: rendered as plain grids in all formats; row/col spans are flattened (first cell text kept, spanned coverage becomes empty cells) — recorded limitation, do not build span fidelity.
- Audit action: `workdoc_exported`, target_type `"drive"`, target_id 0, detail `f"{owner}:{path} → {새파일명}"`.
- New deps pinned as floors in requirements.txt: `python-docx>=1.1.0`, `reportlab>=4.0.0`. Install into .venv before running tests.

## File Structure

- Create: `hub/drive/export.py` — `dedup_name`, `blocks_to_markdown`, `export_workdoc(wd, fmt, dest_dir, source_name) -> Path`
- Modify: `hub/api/drive.py` — `POST /drive/{owner}/workdoc/export`
- Modify: `static/drive.js` — export control in viewer header + success note + list refresh
- Modify: `static/ui.css` — `.dv-export` row styles (existing tokens only)
- Modify: `requirements.txt`, `README.md`
- Modify: `tests/e2e_drive_playwright.mjs` — export scene
- Test: `tests/test_drive_export.py`, `tests/test_api_workdoc_export.py`

---

### Task 1: Export core — md + xlsx + collision-free naming (`hub/drive/export.py`)

**Files:**
- Create: `hub/drive/export.py`
- Test: `tests/test_drive_export.py`

**Interfaces:**
- Produces (consumed by Tasks 2–3):
  - `dedup_name(dest_dir: Path, stem: str, ext: str) -> str` — returns `f"{stem} (편집본).{ext}"` or with ` 2`, ` 3`… counter until non-existing.
  - `blocks_to_markdown(blocks: list[dict]) -> str` — heading→`## text`; paragraph→text + blank line; table→GitHub-style md table (first row = header; spans flattened: only each cell's text, missing cells empty).
  - `export_workdoc(wd: Workdoc, fmt: str, dest_dir: Path, source_name: str) -> Path` — validates kind/format (raises `ExportError(ValueError)` with the Korean message), builds the file, returns the created Path. This task implements `md` and `xlsx`; Task 2 adds `docx`/`pdf` (until then those formats raise `ExportError("아직 지원하지 않는 형식입니다")`).

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_drive_export.py
"""내보내기 코어 — 작업본 → 파일, 이름 충돌 없이."""
from pathlib import Path

import pytest
from openpyxl import load_workbook

from hub.drive.export import ExportError, blocks_to_markdown, dedup_name, export_workdoc
from hub.drive.workdoc import Workdoc


def _tab_wd():
    return Workdoc(kind="tabular", filename="성적.csv", seq=1, sheets=[
        {"name": "성적", "columns": ["이름", "점수"],
         "rows": [["민지", 95], ["하나", 85]]},
        {"name": "메모", "columns": ["내용"], "rows": [["보강 필요"]]},
    ])


def _doc_wd():
    return Workdoc(kind="document", filename="공문.hwpx", seq=1, blocks=[
        {"type": "heading", "text": "제목", "pageNumber": 1, "style": {"fontSize": 150}},
        {"type": "paragraph", "text": "첫 문단입니다.", "pageNumber": 1},
        {"type": "table", "pageNumber": 2, "table": {"rows": 2, "cols": 2, "cells": [
            [{"text": "구분", "colSpan": 1, "rowSpan": 1}, {"text": "값", "colSpan": 1, "rowSpan": 1}],
            [{"text": "인원", "colSpan": 1, "rowSpan": 1}, {"text": "12", "colSpan": 1, "rowSpan": 1}],
        ]}},
    ])


def test_dedup_name(tmp_path):
    assert dedup_name(tmp_path, "성적", "xlsx") == "성적 (편집본).xlsx"
    (tmp_path / "성적 (편집본).xlsx").write_bytes(b"x")
    assert dedup_name(tmp_path, "성적", "xlsx") == "성적 (편집본 2).xlsx"
    (tmp_path / "성적 (편집본 2).xlsx").write_bytes(b"x")
    assert dedup_name(tmp_path, "성적", "xlsx") == "성적 (편집본 3).xlsx"


def test_export_tabular_xlsx_roundtrip(tmp_path):
    p = export_workdoc(_tab_wd(), "xlsx", tmp_path, "성적.csv")
    assert p.name == "성적 (편집본).xlsx" and p.parent == tmp_path
    wb = load_workbook(p)
    assert wb.sheetnames == ["성적", "메모"]
    ws = wb["성적"]
    assert [c.value for c in ws[1]] == ["이름", "점수"]
    assert [c.value for c in ws[2]] == ["민지", 95]


def test_blocks_to_markdown():
    md = blocks_to_markdown(_doc_wd().blocks)
    assert "## 제목" in md
    assert "첫 문단입니다." in md
    assert "| 구분 | 값 |" in md
    assert "| 인원 | 12 |" in md


def test_export_document_md(tmp_path):
    p = export_workdoc(_doc_wd(), "md", tmp_path, "공문.hwpx")
    assert p.name == "공문 (편집본).md"
    text = p.read_text(encoding="utf-8")
    assert "## 제목" in text and "| 인원 | 12 |" in text


@pytest.mark.parametrize("wd,fmt", [
    (_tab_wd(), "md"), (_tab_wd(), "docx"), (_tab_wd(), "pdf"),
    (_doc_wd(), "xlsx"),
])
def test_kind_format_mismatch(tmp_path, wd, fmt):
    with pytest.raises(ExportError):
        export_workdoc(wd, fmt, tmp_path, wd.filename)


def test_unknown_format(tmp_path):
    with pytest.raises(ExportError):
        export_workdoc(_tab_wd(), "hwp", tmp_path, "성적.csv")


def test_malformed_table_block_does_not_crash(tmp_path):
    wd = Workdoc(kind="document", filename="x.hwpx", seq=0, blocks=[
        {"type": "table", "table": {"cells": [None, [{"text": "a"}, None]]}},
        {"type": "paragraph"},
    ])
    p = export_workdoc(wd, "md", tmp_path, "x.hwpx")
    assert p.is_file()
```

- [ ] **Step 2: Run to verify failures**

Run: `./.venv/bin/python -m pytest tests/test_drive_export.py -q`
Expected: FAIL `ModuleNotFoundError: No module named 'hub.drive.export'`

- [ ] **Step 3: Implement**

```python
# hub/drive/export.py
from __future__ import annotations

from pathlib import Path

from openpyxl import Workbook

from hub.drive.workdoc import Workdoc


class ExportError(ValueError):
    pass


def dedup_name(dest_dir: Path, stem: str, ext: str) -> str:
    name = f"{stem} (편집본).{ext}"
    n = 2
    while (dest_dir / name).exists():
        name = f"{stem} (편집본 {n}).{ext}"
        n += 1
    return name


def _table_rows(block: dict) -> list[list[str]]:
    """kordoc 표 블록 → 문자열 그리드. 스팬은 평탄화(각 셀 텍스트만), 비정상 행/셀은 건너뜀."""
    rows: list[list[str]] = []
    for row in (block.get("table") or {}).get("cells") or []:
        if not isinstance(row, list):
            continue
        rows.append([str((c or {}).get("text", "")) for c in row])
    return rows


def blocks_to_markdown(blocks: list[dict]) -> str:
    out: list[str] = []
    for b in blocks or []:
        t = b.get("type")
        if t == "heading":
            out.append(f"## {b.get('text', '')}")
        elif t == "table":
            rows = _table_rows(b)
            if not rows:
                continue
            width = max(len(r) for r in rows)
            grid = [r + [""] * (width - len(r)) for r in rows]
            out.append("| " + " | ".join(grid[0]) + " |")
            out.append("|" + "---|" * width)
            for r in grid[1:]:
                out.append("| " + " | ".join(r) + " |")
        else:
            out.append(str(b.get("text", "")))
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def _export_xlsx(wd: Workdoc, dest: Path) -> None:
    wb = Workbook()
    wb.remove(wb.active)
    for s in wd.sheets:
        ws = wb.create_sheet(title=(s["name"][:31] or "Sheet"))
        ws.append(list(s["columns"]))
        for row in s["rows"]:
            ws.append(["" if v is None else v for v in row])
    wb.save(str(dest))


TABULAR_FORMATS = {"xlsx"}
DOCUMENT_FORMATS = {"md", "docx", "pdf"}


def export_workdoc(wd: Workdoc, fmt: str, dest_dir: Path, source_name: str) -> Path:
    allowed = TABULAR_FORMATS if wd.kind == "tabular" else DOCUMENT_FORMATS
    if fmt not in TABULAR_FORMATS | DOCUMENT_FORMATS:
        raise ExportError(f"알 수 없는 내보내기 형식입니다: {fmt}")
    if fmt not in allowed:
        raise ExportError("이 문서 형식으로는 내보낼 수 없습니다")
    stem = Path(source_name).stem
    dest = dest_dir / dedup_name(dest_dir, stem, fmt)
    if fmt == "xlsx":
        _export_xlsx(wd, dest)
    elif fmt == "md":
        dest.write_text(blocks_to_markdown(wd.blocks), encoding="utf-8")
    else:  # docx / pdf — Task 2에서 구현
        raise ExportError("아직 지원하지 않는 형식입니다")
    return dest
```

- [ ] **Step 4: Run tests** — docx/pdf mismatch cases pass because kind check precedes format availability (tabular+docx → mismatch error). Note: `test_kind_format_mismatch` for `(_tab_wd(), "docx")` hits the kind rule, not the "아직 지원 안 함" branch — both raise ExportError, fine. Module green, then full suite `-q` (278 prior green).

- [ ] **Step 5: Commit**

```bash
git add hub/drive/export.py tests/test_drive_export.py
git commit -m "feat(export): 내보내기 코어 — md/xlsx + 충돌 없는 이름"
```

---

### Task 2: docx + pdf writers (new dependencies)

**Files:**
- Modify: `requirements.txt` (+2 lines), `hub/drive/export.py`
- Test: `tests/test_drive_export.py` (append)

**Interfaces:**
- Consumes: Task 1's `export_workdoc` dispatch (`else` branch) and `_table_rows`.
- Produces: `docx`/`pdf` branches. docx via python-docx (heading→`add_heading(level=2)`, paragraph→`add_paragraph`, table→`add_table` plain grid). pdf via reportlab platypus with `UnicodeCIDFont("HYGothic-Medium")` (Korean without font files): heading→bold 14pt Paragraph, paragraph→10.5pt Paragraph, table→`Table` with a light grid.

- [ ] **Step 1: Add deps and install**

Append to `requirements.txt`:

```
python-docx>=1.1.0
reportlab>=4.0.0
```

Run: `./.venv/bin/python -m pip install "python-docx>=1.1.0" "reportlab>=4.0.0"`
Expected: both install cleanly (pure-python wheels).

- [ ] **Step 2: Append failing tests**

```python
# append to tests/test_drive_export.py

def test_export_document_docx(tmp_path):
    p = export_workdoc(_doc_wd(), "docx", tmp_path, "공문.hwpx")
    assert p.name == "공문 (편집본).docx"
    import docx
    d = docx.Document(str(p))
    texts = [par.text for par in d.paragraphs]
    assert "제목" in texts and "첫 문단입니다." in texts
    assert len(d.tables) == 1
    assert d.tables[0].cell(1, 0).text == "인원"


def test_export_document_pdf(tmp_path):
    p = export_workdoc(_doc_wd(), "pdf", tmp_path, "공문.hwpx")
    assert p.name == "공문 (편집본).pdf"
    data = p.read_bytes()
    assert data[:5] == b"%PDF-"
    assert len(data) > 1000
```

- [ ] **Step 3: Run to verify failures** — both raise ExportError("아직 지원하지 않는 형식입니다").

- [ ] **Step 4: Implement (replace the `else` branch in `export_workdoc` and add helpers)**

```python
def _export_docx(wd: Workdoc, dest: Path) -> None:
    import docx

    d = docx.Document()
    for b in wd.blocks or []:
        t = b.get("type")
        if t == "heading":
            d.add_heading(str(b.get("text", "")), level=2)
        elif t == "table":
            rows = _table_rows(b)
            if not rows:
                continue
            width = max(len(r) for r in rows)
            table = d.add_table(rows=len(rows), cols=width)
            table.style = "Table Grid"
            for i, r in enumerate(rows):
                for j in range(width):
                    table.cell(i, j).text = r[j] if j < len(r) else ""
        else:
            d.add_paragraph(str(b.get("text", "")))
    d.save(str(dest))


def _export_pdf(wd: Workdoc, dest: Path) -> None:
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.cidfonts import UnicodeCIDFont
    from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

    pdfmetrics.registerFont(UnicodeCIDFont("HYGothic-Medium"))
    h = ParagraphStyle("h", fontName="HYGothic-Medium", fontSize=14, leading=20, spaceAfter=8)
    body = ParagraphStyle("body", fontName="HYGothic-Medium", fontSize=10.5, leading=16, spaceAfter=6)
    story = []
    for b in wd.blocks or []:
        t = b.get("type")
        if t == "table":
            rows = _table_rows(b)
            if not rows:
                continue
            width = max(len(r) for r in rows)
            grid = [r + [""] * (width - len(r)) for r in rows]
            tbl = Table(grid)
            tbl.setStyle(TableStyle([
                ("FONTNAME", (0, 0), (-1, -1), "HYGothic-Medium"),
                ("FONTSIZE", (0, 0), (-1, -1), 9.5),
                ("GRID", (0, 0), (-1, -1), 0.4, colors.grey),
            ]))
            story.append(tbl)
            story.append(Spacer(1, 8))
        else:
            style = h if t == "heading" else body
            text = str(b.get("text", "")).replace("&", "&amp;").replace("<", "&lt;")
            story.append(Paragraph(text or " ", style))
    SimpleDocTemplate(str(dest), pagesize=A4).build(story)
```

and in `export_workdoc`:

```python
    elif fmt == "docx":
        _export_docx(wd, dest)
    else:  # "pdf"
        _export_pdf(wd, dest)
```

- [ ] **Step 5: Run tests** — module green, full suite green.

- [ ] **Step 6: Commit**

```bash
git add requirements.txt hub/drive/export.py tests/test_drive_export.py
git commit -m "feat(export): docx/pdf 작성기 (python-docx, reportlab HYGothic CID 한글)"
```

---

### Task 3: Export API endpoint

**Files:**
- Modify: `hub/api/drive.py`
- Test: `tests/test_api_workdoc_export.py`

**Interfaces:**
- Consumes: `export_workdoc`/`ExportError` (Tasks 1–2), `_workdoc_target`, `_get_workdoc`, `work_hub.lock`, `store.add_audit`, `_listing`.
- Produces: `POST /drive/{owner}/workdoc/export` body `{"path","format"}` → `{"filename": "<새 파일명>"}` (201). Reads workdoc under `work_hub.lock(target)` (consistent snapshot while an edit turn may run), writes into the source file's PARENT dir. `ExportError` → 400 with its Korean message. Audit `workdoc_exported`. Does NOT persist the workdoc, does NOT touch `_view`/`_workdoc` caches (a new distinct file appears — no invalidation needed).

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_api_workdoc_export.py
"""내보내기 API — 작업본을 같은 폴더의 새 파일로."""
import sqlite3

import pytest
from fastapi.testclient import TestClient

from hub.api import create_app
from hub.llm.orchestrator import LLMResponse, ToolCall


class ScriptedLLM:
    def __init__(self):
        self._first = True

    def respond(self, system, messages, tools):
        if self._first:
            self._first = False
            return LLMResponse(tool_calls=[ToolCall(id="t1", name="set_cell",
                args={"sheet": "성적", "row": 0, "col": "점수", "value": 95})],
                text=None, usage={})
        return LLMResponse(tool_calls=[], text="고쳤어요.", usage={})


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("OFFICE_HUB_RUNS", str(tmp_path / "runs"))
    app = create_app(llm_factory=lambda cfg: ScriptedLLM(),
                     db_path=str(tmp_path / "hub.db"),
                     drives_dir=str(tmp_path / "drives"))
    c = TestClient(app)
    c.post("/drive/김민지/files", params={"path": ""},
           files={"file": ("성적.csv", "이름,점수\n민지,90\n하나,85\n".encode(), "text/csv")})
    return c, tmp_path


def test_export_edited_workdoc_to_xlsx(client):
    c, tmp = client
    c.post("/drive/김민지/workdoc/ask", json={"path": "성적.csv", "question": "민지 95로"})
    r = c.post("/drive/김민지/workdoc/export", json={"path": "성적.csv", "format": "xlsx"})
    assert r.status_code == 201
    name = r.json()["filename"]
    assert name == "성적 (편집본).xlsx"
    from openpyxl import load_workbook
    wb = load_workbook(tmp / "drives" / "김민지" / name)
    assert wb["성적"].cell(row=2, column=2).value == 95   # 편집이 반영된 값


def test_export_appears_in_listing_and_dedups(client):
    c, _ = client
    c.post("/drive/김민지/workdoc/export", json={"path": "성적.csv", "format": "xlsx"})
    r2 = c.post("/drive/김민지/workdoc/export", json={"path": "성적.csv", "format": "xlsx"})
    assert r2.json()["filename"] == "성적 (편집본 2).xlsx"
    names = [f["name"] for f in c.get("/drive/김민지/list").json()["files"]]
    assert "성적 (편집본).xlsx" in names and "성적 (편집본 2).xlsx" in names


def test_export_wrong_format_400(client):
    c, _ = client
    r = c.post("/drive/김민지/workdoc/export", json={"path": "성적.csv", "format": "pdf"})
    assert r.status_code == 400
    assert "내보낼 수 없습니다" in r.json()["detail"]


def test_export_missing_file_404(client):
    c, _ = client
    assert c.post("/drive/김민지/workdoc/export",
                  json={"path": "없음.csv", "format": "xlsx"}).status_code == 404


def test_export_audits_and_original_untouched(client):
    c, tmp = client
    before = (tmp / "drives" / "김민지" / "성적.csv").read_bytes()
    c.post("/drive/김민지/workdoc/export", json={"path": "성적.csv", "format": "xlsx"})
    assert (tmp / "drives" / "김민지" / "성적.csv").read_bytes() == before
    con = sqlite3.connect(tmp / "hub.db")
    rows = con.execute(
        "SELECT detail FROM audit_log WHERE action='workdoc_exported'").fetchall()
    con.close()
    assert len(rows) == 1 and "성적 (편집본).xlsx" in rows[0][0]


def test_export_does_not_persist_workdoc(client):
    c, tmp = client
    c.post("/drive/김민지/workdoc/export", json={"path": "성적.csv", "format": "xlsx"})
    assert not (tmp / "drives" / "김민지" / "_workdoc").exists()
```

- [ ] **Step 2: Run to verify failures** — 404 route missing.

- [ ] **Step 3: Implement (in `hub/api/drive.py`)**

Model next to the others:

```python
class WorkExportBody(BaseModel):
    path: str
    format: str
```

Endpoint after `workdoc_ask` (imports `export_workdoc`, `ExportError` at module top):

```python
    @r.post("/drive/{owner}/workdoc/export", status_code=201)
    def workdoc_export(owner: str, body: WorkExportBody):
        o = safe_owner(owner)
        target = _workdoc_target(owner, body.path)
        with work_hub.lock(target):
            wd = _get_workdoc(target)
            try:
                dest = export_workdoc(wd, body.format, target.parent, target.name)
            except ExportError as exc:
                raise HTTPException(400, str(exc))
        store.add_audit(o, "workdoc_exported", "drive", 0,
                        f"{o}:{body.path} → {dest.name}")
        return {"filename": dest.name}
```

- [ ] **Step 4: Run tests** — module green, full suite green.

- [ ] **Step 5: Commit**

```bash
git add hub/api/drive.py tests/test_api_workdoc_export.py
git commit -m "feat(export): POST /drive/{owner}/workdoc/export — 같은 폴더 새 파일 + 감사"
```

---

### Task 4: Viewer export UI + E2E + README

**Files:**
- Modify: `static/drive.js`, `static/ui.css`, `tests/e2e_drive_playwright.mjs`, `README.md`

**Interfaces:**
- Consumes: Task 3 endpoint; existing viewer internals (`_viewerFrame` builds `.dv-head`; `_dViewFile`; `_dRefresh`; `driveError` policy; `el()`).
- Produces: export controls in the viewer header, between title and close button: for tabular a single ghost button `xlsx로 내보내기`; for document a `<select class="dv-fmt">` (md/docx/pdf, Korean labels: "md (텍스트)", "docx (워드)", "pdf") + ghost button `내보내기`. Click → POST export → on success append a transient `.dv-note` at the top of `.dv-body` (“'<파일명>'(으)로 저장했어요 — 목록에서 내려받을 수 있어요.”) and call `_dRefresh()` (list shows the new file; viewer stays open). On failure show the detail via the same in-viewer note (error styling not required; message says why). Double-submit guard (`disabled` during request) + `_dViewFile` staleness check after the await.

- [ ] **Step 1: Implement** — sketch (adapt to real `_viewerFrame`/`openViewer` code; the kind is known from the snapshot `data.kind` inside `openViewer`, so build the controls there and insert into the header):

```js
function dExportControls(kind, path) {
  const box = el('span', 'dv-export');
  let sel = null;
  if (kind === 'document') {
    sel = document.createElement('select');
    sel.className = 'dv-fmt';
    [['md', 'md (텍스트)'], ['docx', 'docx (워드)'], ['pdf', 'pdf']].forEach(function (o) {
      const opt = document.createElement('option');
      opt.value = o[0]; opt.textContent = o[1];
      sel.appendChild(opt);
    });
    box.appendChild(sel);
  }
  const btn = el('button', 'b-ghost dv-export-btn',
                 kind === 'tabular' ? 'xlsx로 내보내기' : '내보내기');
  btn.onclick = async function () {
    btn.disabled = true;
    try {
      const fmt = kind === 'tabular' ? 'xlsx' : sel.value;
      const r = await fetch(_dUrl('workdoc/export', {}), {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ path: path, format: fmt }),
      });
      if (_dViewFile !== path) return;
      const body = await r.json().catch(function () { return {}; });
      const note = r.ok
        ? '"' + body.filename + '"(으)로 저장했어요 — 목록에서 내려받을 수 있어요.'
        : '내보내지 못했어요' + (body.detail ? ': ' + body.detail : '');
      const dvBody = document.querySelector('#dViewer .dv-body');
      if (dvBody) dvBody.prepend(el('p', 'dv-note', note));
      if (r.ok) _dRefresh();
    } catch (e) {
      console.error(e);
    } finally {
      btn.disabled = false;
    }
  };
  box.appendChild(btn);
  return box;
}
```

CSS append (existing tokens only):

```css
.dv-export { display: inline-flex; gap: 6px; align-items: center; margin-left: auto; margin-right: 8px; }
.dv-fmt { border: 1px solid var(--line); background: var(--bg); color: var(--text);
  border-radius: 8px; padding: 3px 6px; font-size: 12px; }
```

(`.dv-head` is flex space-between — inserting the export span before the close button with `margin-left:auto` keeps title left, controls right; verify against the real CSS.)

- [ ] **Step 2: E2E scene** (append to the live-edit scene while the viewer is open on the edited csv): click `.dv-export-btn` → wait for a `.dv-note` containing "저장했어요" → assert the list (`#dList`) now contains a `.drow` whose name includes "(편집본)" and ".xlsx". Screenshot drive-export.png. Keep all prior scenes passing; same server (`tests/e2e_server.py`, port 8766, PID teardown).

- [ ] **Step 3: README** — extend the 드라이브 section: 편집한 작업본은 뷰어의 "내보내기"로 같은 폴더에 새 파일(xlsx/md/docx/pdf)로 저장; 원본 불변.

- [ ] **Step 4: Verify + commit**

```bash
node --check static/drive.js
./.venv/bin/python -m pytest -q          # full suite green
# E2E: 서버 기동(8766, tests/e2e_server.py 헤더 참조) → 실행 → PID로만 종료
git add static/drive.js static/ui.css tests/e2e_drive_playwright.mjs README.md
git commit -m "feat(export): 뷰어 내보내기 UI + E2E + README"
```

---

## Final whole-branch review

`scripts/review-package 76bbbad HEAD` (phase-3 delta) on the most capable model. Constraints block: this plan's Global Constraints verbatim. Specific asks: export never overwrites anything (dedup under concurrency — two simultaneous exports of the same file: adjudicate); original-file immutability; the new-deps surface (python-docx/reportlab) — any import-time cost or license concern worth flagging; lock discipline (export holds the workdoc lock only while reading/writing — assess whether writing the file inside the lock is acceptable given pdf generation latency).

## Execution amendments

(record deviations here during execution)
