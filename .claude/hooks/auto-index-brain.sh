#!/bin/sh
# PostToolUse(Edit|Write) hook: rebuild brain/index.md when a brain file
# changes. Deterministic POSIX shell, no LLM, no jq. Fail-open: every anomaly
# exits 0 so a broken vault never breaks a session.
#
# Note: Claude Code hook matchers match TOOL NAMES, not paths (noodle wired
# this with matcher "brain/", which never fires). We match Edit|Write in
# settings.json and filter the file_path here instead.

LC_ALL=C
export LC_ALL

input=$(cat 2>/dev/null) || exit 0

case "$input" in
  *'"file_path"'*) ;;
  *) exit 0 ;;
esac

fp=$(printf '%s' "$input" \
  | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -n 1 \
  | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')

case "$fp" in
  */brain/*) ;;
  *) exit 0 ;;
esac

BRAIN_DIR="${CLAUDE_PROJECT_DIR:-.}/brain"
INDEX="$BRAIN_DIR/index.md"
[ -d "$BRAIN_DIR" ] || exit 0

# Vault entries: vault-relative, .md stripped. Excludes index.md itself and
# anything nested inside a plan directory (plans/index survives the filter —
# plan dirs are indexed via plans/index.md by convention).
disk=$(find "$BRAIN_DIR" -type f -name '*.md' ! -path "$INDEX" 2>/dev/null \
  | sed "s|^$BRAIN_DIR/||; s|\.md$||" \
  | grep -v '^plans/[^/]*/' \
  | grep -v '^archive/plans/[^/]*/' \
  | sort)

indexed=$(sed -n 's/.*\[\[\([^]]*\)\]\].*/\1/p' "$INDEX" 2>/dev/null | sort)

# Fast path: index already reflects disk — do not rewrite.
[ "$disk" = "$indexed" ] && exit 0

tmp=$(mktemp "$INDEX.tmp.XXXXXX" 2>/dev/null) || exit 0
trap 'rm -f "$tmp"' EXIT

emit() { # emit <Title> <grep -E pattern>
  m=$(printf '%s\n' "$disk" | grep -E "$2")
  [ -n "$m" ] || return 0
  printf '\n## %s\n' "$1"
  printf '%s\n' "$m" | sed 's/.*/- [[&]]/'
}

known='^vision$|^principles$|^principles/|^apps$|^codebase/|^todos$|^plans/index$|^archive/'

{
  printf '# Brain\n'
  emit "Vision"     '^vision$'
  emit "Principles" '^principles$|^principles/'
  emit "Apps"       '^apps$'
  emit "Codebase"   '^codebase/'
  emit "Backlog"    '^todos$'
  emit "Plans"      '^plans/index$'
  emit "Archive"    '^archive/'
  other=$(printf '%s\n' "$disk" | grep -Ev "$known")
  if [ -n "$other" ]; then
    printf '\n## Other\n'
    printf '%s\n' "$other" | sed 's/.*/- [[&]]/'
  fi
} > "$tmp" 2>/dev/null || exit 0

mv "$tmp" "$INDEX" 2>/dev/null
exit 0
