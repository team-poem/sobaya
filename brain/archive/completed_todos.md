# Completed Todos

Items move here from [[todos]] when done, newest first.

9. [x] ~~cairn-desktop post-merge polish backlog (runs-Map cap, basename
   run names, greet removal, light-theme badges, console.table/dir,
   stdout flush)~~ — done 2026-07-07, commits 709c405/13cddc6/8a96c36,
   review clean.
8. [x] ~~Merge cairn-desktop `dev/mvp` → main + tag v0.1.0~~ — done
   2026-07-07 (ff to 8972c08, tag v0.1.0; polish wave ff'd after).
   [[plans/12-cairn-desktop/overview]]

7. [x] ~~soba-timer — first app, e2e pipeline test vehicle~~ — done. [[archive/plans/02-soba-timer/overview]]
1. [x] ~~Build the Sobaya harness~~ — done. [[archive/plans/01-sobaya-harness/overview]]
10. [x] ~~loop.sh: cost grows with failed-test.md size, wall time with iteration count~~ — closed
   2026-09-06 via team-poem/sobaya#2: fix 1 (pass only the next entry) is `tdd-set/bin/next.sh`
   (f8e0a38); fix 2 (continue in one session) rejected — /go is one entry per session by rule
   (c84cb4f); fix 3 (`SOBAYA_MODEL`) already existed, loop defaults to sonnet. Remaining
   in-session context growth is measure-only. Evidence table lives in
   [[archive/codebase/legacy-loop-cost-measurement]].
11. [x] ~~loop.sh: `Bash(cd apps/<name> && npm:*)` allowlist patterns never match~~ — fixed
   2026-09-06: patterns split into `Bash(cd <app>:*)` + bare `Bash(npm:*)`/`npx`/`node`/`go` and
   bare `git <sub>` rules; re-verified with haiku (`cd <app> && npm test` runs, no denial).
