# Thin Shell Needs a Refuter

When the design is "pure core + thin shell" (logic in tested functions, a
thin untested shell wiring them to IO), the unit tests cover the core but
nothing covers the shell. Display glitches, exit-code routing, and tick-loop
wiring live in the shell and pass every unit test.

**Pattern — match review depth to risk:**
- Byte-exact transcription tasks (the implementer copies fully-specified
  code from a plan) → a light direct verification is enough; a full spec +
  quality review just re-confirms the transcription.
- The shell / integration / live behavior → dispatch a refuter (review by
  refutation) and run the binary for real ([[principles/prove-it-works]]).
  This is where the real defects hide.

**Evidence:** soba-timer (2026-06-13), the workspace's first end-to-end
pipeline run. Six byte-exact TDD tasks all passed unit tests; the refuter
review found a genuine display bug in `run` (the untested tick loop) — see
[[codebase/terminal-redraw-clear-to-eol]] — and a spec self-contradiction on
usage routing. The pure functions were flawless; the shell was where the
bug was.

This is why the `sobaya` skill's pipeline puts a refuter stage after execute
and has the orchestrator do live verification directly.
