---
description: Run the whole plan autonomously — loop.sh, then the gate
---
The working tree must be clean. Run `../../tdd-set/bin/loop.sh $ARGUMENTS` from the app root
(argument = max iterations, default 50), then report: iterations run, stalls, and the gate
output verbatim. Do not fix anything the gate rejects; report it.
