#!/bin/sh
# PreToolUse(Write|Edit|MultiEdit|NotebookEdit) hook: deterministic gates for
# the CLAUDE.md "Brain"/"Workflow" rules that a doc alone cannot guarantee:
#   1. brain/index.md is hook-generated — block hand edits.
#   2. Flat root: block NEW project markers nested in apps/<name>/app{,s}/.
#   3. Block NEW project markers outside apps/ and references/.
#   4. App scaffold gate: real work in an app not registered in brain/apps.md
#      requires the app's own git repo and a CLAUDE.md "Implementer:" model
#      policy (Skill(new-app) produces both).
# Registered apps are grandfathered; only marker CREATION is policed (2, 3),
# so pre-rule nesting (bdad-mentor-match, office-automation-hub-design) and
# Next.js app/ route files stay untouched.
#
# Deterministic POSIX shell, no LLM, no jq. Fail-open: anything ambiguous
# (no path, no project dir, path outside the project) exits 0 so a broken
# environment never blocks work.

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
  "$ROOT"/*) ;;         # inside the workspace — policed territory below
  *) exit 0 ;;          # outside the workspace — not ours to police
esac

block() { # usage: block <reason> <guidance>
  {
    echo "sobaya workspace guard: blocked — $1"
    echo "Target: $fp"
    echo "$2"
    echo "Do not retry or work around this block via Bash."
  } >&2
  exit 2
}

base=${fp##*/}
is_marker=0
case "$base" in
  package.json|pyproject.toml|Cargo.toml|go.mod|deno.json|composer.json)
    is_marker=1 ;;
esac

# Rule 1 — brain/index.md is machine-owned.
[ "$fp" = "$ROOT/brain/index.md" ] && block \
  "brain/index.md is rebuilt by a hook (auto-index-brain.sh); never hand-edit it (CLAUDE.md 'Brain')." \
  "Edit the individual brain notes instead — the index regenerates on write."

case "$fp" in
  "$ROOT"/references/*) exit 0 ;;   # independent repos, unrestricted
  "$ROOT"/apps/*) ;;                # app territory — rules 2 and 4 below
  *)
    # Rule 3 — root harness territory: no new project markers.
    if [ "$is_marker" = 1 ] && [ ! -e "$fp" ]; then
      block "projects live only under apps/<name> (CLAUDE.md 'Workflow: Apps')." \
        "Use Skill(new-app) to scaffold an app instead of creating $base here."
    fi
    exit 0
    ;;
esac

rel=${fp#"$ROOT"/apps/}
name=${rel%%/*}
{ [ -n "$name" ] && [ "$name" != "$rel" ]; } || exit 0  # write to apps/ itself
inapp=${rel#*/}
appdir="$ROOT/apps/$name"

# Rule 2 — flat root: no NEW project marker inside a nested app/ or apps/.
if [ "$is_marker" = 1 ] && [ ! -e "$fp" ]; then
  case "$inapp" in
    app/*|apps/*)
      block "flat root — apps/<name> IS the project root; never nest a project or workspace inside it (CLAUDE.md 'Workflow: Flat root')." \
        "Existing nested repos are grandfathered; new nesting is not. Put sources directly in apps/$name or scaffold a sibling app."
      ;;
  esac
fi

# Rule 4 — scaffold gate. Registered apps are grandfathered.
grep -qF "| $name " "$ROOT/brain/apps.md" 2>/dev/null && exit 0

# Scaffold files may always be written — they are how an app becomes compliant.
case "$inapp" in
  CLAUDE.md|README*|.gitignore|LICENSE*) exit 0 ;;
esac

[ -e "$appdir/.git" ] || block \
  "apps/$name is not a git repository — every app is its own repo (CLAUDE.md 'Workflow: Apps')." \
  "Scaffold first via Skill(new-app): git init, CLAUDE.md with an 'Implementer:' model policy, then register in brain/apps.md."

grep -qi 'implementer[[:space:]]*:' "$appdir/CLAUDE.md" 2>/dev/null || block \
  "apps/$name declares no model policy — the implementer model is chosen at app creation (CLAUDE.md 'Workflow')." \
  "Add an 'Implementer: <model>' line (under '## Orchestration') to apps/$name/CLAUDE.md, then register the app in brain/apps.md."

exit 0
