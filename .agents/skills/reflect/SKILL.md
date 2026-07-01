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
- Already captured in brain/skills/AGENTS.md → drop it.

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
cross-project facts → Codex auto-memory. Never duplicate one fact into
both.

## 4. Report

Four lines: **Brain** (files written), **Skills** (files edited),
**Structural** (mechanisms added/changed), **Todos** (items filed).
"Nothing durable this session" is a valid outcome — say it and stop.
