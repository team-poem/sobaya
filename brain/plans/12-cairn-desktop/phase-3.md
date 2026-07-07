# cairn-desktop — Phase 3: control API + agent E2E

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** An agent CLI can discover the app, start runs, watch state, and
collect verdicts over localhost HTTP; browser recovery works.

**Architecture:** axum server on `127.0.0.1:0` started in Tauri setup;
actual port written to `~/.cairn-desktop/endpoint.json`. Handlers delegate
to `AppState` (browser) and `Runner` (runs) from phases 1–2.

**Tech Stack:** axum 0.8, tower, serde; `ureq` stays dev-only for tests.

## Global Constraints

- Phases 1–2 constraints apply.
- Bind 127.0.0.1 only. No auth (localhost trust, MVP).
- Every handler returns JSON; errors as `{ "error": "<message>" }` with 4xx/5xx.

---

### Task 12: control module — axum server + /status + /cdp

**Files:**
- Create: `src-tauri/src/control/mod.rs`, `src-tauri/src/control/routes.rs`
- Modify: `src-tauri/src/lib.rs` (start server in setup), `src-tauri/src/state.rs`

**Interfaces (Produces):**
```
GET /status → 200 {"browser":"running"|"degraded"|"starting","browserUrl":string|null,"activeRun":string|null}
GET /cdp    → 200 {"browserUrl":"http://127.0.0.1:<port>"} | 503 {"error":"browser not running"}
```
Endpoint file `~/.cairn-desktop/endpoint.json`: `{"port":<u16>,"pid":<u32>,"startedAt":"<iso8601>"}`
(written on listen, best-effort removed on exit).

**Steps:**
- [ ] Tests (tokio + `axum::serve` on ephemeral port + `ureq` dev-dep): `/status` reflects a fabricated `AppState`; `/cdp` 503 when browser is None.
- [ ] Implement router + endpoint-file write; wire into Tauri setup after browser task starts.
- [ ] Commit.

### Task 13: /runs endpoints

**Files:**
- Modify: `src-tauri/src/control/routes.rs`

**Interfaces (Produces):**
```
POST /runs  body {"kind":"replay","skill":"example"|"/abs/x.skill.json","heal":false}
         or body {"kind":"discover","goal":"...","url":"https://...","model":null}
  → 202 {"id":"run-3"} | 409 {"error":"run active: run-2"} | 400 bad body | 503 browser down
GET /runs/:id → 200 {"id","state":"running"|"passed"|"failed"|"error","reason":null|string,
                     "skillPath":null|string,"events":[...]} | 404
GET /runs     → 200 {"runs":[{"id","state","kind","name"}...]} (newest first)
```

**Steps:**
- [ ] Tests: POST maps to `Runner::start` (fake sidecar: a fixture-cat script `contract/bin/fake-sidecar.sh` that cats a fixture ndjson and exits 0 — runner accepts a sidecar-command override for tests); 409 on busy; GET returns applied state after fake run completes.
- [ ] Implement; green.
- [ ] Commit.

### Task 14: /browser/restart + degraded recovery

**Files:**
- Modify: `src-tauri/src/control/routes.rs`, `src-tauri/src/browser/mod.rs`, `src-tauri/src/lib.rs`

**Steps:**
- [ ] `POST /browser/restart` → kills old child if any, relaunches, reconnects CDP + mirror, 200 with new browserUrl; 409 if a run is active. UI restart button calls the same internal fn via a tauri command.
- [ ] Degraded detection: mirror task exit / CDP `Closed` → one automatic reconnect+remirror attempt (Chrome may still be alive); if that fails → status `degraded` + `mirror://status` event (phase-1 hook already emits; ensure `/status` agrees).
- [ ] Test: fabricate degraded state, restart handler brings `/status` back to `running` (integration `#[ignore]`, real Chrome).
- [ ] Commit.

### Task 15 (phase gate): agent E2E + docs

**Files:**
- Create: `README.md` (what it is, run instructions, API table, agent quickstart), `CLAUDE.md` (app-level: build/test commands, sidecar contract pointer)

**Steps:**
- [ ] Full E2E from a terminal (simulating an agent): read `endpoint.json` → `curl POST /runs` (replay example skill) → poll `GET /runs/:id` until terminal → assert `passed`; watch the app window during it (motion visible).
- [ ] Discover E2E (needs LLM available locally): `POST /runs {"kind":"discover","goal":"open example.com and follow the more-information link","url":"https://example.com"}` → skill file exists under app data `skills/`; then replay that skill by bare name → passed. (If no LLM key/CLI available in the session, mark step skipped in commit message — replay path already proven.)
- [ ] Write README + app CLAUDE.md; commit; tag `v0.1.0`.

## Phase-3 exit criteria

- Agent loop works end-to-end with only `endpoint.json` + HTTP.
- `cargo test` green; `--ignored` suite green locally.
- README documents the exact curl sequence an agent uses.
