#!/bin/bash
# Idempotent app registration and a real Git pre-commit hook.
set -eu
set -o pipefail
harness=$(cd "$(dirname "$0")/.." && pwd -P)
TOOLS_DIR=$(cd "$harness/../scripts" && pwd -P)
. "$TOOLS_DIR/tools-common.sh"
[ $# = 1 ] || { tools_error 'usage: install.sh apps/<name>'; exit 1; }
mkdir -p "$1"; app=$(tools_abs "$1")
[ -e "$app/.git" ] || git -C "$app" init -q -b main
tools_repo "$app" >/dev/null
# Inspect the unresolved path as well: never replace a user symlink.
raw=$(git -C "$app" rev-parse --git-path hooks/pre-commit)
case "$raw" in /*) ;; *) raw=$app/$raw ;; esac
hook=$(tools_hook "$app")
if git -C "$app" config --get core.hooksPath >/dev/null 2>&1; then
  case "$hook" in "$app"/*) ;; *) tools_error 'custom shared hooksPath is configured; preserve it and integrate the app hook manually'; exit 1 ;; esac
fi
if [ -L "$raw" ] || { [ -e "$raw" ] && { [ ! -f "$raw" ] || ! head -n 2 "$raw" | grep -qE '^# Sobaya app pre-commit v[12]$'; }; }; then
  tools_error "existing pre-commit hook preserved: $raw; integrate manually without replacing user hooks"; exit 1
fi
# Hook conflicts are checked before writing any app documents.
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-install.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
if [ ! -e "$app/AGENTS.md" ]; then
  : > "$tmp/lines"
  if [ -f "$app/package.json" ]; then
    command -v jq >/dev/null || { tools_error 'jq required'; exit 1; }
    jq -e 'type=="object" and ((.scripts // {}) | type=="object")' "$app/package.json" >/dev/null || { tools_error 'invalid package.json'; exit 1; }
    for script in test lint format:check; do
      if jq -e --arg key "$script" '.scripts[$key] | type=="string" and length>0' "$app/package.json" >/dev/null; then
        case "$script" in test) printf '%s\n' '- Test: `npm test`' ;; lint) printf '%s\n' '- Lint: `npm run lint`' ;; format:check) printf '%s\n' '- Format: `npm run format:check`' ;; esac >> "$tmp/lines"
      fi
    done
    printf '%s\n' '- Skills: nodejs' >> "$tmp/lines"
  elif [ -f "$app/go.mod" ]; then
    printf '%s\n' '- Test: `go test ./...`' '- Format: `gofmt -l .`' '- Lint: `go vet ./...`' '- Bench: `go test -bench=. -benchmem ./...`' '- Skills: go-mistakes' > "$tmp/lines"
  fi
  {
    printf '# %s\n\n<One line: what this app is.>\n\n## App facts\n' "$(basename "$app")"
    grep -q '^- Test:' "$tmp/lines" || printf '%s\n' '- Test: `<declare the actual test command>`'
    cat "$tmp/lines"
    printf '\nFollow this file and the workspace AGENTS.md. The shared TDD rules are in tdd-set/AGENTS.md.\n'
  } > "$app/AGENTS.md"
fi
[ -e "$app/spec.md" ] || cp "$harness/spec-template.md" "$app/spec.md"
[ -e "$app/failed-test.md" ] || cp "$harness/failed-test-template.md" "$app/failed-test.md"
tools_app_hook "${harness%/tdd-set}" > "$tmp/hook"
mkdir -p "$(dirname "$hook")"
if [ ! -f "$hook" ] || ! cmp -s "$tmp/hook" "$hook"; then cat "$tmp/hook" > "$hook"; fi
[ -x "$hook" ] || chmod 755 "$hook"
printf '%s ready: AGENTS.md, spec.md, failed-test.md; Git pre-commit installed at %s\n' "$app" "$hook"
printf 'Fill spec.md and actual Test/Format/Lint commands in AGENTS.md before planning.\n'
