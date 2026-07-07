# cairn-desktop — Phase 1: scaffold + browser + CDP mirror

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Tauri app that launches headless Chrome and shows its live screen
inside the app window (CDP screencast mirror).

**Architecture:** Rust core spawns system Chrome (`--headless=new`,
`--remote-debugging-port=0`), reads the real port from `DevToolsActivePort`,
connects a minimal hand-rolled CDP client over WebSocket, starts
`Page.startScreencast`, and pushes JPEG frames to the frontend canvas via
Tauri events.

**Tech Stack:** Tauri 2.x, Rust (tokio, tokio-tungstenite, serde,
serde_json, thiserror), vanilla TS + Vite frontend.

## Global Constraints

- App root: `apps/cairn-desktop` — flat (sources + `src-tauri/` + `.git` directly in it).
- Rust: idiomatic — `Result` + `thiserror` error enums, no `unwrap()` outside tests, ownership over globals, modules per responsibility.
- No chromiumoxide / headless_chrome crates — CDP client is hand-rolled, only the domains we use.
- macOS first; Chrome binary default `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`, overridable via `CAIRN_DESKTOP_CHROME` env.
- Commit after each green task (conventional commits, in the app repo).

---

### Task 1: Scaffold Tauri app

**Files:**
- Create: `apps/cairn-desktop/` via `npm create tauri-app@latest` (vanilla-ts template), then `git init` + first commit.
- Modify: `src-tauri/tauri.conf.json` (window title "cairn desktop", 1280×860)

**Steps:**
- [ ] Run `npm create tauri-app@latest cairn-desktop -- --template vanilla-ts --manager npm --yes` inside `apps/` (register with new-app conventions: app-level CLAUDE.md, entry in brain/apps.md — done by the orchestrator, not this task).
- [ ] `npm install && npm run tauri dev` once to verify the stock app opens. Expected: window appears.
- [ ] Set window title/size in `tauri.conf.json`.
- [ ] `git init && git add -A && git commit -m "chore: scaffold tauri vanilla-ts app"`.

### Task 2: browser module — locate + launch + port discovery

**Files:**
- Create: `src-tauri/src/browser/mod.rs`, `src-tauri/src/browser/launch.rs`
- Test: unit tests in `launch.rs` (`#[cfg(test)]`)

**Interfaces (Produces):**
```rust
pub struct BrowserHandle {
    pub http_url: String,          // "http://127.0.0.1:<port>" — for cairn --browserUrl
    pub ws_url: String,            // browser-level ws from DevToolsActivePort line 2
    child: tokio::process::Child,  // killed on Drop
}
pub enum BrowserError { ChromeNotFound, LaunchFailed(String), PortTimeout, Io(std::io::Error) }
pub async fn launch(profile_dir: &Path) -> Result<BrowserHandle, BrowserError>;
pub fn parse_devtools_active_port(contents: &str) -> Option<(u16, String)>; // (port, "/devtools/browser/<id>")
pub fn chrome_binary() -> Result<PathBuf, BrowserError>; // env override, then default macOS path
```

**Steps:**
- [ ] Failing unit tests for `parse_devtools_active_port`: valid two-line file → `(60123, "/devtools/browser/abc")`; empty/garbage → `None`.
- [ ] Implement parser (line 1 = port digits, line 2 = ws path starting with `/devtools/browser/`).
- [ ] Implement `chrome_binary()` + `launch()`: delete stale `DevToolsActivePort`, spawn Chrome with args `--headless=new --remote-debugging-port=0 --user-data-dir=<profile> --no-first-run --no-default-browser-check about:blank`, poll the file (100ms interval, 15s timeout), build handle. `Drop` (or explicit `close()`) kills the child (`start_kill`).
- [ ] Unit tests green: `cargo test -p cairn-desktop --lib`. Integration `#[ignore]` test `launch_real_chrome` asserts the HTTP endpoint answers `GET /json/version` (dev-dependency `ureq`, test-only).
- [ ] Commit.

### Task 3: cdp module — WebSocket client core

**Files:**
- Create: `src-tauri/src/cdp/mod.rs`, `src-tauri/src/cdp/client.rs`, `src-tauri/src/cdp/messages.rs`

**Interfaces (Produces):**
```rust
pub struct CdpClient { /* ws sink + pending map + event broadcast */ }
pub enum CdpError { Connect(String), Send(String), Closed, Protocol(String), Timeout }
impl CdpClient {
    pub async fn connect(ws_url: &str) -> Result<Self, CdpError>;
    /// send command, await matching-id response (10s timeout).
    /// session_id: Some for page-session commands (flat protocol).
    pub async fn call(&self, method: &str, params: serde_json::Value,
                      session_id: Option<&str>) -> Result<serde_json::Value, CdpError>;
    /// subscribe to all events (method + params + sessionId), tokio::sync::broadcast.
    pub fn events(&self) -> broadcast::Receiver<CdpEvent>;
}
pub struct CdpEvent { pub method: String, pub params: serde_json::Value, pub session_id: Option<String> }
```

**Steps:**
- [ ] Failing unit tests in `messages.rs` for envelope (de)serialization: outgoing `{id, method, params, sessionId?}`; incoming response `{id, result}` vs error `{id, error:{message}}` vs event `{method, params, sessionId?}` classification.
- [ ] Implement message types + classifier; tests green.
- [ ] Implement `CdpClient`: reader task owns the ws stream split; `pending: Mutex<HashMap<u64, oneshot::Sender<Result<Value,CdpError>>>>`; `AtomicU64` id counter; events fanned out on `broadcast::channel(256)` (lagging receivers drop frames — acceptable, frames are superseded anyway).
- [ ] Unit-test the pending/dispatch logic against a local in-process ws server (`tokio-tungstenite` accept loop in the test) echoing canned responses. Green, commit.

### Task 4: cdp screencast — attach newest page + frame stream

**Files:**
- Create: `src-tauri/src/cdp/mirror.rs`

**Interfaces (Produces):**
```rust
pub struct Frame { pub data_b64: String, pub width: u32, pub height: u32 }
/// Attaches to the newest "page" target, starts screencast, acks every frame,
/// re-attaches when a newer page target appears (follows cairn's new tabs),
/// forwards frames until the client closes. `on_frame` is called on every kept frame.
pub async fn run_mirror(client: Arc<CdpClient>, on_frame: impl Fn(Frame) + Send + 'static)
    -> Result<(), CdpError>;
```

**Behavior to implement:**
- `Target.setDiscoverTargets {discover:true}` → track `targetCreated/targetInfoChanged/targetDestroyed` for `type=="page"`.
- Attach: `Target.attachToTarget {targetId, flatten:true}` → `sessionId`; then on that session `Page.startScreencast {format:"jpeg", quality:60, maxWidth:1280, maxHeight:800}`.
- On `Page.screencastFrame` event for the active session: immediately `Page.screencastFrameAck {sessionId: params.sessionId}` (note: this is the *screencast* frame sessionId int, distinct from the CDP session), call `on_frame` with `params.data`, `params.metadata.deviceWidth/Height`.
- Newest-page-wins: when a new page target attaches, stop screencast on the old session (best-effort) and start on the new one. When the current page is destroyed, fall back to the newest remaining page.

**Steps:**
- [ ] Unit test: feed a canned `Page.screencastFrame` event through the handler → ack call recorded (use a trait or closure over `call` to fake it) and `on_frame` receives decoded width/height.
- [ ] Implement; unit green.
- [ ] Extend `#[ignore]` integration test: launch real Chrome (Task 2), connect, run mirror, assert ≥1 frame within 10s. `cargo test -- --ignored` green locally.
- [ ] Commit.

### Task 5: wire into Tauri — app state + frame events to frontend

**Files:**
- Modify: `src-tauri/src/lib.rs` (or `main.rs` per scaffold) — setup hook
- Create: `src-tauri/src/state.rs`

**Interfaces (Produces):**
```rust
pub struct AppState { pub browser: RwLock<Option<BrowserHandle>>, pub cdp: RwLock<Option<Arc<CdpClient>>> }
// Tauri event to frontend: "mirror://frame" payload { dataB64, width, height }
// Tauri event: "mirror://status" payload { state: "starting"|"running"|"degraded", httpUrl?: string }
```

**Steps:**
- [ ] In Tauri `setup`, spawn a tokio task: launch browser (profile under `app_data_dir()/chrome-profile`), connect CDP, run mirror with `on_frame` emitting `mirror://frame` (throttle: skip emit if <66ms since last — frames are superseded, mirror stays ≤15fps).
- [ ] Emit `mirror://status` transitions; on mirror/CDP failure emit `degraded`.
- [ ] Manual check: `npm run tauri dev` logs "browser running at http://127.0.0.1:PORT".
- [ ] Commit.

### Task 6: frontend mirror canvas

**Files:**
- Modify: `index.html`, `src/main.ts`, `src/styles.css`

**Steps:**
- [ ] Layout: left = mirror `<canvas id="mirror">` (fit-contain, letterboxed), right = empty run panel placeholder, bottom status bar (browser state + endpoint).
- [ ] `listen("mirror://frame")` → `Image` from `data:image/jpeg;base64,` → draw to canvas sized to frame w/h (device-pixel-ratio aware).
- [ ] `listen("mirror://status")` → status bar text/color.
- [ ] Manual verify (this is the phase gate): `npm run tauri dev`, then from a shell `curl -s http://127.0.0.1:<port>/json/new?url=https://example.com`... (headless new-tab via PUT — if the endpooint rejects GET use `curl -X PUT`). Expected: example.com renders inside the app window.
- [ ] Commit; tag `phase-1`.

## Phase-1 exit criteria

- `cargo test` green; `cargo test -- --ignored` green locally.
- App window shows live headless-Chrome content; navigating via `/json/new` visibly updates the mirror.
- No `unwrap()` in non-test code (`grep -rn "unwrap()" src-tauri/src --include=*.rs | grep -v test` → empty).
