---
description: Phase 0 for one app — draft apps/<name>/failed-test.md (split, cases, each probed red), then ask once
---
App: `apps/$ARGUMENTS`. Run the `tdd` skill's Phase 0 for the feature in `apps/$ARGUMENTS/spec.md`.
If the app already has tests, first audit them against the skill's four rules (isolated, setup
only in the section header, evident data, readable and specific over short); list every
violation with its fix, get the human's yes, commit the fixes as `refactor:` before anything else.
Draft `apps/$ARGUMENTS/failed-test.md`: split into small features, enumerate as many cases as you can,
probe each and record only RED results. Go: `tdd-set/bin/probe.sh apps/$ARGUMENTS/<package-dir> -`.
Node: one header block per small feature (`// file:` line, imports, shared constants) written to
`${TMPDIR:-/tmp}/sobaya-header.ts`, then `tdd-set/bin/probe.sh apps/$ARGUMENTS/<test-dir> - ${TMPDIR:-/tmp}/sobaya-header.ts`
per `test(...)` block; the header goes once at the top of the section in `failed-test.md`.
Show the result and ask once: "검토·추가 끝나셨으면 이대로 진행할까요?" Then stop and wait.
Do not verify the review; the human is trusted. Write no implementation code.
