#!/usr/bin/env bash
# Canonical local harness suite. All workers are fake; no provider calls.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TEMP=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-tests.XXXXXX")
trap 'rm -rf "$TEMP"' EXIT
cd "$ROOT"

# Reject tracked, staged, and untracked interpreter sources in the repository.
# Deleted working-tree paths are omitted so conversion can be tested before staging.
forbidden_extension=$(printf '.%s' py)
git ls-files --cached --others --exclude-standard -z -- "*$forbidden_extension" > "$TEMP/tracked"
while IFS= read -r -d '' file; do
  case "$file" in apps/*|references/*) continue ;; esac
  if [ -e "$file" ] || [ -L "$file" ]; then printf 'FAIL: interpreter source remains in harness: %s\n' "$file" >&2; exit 1; fi
done < "$TEMP/tracked"

# A sentinel fails even if a caller swallows its exit code. Also inspect the
# actual runnable sources for absolute interpreter paths that bypass PATH.
mkdir "$TEMP/bin"
export SOBAYA_FORBIDDEN_INTERPRETER_LOG="$TEMP/interpreter-used"
for interpreter in $(printf 'py%sthon py%sthon2 py%sthon3 py%spy py%spy3' '' '' '' '' ''); do
  cat > "$TEMP/bin/$interpreter" <<'DENY'
#!/bin/sh
printf '%s\n' "$0 $*" >> "$SOBAYA_FORBIDDEN_INTERPRETER_LOG"
echo 'FAIL: non-shell interpreter invoked by harness tests' >&2
exit 97
DENY
  chmod +x "$TEMP/bin/$interpreter"
done
export PATH="$TEMP/bin:$PATH"
pattern='(^#!.*|(^|[;&|[:space:]])(exec[[:space:]]+)?)(/[^[:space:]]*/)?(py''thon[0-9.]*|py''py[0-9.]*)([[:space:]]|$)'
find scripts tdd-set/bin tdd-set/lib tdd-set/hooks tdd-set/tests tests -type f -name '*.sh' -print0 > "$TEMP/shell-sources"
find .githooks -type f -print0 >> "$TEMP/shell-sources"
while IFS= read -r -d '' file; do
  if grep -En "$pattern" "$file" > "$TEMP/commands"; then
    printf 'FAIL: non-shell interpreter command in %s\n' "$file" >&2
    cat "$TEMP/commands" >&2; exit 1
  else
    scan_rc=$?
    [ "$scan_rc" -eq 1 ] || exit "$scan_rc"
  fi
done < "$TEMP/shell-sources"

for suite in tests/test-contract.sh tests/test-runner.sh tests/test-tools.sh \
  tdd-set/tests/next-entry.sh tdd-set/tests/probe-go-imports.sh tdd-set/tests/gate-verbatim.sh; do
  printf '\nRunning %s\n' "$suite"
  bash "$ROOT/$suite"
done
[ ! -s "$SOBAYA_FORBIDDEN_INTERPRETER_LOG" ] || {
  cat "$SOBAYA_FORBIDDEN_INTERPRETER_LOG" >&2
  echo 'FAIL: interpreter sentinel was invoked' >&2; exit 1;
}
printf '\nPASS: all shell harness suites; no forbidden interpreter used.\n'
