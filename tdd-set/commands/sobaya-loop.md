---
description: Run one app's whole plan autonomously — loop.sh, then the gate
---
Run `tdd-set/bin/loop.sh apps/$ARGUMENTS` (append a max-iteration count if the human gave one;
the app's working tree must be clean), then report: iterations run, stalls, and the gate output
verbatim. Do not fix anything the gate rejects; report it.
