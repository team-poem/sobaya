---
name: new-app
description: Use when creating a new project or app under apps/ in the Sobaya workspace — scaffolds the directory as its own git repo with an app-level AGENTS.md and registers it in brain/apps.md.
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

2. Write `apps/<name>/AGENTS.md`:

   ```markdown
   # <name>

   <One line: what this app is.>

   Part of the Sobaya workspace — workspace conventions (brain,
   orchestration, one-writer-per-app) live in the root AGENTS.md and apply
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
