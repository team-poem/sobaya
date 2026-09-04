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
