# cairn-desktop — Phase 2: cairn runner (Node sidecar) + run panel

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** The app runs cairn discover/replay against its own Chrome and shows
a live step timeline; runs are recorded with a terminal verdict.

**Architecture:** A Node sidecar (`sidecar/`, its own package.json depending
on `cairn-engine@^2.4.0`) constructs `ChromeDevToolsDriver` with
`--browserUrl` args pointing at the app's Chrome, runs
`runScenario`/`discover`, and emits NDJSON events on stdout. Rust `runner/`
spawns it, parses events into a `RunRecord`, forwards them to the frontend.

**Tech Stack:** Node ≥20 (system `node` on PATH), cairn-engine 2.4.0,
chrome-devtools-mcp ~1.3.0 (spawned by cairn), Rust tokio::process.

## Global Constraints

- Phase 1 constraints apply (idiomatic Rust, commits per task).
- One run at a time — runner rejects a start while a run is active.
- Sidecar stdout is *only* NDJSON events; all human/debug text goes to stderr (cairn's ConsoleReporter is NOT used; cairn `console.log` noise from the engine, if any, must not corrupt the stream → sidecar redirects `console.log` to stderr before importing cairn).
- Event envelope (the contract, fixtures in `contract/events/*.ndjson`):
  - `{"event":"start","kind":"replay"|"discover","name":string}`
  - `{"event":"step","progress":<StepProgress as serialized by cairn>}` (Rust treats `progress` as opaque JSON; UI renders `progress.step.kind`, `progress.status`, `progress.index` defensively)
  - `{"event":"heal","original":string,"healed":string}`
  - `{"event":"verdict","passed":bool,"assertions":<Result.verdict JSON>}`
  - `{"event":"error","message":string}`
  - exit codes: 0 pass, 1 fail, 2 error.

---

### Task 7: sidecar — replay + discover with browserUrl attach

**Files:**
- Create: `sidecar/package.json` (deps: `cairn-engine@^2.4.0`; `"type":"module"`), `sidecar/run-cairn.mjs`, `sidecar/emit.mjs`
- Test: `sidecar/test/emit.test.mjs` (node --test), contract fixtures `contract/events/replay-pass.ndjson`, `contract/events/discover-error.ndjson`

**CLI contract (Consumes: BrowserHandle.http_url from phase 1):**
```
node run-cairn.mjs --browser-url http://127.0.0.1:PORT --kind replay --skill /abs/skill.json [--heal]
node run-cairn.mjs --browser-url ... --kind discover --goal "intent" --url https://target [--freeze /abs/out.skill.json] [--model id]
```

**Key implementation points (show in code):**
```js
// emit.mjs — the ONLY writer to stdout
export const emit = (obj) => process.stdout.write(JSON.stringify(obj) + "\n");
// run-cairn.mjs, before any cairn import side effects:
console.log = (...a) => console.error(...a);
const driver = new ChromeDevToolsDriver({
  args: ["-y", "chrome-devtools-mcp@~1.3.0", "--browserUrl", browserUrl],
});
// replay: scenario = await loadSkillFile(skillPath)  (validated load)
// const { result } = await runScenario(scenario, { driver, heal,
//     reporter: { emit: async (r) => emit({ event: "verdict", passed: r.verdict.passed, assertions: r.verdict }) },
//     onStep: (p) => emit({ event: "step", progress: p }),
//     onHeal: (h) => emit({ event: "heal", original: h.original?.text ?? "", healed: h.healed?.text ?? h.healed?.selector ?? "" }) });
// discover: llm = createLlmClient(model ? { model } : {});
//     scenario = await discover(goal, { driver, llm, baseUrl: url });
//     if (freeze) await saveSkillFile(freeze, scenario); then replay-run it once? NO (YAGNI) —
//     discover already ran the steps; emit verdict from discover's own outcome:
//     emit({ event:"verdict", passed:true, assertions:{ note:"discovered", steps: scenario.steps.length } })
// finally: await driver.close(); process.exit per contract.
```
- `--heal`/discover need an LLM: env passes through (ANTHROPIC_API_KEY or local claude/codex CLI per cairn's factory).

**Steps:**
- [ ] `node --test`: emit() writes exact single-line JSON; arg parser rejects missing --kind/--browser-url with exit 2 + error event.
- [ ] Implement; test green.
- [ ] Live check (needs phase-1 app or any `chrome --headless=new --remote-debugging-port=9223`): craft `contract/skills/example.skill.json` (goto example.com, click "Learn more"(link), assertions navigated + no-failed-requests — copy the DOGFOOD shape from cairn cli.ts), run replay against it. Expected stdout: start, ~2 step events, verdict passed, exit 0. Save that real output (minus volatile fields) as `contract/events/replay-pass.ndjson`.
- [ ] Commit.

### Task 8: runner module — spawn, parse, record

**Files:**
- Create: `src-tauri/src/runner/mod.rs`, `src-tauri/src/runner/events.rs`, `src-tauri/src/runner/record.rs`

**Interfaces (Produces):**
```rust
pub enum RunKind { Discover, Replay }
pub struct RunRequest { pub kind: RunKind, pub goal: Option<String>, pub skill: Option<PathBuf>,
                        pub url: Option<String>, pub heal: bool, pub model: Option<String> }
pub enum RunState { Running, Passed, Failed, Error }
pub struct RunRecord { pub id: String /* "run-<n>" */, pub state: RunState,
                       pub events: Vec<serde_json::Value>, pub reason: Option<String>,
                       pub skill_path: Option<PathBuf> }
pub struct Runner { /* Mutex<Option<ActiveRun>> + Vec<RunRecord> history */ }
impl Runner {
    pub fn start(&self, req: RunRequest, browser_url: String, app: AppHandle)
        -> Result<String, RunnerError>; // Err(Busy) if active
    pub fn get(&self, id: &str) -> Option<RunRecord>;
}
pub enum RunnerError { Busy, SidecarSpawn(String), InvalidRequest(String) }
// Tauri event to frontend: "run://event" payload { runId, event: <envelope> }
```

**Steps:**
- [ ] Failing tests in `events.rs`: parse each contract fixture line into the envelope (tagged by `event` field, unknown events kept as raw — forward-compatible); full fixture file drives a `RunRecord` to `Passed` with N step events; `error` event or nonzero-exit-without-verdict → `Error` with reason.
- [ ] Implement envelope enum + `RunRecord::apply(event)`; tests green (fixtures read from `../contract/events/`).
- [ ] Implement `Runner::start`: sidecar path = dev: `<app repo>/sidecar/run-cairn.mjs` resolved from `CARGO_MANIFEST_DIR` parent at dev-build, prod: Tauri resource dir (`.resolve("sidecar/run-cairn.mjs")`) — a `fn sidecar_path(app:&AppHandle)` with the dev fallback. Spawn `node` with args from `RunRequest`, stdout line-reader task applies events + emits `run://event`, stderr captured to a ring buffer (last 100 lines) for `reason`, on exit finalize state (exit 0/1 must also have seen a verdict event; otherwise Error).
- [ ] Busy test: second `start` while active returns `Err(Busy)`.
- [ ] Commit.

### Task 9: skills storage + run bookkeeping defaults

**Files:**
- Modify: `src-tauri/src/runner/mod.rs`, `src-tauri/src/state.rs`

**Steps:**
- [ ] Discover default freeze path: `<app_data_dir>/skills/<slug(goal)>-<n>.skill.json` (slug: lowercase, non-alnum → `-`, trimmed, max 40 chars; unit-test slug). Record it in `RunRecord.skill_path`; replay accepts either an absolute path or a bare name resolved against the skills dir (unit-test resolution).
- [ ] `Runner` added to `AppState`; history capped at 50 records (oldest dropped).
- [ ] Commit.

### Task 10: run panel UI

**Files:**
- Modify: `src/main.ts`, `index.html`, `src/styles.css`; Create: `src/run-panel.ts`

**Steps:**
- [ ] `listen("run://event")` → render: run header (kind, name, state badge), step list (index, `progress.step.kind` + target text when present, status icon ·/✓/✗/↻ for healed), verdict block (assertions JSON pretty), error reason when state=Error.
- [ ] Keep the panel bound to the latest run; store is a plain array keyed by runId (no framework).
- [ ] Manual verify: trigger a replay via a temporary `tauri::command` or directly `POST` once Task 11 API exists — acceptable to defer the live check to the phase gate below.
- [ ] Commit.

### Task 11 (phase gate): end-to-end replay visible in-app

**Steps:**
- [ ] `npm run tauri dev`; invoke a replay of `contract/skills/example.skill.json` (temporary dev command bound to a UI button "▶ dogfood", kept — it's the app's smoke test).
- [ ] Expected: mirror shows example.com loading and the link click; run panel shows 2 steps → verdict passed. Chrome stays alive for the next run.
- [ ] Fix what breaks (most likely: chrome-devtools-mcp attaching to a *new* tab vs the mirrored one — the newest-page-wins rule from Task 4 must make the mirror follow it; if `--browserUrl` attach creates no page, cairn's goto creates one).
- [ ] Commit; tag `phase-2`.

## Phase-2 exit criteria

- `cargo test` + `node --test sidecar/test/` green.
- A replay runs end-to-end: visible motion in mirror + live steps + verdict in panel + `RunRecord` retrievable.
- Sidecar stdout contains nothing but NDJSON (verified by the fixture capture in Task 7).
