# cairn-desktop — spec

**Status:** approved (design OK'd in session 2026-07-07)
**App:** `apps/cairn-desktop` (own git repo, scaffolded via new-app)
**Stack:** Tauri 2.x + Rust (core), vanilla TS + Vite (frontend), Node sidecar (cairn-engine)

## Goal

A Tauri desktop app that hosts a live-visible Chrome browser which the
[cairn engine](https://github.com/team-poem/cairn) drives over the Chrome
DevTools Protocol. An agent CLI (e.g. Claude Code) tells the app to test a
web service; the user watches cairn drive Chrome *inside the desktop app
window*; the agent collects the pass/fail verdict over a local HTTP API.

Why: cairn today spawns an invisible/ephemeral Chrome per run. This app
makes agent-driven browser testing *observable* — a persistent, watchable
browser surface plus a queryable run history.

## Non-goals (MVP)

- Manual interaction with the mirrored page (input forwarding) — phase 2+.
- Multiple browsers / concurrent runs — one browser, one run at a time.
- Non-localhost access, auth, packaging/signing for distribution.
- Upstream cairn CLI changes (`--browser-url` flag) — separate effort.

## Key facts (verified in cairn source, local clone `~/lunch.cancelled/cairn`)

- cairn is a TS/Node engine (`cairn-engine` npm; local clone available).
- Its `ChromeDevToolsDriver` spawns `chrome-devtools-mcp@~1.3.0` over stdio
  and accepts an `args` override (`packages/harness/src/adapters/drivers/chrome.ts:35`),
  so `--browserUrl=http://127.0.0.1:<port>` attaches it to a browser we own.
- The cairn CLI hardcodes its own driver (`cli.ts:108`) — so we embed the
  engine programmatically via a Node sidecar instead of shelling to `cairn`.
- macOS cannot reparent another process's window: "Chrome inside the app"
  is implemented as a **CDP screencast mirror** (approved approach A).

## Architecture

```
agent CLI ──HTTP (localhost)──▶ control (axum)
                                   │
        ┌──────────────────────────┼─────────────┐
        ▼                          ▼             │
     browser ◀───CDP ws───── Chrome(headless=new)│
        │ Page.screencast frames   ▲             │
        ▼                          │ --browserUrl attach
   Tauri events ──▶ frontend    runner ──spawn──▶ Node sidecar (cairn-engine)
   (canvas mirror + run panel)     ▲ NDJSON events on stdout
```

### Modules (src-tauri, idiomatic Rust: ownership, `Result`, traits, tokio)

- **browser/** — Chromium lifecycle. Locate system Chrome (macOS app path,
  config override). Launch `--headless=new --remote-debugging-port=0` with a
  dedicated user-data-dir under the app data dir; read the actual port from
  the profile's `DevToolsActivePort` file. Expose the browser HTTP endpoint
  (`http://127.0.0.1:<port>`) for attach + the page WebSocket for our CDP use.
- **cdp/** — minimal hand-rolled CDP client (tokio-tungstenite + serde).
  Only the domains we need: `Target.*` (find/attach page),
  `Page.startScreencast` / `Page.screencastFrameAck` (JPEG frames),
  later `Input.dispatch*`. No chromiumoxide dependency.
- **runner/** — runs cairn via a Node sidecar script shipped in app
  resources. Sidecar constructs `ChromeDevToolsDriver` with
  `args: [..., "--browserUrl", <our chrome>]`, runs discover/replay via the
  cairn-engine programmatic API, and emits NDJSON progress events
  (step started/finished, assertion results, verdict) on stdout. Rust
  parses events → run state + Tauri events. **Runs are serialized**: one
  at a time (`POST /runs` while busy → 409).
- **control/** — axum HTTP server bound to 127.0.0.1. Writes
  `~/.cairn-desktop/endpoint.json` (port) at startup for discovery.

### HTTP API

| Endpoint | Behavior |
| --- | --- |
| `GET /status` | browser state (running/degraded), CDP url, current run id |
| `POST /runs` | `{kind: "discover"\|"replay", goal?, skill?, url?}` → `{id}`; 409 if busy |
| `GET /runs/:id` | state, step timeline, assertions, final verdict + reason |
| `GET /cdp` | `{browserUrl}` — agents may attach their own chrome-devtools-mcp directly |
| `POST /browser/restart` | recover a dead/degraded browser |

Frozen skills (`*.skill.json`) are stored under the app data dir `skills/`;
run records reference their paths.

### Frontend (vanilla TS + Vite)

- Canvas rendering the screencast (JPEG frames via Tauri events, acked and
  throttled) — the "Chrome inside the app" surface.
- Run panel: step timeline with live status, assertion results,
  console/network tail from run events.
- Status bar: browser state, CDP endpoint, restart button.

## Error handling

- Chrome dies → status `degraded`; active run fails (consistent with
  cairn's own fatal-on-transport-loss stance); restart via UI/API.
- Sidecar exits non-zero → run `error`, stderr captured as reason.
- CDP ws drop → bounded reconnect + screencast restart, else `degraded`.
- Every run terminates in `passed`/`failed`/`error` + reason; agents can
  trust the terminal state.

## Testing

- Rust unit: CDP message framing, `DevToolsActivePort` parsing, NDJSON
  event parsing.
- Integration (local tag): launch real headless Chrome, receive one
  screencast frame.
- Contract: sidecar event schema fixtures shared between TS emitter and
  Rust parser.
- E2E manual: from an agent CLI session, `POST /runs` replaying a real
  site → motion visible in app, verdict retrieved.

## Phases

Implementation phases live in `phase-*.md` beside this file.
