#!/bin/sh
# SessionStart hook: surface the brain index so every session starts with the
# knowledge map. Fail-open: a missing vault produces no output and exit 0.

BRAIN_INDEX="${CLAUDE_PROJECT_DIR:-.}/brain/index.md"

if [ -f "$BRAIN_INDEX" ] && [ -r "$BRAIN_INDEX" ]; then
  echo "Brain vault index — read the relevant files before acting:"
  echo
  cat "$BRAIN_INDEX"
fi

exit 0
