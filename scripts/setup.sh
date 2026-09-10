#!/bin/bash
# Activate neutral Git hooks, or verify setup without running a worker.
set -eu
set -o pipefail
TOOLS_DIR=$(cd "$(dirname "$0")" && pwd -P)
. "$TOOLS_DIR/tools-common.sh"
[ $# -ge 1 ] || { tools_error 'usage: setup.sh ROOT [--check] [--app APP]'; exit 1; }
root=$(tools_repo "$1"); shift
check=0; app=
while [ $# -gt 0 ]; do
  case "$1" in --check) check=1 ;; --app) shift; [ $# -gt 0 ] || exit 1; app=$(tools_repo "$1") ;; *) tools_error "unknown option: $1"; exit 1 ;; esac; shift
done
[ -z "$app" ] || [ "$check" = 1 ] || { tools_error '--app requires --check; install apps with tdd-set/bin/install.sh'; exit 1; }
expected=$root/.githooks/pre-commit
tools_executable "$expected" 'Root pre-commit'
[ -f "$root/scripts/workspace-check.sh" ] || { tools_error 'workspace checker is missing'; exit 1; }
current=$(tools_hook "$root"); expected_abs=$(tools_abs "$expected")
if [ "$check" = 1 ]; then
  [ "$current" = "$expected_abs" ] || { tools_error "Root hooks are not active; run scripts/setup.sh $root"; exit 1; }
  printf 'Root hook active: %s\n' "$expected"
  if [ -n "$app" ]; then
    hook=$(tools_hook "$app"); tools_executable "$hook" 'App pre-commit'
    [ -f "$root/tdd-set/hooks/pre-commit.sh" ] || { tools_error 'app hook helper is missing'; exit 1; }
    if ! tools_app_hook "$root" | cmp -s "$hook" -; then tools_error "App pre-commit is not the managed hook for this harness: $hook; preserve custom hooks or upgrade with tdd-set/bin/install.sh"; exit 1; fi
    printf 'App hook active: %s\n' "$hook"
  fi
  printf 'Setup checks passed; no worker was invoked\n'; exit 0
fi
if [ "$current" = "$expected_abs" ]; then printf 'Root hooks already active; configuration unchanged\n'; exit 0; fi
if git -C "$root" config --get core.hooksPath >/dev/null 2>&1; then tools_error 'Conflicting core.hooksPath is configured; it was preserved. Integrate existing hooks explicitly.'; exit 1; fi
if [ -d "$(dirname "$current")" ]; then
  for item in "$(dirname "$current")"/* "$(dirname "$current")"/.[!.]*; do
    [ -f "$item" ] || [ -L "$item" ] || continue
    case "$item" in *.sample) continue ;; esac
    tools_error "Existing Git hooks would be shadowed; preserved: $(basename "$item")"; exit 1
  done
fi
git -C "$root" config --local core.hooksPath .githooks
[ "$(tools_hook "$root")" = "$expected_abs" ] || { tools_error 'hook configuration did not take effect'; exit 1; }
printf 'Root hooks activated: %s\n' "$expected"
