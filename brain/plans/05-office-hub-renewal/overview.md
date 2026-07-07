# 05 · office-hub-renewal — Design Spec

Status: **phase 1 implemented (2026-07-02) — branch `renewal/phase-1` (13 commits, 156 tests green, final review: Ready to merge=Yes). Superseded by plan 06 (ux/phase-a branches off renewal/phase-1 and carries the UI work forward); phases 2-3 will not proceed under this plan. Disposition (2026-07-07 lineage audit): phase-2 templates (excel-cleanup/file-merge) RETIRED — superseded by drive workdoc chat editing (plan 10); the 지표(metrics) screen idea is CARRIED FORWARD to a future 관제실-as-monitoring plan (post plan 11, where auto-run removed the approval-console role).**
Date: 2026-07-02
App: `apps/office-automation-hub-design/app/` (existing repo, restructured in place)

## Goal

Rebuild the office-automation hub so it actually implements the MVP spec's
operational flow — request intake → FDE review → template → execution →
approval → per-task metrics — instead of only the chat-answer slice. The
well-tested deterministic engine (ingest / tools / normalize workers /
exporter, ~90 stub-injected tests incl. the 14-vs-40 golden) is kept and
demoted to an internal execution engine. App shell, API surface, and UI are
redesigned from scratch.

## Why (gap analysis, 2026-07-02)

Audit of `app/` against its four specs found:

- **MVP 사양서 success criteria: 4 of 6 have no implementation at all**
  (request form, FDE review/classification, human review gate, per-task
  time/savings metrics), 2 are partial (only 1 automated task type; logs are
  per chat turn, not per task). None of the MVP §10 entities
  (Request/Template/Job/Approval/AuditLog) exist in code. No role screens,
  no 학칙챗봇 tab, no risk classification.
- The three implemented slices (chat answer, typed-worker normalization,
  k-skill catalog) are solid at the deterministic layer but diverge from
  their own specs in 8 places: no SSE streaming (spec mandates it), default
  LLM backend is codex CLI (spec fixes OpenAI Responses/GPT-5.5), no cost
  logging, `/export` and `/skills/{name}` unreachable from the UI,
  evidence chips not clickable, no card-detail expansion, `convert_kordoc`
  worker never modularized ("converted" state untracked), no content-hash
  cache invalidation. Plus dead code (`query_rows.group_by`), a stale
  comment (normalize_spec.py:159), and table heading context lost before
  reaching the hwp worker.

So "the hub" today is a good chat Q&A tool with no hub around it. The
renewal builds the hub and mounts the engine inside it.

## Open decision (user gate)

The user asked for a full teardown ("싹 다 갈아엎고 리뉴얼") but was AFK when
asked which baseline defines "requirements". This spec assumes **option A:
rebuild as the MVP operational hub, absorbing the proven deterministic
engine**. Rejected alternatives: (B) discard everything including the tested
engine — pure cost, the engine is the best part and matches its specs;
(C) only fix the 8 divergences — not a renewal, doesn't touch the actual gap.
**User must confirm A before any code is torn down.**

## Decisions

- **Persistence: SQLite** (stdlib `sqlite3`, single file `data/hub.db`).
  The MVP's core promise is "요청·결과·로그가 남는다" — in-memory sessions
  can't deliver that. Chat sessions stay in-memory (ephemeral by design);
  everything operational (requests, jobs, approvals, audit) persists.
- **No auth in this renewal.** Roles (requester / FDE / admin) are separate
  screens, not separate logins — single-department pilot on a local Mac.
  A visible role switcher in the header; names are free-text fields.
  OAuth is the MVP spec's "중간형" stage, out of scope.
- **Three task templates at launch** (satisfies "최소 3개 반복 업무"):
  1. `chat-answer` — the existing slice, wrapped as a template whose "run"
     opens a chat session bound to the request's files.
  2. `excel-cleanup` (MVP §8-A) — deterministic: normalize columns via the
     existing worker pipeline, dedupe, flag missing values, summary sheet;
     output via exporter (clean xlsx + issues sheet).
  3. `file-merge` (MVP §8-B) — deterministic: extract chosen columns from a
     batch of uploaded tabular files, produce one merged xlsx + a
     missing/error list.
  Templates C/D/E (mail draft, folder rename, web automation) stay out.
- **Risk gates per MVP §11**: every request gets a risk level (low/medium/
  high) set by FDE at review. All runs end in "검수 대기"; the levels differ
  in who closes it and what must exist before running. Low → FDE runs
  immediately and may mark 완료 after checking the result (requester confirm
  optional). Medium → FDE runs, but only the requester's explicit confirm
  transitions 검수 대기 → 완료. High → job cannot be created until an
  Approval row (approver + comment) exists; completion same as medium.
  PII stays a warning + a `contains_personal_data` flag that forces
  risk ≥ medium; no auto-detection.
- **Per-job metrics**: `started_at/finished_at` (wall time), FDE-entered
  `manual_minutes_estimate` (baseline for 절감시간), `rework_count`
  (incremented on requester "수정 요청"), error message on failure. LLM cost:
  add per-turn estimated cost to runlog (price table in config) and roll up
  per job. Aggregations rendered on the admin screen.
- **LLM backend**: keep `auto` (OpenAI Responses when key present, codex CLI
  fallback) but record the divergence from "GPT-5.5 fixed" openly in README;
  cost tracking applies to the OpenAI path only.
- **Engine cleanups ride along with the move** (they're renames anyway):
  drop dead `group_by`, delete stale comments, pass table heading context
  (`RawTable.context`) through to workers, route dispatcher by the design's
  contract. Content-hash invalidation and SSE streaming are explicitly
  deferred (phase 3 / later).

## Architecture

```
hub/
  core/        # deterministic engine (moved, behavior-preserving):
               # models.py ingest.py tools.py raw_extract.py
               # normalize_spec.py exporter.py fanout.py dispatcher.py
               # workers/
  llm/         # orchestrator.py codex_client.py text_llm.py prompts.py
  ops/         # NEW operational domain:
               # models.py   (Request, Template, Job, Approval, AuditLog)
               # store.py    (SQLite; schema DDL + thin DAO, no ORM)
               # requests.py (intake, status transitions — pure state machine)
               # jobs.py     (create/run; binds template runner to engine)
               # metrics.py  (per-job rollups + admin aggregates)
               # templates/  (chat_answer.py, excel_cleanup.py, file_merge.py)
  api/         # routers: ops.py (requests/jobs/approvals/metrics),
               # chat.py (session/files/ask/normalize/export),
               # catalog.py (/skills)
  session.py   # chat sessions (in-memory, unchanged role)
  runlog.py    # + estimated cost per turn
  config.py    # + price table, db path
static/        # rebuilt UI, tabs: 요청 (requester form + my requests)
               # · 운영 (FDE queue: review, risk, run, results, logs)
               # · 채팅 (existing chat, + export button, clickable chips)
               # · 카탈로그 (k-skill, + card detail)
               # · 지표 (admin metrics)
```

Request status flow (MVP §9): 접수됨 → 검토 중 → 자동화 가능 → 실행 중 →
검수 대기 → 완료, with 보류 reachable from any pre-완료 state. Transitions
are validated in `ops/requests.py` (illegal transition → 409). Every
transition, job run, and approval writes an AuditLog row.

Job execution is synchronous in-process (BackgroundTasks at most) — no
queue, one Mac, one FDE. Results land in `runs/request-<id>/output/` and are
downloadable from both 요청 and 운영 screens.

## Error handling

- Template runner failure → job status `failed` + `error_message`, request
  returns to 자동화 가능 (re-runnable), audit row written.
- Engine errors keep their current contracts (structured tool errors,
  raw_fallback on normalization failure, convert_failed surfaced per source).
- SQLite writes wrapped in transactions; store raises typed errors mapped to
  4xx/5xx in the router.

## Testing

Same discipline as today: no real LLM/network/subprocess in tests.

- `ops/` state machine and store: pure-function unit tests (happy paths +
  every illegal transition + risk-gate matrix low/medium/high).
- Template runners: fixture xlsx in → asserted output workbook (excel-cleanup,
  file-merge), stub LLM for chat-answer wrapper.
- API: request→review→run→confirm full flow; approval-required-before-run
  for high risk; metrics rollup numbers.
- Existing 90 engine tests must pass unchanged after the `core/` move
  (import-path updates only) — that is the "engine preserved" proof.

## Migration / teardown plan

1. Phase 1 — `ops/` domain + SQLite + 요청/운영 screens + chat-answer
   template wrapper (MVP success criteria 1, 2, 5 land here).
2. Phase 2 — excel-cleanup & file-merge templates + metrics/cost + 지표
   screen (criteria 3, 4, 6 land here).
3. Phase 3 — divergence fixes in the chat slice UI (export button, clickable
   evidence chips, catalog card detail); SSE streaming if still wanted.

Old `api.py`/`static/` are replaced (git history keeps them); engine modules
move under `core/`/`llm/` with behavior preserved. Each phase gets its own
implementation plan (`phase-N.md`) via writing-plans.

## Out of scope (YAGNI)

- Auth/OAuth, multi-department, Kubernetes, job queue, Mac mini remote worker
- 학칙챗봇 tab (separate app; revisit after phase 2)
- Templates C/D/E, PII auto-detection/masking, content-hash re-upload cache
- Mobile app, Notion/Sheets integrations
