# Sobaya Harness Implementation Plan — Phase 3: Skills

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the four Sobaya skills (`sobaya`, `new-app`, `reflect`, `meditate`) plus the dispatch-pattern reference, and smoke-test `new-app` end to end.

**Architecture:** Skills are the only extension point (spec D2). Each is a `SKILL.md` under `.claude/skills/<name>/` with `name` + trigger-phrased `description` frontmatter; depth goes to `references/` (progressive disclosure). They complement superpowers — never duplicate its plan/TDD/debug/review skills.

**Tech Stack:** Markdown + YAML frontmatter (Claude Code project skills).

**Spec:** `brain/plans/01-sobaya-harness/overview.md` (approved 2026-06-12). Phases: 1 skeleton+hooks → 2 brain seeding → **3 skills** → 4 identity & docs.

**Working directory:** `/Users/amazon/lunch.cancelled/sobaya`. Use `git -C /Users/amazon/lunch.cancelled/sobaya` for git commands.

**Authoring note:** The executor should hold these against superpowers:writing-skills conventions (clear trigger in description, third-person, concise body). The contents below were drafted with those conventions; if writing-skills flags a violation, fix the content and note the deviation in the task report.

---

### Task 10: sobaya skill + dispatch patterns reference

**Files:**
- Create: `.claude/skills/sobaya/SKILL.md`
- Create: `.claude/skills/sobaya/references/dispatch-patterns.md`

- [ ] **Step 1: Write `.claude/skills/sobaya/SKILL.md`** with exactly:

````markdown
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
````

- [ ] **Step 2: Write `.claude/skills/sobaya/references/dispatch-patterns.md`** with exactly:

````markdown
# Dispatch Patterns

Prompt templates for the brigade. Replace `<angle>` fields; delete sections
that don't apply. Every dispatch is scoped and reportable.

## Explore (read-only scout)

Use the Explore agent type. One concern per agent; fan out for breadth.

```
Explore apps/<name> to answer: <question>.
Context: <one or two sentences — why this matters>.
Start at: <entry points if known>.
Do NOT propose changes. Return: the direct answer first, then key files as
path:line references, then anything surprising. Keep it under ~400 words.
```

## Implement (cook)

general-purpose agent. One unit of work per dispatch.

```
Work in apps/<name> (a standalone git repo at apps/<name>).
Task: <the change, concretely — behavior, not vibes>.
Constraints: <stack, conventions; read apps/<name>/CLAUDE.md first>.
Do NOT touch: <files/areas owned by other agents or out of scope>.
Process: follow superpowers:test-driven-development — failing test, minimal
code, pass. Commit per logical change with conventional messages.
Report: append progress to <brain/plans/NN-slug/reports/task-N.md> as you
finish each part (do not wait until the end), then return: what changed,
what you verified (commands + output), what remains.
```

For parallel cooks on one app: give each `isolation: worktree` and disjoint
"Do NOT touch" sets; merge their branches one at a time afterward, running
the app's tests between merges.

## Review (refuter)

Independent agent — never the implementer.

```
Review the diff in apps/<name> (<rev range or worktree path>). Your job is
to REFUTE that it is correct, complete, and scoped — not to approve it.
Hunt specifically for: broken edge cases, missing or vacuous tests, scope
creep, violations of <app conventions / the brain principles relevant here>.
For each finding: severity, file:line, why it is wrong, the smallest fix.
If you cannot refute it, say so explicitly and list what you checked.
```

## Verify (prove-it-works pass)

```
In apps/<name>, run: <test/build/run commands>.
Report the exact commands and the full relevant output. If anything fails,
capture the failure verbatim and stop — do NOT fix it.
```
````

- [ ] **Step 3: Verify frontmatter shape**

Run: `head -4 .claude/skills/sobaya/SKILL.md`
Expected: line 1 `---`, line 2 starts `name: sobaya`, line 3 starts `description: Use when`, line 4 `---`.

- [ ] **Step 4: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add .claude/skills/sobaya/
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(skills): Add sobaya orchestration skill

Pre-flight brief, dispatch rules, pipeline discipline, concurrency and
failure conventions — noodle's working methods on Claude Code primitives.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 11: new-app skill

**Files:**
- Create: `.claude/skills/new-app/SKILL.md`

- [ ] **Step 1: Write `.claude/skills/new-app/SKILL.md`** with exactly:

````markdown
---
name: new-app
description: Use when creating a new project or app under apps/ in the Sobaya workspace — scaffolds the directory as its own git repo with an app-level CLAUDE.md and registers it in brain/apps.md.
---

# New App

Creates `apps/<name>` as an independent git repository and registers it.

## Before scaffolding

1. **Name:** kebab-case (`lower-case-with-dashes`). If the requested name
   doesn't fit, propose the kebab-case form and confirm — never rename
   silently.
2. **Existing target:** if `apps/<name>` already exists, stop and report.
   Never overwrite or "merge into" an existing app.
   ([[principles/make-operations-idempotent]])
3. **Design gate:** if this is a new product/feature being designed (not a
   directory the user already fully specified), run superpowers:brainstorming
   first. Scaffold immediately only when the user explicitly asks for just
   the scaffold.

## Steps

1. Create and init:

   ```sh
   mkdir -p apps/<name>
   git -C apps/<name> init -b main
   ```

2. Write `apps/<name>/CLAUDE.md`:

   ```markdown
   # <name>

   <One line: what this app is.>

   Part of the Sobaya workspace — workspace conventions (brain,
   orchestration, one-writer-per-app) live in the root CLAUDE.md and apply
   here.

   ## App facts
   - Stack: <decided at design>
   - Run: <command>
   - Test: <command>
   ```

   Angle fields are filled at design time; none may survive past the app's
   first implementation commit.

3. Write `apps/<name>/README.md` — Korean, one paragraph: 이 앱이 무엇을
   하는지, 어떤 스택인지.

4. First commit inside the app:

   ```sh
   git -C apps/<name> add -A
   git -C apps/<name> commit -m "chore: scaffold <name>"
   ```

5. Register the app — append one row to the table in `brain/apps.md`:
   `| <name> | <purpose> | <stack or –> | scaffolded |`

6. Suggest (don't force) a first-milestone plan under `brain/plans/`.

## Report

App path, `git -C apps/<name> log --oneline` output, the registry row added.
````

- [ ] **Step 2: Verify frontmatter shape**

Run: `head -4 .claude/skills/new-app/SKILL.md`
Expected: `---` / `name: new-app` / `description: Use when creating...` / `---`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add .claude/skills/new-app/
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(skills): Add new-app scaffold skill

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 12: reflect skill

**Files:**
- Create: `.claude/skills/reflect/SKILL.md`

- [ ] **Step 1: Write `.claude/skills/reflect/SKILL.md`** with exactly:

````markdown
---
name: reflect
description: Use at the end of substantial work sessions, after completing an app milestone, or immediately after the user corrects a mistake — captures session learnings into the brain, skills, or structure.
---

# Reflect

Scan the session, keep what's durable, route it to the strongest encoding.
Low-quality or speculative content degrades everything downstream — when in
doubt, drop it.

## 1. Scan

Look through the session for:

- Mistakes and their corrections (especially user corrections)
- User preferences revealed (workflow, style, tooling)
- Workspace/app knowledge that isn't written anywhere yet
- Tool and harness quirks (gotchas that cost turns)
- Friction: repeated manual steps, missing templates, unclear conventions

## 2. Durability test

For each candidate ask: **"Would this matter in a different task?"**

- No, it's task-specific → drop it (or note it in the active plan).
- Already captured in brain/skills/CLAUDE.md → drop it.

## 3. Route — strongest encoding wins

1. **Structure** — can a hook, script, scaffold, or rule enforce it? Do
   that instead of writing advice. ([[principles/encode-lessons-in-structure]])
2. **Skill edit** — about how a specific skill should work? Edit that
   SKILL.md or its references.
3. **Brain note** — workspace/app knowledge: one topic per file in
   `brain/codebase/<kebab-slug>.md`, ~150–600 words shaped as
   problem → cause → pattern → evidence, wikilinking related principles.
   The index updates itself via hook.
4. **Todo** — follow-up work that can't be done now: in `brain/todos.md`,
   read `<!-- next-id: N -->`, append `N. [ ] ...` under the right section,
   increment the counter. IDs are permanent; never renumber.

**Memory split:** workspace/app knowledge → `brain/`. User preferences and
cross-project facts → Claude auto-memory. Never duplicate one fact into
both.

## 4. Report

Four lines: **Brain** (files written), **Skills** (files edited),
**Structural** (mechanisms added/changed), **Todos** (items filed).
"Nothing durable this session" is a valid outcome — say it and stop.
````

- [ ] **Step 2: Verify frontmatter shape**

Run: `head -4 .claude/skills/reflect/SKILL.md`
Expected: `---` / `name: reflect` / `description: Use at the end...` / `---`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add .claude/skills/reflect/
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(skills): Add reflect learning-capture skill

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 13: meditate skill

**Files:**
- Create: `.claude/skills/meditate/SKILL.md`

- [ ] **Step 1: Write `.claude/skills/meditate/SKILL.md`** with exactly:

````markdown
---
name: meditate
description: Use after several reflect cycles have accumulated, or on explicit user request — audits the brain vault with subagents, extracts principles from repeated lessons, refines skills, and archives finished work. Expensive; don't run casually.
---

# Meditate

A vault audit. Two subagents examine the vault from different angles; the
orchestrator judges and applies. [[principles/prove-it-works]] applies to
their proposals too — verify claims against the actual files before acting.

## 1. Snapshot

Build a cheap snapshot to paste into both agent prompts:

```sh
find brain -name '*.md' -type f | sort
wc -l brain/*.md brain/*/*.md brain/*/*/*.md 2>/dev/null | tail -25
```

Include the snapshot AND the current `brain/index.md` content.

## 2. Auditor (staleness pass)

Dispatch one general-purpose agent:

```
Audit the Sobaya brain vault at <absolute path>/brain.
Snapshot: <paste snapshot + index>.
Read every codebase note and principle, then propose, each with a reason:
- DELETE: stale, superseded, or speculative notes
- MERGE: two files covering one topic
- ORPHANS: files reachable from no index or note
- QUALITY: notes failing the bar "an agent would get this wrong without it"
Return a markdown list of: action | file | reason. Propose only — do NOT
edit anything.
```

## 3. Early-exit gate

Fewer than 3 actionable findings → report "vault is healthy" and stop.
Don't churn a clean vault.

## 4. Reviewer (pattern pass)

Dispatch a second general-purpose agent:

```
Read the Sobaya brain vault at <absolute path>/brain and the skills in
.claude/skills/.
1. Patterns: lessons appearing in 2+ notes that no principle captures →
   propose a principle (name, rule, why, evidence wikilinks). Candidates
   must be independent, evidenced by 2+ notes, and actionable.
2. Contradictions: skill instructions that conflict with brain principles
   or notes → cite both sides, propose the smaller fix.
3. Missing wikilinks between clearly related notes.
Propose only — do NOT edit anything.
```

## 5. Judge and apply

Review both reports against the actual files; reject weak proposals (false
positives are normal). Present the consolidated change list to the user,
then apply the approved ones: edit/delete/merge notes, add principles (and
update `brain/principles.md`), fix skills, add wikilinks.

## 6. Housekeep

- Move completed plan dirs to `brain/archive/plans/`; tick their entries in
  `brain/plans/index.md`.
- Move done todos to `brain/archive/completed_todos.md`.
- The index rebuilds itself via hook as you edit.

## Report

Counts: notes deleted/merged, principles added, skills fixed, plans
archived — plus what was rejected and why.
````

- [ ] **Step 2: Verify frontmatter shape**

Run: `head -4 .claude/skills/meditate/SKILL.md`
Expected: `---` / `name: meditate` / `description: Use after several...` / `---`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add .claude/skills/meditate/
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(skills): Add meditate vault-audit skill

Auditor + reviewer subagent pattern with early-exit gate, from noodle.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 14: new-app smoke test

**Files:**
- Create then delete: `apps/_smoke/` (never committed — `apps/*` is gitignored)
- Modify then revert: `brain/apps.md`

- [ ] **Step 1: Execute the new-app steps against a throwaway name**

Follow `.claude/skills/new-app/SKILL.md` steps 1–5 literally with name `_smoke`, purpose "smoke test", skipping the design gate (this is explicitly scaffold-only):

```bash
cd /Users/amazon/lunch.cancelled/sobaya
mkdir -p apps/_smoke
git -C apps/_smoke init -b main
printf '# _smoke\n\nSmoke test app.\n\nPart of the Sobaya workspace — workspace conventions live in the root CLAUDE.md.\n\n## App facts\n- Stack: shell\n- Run: true\n- Test: true\n' > apps/_smoke/CLAUDE.md
printf '# _smoke\n\n스모크 테스트용 임시 앱입니다.\n' > apps/_smoke/README.md
git -C apps/_smoke add -A
git -C apps/_smoke commit -m "chore: scaffold _smoke"
```

Then append the registry row to `brain/apps.md` table:

```
| _smoke | smoke test | shell | scaffolded |
```

- [ ] **Step 2: Verify the scaffold**

Run: `git -C apps/_smoke log --oneline && git -C /Users/amazon/lunch.cancelled/sobaya status --short`
Expected: one commit `chore: scaffold _smoke`; root repo shows ONLY `M brain/apps.md` (the app itself is invisible to the root repo — proves the gitignore boundary).

Run: `grep -c '_smoke' brain/apps.md`
Expected: `1`

- [ ] **Step 3: Tear down (leave no trace)**

```bash
rm -rf apps/_smoke
```

Remove the `| _smoke | ... |` row from `brain/apps.md` (restore the file to its seeded content), then:

Run: `git -C /Users/amazon/lunch.cancelled/sobaya status --short && ls apps/`
Expected: clean status (no modifications), `apps/` contains only `.gitkeep`.

- [ ] **Step 4: Record the result (no commit needed)**

Nothing to commit — the smoke test must leave the tree exactly as it found it. State PASS/FAIL with the observed outputs in the task report.
