---
id: 1
created: 2026-06-12
status: done
---

# Plan 01 — Sobaya Harness

## Summary

Build Sobaya: a Claude Code harness environment (not a framework) for subagent-heavy, multi-project work. Projects live in `apps/<name>` as independent git repositories; the workspace root provides persistent memory (`brain/`), four orchestration skills, two deterministic hooks, and a short harness contract (`CLAUDE.md`). Patterns are extracted from poteto/noodle and adapted to compose with the superpowers plugin.

## Motivation

The user wants a workspace where max-effort Opus 4.8 / Fable 5 sessions orchestrate complex work across multiple projects using subagents as the default mode. noodle (a Go agent-orchestration framework) demonstrates the strongest known set of working methods for this style — file-based state, skills as the only extension point, a self-improving brain vault, worktree isolation — but it is a standalone autonomous framework. Sobaya borrows its working methods without its runtime: Claude Code itself is the orchestrator, superpowers provides the dev lifecycle, and Sobaya adds only what neither provides.

## Source Analysis (noodle)

What noodle is: a Go event loop that schedules LLM "cook" sessions over file-based work orders (`orders.json`), each cook running a skill in an isolated git worktree, with a brain vault that the system reads before acting and rewrites as it learns. Three big ideas: (1) everything is a file, (2) skills are the only extension point, (3) LLM judgment / deterministic mechanics split.

What Sobaya takes:

- **Brain vault** — Obsidian-compatible markdown memory: `principles/` (distilled decision rules), `codebase/` (one-topic gotcha notes, 150–600 words), `plans/NN-slug/` (overview + phase files), `todos.md` (permanent numbered IDs), `archive/`, wikilink indexes with no inlined content.
- **Self-improvement loop** — reflect (route session learnings: structural encoding > skill update > brain note > todo) and meditate (subagent auditor + reviewer over the vault; extract principles evidenced by 2+ notes; refine skills; early-exit gate).
- **Deterministic hooks** — inject brain index at SessionStart; auto-rebuild the index after brain writes. POSIX shell, no LLM, fail-open.
- **Go-mechanics-as-conventions** — atomic writes, one-writer-per-target, worktree isolation for parallel mutation, persist-before-spawn, deliverable-as-files (stage_yield), diagnose-don't-retry, pre-flight context brief (mise), concurrency caps. See Conventions below.

What Sobaya does **not** take: the Go binary and event loop, autonomous scheduling (`schedule`/`execute` task types, cron cycles), the web UI, multi-harness `.agents/` indirection, NDJSON event sourcing, and ~21 of the 25 skills (superpowers already covers plan/TDD/debugging/review; others are noodle-CLI-specific).

## Design Decisions

**D1. Harness, not framework.** Sobaya is conventions + skills + hooks that make a Claude Code session orchestrate well. No daemon, no scheduler, no new runtime code beyond two shell hooks.
- *Alternative A — port noodle to a Claude-native autonomous loop (orders.json + /loop):* rejected; the user explicitly scoped this out. The structure leaves room to add it later (`/loop`, `/schedule` exist in the harness).
- *Alternative B — install noodle itself:* rejected; noodle owns the session lifecycle, which conflicts with interactive Claude Code + superpowers use.

**D2. Selective skill overlay (4 skills), superpowers owns the dev lifecycle.** Sobaya adds only `sobaya`, `new-app`, `reflect`, `meditate`.
- *Alternative — full 25-skill port:* rejected; `plan`/`debugging`/`testing`/`review` collide with superpowers triggers (double maintenance, ambiguous skill selection), and noodle-CLI skills (`worktree`, `todo`, `noodle`) assume a binary that doesn't exist here. Violates subtract-before-you-add.
- *Alternative — CLAUDE.md only, no skills:* rejected; the self-improvement loop would exist only as textual instruction, which is exactly what noodle's encode-lessons-in-structure principle says fails.

**D3. Root repo tracks the harness; apps are independent repos.** `apps/*` is gitignored; each app gets its own `git init`. Rationale: unrelated project histories must not mix; git worktrees are per-repo, so per-app repos make parallel-mutation isolation natural.
- *Alternative — one monorepo:* rejected; app worktrees and app-specific remotes become awkward, and harness history fills with app noise.

**D4. Unified plan/spec location: `brain/plans/NN-slug/`.** `overview.md` is the spec (this document is the first instance); `phase-*.md` files are the implementation plan. This is declared in CLAUDE.md as the user preference that overrides plugin default paths (superpowers explicitly honors such overrides).
- *Alternative — superpowers default `docs/superpowers/specs/` + separate plans:* rejected; two document systems for one lifecycle invites drift.

**D5. Two hooks, not three.** noodle's `block-sleep.sh` is omitted: the current Claude Code harness already blocks foreground `sleep` natively. Re-adding it would be a redundant mechanism (subtract-before-you-add). Also fixed during porting: noodle wires `auto-index-brain.sh` with hook matcher `"brain/"`, but Claude Code matchers match tool *names*, not paths — Sobaya uses matcher `Edit|Write` and filters `file_path` inside the script.

**D6. No `.agents/` indirection.** noodle symlinks `.claude/{skills,hooks} -> .agents/` to serve Claude and Codex from one source. Sobaya targets Claude Code only; skills and hooks live directly under `.claude/`. If a second harness arrives, migrate then (migrate-callers, then delete).

**D7. Language split.** Agent-consumed text (CLAUDE.md, skills, brain) in English; human-facing docs (README.md, docs/) in Korean. Declared in CLAUDE.md so future sessions preserve it.

**D8. Two memory systems, explicit routing.** Claude Code's auto-memory (`~/.claude/projects/...`) stores user preferences and cross-project facts; `brain/` stores workspace and app knowledge (in-repo, shareable). The reflect skill encodes this routing rule.

## Scope

In scope:
- Root git repo, `.gitignore`, directory skeleton (`apps/` kept via `.gitkeep`)
- `CLAUDE.md` harness contract (~30 lines, English)
- `brain/` seeded: `index.md`, `vision.md`, `principles.md` + 10 principle files, `codebase/noodle-reference.md`, `apps.md`, `todos.md`, `plans/index.md`, `archive/` skeleton
- 4 skills under `.claude/skills/`: `sobaya` (+ `references/dispatch-patterns.md`), `new-app`, `reflect`, `meditate`
- 2 hooks under `.claude/hooks/` + `.claude/settings.json` wiring
- `README.md` (Korean, banner-first format — see component spec) + `banner.svg` + `docs/guide.md` (Korean)
- `references/noodle/` — working clone of poteto/noodle kept in the workspace for reference while building and extending Sobaya (gitignored; user request)
- Verification of hooks (synthetic stdin tests, index golden check) and `new-app` (smoke test)

Out of scope (future candidates, tracked in todos):
- `ruminate` (past-conversation mining), `unslop`, cross-provider adversarial review (requires codex CLI), autonomous scheduling via `/loop`/`/schedule`, `.agents/` multi-harness layout, any first real app.

## Constraints

- **Superpowers compatibility:** Sobaya skills must not overlap superpowers triggers. `new-app` defers new-app design to superpowers:brainstorming; `sobaya` defers planning to writing-plans, debugging to systematic-debugging.
- **Model-agnostic max effort:** Conventions must work for Opus 4.8 and Fable 5; never reference tools or behaviors specific to one model tier.
- **Hooks are deterministic and fail-open:** POSIX shell only, no jq/python dependencies, any anomaly exits 0; a broken brain must never break a session.
- **Shared-file mutations are atomic:** index rebuild writes via `mktemp` + `mv`.
- **Honest seeding:** Do not fabricate brain notes for lessons not yet learned. `codebase/` starts with the single provenance note.

## Architecture

```
sobaya/                        # git repo (harness only)
├── CLAUDE.md                  # harness contract (EN)
├── README.md                  # guide (KO), banner-first format
├── banner.svg                 # README banner, authored in-repo
├── .gitignore                 # apps/* (with !apps/.gitkeep), references/, OS junk
├── .claude/
│   ├── settings.json          # hook wiring
│   ├── hooks/
│   │   ├── inject-brain.sh    # SessionStart(startup|resume)
│   │   └── auto-index-brain.sh# PostToolUse(Edit|Write), path-filtered
│   └── skills/
│       ├── sobaya/SKILL.md  (+ references/dispatch-patterns.md)
│       ├── new-app/SKILL.md
│       ├── reflect/SKILL.md
│       └── meditate/SKILL.md
├── brain/
│   ├── index.md               # auto-rebuilt; wikilinks only, no inlined content
│   ├── vision.md
│   ├── principles.md          # categorized wikilink index of principles
│   ├── principles/            # 10 seeded principle files
│   ├── codebase/noodle-reference.md
│   ├── apps.md                # app registry: one line per app
│   ├── todos.md               # numbered, permanent IDs, <!-- next-id -->
│   ├── plans/
│   │   ├── index.md           # checkbox list of plans (manual, by convention)
│   │   └── 01-sobaya-harness/ # this plan
│   └── archive/
│       ├── completed_todos.md
│       └── plans/             # completed plan dirs move here
├── apps/                      # independent git repos, gitignored from root
│   └── .gitkeep
├── tests/
│   └── hooks-test.sh          # POSIX test suite for the hooks
├── references/
│   └── noodle/                # poteto/noodle working clone for reference (gitignored)
└── docs/
    └── guide.md               # KO usage guide
```

## Component Specs

### CLAUDE.md (full draft)

```markdown
# Sobaya

Orchestration workspace for multi-project agent work. Projects live in
`apps/<name>` — each an independent git repository. This root repo tracks
only the harness: `CLAUDE.md`, `.claude/`, `brain/`, `docs/`.

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

## Skills

superpowers owns the dev lifecycle (brainstorming, writing-plans, TDD,
systematic-debugging, code review). Sobaya skills own the workspace:
`sobaya` (orchestration), `new-app` (scaffold), `reflect` (capture
learnings), `meditate` (vault audit + skill refinement).

## Language

Agent-facing text (this file, skills, brain) is English. Human-facing docs
(README.md, docs/) are Korean.
```

### Brain seeding

**`vision.md`** — one page: what Sobaya is (soba shop: the workspace is the kitchen, apps are dishes, the orchestrating session is the head cook), what good looks like (sessions that read the brain, dispatch well-briefed subagents, leave the vault smarter than they found it).

**`principles.md`** — wikilink index grouped: Core / Delegation / State / Verification / Meta.

**`principles/` — 10 files**, adapted from noodle (provenance recorded in `codebase/noodle-reference.md`, not per-file):

| File | Core rule (adapted) |
|---|---|
| `prove-it-works` | Verify outputs by checking the real thing — never proxies or subagent self-reports. |
| `fix-root-causes` | Never paper over symptoms; trace to the root cause and fix there. |
| `subtract-before-you-add` | Remove complexity first, then build. |
| `guard-the-context-window` | Every token entering the orchestrator context must earn its place; route bulk reads to subagents. |
| `cost-aware-delegation` | Every dispatch gets a budget and a hard-capped scope; a longer brief is cheaper than rediscovery turns. |
| `serialize-shared-state-mutations` | Concurrent mutation of shared state needs structural serialization (one writer per app, worktrees, sequential merges) — instructions alone are insufficient. |
| `make-operations-idempotent` | Scripts and conventions must converge to the correct state no matter how many times they run (hooks, scaffolds, index rebuilds). |
| `encode-lessons-in-structure` | Recurring fixes become mechanisms (hooks, rules, scaffolds), not repeated textual instructions. |
| `never-block-on-the-human` | During approved execution, make reasonable decisions and let the human course-correct afterward. Design-approval gates (brainstorming) are a different phase and still apply. |
| `foundational-thinking` | Structural decisions optimize for option value; code-level decisions optimize for simplicity. |

**`codebase/noodle-reference.md`** — provenance note: source repo URL, commit analyzed, what was borrowed (vault structure, reflect/meditate, hooks, conventions table), what was deliberately dropped, where to look when porting more. The working clone lives at `references/noodle/` (analyzed at commit `82d2921`).

**`apps.md`** — registry header + table (name | purpose | stack | status), empty body.

**`todos.md`** — noodle format: `priority` frontmatter, `<!-- next-id: 2 -->`, item 1 = this harness build linking `[[plans/01-sobaya-harness/overview]]`.

**`plans/index.md`** — `- [ ] [[plans/01-sobaya-harness/overview]]`.

**`archive/completed_todos.md`** — empty skeleton.

### Skills

All four follow superpowers:writing-skills conventions during implementation (frontmatter `name` + `description` with trigger phrasing; body under 500 lines; references/ for detail).

**`sobaya`** — *trigger: orchestrating work across apps, dispatching subagents for app work, starting substantial multi-step work in any app.*
1. **Pre-flight (mise):** read relevant brain index links → `apps.md` + target app git status → `todos.md` + active plan if one exists. Assemble a one-paragraph brief: what's active, what's in scope, capacity.
2. **Dispatch rules:** exploration → Explore agents (read-only, return conclusions not file dumps); implementation → general-purpose agents briefed with app path, task, constraints, expected report format (templates in `references/dispatch-patterns.md`); review → independent agent prompted to refute, not confirm.
3. **Pipeline discipline:** substantial work runs execute → review → reflect; declare each stage's deliverable up front; subagents write progress artifacts to files as they go so interrupted work survives.
4. **Concurrency:** one writer per app; parallel mutation → worktree isolation; merges sequential; cap concurrent agents; on failure, diagnose before re-dispatch.
5. **Persist-before-spawn:** for long work, ensure the plan/progress file exists in `brain/plans/` before dispatching, so a dropped session can be adopted by the next one.

**`new-app`** — *trigger: creating a new project under `apps/`.*
1. Validate kebab-case name; refuse if `apps/<name>` exists.
2. For a new product/feature design, invoke superpowers:brainstorming first (skill defers; scaffold-only if the user explicitly says so).
3. `mkdir apps/<name> && git init -b main`; write app-level `CLAUDE.md` (points to workspace conventions + app-specific facts) and minimal README.
4. Register one line in `brain/apps.md`; suggest a `brain/plans/` entry for the app's first milestone.

**`reflect`** — *trigger: end of substantial sessions, after completing a milestone, immediately after a user correction.*
1. Scan the session: mistakes/corrections, user preferences, gotchas, friction, repeated manual steps.
2. Durability test per finding: "would this matter in a different task?" — drop if no.
3. Route, in priority order: structural encoding (hook/rule/scaffold change) > skill update > brain note (`codebase/`, one topic per file) > todo. Workspace/app knowledge → `brain/`; user preferences and cross-project facts → Claude auto-memory.
4. Report: Brain / Skills / Structural / Todos summary. (Index updates itself via hook.)

**`meditate`** — *trigger: after several reflect cycles accumulate, or explicit user request.*
1. Snapshot the vault (file list + sizes + mtimes).
2. Spawn an **auditor** subagent: stale, redundant, orphaned (unlinked), low-value notes → proposals.
3. Early-exit gate: fewer than 3 findings → report and stop.
4. Spawn a **reviewer** subagent: patterns evidenced by 2+ notes → principle candidates; skills contradicting brain content → fix proposals.
5. Present consolidated report; apply approved changes; archive completed plans; prune todos.

### Hooks

**`.claude/settings.json`**

```json
{
  "hooks": {
    "SessionStart": [
      { "matcher": "startup|resume", "hooks": [
        { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/inject-brain.sh" } ] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write", "hooks": [
        { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/auto-index-brain.sh" } ] }
    ]
  }
}
```

**`inject-brain.sh`** — print header + `cat brain/index.md`; missing file → silent `exit 0`.

**`auto-index-brain.sh`** — read stdin JSON; extract `file_path` via grep/sed (no jq); exit 0 unless the path contains `/brain/`; `find` all vault `.md` files (excluding `index.md` and files nested inside plan dirs); compare against wikilinks currently in `index.md`; if identical, exit (fast path); else regenerate sections (Vision / Principles / Apps / Codebase / Backlog / Plans / Archive / Other catch-all) and write atomically via `mktemp` + `mv`. Every failure path exits 0.

### Conventions adopted from noodle's Go internals

| noodle mechanism | Sobaya form | Encoded in |
|---|---|---|
| `WriteFileAtomic` (tmp+rename) | atomic shared-file writes | hook script; `make-operations-idempotent` |
| busy-target tracking | one writer per app | CLAUDE.md; `sobaya` |
| worktree lifecycle + merge lock | worktree isolation for parallel mutation; sequential merges | CLAUDE.md; `sobaya`; `serialize-shared-state-mutations` |
| persist-before-spawn + session adoption | plan/progress files exist before long dispatches; next session adopts via `brain/plans` | `sobaya` |
| `stage_yield` (deliverable ≠ process exit) | subagents write incremental file artifacts | `sobaya` dispatch templates |
| scheduler-driven recovery (no auto-retry) | diagnose-then-decide on failure | CLAUDE.md; `sobaya` |
| mise brief | pre-flight checklist | `sobaya` step 1 |
| concurrency caps + backpressure | cap concurrent agents; no repeat dispatch of failing work | `sobaya`; `cost-aware-delegation` |

### README.md (Korean)

Format follows the user's reference, [coctostan/pi-superpowers-plus](https://github.com/coctostan/pi-superpowers-plus): H1 title, full-width banner image immediately below it (`![Sobaya banner](banner.svg)` — root-relative path, SVG authored in-repo so there is no external image dependency), one-line pitch, then flowing sections in this order:

1. **무엇이 들어있나** — skills 4종, hooks 2종, brain vault, apps 구조 (bullet list)
2. **시작하기** — 세션을 열면 일어나는 일(brain 인덱스 주입), 새 앱 만들기(new-app), 일상 워크플로
3. **워크플로** — ASCII pipeline diagram (execute → review → reflect; meditate 루프) + supporting table, reference style
4. **구조** — directory tree (fenced block)
5. **noodle과 superpowers의 관계** — attribution: what came from noodle (commit `82d2921`), what superpowers owns

Tables and fenced code blocks styled per the reference. Banner motif: soba shop (bowl/noodles/lantern), dark-friendly palette, "Sobaya" wordmark.

## Verification

- **Hooks, unit:** run each script with synthetic stdin payloads — brain path (rebuild expected), non-brain path (no-op), malformed JSON (exit 0), missing brain dir (exit 0). Assert index content matches a golden expectation for the seeded vault; assert idempotence (second run = fast-path no-op).
- **Hooks, e2e:** confirmed at next session start (index injection visible); documented in README.
- **Skills:** frontmatter validity + trigger phrasing reviewed under superpowers:writing-skills; skills appear in the session skill list after reload.
- **new-app smoke test:** create `apps/_smoke`, assert git repo + CLAUDE.md + registry line, then delete and de-register.
- **Index discipline:** `index.md` wikilinks exactly match on-disk files after seeding (the hook's own comparison logic doubles as the check).

## Error Handling

- Hooks fail open: any missing file, unparseable input, or write failure exits 0 — a broken vault never breaks a session.
- Index rebuild writes atomically; a crash mid-write leaves the old index intact.
- `new-app` refuses existing directories and never touches existing apps.
- `meditate` early-exits below the findings threshold to avoid churning the vault.
- Failed subagent dispatches are never blindly retried (diagnose-then-decide).

## Phases

Implementation plan, one file per phase (tasks use checkbox tracking; execute in order):

- [[plans/01-sobaya-harness/phase-1-skeleton-and-hooks]] — skeleton dirs, inject-brain + auto-index-brain hooks (TDD, POSIX test suite), settings wiring
- [[plans/01-sobaya-harness/phase-2-brain-seeding]] — vision, 10 principles, provenance/registry/todos/plan-index, golden-verified index generation
- [[plans/01-sobaya-harness/phase-3-skills]] — sobaya (+dispatch patterns), new-app, reflect, meditate; new-app smoke test
- [[plans/01-sobaya-harness/phase-4-identity-and-docs]] — CLAUDE.md, banner.svg, Korean README/guide, final sweep + plan close-out

## Future Work (tracked in todos after build)

ruminate skill; unslop skill; cross-provider adversarial review when a second provider CLI is present; optional autonomous cycles via `/loop` or `/schedule`; `.agents/` indirection if a second harness is adopted.
