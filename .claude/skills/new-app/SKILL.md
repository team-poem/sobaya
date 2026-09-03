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
3. **Flat root:** `apps/<name>` IS the project root. Sources, manifest, and
   `.git` go directly in it — never a nested wrapper (`apps/<name>/app/`)
   and never another workspace clone (`apps/<name>/apps/`). When importing
   an existing project, flatten it into `apps/<name>` at import time.
4. **Spec gate:** scaffolding installs an empty `spec.md`; no implementation
   starts until the user has filled it. Do not draft `spec.md` for the user.
5. **Model policy:** ask the user which model implements this app (who
   writes the code — e.g. `sonnet`; the orchestrator stays the session
   model). The choice is fixed at creation and recorded in the app
   CLAUDE.md. The workspace guard hook blocks real work in an unregistered
   app until an `Implementer:` line exists there.

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
   - Test: `<command>`     (the gate runs this)
   - Format: `<command>`   (commit hook: must print nothing, e.g. gofmt -l .)
   - Lint: `<command>`     (commit hook: must exit 0, e.g. go vet ./...)
   - Bench: `<command>`    (gate prints it; gopher compares before/after on hot paths, e.g. go test -bench=. -benchmem ./...)

   ## Orchestration
   - Implementer: <model that writes the code, e.g. sonnet>
   ```

   Angle fields are filled at design time; none may survive past the app's
   first implementation commit.

3. Install tdd-set into the app:

   ```sh
   cat tdd-set/CLAUDE.md >> apps/<name>/CLAUDE.md
   cp tdd-set/spec-template.md apps/<name>/spec.md
   cp tdd-set/plan-template.md apps/<name>/plan.md
   mkdir -p apps/<name>/.claude/skills
   cp -r tdd-set/skills/tdd tdd-set/skills/gopher apps/<name>/.claude/skills/
   cp -r tdd-set/commands apps/<name>/.claude/commands
   ```

   Add the commit gate hook to `apps/<name>/.claude/settings.json` (snippet in
   `tdd-set/README.md`); it runs the Format/Lint lines above before every commit.

4. Write `apps/<name>/README.md` — Korean, one paragraph: 이 앱이 무엇을
   하는지, 어떤 스택인지.

5. First commit inside the app:

   ```sh
   git -C apps/<name> add -A
   git -C apps/<name> commit -m "chore: scaffold <name>"
   ```

6. Register the app — append one row to the table in `brain/apps.md`:
   `| <name> | <purpose> | <stack or –> | scaffolded |`

7. Suggest (don't force) filling `spec.md`, then the `tdd` skill's Phase 0
   to write `plan.md`.

## Report

App path, `git -C apps/<name> log --oneline` output, the registry row added.
