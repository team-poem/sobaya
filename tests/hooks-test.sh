#!/bin/sh
# Unit tests for Sobaya hooks. Run: sh tests/hooks-test.sh
# Plain POSIX, no framework. Exits 1 on any failure.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
fail=0

check() { # usage: check <0-for-pass> <name>
  if [ "$1" -eq 0 ]; then
    echo "ok   - $2"
  else
    echo "FAIL - $2"
    fail=1
  fi
}

INJECT="$ROOT/.claude/hooks/inject-brain.sh"

# --- inject-brain: with an index present, prints header + index body ---
proj="$TMP/p1"
mkdir -p "$proj/brain"
printf '# Brain\n\n## Backlog\n- [[todos]]\n' > "$proj/brain/index.md"
out=$(CLAUDE_PROJECT_DIR="$proj" sh "$INJECT" 2>/dev/null)
rc=$?
check "$rc" "inject: exits 0 with index present"
case "$out" in
  *"Brain vault index"*"[[todos]]"*) check 0 "inject: prints header and index body" ;;
  *) check 1 "inject: prints header and index body" ;;
esac

# --- inject-brain: missing brain dir is silent and exit 0 ---
proj="$TMP/p2"
mkdir -p "$proj"
out=$(CLAUDE_PROJECT_DIR="$proj" sh "$INJECT" 2>/dev/null)
rc=$?
check "$rc" "inject: exits 0 with no brain"
[ -z "$out" ]; check $? "inject: silent with no brain"

echo
if [ "$fail" -eq 0 ]; then
  echo "ALL PASS"
else
  echo "FAILURES PRESENT"
  exit 1
fi
