# Terminal Redraw: Clear to End of Line

A single-line CLI display redrawn with `\r` leaves stale characters when a
later frame is shorter than an earlier one. A trailing space or two is not
enough — clear to end of line.

**Cause:** `\r` only moves the cursor to column 0; it does not erase. Writing
a shorter string over a longer one leaves the tail of the old frame visible.

**Pattern:** append `\033[K` (ANSI erase-to-end-of-line) after the content on
every redraw:

```go
fmt.Printf("\r%s: %s \033[K", name, FormatRemaining(remaining))
```

Safe on any terminal that already interprets `\r` and the bell `\a` — the
same class this kind of app targets. Fixed-width padding also works but
breaks when the content can exceed the pad.

**Evidence:** soba-timer (apps/soba-timer, 2026-06-13). A ≥1h countdown
shrank `1:00:01` → `59:59` and left a stray `1`. A refuter review caught it;
unit tests of the pure formatter never could — see
[[codebase/thin-shell-needs-a-refuter]].

See also: [[principles/prove-it-works]]
