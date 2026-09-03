---
description: Phase 0 for one app — draft apps/<name>/failed-test.md (split, cases, each probed red), then ask once
---
App: `apps/$ARGUMENTS`. Run the `tdd` skill's Phase 0 for the feature in `apps/$ARGUMENTS/spec.md`.
Draft `apps/$ARGUMENTS/failed-test.md`: split into small features, enumerate as many cases as you can,
probe each with `tdd-set/bin/probe.sh apps/$ARGUMENTS/<package-dir> -` and record only RED results.
Show the result and ask once: "검토·추가 끝나셨으면 이대로 진행할까요?" Then stop and wait.
Do not verify the review; the human is trusted. Write no implementation code.
