# Claude Config Load Timing

`.claude/` config added mid-session activates at a session refresh point,
not at file creation. Observed during the plan 01 build (one session):

- `settings.json` + hooks landed mid-session → brain writes by subagents
  did NOT trigger the auto-index hook (index was verifiably absent until
  generated manually).
- Later in the same session — after an interrupt/resume refresh that also
  surfaced the new skills in the live skill list — the PostToolUse hook
  DID fire on main-session Writes and rebuilt the index automatically.

**Pattern:**
- Never assume a just-created hook is active; test the script directly
  with a synthetic payload:
  `printf '{"tool_input":{"file_path":"..."}}' | CLAUDE_PROJECT_DIR="$PWD" sh .claude/hooks/<hook>.sh`
- Treat SessionStart behavior as verified only after a fresh session start.
- Subagent tool calls were not observed triggering project hooks; do not
  rely on hooks to run during dispatched work.

**Evidence:** plan 01 — index absent after Tasks 5–8 (reviewer-confirmed),
manual generation in Tasks 9/19, automatic rebuild firing on reflect-note
Writes at session end.
