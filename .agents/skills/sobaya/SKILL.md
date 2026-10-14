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
piece of work. Read the app's intent, scenario list and active execution state before implementation.
Use `tdd-set/bin/status.sh <app>` and `doctor.sh <app>` where appropriate.

## Choose the work shape

Work locally when one focused investigation is enough. Delegate a bounded
subtask when it can proceed independently and the breadth, implementation
risk, or need for independent judgment pays for the extra context. File
count alone is not a reason to spawn an agent. Do not create parallel work
that requires the same mutable state.

For unfamiliar areas, delegate targeted exploration when useful; request
conclusions with evidence, not file dumps. Use an independent reviewer when the risk or uncertainty justifies
a separate judgment; this is optional, not a per-cycle gate. The implementer does
not serve as its own independent reviewer. Dispatch examples are in
`references/dispatch-patterns.md`; load them only when dispatching.

## Execute, verify, reflect

Carry authorized reversible work to completion. Each handoff names the
checkout, scope, protected inputs, expected artifact, and verification.
One writer owns each checkout. Parallel mutation uses isolated worktrees;
integration is sequential with verification between changes.

For implementation, select and verify one test at a time within the
authorized intent. Do not insert exact-test approvals or freeze future scenarios. The runner's policy fixes allowed workers, call and
time limits, and any fallback; never silently upgrade a model or relax
acceptance. Do not equate a session boundary with an entry boundary.

At GREEN, consider useful tidying within the authorized task and the current
runtime limits in `tdd-set/AGENTS.md`. Before the next feature, expose what
was learned, whether the user outcome was observed, and what that means for
the next choice. This decision boundary does not require a new task, a timed
wait, a forced artifact or repeated permission for already authorized work.
Do not equate an exhausted executable plan with the whole product goal.

Verify actual artifacts and command results before accepting a report.
Diagnose failed delegation before a retry, revised brief, or handoff. If
product intent is unclear or changing, present the concrete decision while
continuing unaffected authorized work. Test code can evolve within existing intent.

Persist progress before long or interruption-prone handoffs. App plans live
in their app repo; cross-app and harness plans live in `brain/plans/`.
After substantial verified work, use `reflect` and retain only durable
learnings. Do not manufacture a memory change when there is none.
