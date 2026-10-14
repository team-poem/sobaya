---
name: reflect
description: Review outcomes and learning between features, after substantial work or a milestone, or after a user correction. Connect learning to the next decision and retain only durable knowledge.
---

# Reflect

Scan the session, keep what's durable, route it to the strongest encoding.
Root maintenance is role-neutral and follows the authorized task scope.
Do not use reflection to override human-owned product intent. Tests and
scenarios may evolve from learning within that intent.
Low-quality or speculative content degrades everything downstream — when in
doubt, drop it.

## 1. Scan

Look through the session for:

- Mistakes and their corrections (especially user corrections)
- User preferences revealed (workflow, style, tooling)
- Workspace/app knowledge that isn't written anywhere yet
- Tool and harness quirks (gotchas that cost turns)
- Friction: repeated manual steps, missing templates, unclear conventions
- Outcomes: what the user actually experienced, what only implementation
  checks established, and what still needs real feedback
- Decisions: which expectation changed and whether that alters the next
  scenario, a design choice, or the value of a small GREEN tidy

Apply the feature-boundary pause from `tdd-set/AGENTS.md` before selecting
more work. Prefer earlier feedback when cleanup would delay learning without
a concrete benefit. Reflection does not require a code change or new note.

## 2. Durability test

For each candidate ask: **"Would this matter in a different task?"**

- No, it's task-specific → drop it (or note it in the active plan).
- Already captured in brain/skills/AGENTS.md → drop it.

## 3. Route — strongest encoding wins

1. **Structure** — can a script, scaffold, or rule enforce it? Prefer
   that to advice when it is within the authorized scope. ([[principles/encode-lessons-in-structure]])
2. **Skill edit** — about how a specific skill should work? Edit that
   SKILL.md or its references.
3. **Brain note** — workspace/app knowledge: one topic per file in
   `brain/codebase/<kebab-slug>.md`, ~150–600 words shaped as
   problem → cause → pattern → evidence, wikilinking related principles.
   Rebuild the index with `bash scripts/brain-index.sh .`; do not assume
   a host hook ran.
4. **Todo** — follow-up work that can't be done now: in `brain/todos.md`,
   read `<!-- next-id: N -->`, append `N. [ ] ...` under the right section,
   increment the counter. IDs are permanent; never renumber.

**Memory split:** workspace/app knowledge → `brain/`. User preferences and
cross-project facts → the agent's own auto-memory. Never duplicate one fact into
both.

## 4. Report

Briefly state the useful learning, remaining uncertainty and next decision.
Mention Brain, Skills, Structural or Todos only when something was actually
changed there. Do not manufacture four categories of output or a new TODO.
"No new durable lesson" and "no useful refactor" are valid outcomes.
