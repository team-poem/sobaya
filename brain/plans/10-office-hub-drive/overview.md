# 10 · office-hub-drive — Design Spec

Status: **phases 1+2 implemented (2026-07-06) — branch `drive/phase-1` (31 commits off ux/phase-a, 278 tests green, E2E 12/12). Phase 1 final review: Ready to merge=Yes (conditions fixed in 5a90e9e). Phase 2 final review: conditional Yes — all four conditions fixed (f69af20) and the I1 regression test strengthened with a proven revert-fails bystander check (76bbbad). Re-upload overwrite confirmation shipped in phase 2 (409+overwrite=1+confirm), resolving that deferred decision. Remaining for user: merge decision on the stack (main ← renewal/phase-1 ← ux/phase-a ← drive/phase-1), and the standing note that the no-auth owner model must gain auth before shared campus deployment. Phase 3 (export expansion: workdoc → xlsx/docx/pdf/md as new files) not started. Known accepted limits recorded in the app ledger (folder-move keeps nested edits; mode chip replaced by hint text; multi-sheet cap 200 rows in viewer).**
Date: 2026-07-06
App: `apps/office-automation-hub-design/app/`
Base: to branch off `ux/phase-a` (the current tip of the stack main ← renewal/phase-1 ← ux/phase-a)
Source: the user's own vision paragraph, written directly into `app/README.md`:

> 접수하는 방식이 따로 있고, 나머지 하나는 사용자가 그냥 파일들을 구글 드라이브처럼
> 얹어서 둔 폴더 베이스 안에서 채팅을 하면 해당 파일들을 읽으면서 같이 문서작업을
> 해준다. 그리고 뷰어 같은 게 떠서 한글을 열면 뷰어 안에서 어떻게 지금 작업되고
> 있는지 볼 수 있다. 엑셀도 마찬가지.

## Goal

Add a second entrance to 뚝딱 Hub: **내 드라이브** — a personal, persistent,
Google-Drive-like file space where the user drops files and chats *inside a
folder*; the assistant reads those files and does document work with them.
Opening a 한글 or 엑셀 file raises a **viewer** that shows, live, how the
document is being worked on.

## Decisions (user-confirmed, 2026-07-06 brainstorm)

| Decision | Choice |
|---|---|
| Relation to 접수 flow | **Parallel entrances with different purposes.** Formal automation that needs risk levels / approvals stays in 창구→관제실. Light document work goes through the drive directly. |
| Drive unit | **One drive per person** (keyed by the same name field / currentUser). Free subfolder creation inside. |
| Folder chat | Chatting inside a folder makes that folder's files the reading sources automatically — no per-session re-upload. Reuses the existing chat engine (/ask, citations). |
| Viewer level | **Real-time relay.** While the assistant works, the viewer shows paragraphs/cells changing sequentially (like watching a collaborator in Google Docs). |
| HWP rendering | kordoc-blocks structural render: page breaks (pageNumber), heading hierarchy (style.fontSize), merged tables (rowSpan/colSpan). 100% original formatting fidelity is out of scope; final formatting check happens in 한글 after download. User's words: "kordoc의 능력을 활용해서 hwpx/hwp 뷰어 수준이 나오면 좋겠음, 실시간으로 변경되는 것도 볼 수 있게." |
| Result files | **Originals are immutable + new file.** Edits produce a new file in the same folder. 엑셀 → xlsx; 한글 work → docx/pdf/md (user picks). |
| Phase order | **Drive first**: 1) drive + folder chat + read-only viewer → 2) workdoc + real-time relay → 3) export expansion. |

## Core architecture: the workdoc

When a file is opened for work, the server builds a **block-structured
intermediate document state** — the workdoc. Everything looks at that one
object:

```
original file (immutable)
   │  HWP/HWPX/PDF/DOCX: kordoc pipeline → blocks.json
   │  XLSX/CSV: openpyxl → sheet/cell grid
   ▼
workdoc  (block list: paragraph / heading / table / sheet)
   │                               │
   ▼ viewer renders it             ▼ assistant emits block-level patches
viewer (in the drive screen)      "replace paragraph 12", "edit table 2 row 3"
   ▲                               │
   └────── patches relayed over SSE ┘
                                   ▼
              export: workdoc → xlsx / docx / pdf / md → new file in folder
```

- Block-level patches keep SSE events small; the viewer re-renders and
  highlights only the changed block.
- Existing stack preserved: FastAPI + vanilla JS (no build step), SSE — no
  WebSocket.
- kordoc's blocks.json already carries what the render needs (verified on the
  12,265-block 요람 document): type, text, pageNumber, style.fontSize, table
  cells with rowSpan/colSpan.

## Phases

### Phase 1 — 내 드라이브 + folder chat + read-only viewer
- **Drive storage**: per-user root (`drives/{user}/…`), subfolder
  create/move/delete, file upload/download/delete. Metadata in SQLite.
- **Folder chat**: opening a folder shows a chat panel; the folder's files are
  the sources (whether subfolders are included is decided at plan time).
  Reuses the existing chat engine and citation contract.
- **Read-only viewer**: clicking a file opens a viewer panel.
  - hwp/hwpx/pdf/docx: kordoc conversion rendered as a document (not live yet)
  - xlsx/csv: sheet grid render
- Exit criterion: drop files in the drive → open and read them → ask questions
  in folder chat, end to end.

### Phase 2 — workdoc + real-time relay
- Workdoc storage shape and the block-patch protocol.
- Extend the chat backend so document-editing tools emit patches.
- SSE endpoint + viewer-side patch application with change highlighting.
- Patch history (what changed, when) — consistent with the audit-log culture.

### Phase 3 — export expansion
- workdoc → xlsx (extends the existing export), → docx, → pdf, → md.
- Exported files land in the same folder as new files + download links.

## Relation to existing screens
- **창구 / 관제실**: unchanged — the formal automation entrance.
- **작업 공간 (current session chat)**: kept for now. Once folder chat is
  stable, re-evaluate whether the drive absorbs the scratch-session role
  (open question).
- Request-bound result chats (`session:` binding) stay in the 접수 flow.

## Global constraints (unchanged from 05/06)
- Operational strings byte-exact: 접수됨/검토 중/자동화 가능/실행 중/검수
  대기/완료/보류; risk 낮음/중간/높음; approval 승인/반려; job 성공/실패.
- Server strings enter the DOM only via `el()`/`textContent`/`createTextNode`
  — no innerHTML in new JS.
- Design tokens and dark-mode rules exactly as in spec 06.
- Original files are never mutated. Filename traversal/null-byte guards reuse
  the existing download-route pattern (`ops.py` / `chat.py`).
- Tests isolate via `OFFICE_HUB_RUNS` / `OFFICE_HUB_DB`. The user's live
  server on port 8000 is managed by PID only — never `pkill -f uvicorn`.

## Open questions (defer to plan time)
- Folder chat source scope: current folder only vs. subfolders included.
- Viewer paging for very large documents (요람-class, ~12k blocks).
- Whether to attempt direct hwpx writing (post-phase-3; default is docx/pdf/md).
- Drive quotas (size / file count), if any.
