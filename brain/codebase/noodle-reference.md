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
