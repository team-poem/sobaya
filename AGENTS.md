# Sobaya

Orchestration workspace for multi-project agent work. Projects live in
`apps/<name>` — each an independent git repository. This root repo tracks
only the harness: `AGENTS.md`/`CLAUDE.md` (mirrors), `.codex/`, `.claude/`,
`.agents/` (shared skills), `brain/`, `docs/`, `tests/`, the READMEs.

## Brain

`brain/` is an Obsidian-compatible vault — persistent memory across sessions.
A hook injects its index at session start.

- **Read first.** Read brain files relevant to your task before acting.
- **Write** after mistakes, corrections, or notable learnings — use Skill(reflect).
- **Structure:** One topic per file. `brain/index.md` is rebuilt by a hook —
  never hand-edit it. Plan dirs maintain `brain/plans/index.md` by convention.
- **Maintain:** Delete outdated notes. Move completed plans to `brain/archive/plans/`.

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
- **Plans and specs live in `brain/plans/NN-slug/`** (overview.md = spec,
  phase-*.md = plan). This is the user's preferred location and overrides
  plugin defaults.
- **Enforced:** flat-root nesting, project markers outside `apps/`,
  `brain/index.md` hand-edits, and the app scaffold gate (own git repo +
  `Implementer:` model policy in the app CLAUDE.md before real work in an
  unregistered app) are blocked deterministically by a PreToolUse hook
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

superpowers owns the dev lifecycle (brainstorming, writing-plans, TDD,
systematic-debugging, code review). Sobaya skills own the workspace:
`sobaya` (orchestration), `new-app` (scaffold), `reflect` (capture
learnings), `meditate` (vault audit + skill refinement).

## Language

Agent-facing text (this file, skills, brain) is English. README.md is
English (main) with a Korean mirror at README.ko.md — keep both in sync
when either changes. Other human-facing docs (docs/) are Korean.
