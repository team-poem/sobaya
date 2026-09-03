#!/usr/bin/env bash
# Run the TDD loop until plan.md has no unchecked boxes, then run the gate.
# usage: bin/loop.sh [max_iterations]   (run from the app root containing plan.md + spec.md)
#
# The loop only ever runs "go". It never plans. Whether the human reviewed plan.md is not
# verified — the human is trusted. It halts if an iteration adds entries (defect flow), because
# nobody inside the loop can be asked; the human looks and re-runs.
set -u
max=${1:-50}
here=$(cd "$(dirname "$0")" && pwd)

# ponytail: allowlist only what the tdd skill needs; set CLAUDE_FLAGS to override wholesale
if [ -n "${CLAUDE_FLAGS:-}" ]; then
  read -r -a flags <<<"$CLAUDE_FLAGS"
else
  flags=(--permission-mode acceptEdits --allowedTools
    'Bash(go test:*)' 'Bash(go vet:*)' 'Bash(gofmt:*)'
    'Bash(git add:*)' 'Bash(git commit:*)' 'Bash(git diff:*)' 'Bash(git status:*)' 'Bash(git log:*)'
    'Bash(../../tdd-set/bin/probe.sh:*)' 'Bash(tdd-set/bin/probe.sh:*)')
fi

[ -f plan.md ] || { echo "no plan.md"; exit 1; }
[ -f spec.md ] || { echo "no spec.md"; exit 1; }
git diff --quiet || { echo "working tree dirty; commit first"; exit 1; }
grep -qE '<name>|<feature>|^\.\.\.$' plan.md && { echo "plan.md still has template placeholders; Phase 0 is not finished"; exit 1; }
grep -qE '<what must be true|<requirement 1>' spec.md && { echo "spec.md is still the template; the human fills it first"; exit 1; }

entries() { grep -cE '^- \[[ x]\] ' plan.md; }

start=$(git rev-parse HEAD)
echo "$start" > .git/sobaya-loop-start   # inside .git so it is never an untracked file
stalls=0

for ((i = 1; i <= max; i++)); do
  grep -q '^- \[ \]' plan.md || break
  before=$(git rev-parse HEAD); n_before=$(entries)
  echo "=== iteration $i ==="
  claude -p "go" "${flags[@]}" </dev/null || echo "claude exited non-zero"
  if ! git diff --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo "iteration $i left uncommitted changes; stashing (git stash list to inspect)"
    git stash push -u -m "tdd-loop iteration $i leftovers"
  fi
  if [ "$(entries)" -gt "$n_before" ]; then
    echo "iteration $i added entries to plan.md (defect flow); halting — look at them, then re-run the loop"
    break
  fi
  if [ "$(git rev-parse HEAD)" = "$before" ]; then
    stalls=$((stalls + 1))
    echo "no commit this iteration (stall $stalls/3)"
    [ $stalls -ge 3 ] && { echo "stalled 3 times; stopping"; break; }
  else
    stalls=0
  fi
done

exec "$here/gate.sh" "$start"
