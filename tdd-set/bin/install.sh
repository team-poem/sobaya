#!/usr/bin/env bash
# Prepare an app for the loop. Everything else (skills, commands, hooks, the TDD rules) lives in
# the sobaya root and is used from there. Idempotent: creates only what is missing.
# usage: tdd-set/bin/install.sh apps/<name>        (run from the sobaya root)
set -eu
app=${1:?usage: install.sh apps/<name>}; app=${app%/}
here=$(cd "$(dirname "$0")/.." && pwd)
name=$(basename "$app")

mkdir -p "$app"
[ -d "$app/.git" ] || git -C "$app" init -q -b main

if [ ! -f "$app/AGENTS.md" ]; then
  if [ -f "$app/package.json" ]; then
    lines='- Test: `npm test`
- Lint: `npm run lint`
- Skills: nodejs'
    grep -q '"prettier"' "$app/package.json" && lines="$lines
- Format: \`npx prettier --check .\`"
  else
    lines='- Test: `go test ./...`
- Format: `gofmt -l .`
- Lint: `go vet ./...`
- Bench: `go test -bench=. -benchmem ./...`
- Skills: gopher'
  fi
  cat > "$app/AGENTS.md" <<AGENTS
# $name

<One line: what this app is.>

## App facts
- Run: \`<command>\`
$lines

The workspace harness and the TDD rules live in the sobaya root: \`../../AGENTS.md\` and
\`../../tdd-set/AGENTS.md\`. Work on this app from the sobaya root (\`/go $name\`).
AGENTS
fi
if [ ! -f "$app/CLAUDE.md" ]; then printf 'Read and follow `AGENTS.md`.\n' > "$app/CLAUDE.md"
elif ! grep -q 'AGENTS.md' "$app/CLAUDE.md"; then printf '\nRead and follow `AGENTS.md` as well.\n' >> "$app/CLAUDE.md"; fi
[ -f "$app/spec.md" ] || cp "$here/spec-template.md" "$app/spec.md"
[ -f "$app/plan.md" ] || cp "$here/plan-template.md" "$app/plan.md"

echo "$app ready: AGENTS.md (command lines + Skills), spec.md, plan.md"
echo "next: fill $app/AGENTS.md lines and spec.md, add a row to brain/apps.md, then /sobaya-plan $name"
