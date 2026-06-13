# soba-timer Implementation Plan — Phase 1

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `apps/soba-timer`, a zero-dependency Go CLI that counts down noodle-cooking timers from presets or duration strings, with a live single-line display and a completion bell.

**Architecture:** Pure core (`timer.go`: `Resolve`, `FormatRemaining`) is table-driven-tested; `main.go` is a thin shell doing arg handling + a one-second tick loop. stdlib only.

**Tech Stack:** Go 1.26 (stdlib only), `time.ParseDuration`, `testing`.

**Spec:** `brain/plans/02-soba-timer/overview.md` (approved 2026-06-13).

**Working directory:** The app is its OWN git repo at `/Users/amazon/lunch.cancelled/sobaya/apps/soba-timer`. ALL git commands for the app use `git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer`. NEVER bare-`cd` into the app or into `references/`; the shell cwd persists between calls. The harness repo (`git -C /Users/amazon/lunch.cancelled/sobaya`) is only touched in Task 6 (registry). `apps/*` is gitignored by the harness, so the app is invisible to harness `git status` — that is expected.

---

### Task 1: Scaffold the app repo

**Files:**
- Create: `apps/soba-timer/go.mod`
- Create: `apps/soba-timer/CLAUDE.md`
- Create: `apps/soba-timer/README.md`
- Create: `apps/soba-timer/.gitignore`

- [ ] **Step 1: Create the directory and init the repo**

```bash
mkdir -p /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer
git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer init -b main
```

- [ ] **Step 2: Write `apps/soba-timer/go.mod`** with exactly:

```
module github.com/amazon7737/soba-timer

go 1.26
```

- [ ] **Step 3: Write `apps/soba-timer/CLAUDE.md`** with exactly:

```markdown
# soba-timer

A zero-dependency Go CLI that counts down noodle-cooking timers from presets
(soba, udon, somen, ramen) or Go duration strings.

Part of the Sobaya workspace — workspace conventions (brain, orchestration,
one-writer-per-app) live in the root CLAUDE.md and apply here.

## App facts
- Stack: Go (stdlib only)
- Run: `go run . <preset|duration>` (e.g. `go run . soba`, `go run . 90s`)
- Test: `go test ./...`
- Vet: `go vet ./...`
```

- [ ] **Step 4: Write `apps/soba-timer/README.md`** with exactly:

```markdown
# soba-timer

면 삶기 타이머 CLI입니다. 프리셋(`soba` 5분, `udon` 10분, `somen` 2분,
`ramen` 3분) 또는 Go 시간 문자열(`90s`, `2m30s`)로 카운트다운하고, 끝나면
터미널 벨을 울립니다. Go 표준 라이브러리만 사용합니다.

```sh
go run . soba      # 5:00 부터 카운트다운
go run . 90s       # 1:30 부터 카운트다운
go test ./...      # 테스트
```
```

- [ ] **Step 5: Write `apps/soba-timer/.gitignore`** with exactly:

```
/soba-timer
*.out
```

- [ ] **Step 6: Verify the scaffold**

Run: `git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer status --short`
Expected: four untracked files — `.gitignore`, `CLAUDE.md`, `README.md`, `go.mod`.

Run: `go -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer mod verify 2>&1 || true`
Expected: `all modules verified` (no dependencies, so this is trivially true).

- [ ] **Step 7: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer add -A
git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer commit -m "chore: scaffold soba-timer

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: `Resolve` — preset/duration parsing (TDD)

**Files:**
- Create: `apps/soba-timer/timer_test.go`
- Create: `apps/soba-timer/timer.go`

- [ ] **Step 1: Write the failing test**

Create `apps/soba-timer/timer_test.go` with exactly:

```go
package main

import (
	"testing"
	"time"
)

func TestResolve(t *testing.T) {
	cases := []struct {
		arg     string
		want    time.Duration
		wantErr bool
	}{
		{"soba", 5 * time.Minute, false},
		{"udon", 10 * time.Minute, false},
		{"somen", 2 * time.Minute, false},
		{"ramen", 3 * time.Minute, false},
		{"SOBA", 5 * time.Minute, false},   // case-insensitive preset
		{"Udon", 10 * time.Minute, false},  // case-insensitive preset
		{"90s", 90 * time.Second, false},   // raw duration
		{"2m30s", 150 * time.Second, false},
		{"1h2m", 62 * time.Minute, false},
		{"xyz", 0, true},                   // unknown
		{"", 0, true},                      // empty
		{"0s", 0, true},                    // non-positive
		{"-5s", 0, true},                   // negative
		{"25h", 0, true},                   // over 24h
	}
	for _, c := range cases {
		got, err := Resolve(c.arg)
		if c.wantErr {
			if err == nil {
				t.Errorf("Resolve(%q): want error, got %v", c.arg, got)
			}
			continue
		}
		if err != nil {
			t.Errorf("Resolve(%q): unexpected error %v", c.arg, err)
			continue
		}
		if got != c.want {
			t.Errorf("Resolve(%q) = %v, want %v", c.arg, got, c.want)
		}
	}
}
```

- [ ] **Step 2: Run the test to verify it fails to compile**

Run: `go -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer test ./...`
Expected: FAIL — build error `undefined: Resolve`.

- [ ] **Step 3: Write the implementation**

Create `apps/soba-timer/timer.go` with exactly:

```go
package main

import (
	"fmt"
	"strings"
	"time"
)

// maxDuration is the longest timer we accept.
const maxDuration = 24 * time.Hour

// Presets maps lowercase preset names to cooking durations.
var Presets = map[string]time.Duration{
	"soba":  5 * time.Minute,
	"udon":  10 * time.Minute,
	"somen": 2 * time.Minute,
	"ramen": 3 * time.Minute,
}

// Resolve turns a CLI argument into a timer duration. It looks up presets
// case-insensitively first, then falls back to time.ParseDuration. It rejects
// durations that are non-positive or longer than maxDuration.
func Resolve(arg string) (time.Duration, error) {
	if d, ok := Presets[strings.ToLower(arg)]; ok {
		return d, nil
	}
	d, err := time.ParseDuration(arg)
	if err != nil {
		return 0, fmt.Errorf("unknown preset or duration: %q", arg)
	}
	if d <= 0 {
		return 0, fmt.Errorf("duration must be positive: %q", arg)
	}
	if d > maxDuration {
		return 0, fmt.Errorf("duration must be 24h or less: %q", arg)
	}
	return d, nil
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `go -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer test ./...`
Expected: PASS (`ok  github.com/amazon7737/soba-timer`).

- [ ] **Step 5: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer add timer.go timer_test.go
git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer commit -m "feat: resolve presets and durations

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: `FormatRemaining` — countdown display (TDD)

**Files:**
- Modify: `apps/soba-timer/timer_test.go` (append a test function)
- Modify: `apps/soba-timer/timer.go` (append the function)

- [ ] **Step 1: Append the failing test**

Append to `apps/soba-timer/timer_test.go` (after the existing `TestResolve` function, before EOF):

```go
func TestFormatRemaining(t *testing.T) {
	cases := []struct {
		d    time.Duration
		want string
	}{
		{0, "00:00"},
		{1 * time.Second, "00:01"},
		{90 * time.Second, "01:30"},
		{5 * time.Minute, "05:00"},
		{1500 * time.Millisecond, "00:02"},          // ceil to 2s
		{1001 * time.Millisecond, "00:02"},          // ceil to 2s
		{1*time.Hour + 1*time.Minute + 1*time.Second, "1:01:01"},
		{61 * time.Minute, "1:01:00"},
		{-3 * time.Second, "00:00"},                 // never negative
	}
	for _, c := range cases {
		if got := FormatRemaining(c.d); got != c.want {
			t.Errorf("FormatRemaining(%v) = %q, want %q", c.d, got, c.want)
		}
	}
}
```

- [ ] **Step 2: Run the test to verify it fails to compile**

Run: `go -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer test ./...`
Expected: FAIL — build error `undefined: FormatRemaining`.

- [ ] **Step 3: Append the implementation**

Append to `apps/soba-timer/timer.go` (after `Resolve`, before EOF):

```go
// FormatRemaining renders a remaining duration ceiled to whole seconds as
// MM:SS, or H:MM:SS when the duration is one hour or more. Negative durations
// render as "00:00".
func FormatRemaining(d time.Duration) string {
	if d < 0 {
		d = 0
	}
	total := int((d + time.Second - 1) / time.Second) // ceil to whole seconds
	h := total / 3600
	m := (total % 3600) / 60
	s := total % 60
	if h > 0 {
		return fmt.Sprintf("%d:%02d:%02d", h, m, s)
	}
	return fmt.Sprintf("%02d:%02d", m, s)
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `go -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer test ./...`
Expected: PASS.

- [ ] **Step 5: Vet**

Run: `go -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer vet ./...`
Expected: no output (clean).

- [ ] **Step 6: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer add timer.go timer_test.go
git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer commit -m "feat: format remaining time with ceil

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: `label` helper — display label (TDD)

The running display shows a label: the preset name for presets, or the
normalized duration for raw inputs (`2m30s: 02:29`). This is a pure helper so
it gets its own test.

**Files:**
- Modify: `apps/soba-timer/timer_test.go` (append a test function)
- Modify: `apps/soba-timer/timer.go` (append the function)

- [ ] **Step 1: Append the failing test**

Append to `apps/soba-timer/timer_test.go` (after `TestFormatRemaining`, before EOF):

```go
func TestLabel(t *testing.T) {
	cases := []struct {
		arg  string
		d    time.Duration
		want string
	}{
		{"soba", 5 * time.Minute, "soba"},
		{"SOBA", 5 * time.Minute, "soba"},     // normalized to preset key
		{"Udon", 10 * time.Minute, "udon"},
		{"90s", 90 * time.Second, "1m30s"},    // raw -> normalized duration
		{"2m30s", 150 * time.Second, "2m30s"},
		{"1h2m", 62 * time.Minute, "1h2m0s"},
	}
	for _, c := range cases {
		if got := label(c.arg, c.d); got != c.want {
			t.Errorf("label(%q, %v) = %q, want %q", c.arg, c.d, got, c.want)
		}
	}
}
```

- [ ] **Step 2: Run the test to verify it fails to compile**

Run: `go -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer test ./...`
Expected: FAIL — build error `undefined: label`.

- [ ] **Step 3: Append the implementation**

Append to `apps/soba-timer/timer.go` (after `FormatRemaining`, before EOF):

```go
// label returns the display label for a timer: the canonical preset name when
// arg names a preset (case-insensitive), otherwise the normalized duration.
func label(arg string, d time.Duration) string {
	if _, ok := Presets[strings.ToLower(arg)]; ok {
		return strings.ToLower(arg)
	}
	return d.String()
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `go -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer test ./...`
Expected: PASS (all three test functions).

- [ ] **Step 5: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer add timer.go timer_test.go
git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer commit -m "feat: display label for presets and raw durations

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: `main.go` — CLI shell + tick loop

This is the thin shell: arg handling, usage, and the one-second countdown loop.
No pure logic lives here (it is in `timer.go`), so it has no unit tests; it is
verified by live runs in Task 6.

**Files:**
- Create: `apps/soba-timer/main.go`

- [ ] **Step 1: Write `apps/soba-timer/main.go`** with exactly:

```go
package main

import (
	"fmt"
	"os"
	"sort"
	"time"
)

func usage(w *os.File) {
	fmt.Fprintln(w, "usage: soba-timer <preset|duration>")
	fmt.Fprintln(w, "")
	fmt.Fprintln(w, "presets:")
	names := make([]string, 0, len(Presets))
	for n := range Presets {
		names = append(names, n)
	}
	sort.Slice(names, func(i, j int) bool { return Presets[names[i]] < Presets[names[j]] })
	for _, n := range names {
		fmt.Fprintf(w, "  %-6s %s\n", n, Presets[n])
	}
	fmt.Fprintln(w, "")
	fmt.Fprintln(w, "duration: any Go duration, e.g. 90s, 2m30s, 1h2m")
}

func main() {
	args := os.Args[1:]
	if len(args) == 1 && (args[0] == "-h" || args[0] == "--help") {
		usage(os.Stdout)
		return
	}
	if len(args) != 1 {
		usage(os.Stderr)
		os.Exit(2)
	}

	d, err := Resolve(args[0])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		fmt.Fprintln(os.Stderr, "run with -h for usage")
		os.Exit(2)
	}

	name := label(args[0], d)
	run(name, d)
}

// run counts down d, refreshing a single line once per second, then rings the
// terminal bell and prints a completion line.
func run(name string, d time.Duration) {
	deadline := time.Now().Add(d)
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			break
		}
		fmt.Printf("\r%s: %s ", name, FormatRemaining(remaining))
		<-ticker.C
	}
	fmt.Printf("\r%s: %s \n", name, FormatRemaining(0))
	fmt.Printf("\adone! (%s, %s)\n", name, d)
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `go -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer build ./...`
Expected: no output, exit 0.

- [ ] **Step 3: Re-run the full test suite (nothing should break)**

Run: `go -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer test ./...`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer add main.go
git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer commit -m "feat: CLI shell and countdown loop

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Live verification + registry

prove-it-works: run the actual binary and observe behavior. Then register the
app in the harness brain.

**Files:**
- Modify: `brain/apps.md` (harness repo — append registry row)

First build a binary once so the live checks don't recompile each time:

Run: `go -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer build -o /tmp/soba-timer .`
Expected: no output, exit 0; `/tmp/soba-timer` exists.

- [ ] **Step 1: Countdown completes and rings the bell**

Run: `/tmp/soba-timer 3s | cat -v; echo "exit=${PIPESTATUS[0]}"`
Expected: the display line refreshes (`cat -v` shows the `\r` carriage returns as `^M`), ending with `3s: 00:00` then `done! (3s, 3s)`. `exit=0`.

NOTE: `label("3s", 3s)` → `"3s"` (raw duration normalized), so the display reads `3s: 00:03`, `00:02`, `00:01`, `00:00`. That is expected.

- [ ] **Step 2: Preset opens at the right time (non-blocking peek)**

The first line renders immediately, before the first one-second tick. Capture it without waiting for the full 5 minutes by launching in the background, reading the output, then killing:

Run:
```bash
/tmp/soba-timer soba > /tmp/soba-open.txt 2>&1 &
SOBA_PID=$!
/tmp/soba-timer 1s >/dev/null 2>&1   # ~1s of real work, no `sleep` needed
kill "$SOBA_PID" 2>/dev/null
cat -v /tmp/soba-open.txt | head -c 80; echo
```
Expected: the captured output begins with `soba: 05:00`.

- [ ] **Step 3: Error paths**

Run: `/tmp/soba-timer xyz; echo "exit=$?"`
Expected: stderr shows `unknown preset or duration: "xyz"` then `run with -h for usage`; `exit=2`.

Run: `/tmp/soba-timer 25h; echo "exit=$?"`
Expected: `duration must be 24h or less: "25h"`; `exit=2`.

Run: `/tmp/soba-timer 0s; echo "exit=$?"`
Expected: `duration must be positive: "0s"`; `exit=2`.

Run: `/tmp/soba-timer; echo "exit=$?"`
Expected: usage printed to stderr; `exit=2`.

- [ ] **Step 4: Help path**

Run: `/tmp/soba-timer -h; echo "exit=$?"`
Expected: usage with a preset table sorted by duration (`somen 2m0s`, `ramen 3m0s`, `soba 5m0s`, `udon 10m0s`) printed to **stdout**; `exit=0` (help is not an error).

- [ ] **Step 5: Final test + vet pass**

Run: `go -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer test ./... && go -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer vet ./...`
Expected: `ok` then no vet output. Both exit 0.

- [ ] **Step 6: Confirm the app's git history is clean and conventional**

Run: `git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer log --oneline && git -C /Users/amazon/lunch.cancelled/sobaya/apps/soba-timer status --short`
Expected: five commits (scaffold, resolve, format, label, CLI shell); working tree clean.

- [ ] **Step 7: Register in the harness brain**

Append one row to the table in `/Users/amazon/lunch.cancelled/sobaya/brain/apps.md`:

```
| soba-timer | noodle-cooking countdown timer | Go | active |
```

- [ ] **Step 8: Commit the registry update (harness repo)**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add brain/apps.md
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(apps): Register soba-timer

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

NOTE: editing `brain/apps.md` may trigger the PostToolUse auto-index hook. Since
`apps` is already indexed, no `brain/index.md` change should result. If
`git status` unexpectedly shows `brain/index.md` modified, include it in this
commit and note it in the report.
