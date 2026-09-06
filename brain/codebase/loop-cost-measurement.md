# Loop cost measurement (2026-09-04)

First real run of `tdd-set/bin/loop.sh` with `usage.sh` logging — ddukddak-hub-go, token-gate
feature, 25 entries, `SOBAYA_MODEL=sonnet`. Basis for issue #2.

- 25/25 entries green, gate PASS, 28 commits, 44 minutes, **$13.76** (mean $0.55, median ≈ $0.41,
  max $1.52 on the kill-the-process entry: 505 s, 53 turns).
- Fixed load per fresh `claude -p` session (cache_create): **41K tokens average** (27K–83K).
  25 sessions = 1.03M tokens spent only on re-reading AGENTS.md files, skills, the 653-line
  `failed-test.md`, and the package. This is the "fixed load × N" term.
- Cost tracks turn count almost linearly: 16–18 turns ≈ $0.30–0.38, 43–53 turns ≈ $1.0–1.5.
- 54 permission denials over 19 cycles, all read-only forms outside the allowlist
  (`cd <app> && go test`, `git branch`, `find | xargs`, git on the sobaya root). Cycles with
  denials averaged $0.55 vs $0.39 without — a denial is a wasted turn plus a retry.
- One cycle spawned a subagent; nothing in the loop needs fan-out. Now refused via
  `--disallowedTools Agent WebFetch WebSearch`.
- One stall: a commit written as `-m "$(cat <<'EOF' … EOF)"` — command substitution turns an
  allowlisted command into a permission prompt. `/go` now says: plain one-line `-m`.
- Sonnet handled every entry, so the loop defaults to sonnet; no Fable/Opus comparison run was
  made (estimated $30–50 for the same plan).

Lessons for the harness:
- **Never edit `loop.sh`/`usage.sh` while a loop is running.** bash reads scripts by offset;
  rewriting `usage.sh` mid-run produced a syntax error in one `record` call. Change scripts between
  runs only.
- `probe.sh` only adds `import "testing"` to a Go snippet, so any test using `context`, `os`,
  `errors`… is RED by construction — the probe cannot tell "new symbol missing" from "import
  missing". All 25 probes were build-failure REDs for this reason. Needs a fix (import block in
  the snippet or goimports) before probe results mean anything for non-trivial tests.

## Second run (2026-09-06) — after next.sh, SOBAYA_LOOP, one-chapter go-mistakes

ddukddak-hub-go, drive-permission leftovers (organize API gate, folder routes removed), 6 entries,
sonnet. Phase 0 also on sonnet (`claude -p "/sobaya-plan"`, logged as run `phase0-0b40e73`).

| | first run (token gate) | second run (drive leftovers) |
|---|---|---|
| entries | 25 | 6 |
| sessions | 25 (one per entry) | **1** (the agent did all 6 in one session) |
| cost | $13.76 | $2.02 (+ Phase 0 $0.94) |
| per entry | $0.55 | $0.34 |
| cache_create per session | 41K | 86K once (not 6 × 41K) |
| cache_read per entry | 1.52M | 1.21M |
| turns per entry | 27.5 | 15.3 |
| wall time per entry | 104 s | 80 s |
| denials | 54 | 8 (`cat >>` into the test file, python heredocs, /tmp writes) |

Not comparable one-to-one (different feature, simpler entries), but two things are clear:

- **The agent ignored "one entry per session"**: with `next.sh` it kept calling it after each commit
  and finished the plan in one 92-turn session. That skips `loop.sh`'s per-iteration guards (stall,
  defect-flow halt, per-entry usage row). `/go` now says explicitly: one entry, then stop.
  Cost-wise the single session saved ~5 × 41K cache_create; per-entry context (cache_read) barely
  moved, so the O(N²) term is now the growing session, not the re-read file.
- **Three of six entries were rewritten, not appended verbatim**, and the gate passed them. The plan
  was wrong twice (mux answers 405 for POST /api/drive while GET /api/drive stays; `EnsureRoot` seeds
  5 default folders, so `len(entries) == 0` can never hold), and the agent silently fixed the tests
  instead of stopping. Phase 0's probe cannot catch a wrong expectation — it is RED either way.
  `gate.sh` now requires every checked entry's code block verbatim in the committed suite
  (`tdd-set/tests/gate-verbatim.sh`). The plan was aligned to the suite by hand afterwards.
- probe.sh with import blocks (issue #3) worked: the hand-added entry
  `TestOrganizeDriveAPIEmptyConsoleKeyRejectsAnyCookie` probed as a runtime RED (`status = 200`),
  not a build failure. Phase 0's own probes: 5 RED, 1 GREEN dropped.
- No `refactor:` commit in the run; the agent judged nothing to tidy (diff: 4 files, +151/−9).
