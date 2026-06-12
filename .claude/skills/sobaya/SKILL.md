---
name: sobaya
description: Use when orchestrating work across apps/ in the Sobaya workspace — starting substantial multi-step work in any app, dispatching subagents for app work, or deciding how to parallelize and isolate changes. Not for trivial single-file edits.
---

# Sobaya Orchestration

You are the head cook. Judgment stays here; bulk work goes to the brigade
(subagents). superpowers owns the dev lifecycle — brainstorming for design,
writing-plans for plans, test-driven-development, systematic-debugging, code
review — this skill governs how work moves through the workspace around
those.

## 1. Pre-flight (mise en place)

Before dispatching anything substantial:

1. Check the brain index (injected at session start; otherwise read
   `brain/index.md`) and open only the notes relevant to this task.
2. Read `brain/apps.md` and the target app's state:
   `git -C apps/<name> status --short` and `git -C apps/<name> log --oneline -5`.
3. Check `brain/todos.md` and any active plan in `brain/plans/`.
4. Assemble a one-paragraph brief: what is active, what is in scope, what
   the deliverable is, how much parallelism the task deserves.

If a plan for this work exists, follow it. If the work needs one (multi-
phase, 3+ files), use superpowers:writing-plans first and store it in
`brain/plans/NN-slug/`.

## 2. Dispatch rules

- **Explore before you touch.** Unknown code is mapped by Explore agents
  that return conclusions, not file dumps. Never bulk-read an app into the
  orchestrator context. ([[principles/guard-the-context-window]])
- **Brief like a work order.** Implementation dispatches state: app path,
  task, constraints, files NOT to touch, expected report format. Templates:
  `references/dispatch-patterns.md`. ([[principles/cost-aware-delegation]])
- **Review by refutation.** Review agents are told to refute the work, not
  confirm it — and are never the agent that implemented it.
- **Artifacts over messages.** Long-running subagents write progress and
  results to files as they go (reports under the active plan dir), so
  interrupted work survives. The final message points at the files.

## 3. Pipeline discipline

Substantial work runs staged: **execute → review → reflect**.

- Declare each stage's deliverable before dispatching it.
- A stage is complete when its artifact is verified directly
  ([[principles/prove-it-works]]) — not when an agent says so.
- After the final stage of meaningful work, run Skill(reflect).

## 4. Concurrency

- One writer per app at any moment. Parallel mutation means one worktree per
  agent; merge sequentially, verifying between merges.
  ([[principles/serialize-shared-state-mutations]])
- Read-only agents may fan out freely.
- Cap concurrent agents at what the task actually needs, not what the
  harness allows.

## 5. Failure handling

No blind retries. When a dispatch fails or returns garbage: read its output
and artifacts, diagnose (superpowers:systematic-debugging for real bugs),
then decide — fix the brief, change the decomposition, or do it directly.
Re-dispatching the same prompt is almost never the answer.
([[principles/fix-root-causes]])

## 6. Persist before you spawn

For work that spans sessions or long dispatches: make sure the plan/progress
file exists in `brain/plans/` *before* spawning. If the session dies, the
next one adopts the work from the plan's checkboxes and report files.
