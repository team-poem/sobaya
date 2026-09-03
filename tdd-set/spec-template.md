# <feature> — spec

Human-written. Agents read this file and never edit it. It exists so Phase 0 can
enumerate the right tests; the tests in plan.md are the real spec.

## Goal (one paragraph)
<what must be true when this is done>

## Must
- <requirement 1>
- <requirement 2>

## Must not
- <constraint / out of scope>

## Done when
- every entry in plan.md is checked and a test with its name exists in the suite
- full test suite is green
- no existing test line was modified or removed (gate.sh enforces)
