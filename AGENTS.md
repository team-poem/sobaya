# Sobaya

Failing-test-first agentic engineering workspace: the human writes the spec
and every failing test, the loop turns them green one at a time, the gate
refuses anything that touched the tests. Projects live in
`apps/<name>` — each an independent git repository. This root repo tracks
only the harness: `AGENTS.md` (`CLAUDE.md` just points here), `.agents/skills/`
(`.claude/skills` is a link to it), `.claude/hooks/` (`.claude/settings.json` and
`.codex/hooks.json` wire the same scripts), `brain/`, `docs/`, `tests/`, the READMEs.

## Brain

`brain/` is an Obsidian-compatible vault — persistent memory across sessions.
A hook injects its index at session start.

- **Read first.** Read brain files relevant to your task before acting.
- **Write** after mistakes, corrections, or notable learnings — use Skill(reflect).
- **Structure:** One topic per file. `brain/index.md` is rebuilt by a hook —
  never hand-edit it. Plan dirs maintain `brain/plans/index.md` by convention.
- **Maintain:** Delete outdated notes. Move completed plans to `brain/archive/plans/`.
- **Per-clone:** `brain/apps.md` is gitignored (each checkout grows its own
  `apps/`); create it from `brain/apps.template.md`. App design docs never go
  in `brain/` — they live in the app repo.

## Workflow

- **Apps:** Never create projects outside `apps/`. Each app is its own git
  repo; cross-app changes are separate commits per app.
- **Flat root:** `apps/<name>` IS the project root — sources, manifest, and
  the app's `.git` sit directly in it. Never nest the real project a level
  down (`apps/<name>/app/`) or put another workspace inside
  (`apps/<name>/apps/`).
- **Subagent-first:** For multi-file or exploratory work, dispatch subagents
  (Explore to read, general-purpose to change) — keep this context clean.
  See Skill(sobaya) for dispatch patterns.
- **One writer per app:** Never run two mutating agents against the same
  checkout. Parallel mutation requires worktree isolation.
- **No blind retries:** When delegated work fails, read its output and
  diagnose before re-dispatching.
- **Spec and plan live in the app root** as `spec.md` (human-written goal,
  never edited by agents) and `plan.md` (failing tests: checkbox + code block each) — the loop
  and gate read them there. `brain/plans/NN-slug/` holds only cross-app or
  harness plans.
- **Enforced:** flat-root nesting, project markers outside `apps/`,
  `brain/index.md` hand-edits, and the app gate (own git repo + a `- Test:`
  line in the app AGENTS.md, i.e. `tdd-set/bin/install.sh` was run, before
  real work in an unregistered app) are blocked deterministically by a PreToolUse hook
  (`.claude/hooks/guard-workspace-rules.sh`).

## Harness guard

The root repo — everything outside `apps/` and `references/` — is
maintained by Claude Fable 5 sessions only. If you are any other model or
agent: read freely, but do not create, edit, or delete root-repo files
(including `brain/`), and do not commit here. Propose harness changes to
the user instead; work under `apps/` is unrestricted. Enforced by a
PreToolUse hook (`.claude/hooks/guard-fable-only.sh`) and a commit gate
(`.githooks/commit-msg`, wired via `git config core.hooksPath .githooks`).

## Skills

`tdd-set/` owns the dev lifecycle — no external plugins. `tdd-set/AGENTS.md`
(the TDD + Tidy First rules, appended into every app's `AGENTS.md`) runs the
Red → Green → Refactor cycle; the `tdd` skill
adds Phase 0 (split the feature, enumerate as many test cases as possible,
probe each one red with `tdd-set/bin/probe.sh`, record it in `plan.md` as
code) and loop guards; `gopher` is the Go refactor checklist;
`tdd-set/bin/loop.sh` repeats `claude -p "go"` until `plan.md` is fully
checked, then `tdd-set/bin/gate.sh` passes only when every entry is
checked, suite green, no existing test modified, each checked entry's test
present in the suite. The human-written tests are the spec.
Everything runs from this root with the app named — `/sobaya-plan <name>`,
`/go <name>`, `/gate <name>`, `/sobaya-loop <name>` — because a session opened
inside an app inherits only CLAUDE.md, not skills, commands, or hooks. An app
carries three files: `AGENTS.md` (its command lines and a `Skills:` line naming
the stack skills it uses, e.g. `gopher`), `spec.md`, `plan.md`.
`tdd-set/bin/install.sh apps/<name>` creates them; there is no scaffold step. Sobaya skills own the workspace:
`sobaya` (orchestration), `reflect` (capture learnings), `meditate` (vault
audit + skill refinement).

## Language

Agent-facing text (this file, skills, brain) is English. One copy of everything:
Claude reads it through `CLAUDE.md` → `AGENTS.md` and `.claude/skills` → `.agents/skills`;
Codex reads `AGENTS.md` and `.agents/skills` directly. README.md is
English (main) with a Korean mirror at README.ko.md — keep both in sync
when either changes. Other human-facing docs (docs/) are Korean.
