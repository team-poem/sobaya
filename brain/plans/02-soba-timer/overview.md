---
id: 2
created: 2026-06-13
status: active
---

# Plan 02 — soba-timer

## Summary

Build `apps/soba-timer`: a zero-dependency Go CLI that counts down noodle-cooking timers from presets (`soba`, `udon`, `somen`, `ramen`) or arbitrary Go duration strings, with a single-line live display and a terminal bell on completion. First app in the workspace — deliberately small so one session can run the full Sobaya pipeline end to end (design → scaffold → plan → TDD dispatch → refuter review → reflect).

## Motivation

The harness (plan 01) is built and unit-verified, but the orchestration pipeline has never run against a real app. This app is the e2e test vehicle: every convention (new-app scaffold, brain/plans lifecycle, dispatch briefs, one-writer rule, prove-it-works verification, reflect) gets exercised once at small scale.

## Design Decisions

**D1. stdlib only, pure core + thin shell.** All logic lives in two pure functions (`Resolve`, `FormatRemaining`) that are table-driven-testable; `main.go` is a thin tick loop.
- *Alternative — cobra:* rejected; one command, no subcommands (subtract-before-you-add).
- *Alternative — bubbletea TUI:* rejected; heavy dependency, harder TDD, irrelevant to the e2e purpose.

**D2. Exit codes.** `0` success; `2` for any input/usage error (matches Go `flag` convention). No other failure modes exist (no IO beyond stdout/stderr).

**D3. Ceiling display.** Remaining time is ceiled to whole seconds — `00:00` appears only at completion, never while time remains.

**D4. Module path `github.com/amazon7737/soba-timer`.** Push-ready if the app ever gets its own remote.

## Scope

In scope: the CLI described here, its tests, app-level CLAUDE.md + Korean README, registry entry in `brain/apps.md`.
Out of scope: pause/resume, multiple parallel timers, sound beyond `\a`, desktop notifications, config files.

## Constraints

- Go stdlib only; single `main` package; works with the locally installed Go toolchain.
- App is its own git repo at `apps/soba-timer` (invisible to the harness repo).
- One writer: a single implementation dispatch at a time.
- TDD per superpowers:test-driven-development for the pure core.

## Behavior

```
soba-timer <preset|duration>
```

| Input | Result |
|---|---|
| `soba` | 5m countdown |
| `udon` | 10m countdown |
| `somen` | 2m countdown |
| `ramen` | 3m countdown |
| `90s`, `2m30s`, `1h2m` | parsed by `time.ParseDuration` |
| `-h` / `--help` | usage + preset table to stdout, exit 0 (help is not an error) |
| no args | usage to stderr, exit 2 (a usage error, per the Error Handling section and D2) |
| unknown string | `unknown preset or duration: "xyz"` to stderr + usage hint, exit 2 |
| `0s`, negative, `> 24h` | rejected to stderr, exit 2 |

Running display (single line, `\r`-refreshed once per second): `soba: 04:32` — label is the preset name, or the normalized duration for raw inputs (`2m30s: 02:29`). Completion: bell `\a`, line `done! (soba, 5m0s)`, exit 0. Durations ≥ 1h render `H:MM:SS`. Ctrl-C keeps default behavior (no trap).

## Architecture

```
apps/soba-timer/
├── CLAUDE.md      # app facts (stack go, run/test commands)
├── README.md      # Korean, one paragraph
├── go.mod         # module github.com/amazon7737/soba-timer
├── main.go        # arg handling + tick loop + bell (thin shell, no logic)
├── timer.go       # Presets map; Resolve(); FormatRemaining()
└── timer_test.go  # table-driven tests
```

Function contracts (`timer.go`):

```go
// Presets maps lowercase preset names to durations.
var Presets = map[string]time.Duration{
    "soba": 5 * time.Minute, "udon": 10 * time.Minute,
    "somen": 2 * time.Minute, "ramen": 3 * time.Minute,
}

// Resolve turns a CLI argument into a duration: preset lookup
// (case-insensitive) first, then time.ParseDuration. Rejects d <= 0
// and d > 24h with descriptive errors.
func Resolve(arg string) (time.Duration, error)

// FormatRemaining renders a remaining duration ceiled to whole seconds
// as MM:SS, or H:MM:SS when >= 1h.
func FormatRemaining(d time.Duration) string
```

## Verification

- `go test ./...` — table-driven cases: every preset resolves; case-insensitivity (`SOBA`); raw durations (`90s`→1m30s, `2m30s`, `1h2m`); rejections (`xyz`, `0s`, `-5s`, `25h`, empty string); formats (`0s`→`00:00`, `90s`→`01:30`, `3661s`→`1:01:01`, `1500ms`→`00:02` ceil, `61m`→`1:01:00`).
- `go vet ./...` clean.
- Live runs (prove-it-works): `go run . 3s` counts down and exits 0 with bell; `go run . soba` opens at `soba: 05:00` (interrupt after observing); `go run . xyz; echo $?` prints the error and `2`.
- Registry row exists in `brain/apps.md`; app repo has clean conventional history.

## Error Handling

All failures are input errors: descriptive message to stderr + usage hint, exit 2. The tick loop cannot fail (time and stdout only).
