#!/bin/bash
# Read-only checks for doctor and ordinary Git hooks.
set -eu
set -o pipefail
TOOLS_DIR=$(cd "$(dirname "$0")" && pwd -P)
. "$TOOLS_DIR/tools-common.sh"
[ $# -ge 1 ] || { tools_error 'usage: workspace-check.sh ROOT [--staged] [--app APP] [--apps]'; exit 1; }
root=$(tools_abs "$1"); shift
staged=0; app=; apps=0
while [ $# -gt 0 ]; do
  case "$1" in --staged) staged=1 ;; --apps) apps=1 ;; --app) shift; [ $# -gt 0 ] || exit 1; app=$(tools_abs "$1") ;; *) tools_error "unknown option: $1"; exit 1 ;; esac
  shift
done
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-workspace.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
failures=0
problem() { tools_error "$*" || :; failures=$((failures + 1)); }
marker() { case "$1" in package.json|pyproject.toml|Cargo.toml|go.mod|deno.json|composer.json) return 0 ;; *) return 1 ;; esac; }
registered() {
  [ -f "$root/brain/apps.md" ] || return 1
  awk -F'|' -v name="$1" '{v=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); if ($0 ~ /^\|/ && v==name) found=1} END {exit !found}' "$root/brain/apps.md"
}
introduced() {
  local repo=$1 path
  if [ "$staged" = 1 ]; then git -C "$repo" diff --cached --no-renames --name-only --diff-filter=A -z > "$tmp/introduced"
  else
    git -C "$repo" ls-files --cached --others --exclude-standard -z > "$tmp/candidates"
    : > "$tmp/introduced"
    while IFS= read -r -d '' path; do
      if ! git -C "$repo" cat-file -e "HEAD:$path" 2>/dev/null; then printf '%s\0' "$path" >> "$tmp/introduced"; fi
    done < "$tmp/candidates"
  fi
}
if [ -n "$app" ]; then
  grandfather=0; registered "$(basename "$app")" && grandfather=1
  top=$(git -C "$app" rev-parse --show-toplevel 2>/dev/null) || top=
  [ -z "$top" ] || top=$(tools_abs "$top")
  if [ "$top" != "$app" ]; then
    [ "$grandfather" = 1 ] || problem "$app: app needs its own git repository; run tdd-set/bin/install.sh"
  else
    introduced "$app"
    while IFS= read -r -d '' path; do
      if marker "${path##*/}"; then case "$path" in app/*|apps/*) problem "$app/$path: nested project marker; app root must be flat" ;; esac; fi
    done < "$tmp/introduced"
    if [ "$grandfather" = 0 ]; then
      if [ "$staged" = 1 ]; then git -C "$app" show :AGENTS.md > "$tmp/agents" 2>/dev/null || : > "$tmp/agents"
      elif [ -f "$app/AGENTS.md" ]; then cat "$app/AGENTS.md" > "$tmp/agents"
      else : > "$tmp/agents"; fi
      if ! awk '/^- Test:/ {s=$0; sub(/^- Test:[[:space:]]*`?/, "", s); sub(/`[[:space:]]*$/, "", s); gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); n++; if (s=="" || s=="true" || s==":" || s ~ /</) bad=1} END {exit n==0 || bad}' "$tmp/agents"; then problem "$app: declare an actual - Test: command in AGENTS.md"; fi
    fi
  fi
else
  tools_repo "$root" >/dev/null
  introduced "$root"
  while IFS= read -r -d '' path; do
    if marker "${path##*/}"; then
      case "$path" in apps/*|references/*) ;; *) problem "$path: new projects belong under apps/<name>" ;; esac
      case "$path" in apps/*/*) rel=${path#apps/}; rel=${rel#*/}; case "$rel" in app/*|apps/*) problem "$path: nested project marker; app root must be flat" ;; esac ;; esac
    fi
  done < "$tmp/introduced"
  if [ "$staged" = 1 ]; then
    git -C "$root" diff --cached --name-only -z > "$tmp/changed"; changed=0
    while IFS= read -r -d '' path; do case "$path" in brain/*.md) changed=1 ;; esac; done < "$tmp/changed"
    if [ "$changed" = 1 ]; then
      git -C "$root" ls-files -z -- brain > "$tmp/files"; : > "$tmp/paths"
      while IFS= read -r -d '' path; do tools_plain_path "$path" || exit 1; printf '%s\n' "${path#brain/}" >> "$tmp/paths"; done < "$tmp/files"
      [ ! -f "$root/brain/apps.md" ] || printf 'apps.md\n' >> "$tmp/paths"
      tools_index_render "$tmp/paths" > "$tmp/expected"
      if ! git -C "$root" show :brain/index.md > "$tmp/actual" 2>/dev/null || ! cmp -s "$tmp/actual" "$tmp/expected"; then problem 'brain/index.md is not the generated index for staged notes; run scripts/brain-index.sh and stage the index with the notes'; fi
    fi
  elif [ -d "$root/brain" ]; then
    if ! "$TOOLS_DIR/brain-index.sh" "$root" --check > "$tmp/index-check" 2>&1; then problem 'brain/index.md is stale or invalid; run scripts/brain-index.sh ROOT'; fi
  fi
  if [ "$apps" = 1 ] && [ -d "$root/apps" ]; then
    for candidate in "$root/apps"/*; do
      [ -d "$candidate" ] || continue
      if ! "$TOOLS_DIR/workspace-check.sh" "$root" --app "$candidate" > "$tmp/app-check" 2>&1; then sed 's/^/WARN (existing app): /' "$tmp/app-check"; fi
    done
  fi
fi
[ "$failures" = 0 ] || exit 1
printf 'workspace checks passed\n'
