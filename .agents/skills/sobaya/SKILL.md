---
name: sobaya
description: Use for substantial Sobaya orchestration, app preflight, or deciding whether work benefits from delegation and worktree isolation.
---

# Sobaya orchestration

Read the root shared contract first. This skill adds orchestration decisions,
not another development lifecycle. `tdd-set/AGENTS.md` owns that lifecycle.

## Preflight

Read the brain index and only relevant notes; inspect `brain/apps.md` when
present, the target app's Git status, active work, and applicable contracts.
State the objective, authorized scope, acceptance evidence, and next bounded
piece of work. Read the app's spec and approval state before implementation.
Use `tdd-set/bin/status.sh <app>` and `doctor.sh <app>` where appropriate.

## Choose the work shape

Work locally when one focused investigation is enough. Delegate a bounded
subtask when it can proceed independently and the breadth, implementation
risk, or need for independent judgment pays for the extra context. File
count alone is not a reason to spawn an agent. Do not create parallel work
that requires the same mutable state.

For unfamiliar areas, delegate targeted exploration when useful; request
conclusions with evidence, not file dumps. For consequential changes, use
an independent reviewer to try to refute correctness. The implementer does
not serve as its own independent reviewer. Dispatch examples are in
`references/dispatch-patterns.md`; load them only when dispatching.

## Execute, verify, reflect

Carry authorized reversible work to completion. Each handoff names the
checkout, scope, protected inputs, expected artifact, and verification.
One writer owns each checkout. Parallel mutation uses isolated worktrees;
integration is sequential with verification between changes.

For implementation, progress through one approved entry and a validated
checkpoint at a time. The runner's policy fixes allowed workers, call and
time limits, and any fallback; never silently upgrade a model or relax
acceptance. Do not equate a session boundary with an entry boundary.

Verify actual artifacts and command results before accepting a report.
Diagnose failed delegation before a retry, revised brief, or handoff. If
human approval is required for changed tests or scope, present the concrete
proposal while continuing unaffected authorized work.

Persist progress before long or interruption-prone handoffs. App plans live
in their app repo; cross-app and harness plans live in `brain/plans/`.
After substantial verified work, use `reflect` and retain only durable
learnings. Do not manufacture a memory change when there is none.
