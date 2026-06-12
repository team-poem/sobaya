# Sobaya Harness Implementation Plan — Phase 2: Brain Seeding

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Seed the brain vault — vision, 10 principles, provenance note, app registry, todos, plan index, archive skeleton — then generate `brain/index.md` with the phase-1 hook script and prove it matches the golden expectation.

**Architecture:** The vault is plain markdown with wikilinks (spec: Brain seeding). Content files are written verbatim from this plan; `index.md` is *never* hand-written — it is produced by `.claude/hooks/auto-index-brain.sh` (built in phase 1), which doubles as the verification of index discipline.

**Tech Stack:** Markdown, wikilinks (`[[...]]`), POSIX sh (index generation only).

**Spec:** `brain/plans/01-sobaya-harness/overview.md` (approved 2026-06-12). Phases: 1 skeleton+hooks → **2 brain seeding** → 3 skills → 4 identity & docs.

**Working directory:** `/Users/amazon/lunch.cancelled/sobaya`. Use `git -C /Users/amazon/lunch.cancelled/sobaya` for git commands.

---

### Task 5: Vision and principles index

**Files:**
- Create: `brain/vision.md`
- Create: `brain/principles.md`

- [x] **Step 1: Write `brain/vision.md`** with exactly:

```markdown
# Vision

Sobaya (蕎麦屋 — a soba shop) is an orchestration workspace: the root is the
kitchen, each app in `apps/` is a dish, and the orchestrating session is the
head cook.

A good session here looks like this: it starts knowing the kitchen (the brain
index arrives via hook), reads only the notes that matter, briefs subagents
well instead of doing everything inline, keeps parallel work isolated (one
writer per app, worktrees for the rest), verifies real artifacts instead of
trusting reports, and leaves the vault smarter than it found it (reflect;
eventually meditate).

The workspace optimizes for max-effort orchestrator models (Opus 4.8,
Fable 5) driving many subagents — judgment stays in the orchestrator, bulk
work goes to the brigade, and lessons get encoded into structure so the
harness itself improves over time.

Working methods are borrowed from noodle ([[codebase/noodle-reference]]) and
composed with the superpowers plugin, which owns the dev lifecycle. Sobaya
adds only what neither provides.
```

- [x] **Step 2: Write `brain/principles.md`** with exactly:

```markdown
# Principles

Read the ones relevant to your task before acting; they are decision rules,
not documentation.

## Core
- [[principles/foundational-thinking]]
- [[principles/subtract-before-you-add]]

## Delegation
- [[principles/cost-aware-delegation]]
- [[principles/guard-the-context-window]]
- [[principles/never-block-on-the-human]]

## State
- [[principles/serialize-shared-state-mutations]]
- [[principles/make-operations-idempotent]]

## Verification
- [[principles/prove-it-works]]
- [[principles/fix-root-causes]]

## Meta
- [[principles/encode-lessons-in-structure]]
```

- [x] **Step 3: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add brain/vision.md brain/principles.md
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(brain): Seed vision and principles index

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Principle files — verification & state group

**Files:**
- Create: `brain/principles/prove-it-works.md`
- Create: `brain/principles/fix-root-causes.md`
- Create: `brain/principles/serialize-shared-state-mutations.md`
- Create: `brain/principles/make-operations-idempotent.md`
- Create: `brain/principles/encode-lessons-in-structure.md`

- [x] **Step 1: Write `brain/principles/prove-it-works.md`** with exactly:

```markdown
# Prove It Works

**Rule:** Every output is verified by checking the real thing directly —
never by proxies, "it compiles", or a subagent's self-report.

**Why:** Unverified work has unknown correctness. A subagent saying "done"
is a claim, not evidence; acting on wrong claims costs more than checking.

**In practice:**
- After a subagent reports completion, read the artifact it produced (diff,
  file, test output) before advancing the pipeline.
- Hooks and scripts are verified by running them against synthetic inputs,
  not by reading them.
- "Tests pass" means you ran them and saw the output in this session.

See also: [[principles/fix-root-causes]]
```

- [x] **Step 2: Write `brain/principles/fix-root-causes.md`** with exactly:

```markdown
# Fix Root Causes

**Rule:** Never paper over symptoms. Trace every problem to its root cause
and fix it there.

**Why:** Symptom fixes accumulate into workarounds that make the system
harder to reason about while the real bug stays. Root-cause fixes are slower
once and cheaper forever.

**In practice:**
- A failed dispatch is diagnosed from its output before any re-dispatch.
- When you apply the same fix twice, stop — the second occurrence is the
  signal to find the underlying cause or to encode a guard
  ([[principles/encode-lessons-in-structure]]).

See also: [[principles/prove-it-works]]
```

- [x] **Step 3: Write `brain/principles/serialize-shared-state-mutations.md`** with exactly:

```markdown
# Serialize Shared-State Mutations

**Rule:** Concurrent actors mutating shared state need structural
serialization — one writer per app, worktree isolation, sequential merges.
Instructions alone are insufficient.

**Why:** Concurrent writes race intermittently and unreproducibly. Agents
have no coordination mechanism unless the structure provides one.

**In practice:**
- Never run two mutating agents against the same checkout; parallel mutation
  gets one worktree per agent.
- Merge one worktree at a time, verifying between merges.
- Shared harness files (index, todos) are written atomically — tmp + rename
  in scripts, single Edit calls otherwise.

See also: [[principles/make-operations-idempotent]]
```

- [x] **Step 4: Write `brain/principles/make-operations-idempotent.md`** with exactly:

```markdown
# Make Operations Idempotent

**Rule:** Scripts and conventions converge to the correct state no matter
how many times they run or where they start from.

**Why:** Sessions get interrupted and hooks re-fire. If a re-run produces a
different outcome, every interruption becomes a debugging session.

**In practice:**
- The index hook rebuilds from disk state (never appends) and exits without
  writing when nothing changed.
- Scaffolds (new-app) refuse existing targets instead of half-applying over
  them.
- Resuming a plan means re-reading its checkboxes and continuing; re-running
  a completed step must be a no-op.

See also: [[principles/serialize-shared-state-mutations]]
```

- [x] **Step 5: Write `brain/principles/encode-lessons-in-structure.md`** with exactly:

```markdown
# Encode Lessons in Structure

**Rule:** Recurring fixes become mechanisms — hooks, rules, scaffolds,
templates — not repeated textual instructions.

**Why:** Textual instructions decay and get ignored under context pressure;
mechanisms enforce without cooperation. This is the founding lesson Sobaya
took from noodle.

**In practice:**
- During reflect, route each learning to the strongest encoding it supports:
  hook/script > skill edit > brain note > todo.
- Writing the same instruction twice is the trigger to mechanize it.
- The brain index is hook-maintained precisely so "update the index" never
  has to be remembered.
```

- [x] **Step 6: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add brain/principles/
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(brain): Seed verification, state, and meta principles

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Principle files — core & delegation group

**Files:**
- Create: `brain/principles/subtract-before-you-add.md`
- Create: `brain/principles/foundational-thinking.md`
- Create: `brain/principles/guard-the-context-window.md`
- Create: `brain/principles/cost-aware-delegation.md`
- Create: `brain/principles/never-block-on-the-human.md`

- [x] **Step 1: Write `brain/principles/subtract-before-you-add.md`** with exactly:

```markdown
# Subtract Before You Add

**Rule:** Remove complexity first, then build. Deletion creates a simpler
substrate that makes additions cleaner and less error-prone.

**Why:** Adding to a complex system compounds complexity; removing first
reveals the essential structure and usually shrinks the addition.

**In practice:**
- Before adding a skill, rule, or hook, check whether an existing one (here
  or in superpowers) already covers it — extend or delete rather than
  duplicate.
- Plans sequence removals before constructions.
- A redundant mechanism is a defect even when harmless — Sobaya omits
  noodle's block-sleep hook because the harness already enforces it.
```

- [x] **Step 2: Write `brain/principles/foundational-thinking.md`** with exactly:

```markdown
# Foundational Thinking

**Rule:** Structural decisions (data layout, file boundaries, phase
ordering) optimize for option value. Code-level decisions optimize for
simplicity.

**Why:** Real over-engineering is the premature decision that closes doors;
the right structure chosen early opens them. Meanwhile clever code mostly
closes understanding.

**In practice:**
- Many small phases beat a few large ones: they keep serial/parallel options
  open until dispatch time.
- Directory boundaries (apps/ as independent repos, brain/ sections) are
  chosen for how they will be navigated and archived, not for today's
  convenience.
- Inside a file, prefer the boring implementation.
```

- [x] **Step 3: Write `brain/principles/guard-the-context-window.md`** with exactly:

```markdown
# Guard the Context Window

**Rule:** The orchestrator's context is finite and non-renewable within a
session. Every token that enters must earn its place.

**Why:** Context bloat degrades reasoning quality and halts long work. The
orchestrator's judgment is the scarcest resource in the workspace; bulk
content belongs in subagents.

**In practice:**
- Route bulk reads (whole-repo exploration, long logs, reference docs) to
  Explore subagents that return conclusions, not file dumps.
- Always-loaded text stays minimal: CLAUDE.md stays ~30 lines; the
  session-start injection is the brain *index*, never note bodies.
- Skills carry their depth in `references/` so it loads only when invoked.

See also: [[principles/cost-aware-delegation]]
```

- [x] **Step 4: Write `brain/principles/cost-aware-delegation.md`** with exactly:

```markdown
# Cost-Aware Delegation

**Rule:** Every dispatch gets a budget and a hard-capped scope. A longer
brief is cheaper than rediscovery turns.

**Why:** Without explicit scope, delegated work expands to fill available
resources, and an under-briefed agent burns turns rediscovering context the
orchestrator already had.

**In practice:**
- Dispatch prompts state: target app path, the task, constraints, what NOT
  to touch, and the expected report format (templates live in the sobaya
  skill's references).
- Match agent count and model to the work; don't fan out ten agents where
  two suffice.
- Repeatedly re-dispatching failing work is backpressure ignored, not
  progress ([[principles/fix-root-causes]]).

See also: [[principles/guard-the-context-window]]
```

- [x] **Step 5: Write `brain/principles/never-block-on-the-human.md`** with exactly:

```markdown
# Never Block on the Human

**Rule:** During approved execution, make reasonable decisions, proceed, and
let the human course-correct afterward. Code is cheap; waiting is expensive.

**Why:** Mid-execution questions stall the entire pipeline, and most of them
are answerable from the plan, the brain, or the code.

**Boundary:** This governs *execution*, not *design*. Design-approval gates
(superpowers brainstorming, spec review) still apply — this principle starts
after approval, and stops for destructive or scope-changing decisions, which
always go to the human.

**In practice:**
- Inside an approved plan, resolve ambiguity from the spec and principles,
  note the decision in your report, and flag it for review — don't pause.
```

- [x] **Step 6: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add brain/principles/
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(brain): Seed core and delegation principles

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Provenance note, registry, todos, plan index, archive

**Files:**
- Create: `brain/codebase/noodle-reference.md`
- Create: `brain/apps.md`
- Create: `brain/todos.md`
- Create: `brain/plans/index.md`
- Create: `brain/archive/completed_todos.md`

- [x] **Step 1: Write `brain/codebase/noodle-reference.md`** with exactly:

```markdown
# noodle Reference

Source: https://github.com/poteto/noodle — analyzed at commit `82d2921`
(2026-06-12). Working clone: `references/noodle/` (gitignored).

**Borrowed into Sobaya:**
- Brain vault structure: principles/, codebase/ (one topic per file,
  150–600 words), plans/NN-slug (overview + phases), todos with permanent
  numbered IDs, archive discipline, wikilink indexes with no inlined content.
- reflect → meditate self-improvement loop: routing strength
  structure > skill > note > todo; auditor/reviewer subagents; early-exit
  gate; principle candidates need evidence from 2+ notes.
- Hooks: inject-brain (SessionStart), auto-index-brain (PostToolUse) —
  ported with a fix: noodle's matcher `"brain/"` never fires because Claude
  Code matchers are tool names; Sobaya filters file_path inside the script.
- Go mechanics as conventions: atomic writes (tmp+rename), one writer per
  target, worktree isolation + sequential merges, persist-before-spawn,
  stage_yield (artifacts ≠ process exit), diagnose-don't-retry, mise
  pre-flight brief, concurrency caps.

**Deliberately dropped:** Go runtime/event loop, autonomous scheduling, web
UI, `.agents/` multi-harness indirection, NDJSON event sourcing, block-sleep
hook (harness-native now), ~21 skills (superpowers covers the dev lifecycle;
others are noodle-CLI-specific).

**Where to look when porting more:** `.agents/skills/` (skill bodies),
`brain/principles/` (the full 16), `loop/loop.go` + `internal/`
(orchestration mechanics), `docs/` (concepts).
```

- [x] **Step 2: Write `brain/apps.md`** with exactly:

```markdown
# Apps

One line per app. `new-app` registers entries; keep status current
(scaffolded → active → paused → archived).

| App | Purpose | Stack | Status |
|---|---|---|---|
```

- [x] **Step 3: Write `brain/todos.md`** with exactly:

```markdown
---
priority: [1]
# 1 — the harness must exist before anything else can run
---

# Todos

<!-- next-id: 2 -->
<!-- completed todos live in archive/completed_todos.md -->
<!-- completed plans live in archive/plans/ -->

## Workspace

1. [ ] Build the Sobaya harness — skeleton, hooks, brain seeding, skills,
   identity & docs. [[plans/01-sobaya-harness/overview]]
```

- [x] **Step 4: Write `brain/plans/index.md`** with exactly:

```markdown
# Plans

- [ ] [[plans/01-sobaya-harness/overview]]
```

- [x] **Step 5: Write `brain/archive/completed_todos.md`** with exactly:

```markdown
# Completed Todos

Items move here from [[todos]] when done, newest first.
```

- [x] **Step 6: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add brain/codebase/ brain/apps.md brain/todos.md brain/plans/index.md brain/archive/
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(brain): Seed provenance note, app registry, todos, plan index

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Generate the index and prove index discipline

**Files:**
- Create: `brain/index.md` (generated — never hand-written)

- [x] **Step 1: Generate the index with the phase-1 hook script**

The hook won't fire in this session (hooks load at session start), so invoke it directly with a synthetic payload:

```bash
cd /Users/amazon/lunch.cancelled/sobaya
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/brain/todos.md"}}' "$PWD" \
  | CLAUDE_PROJECT_DIR="$PWD" sh .claude/hooks/auto-index-brain.sh
```

Expected: exit 0, `brain/index.md` now exists.

- [x] **Step 2: Verify against the golden index**

Run: `cat brain/index.md`
Expected — exactly this content:

```markdown
# Brain

## Vision
- [[vision]]

## Principles
- [[principles]]
- [[principles/cost-aware-delegation]]
- [[principles/encode-lessons-in-structure]]
- [[principles/fix-root-causes]]
- [[principles/foundational-thinking]]
- [[principles/guard-the-context-window]]
- [[principles/make-operations-idempotent]]
- [[principles/never-block-on-the-human]]
- [[principles/prove-it-works]]
- [[principles/serialize-shared-state-mutations]]
- [[principles/subtract-before-you-add]]

## Apps
- [[apps]]

## Codebase
- [[codebase/noodle-reference]]

## Backlog
- [[todos]]

## Plans
- [[plans/index]]

## Archive
- [[archive/completed_todos]]
```

Note: nothing from `plans/01-sobaya-harness/` appears — plan-nested files are excluded by design; plans are reached via `plans/index`.

- [x] **Step 3: Verify the fast path (idempotence)**

```bash
touch -t 200001010000 brain/index.md
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/brain/todos.md"}}' "$PWD" \
  | CLAUDE_PROJECT_DIR="$PWD" sh .claude/hooks/auto-index-brain.sh
ls -l brain/index.md
```

Expected: exit 0 and the listed modification time still shows Jan 2000 (no rewrite happened).

- [x] **Step 4: Run the full hook test suite once more**

Run: `sh tests/hooks-test.sh`
Expected: `ALL PASS`

- [x] **Step 5: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add brain/index.md
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(brain): Generate index via auto-index hook

Index is generated, never hand-written; golden content verified.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
