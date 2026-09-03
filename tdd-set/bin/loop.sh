#!/usr/bin/env bash
# Run one app's TDD loop from the sobaya root until its plan.md has no unchecked boxes, then gate.
# usage: tdd-set/bin/loop.sh apps/<name> [max_iterations]
#
# The loop only ever runs "/go <name>". It never plans. Whether the human reviewed plan.md is
# not verified; the human is trusted. It halts if an iteration adds entries (defect flow),
# because nobody inside the loop can be asked; the human looks and re-runs.
set -u
app=${1:?usage: loop.sh apps/<name> [max_iterations]}; max=${2:-50}
app=${app%/}; name=$(basename "$app")
here=$(cd "$(dirname "$0")" && pwd)
g() { git -C "$app" "$@"; }

# ponytail: allowlist only what one cycle needs, scoped to this app; CLAUDE_FLAGS overrides wholesale
if [ -n "${CLAUDE_FLAGS:-}" ]; then
  read -r -a flags <<<"$CLAUDE_FLAGS"
else
  abs=$(cd "$app" && pwd)   # the agent sometimes writes absolute paths; allow both forms
  flags=(--permission-mode acceptEdits --allowedTools "Bash(gofmt:*)" "Bash(tdd-set/bin/probe.sh:*)")
  for a in "$app" "$abs"; do
    flags+=("Bash(go -C $a:*)" "Bash(cd $a && npm:*)" "Bash(cd $a && npx:*)" "Bash(cd $a && node:*)")
    for sub in add commit diff status log show; do flags+=("Bash(git -C $a $sub:*)"); done
  done
fi

[ -f "$app/plan.md" ] || { echo "no $app/plan.md"; exit 1; }
[ -f "$app/spec.md" ] || { echo "no $app/spec.md"; exit 1; }
[ -d "$app/.git" ] || { echo "$app is not a git repository"; exit 1; }
g diff --quiet || { echo "$app working tree dirty; commit first"; exit 1; }
grep -qE '<name>|<feature>|^\.\.\.$' "$app/plan.md" && { echo "plan.md still has template placeholders; Phase 0 is not finished"; exit 1; }
grep -qE '<what must be true|<requirement 1>' "$app/spec.md" && { echo "spec.md is still the template; the human fills it first"; exit 1; }

entries() { grep -cE '^- \[[ x]\] ' "$app/plan.md"; }
start=$(g rev-parse HEAD)
echo "$start" > "$app/.git/sobaya-loop-start"
stalls=0

for ((i = 1; i <= max; i++)); do
  grep -q '^- \[ \]' "$app/plan.md" || break
  before=$(g rev-parse HEAD); n_before=$(entries)
  echo "=== $name iteration $i ==="
  claude -p "/go $name" "${flags[@]}" </dev/null || echo "claude exited non-zero"
  if ! g diff --quiet || [ -n "$(g ls-files --others --exclude-standard)" ]; then
    echo "iteration $i left uncommitted changes; stashing (git -C $app stash list to inspect)"
    g stash push -u -m "sobaya-loop iteration $i leftovers"
  fi
  if [ "$(entries)" -gt "$n_before" ]; then
    echo "iteration $i added entries to plan.md (defect flow); halting — look at them, then re-run the loop"
    break
  fi
  if [ "$(g rev-parse HEAD)" = "$before" ]; then
    stalls=$((stalls + 1))
    echo "no commit this iteration (stall $stalls/3)"
    [ $stalls -ge 3 ] && { echo "stalled 3 times; stopping"; break; }
  else
    stalls=0
  fi
done

exec "$here/gate.sh" "$app" "$start"
