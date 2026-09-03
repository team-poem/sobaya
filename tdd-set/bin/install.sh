#!/usr/bin/env bash
# Install tdd-set into an app, new or existing. Idempotent: creates only what is missing,
# never rewrites an existing file. This is step 0 of the loop; there is no separate scaffold.
# usage: tdd-set/bin/install.sh apps/<name>        (run from the sobaya root)
set -eu
app=${1:?usage: install.sh <app-dir>}
here=$(cd "$(dirname "$0")/.." && pwd)        # tdd-set/
name=$(basename "$app")

mkdir -p "$app"
[ -d "$app/.git" ] || git -C "$app" init -q -b main

if [ ! -f "$app/CLAUDE.md" ]; then
  cat > "$app/CLAUDE.md" <<EOF
# $name

<One line: what this app is.>

## App facts
- Stack: <fill>
- Run: \`<command>\`
- Test: \`go test ./...\`
- Format: \`gofmt -l .\`
- Lint: \`go vet ./...\`
- Bench: \`go test -bench=. -benchmem ./...\`
EOF
fi
# Kent Beck's rules, appended once (verbatim file; "Tidy First" is its marker)
grep -q 'Tidy First' "$app/CLAUDE.md" || { printf '\n'; cat "$here/CLAUDE.md"; } >> "$app/CLAUDE.md"

[ -f "$app/spec.md" ] || cp "$here/spec-template.md" "$app/spec.md"
[ -f "$app/plan.md" ] || cp "$here/plan-template.md" "$app/plan.md"

mkdir -p "$app/.claude/skills" "$app/.claude/commands"
cp -R "$here/skills/tdd" "$here/skills/gopher" "$app/.claude/skills/"
cp "$here/commands/"*.md "$app/.claude/commands/"

python3 - "$app/.claude/settings.json" <<'PY'
import json, os, sys
p = sys.argv[1]
cmd = "$CLAUDE_PROJECT_DIR/../../tdd-set/hooks/commit-gate.sh"
s = json.load(open(p)) if os.path.exists(p) else {}
pre = s.setdefault("hooks", {}).setdefault("PreToolUse", [])
if not any(h.get("command") == cmd for e in pre for h in e.get("hooks", [])):
    pre.append({"matcher": "Bash", "hooks": [{"type": "command", "command": cmd}]})
with open(p, "w") as f:
    json.dump(s, f, indent=2); f.write("\n")
PY

echo "tdd-set installed in $app"
grep -qE '^- Test: `[^<]' "$app/CLAUDE.md" || echo "next: fill the Test/Format/Lint/Bench lines in $app/CLAUDE.md"
echo "next: add a row for $name to brain/apps.md, fill spec.md, then /sobaya-plan"
