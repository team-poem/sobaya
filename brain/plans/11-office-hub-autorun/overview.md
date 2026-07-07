# 11 · office-hub-autorun — Design Spec + Plan

Status: approved verbally by user 2026-07-07 ("수락하는 방식의 흐름은 일단 모두 해제시키자", "알아서 실행되야지"). OCR deferred (user chose hub-first; kordoc OCR is the follow-up project).
App: `apps/office-automation-hub-design/app/`, branch `drive/phase-1` (stacked continuation).
Origin: user friction report — (1) 창구 submit waits for 관제실 review/run approval before anything happens; should go straight to chat. (2) Workspace answers hedge with "확인 불가" — root-caused: the 6/26 PDF is genuinely an image-based scan (kordoc warning: "이미지 기반 PDF (4페이지, 텍스트 21자) — OCR 필요"), but the user only learns this at answer time, after the whole approval chain.

## Decisions

| # | Decision |
|---|---|
| 1 | **Auto-run mode ON by default** (`OFFICE_HUB_AUTO_RUN` env, default "1"; cfg.auto_run). 창구 submit + file uploads → frontend calls new `POST /requests/{id}/auto` → server auto-reviews (actor "자동", risk 낮음, the chat-session-producing template) and auto-executes the job → responds with the session id → frontend jumps STRAIGHT to 작업 공간 with the session attached. No human gate anywhere in the default path. |
| 2 | 관제실 stays as a **monitoring** screen (queue/audit/stats still work; manual run/approve buttons remain functional for 보류/재실행 cases). Approval machinery and operational strings are UNTOUCHED — auto mode just drives them automatically. Flag off (`OFFICE_HUB_AUTO_RUN=0`) restores the old gated flow; `/auto` then returns 409 "자동 실행이 꺼져 있습니다". |
| 3 | **Read-limits surface early and loudly.** Source warnings (already captured in DocSource.warnings / list_sources) get shown: 작업 공간 소스 패널 + 드라이브 폴더채팅 힌트/뷰어 노트에 "⚠️ 파일명: <kordoc 경고>" lines. |
| 4 | **ORCHESTRATOR prompt guardrail** (parity with EDITOR): 한계·불가 사유는 도구가 보고한 warning/결과 그대로만 서술, 추정 금지; warnings가 있는 소스는 답변 서두에 한 줄로 고지. |
| 5 | **raw_fallback 정규화 품질**: diagnose why normalization empties rows (e.g. 0703 HWP rows showing only "[실시사항]"); if the fix is local (prompt/parser/fallback-to-raw-rows-when-normalized-empty), apply it; if structural, write findings to this doc and stop. |
| 6 | 검수 대기 → 완료 confirm 버튼(요청자 본인)은 유지 — 그건 승인이 아니라 본인 확인. |

## Global Constraints
- Operational strings byte-exact (접수됨/검토 중/자동화 가능/실행 중/검수 대기/완료/보류, 낮음/중간/높음, 승인/반려, 성공/실패) — auto mode SETS them, never renames them.
- No innerHTML; existing tokens only; Korean errors; traversal guards untouched; tests isolated (tmp db/runs/drives, zero real LLM/kordoc — stub runners/converters); port 8000 by PID only; venv pytest (`./.venv/bin/python -m pytest -q`, currently 301 green).
- Auto review/run must reuse the EXISTING ops_requests.review / ops_jobs.execute functions (no parallel state machine) — audit trail shows actor "자동".

## Tasks (SDD, fresh implementer per task, reviewer after each)

1. **Backend auto-run**: cfg.auto_run (env `OFFICE_HUB_AUTO_RUN`, default on) + `POST /requests/{request_id}/auto` in hub/api/ops.py — calls review(자동, 낮음, <chat-session template id — find the runner whose result_location is `session:...` in hub/ops/templates>) then execute; returns `{request, job, session_id}` (session id parsed from result_location; null if the runner failed). 409 when flag off; illegal transitions map like existing `_run`. Tests: happy path (stub runner), flag-off 409, audit actor 자동, no approval needed at 낮음.
2. **창구 직행**: counter.js submitComposer — after uploads, call `/auto`; on success with session_id → `attachSession(session_id, request)` + `go('work')` (straight to chat). On auto failure → keep today's card flow + driveError-style message (말해주는 실패). Card detail's "결과 채팅 열기" unchanged. E2E: submit with csv → lands in 작업 공간 with sources visible, ask works (scripted server).
3. **경고 조기 표시 + 프롬프트 가드레일**: (a) workspace 소스 패널과 드라이브 채팅 힌트/뷰어에 warnings 표시 ("⚠️ <파일명>: <경고>", createTextNode only); (b) prompts.ORCHESTRATOR에 결정 4의 가드레일 문구 추가 + test asserting the phrases; (c) list_sources already carries warnings — no backend change expected beyond verifying.
4. **raw_fallback 진단**: reproduce normalization on the real 0703 HWP kordoc output (runs/0f0839edfba04f41 sibling sessions hold real data; tests use synthetic equivalents), identify why rows lose content, fix locally if small (with tests), else write findings here. Timebox: one implementer dispatch.
5. **최종 리뷰**: whole-delta review (base = e565556) on the most capable model; verify flag-off path preserves the exact old flow.

## Execution amendments
(record during execution)
