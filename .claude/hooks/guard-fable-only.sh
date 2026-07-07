#!/bin/sh
# PreToolUse(Write|Edit|MultiEdit|NotebookEdit) hook: the root harness repo
# is maintained by Fable sessions only (CLAUDE.md "Harness guard"). Block
# file mutations inside the root repo when the session model is not Fable;
# apps/ and references/ are other repos and stay unrestricted.
#
# Deterministic POSIX shell, no LLM, no jq. Model is read from the session
# transcript (last assistant "model" field). Fail-open: anything ambiguous
# (no path, no transcript, no model line, path outside the project) exits 0
# so a broken environment never blocks work — the commit-msg gate in
# .githooks/ is the backstop.

LC_ALL=C
export LC_ALL

input=$(cat 2>/dev/null) || exit 0

json_str() { # usage: json_str <key> — first string value for key in $input
  printf '%s' "$input" \
    | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -n 1 \
    | sed "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"//; s/\"\$//"
}

fp=$(json_str file_path)
[ -n "$fp" ] || fp=$(json_str notebook_path)
[ -n "$fp" ] || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$ROOT" ] || exit 0

case "$fp" in
  "$ROOT"/*) ;;         # inside the workspace — guarded territory below
  *) exit 0 ;;          # outside the workspace — not ours to police
esac

case "$fp" in
  "$ROOT"/apps/* | "$ROOT"/references/*) exit 0 ;;  # independent repos
esac

tp=$(json_str transcript_path)
[ -n "$tp" ] && [ -f "$tp" ] || exit 0

model=$(grep -o '"model"[[:space:]]*:[[:space:]]*"claude[^"]*"' "$tp" 2>/dev/null \
  | tail -n 1 \
  | sed 's/.*"claude/claude/; s/"$//')
[ -n "$model" ] || exit 0

case "$model" in
  *fable*) exit 0 ;;
esac

cat >&2 <<EOF
sobaya harness guard: blocked — this session runs on "$model", but the root
harness repo (everything outside apps/ and references/) is maintained by
Claude Fable 5 sessions only. See CLAUDE.md "Harness guard".
Target: $fp
Work under apps/ is unrestricted. For harness changes, describe the change
to the user and let a Fable session apply it. Do not retry or work around
this block via Bash.
EOF
exit 2
