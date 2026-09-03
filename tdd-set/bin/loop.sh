#!/usr/bin/env bash
# Run the TDD loop until plan.md has no unchecked boxes, then run the gate.
# usage: bin/loop.sh [max_iterations]   (run from the app root containing plan.md + spec.md)
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

start=$(git rev-parse HEAD)
echo "$start" > .tdd-loop-start
stalls=0

for ((i = 1; i <= max; i++)); do
  grep -q '^- \[ \]' plan.md || break
  before=$(git rev-parse HEAD)
  echo "=== iteration $i ==="
  claude -p "go" "${flags[@]}" </dev/null || echo "claude exited non-zero"
  if ! git diff --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo "iteration $i left uncommitted changes; stashing (git stash list to inspect)"
    git stash push -u -m "tdd-loop iteration $i leftovers"
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
