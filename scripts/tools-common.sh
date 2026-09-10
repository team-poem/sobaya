#!/bin/bash
# Private shell helpers for setup/index/workspace tools (Bash 3.2).
tools_error() { printf 'ERROR: %s\n' "$*" >&2; return 1; }
tools_abs() {
  local path=$1 depth=${2:-0} parent leaf target
  [ "$depth" -lt 40 ] || { tools_error 'too many symbolic links'; return 1; }
  case "$path" in /*) ;; *) path=$PWD/$path ;; esac
  if [ -d "$path" ]; then (cd "$path" && pwd -P); return; fi
  parent=$(dirname "$path"); leaf=$(basename "$path")
  if [ "$parent" = "$path" ]; then printf '/\n'; return; fi
  parent=$(tools_abs "$parent" "$((depth + 1))") || return
  case "$leaf" in .) printf '%s\n' "$parent"; return ;; ..) dirname "$parent"; return ;; esac
  path=${parent%/}/$leaf
  if [ -L "$path" ]; then
    target=$(readlink "$path") || return
    case "$target" in /*) ;; *) target=$parent/$target ;; esac
    tools_abs "$target" "$((depth + 1))"
  else printf '%s\n' "$path"; fi
}
tools_repo() {
  local path top
  path=$(tools_abs "$1") || return
  top=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null) || { tools_error "$path must be a git repository"; return 1; }
  top=$(tools_abs "$top") || return
  [ "$top" = "$path" ] || { tools_error "$path must be the repository root"; return 1; }
  printf '%s\n' "$path"
}
tools_hook() {
  local path
  path=$(git -C "$1" rev-parse --git-path hooks/pre-commit) || return
  case "$path" in /*) ;; *) path=$1/$path ;; esac
  tools_abs "$path"
}
tools_quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
tools_app_hook() {
  printf '#!/bin/sh\n# Sobaya app pre-commit v2\nexec /bin/bash '
  tools_quote "$1/tdd-set/hooks/pre-commit.sh"
  printf '\n'
}
tools_executable() { [ -f "$1" ] && [ -x "$1" ] || { tools_error "$2 is missing or not executable: $1"; return 1; }; }
tools_plain_path() { case "$1" in *$'\n'*) tools_error 'newline filenames cannot be represented in the brain index'; return 1 ;; esac; }
tools_index_render() { LC_ALL=C sort -u "$1" | awk -f "$TOOLS_DIR/index-render.awk"; }
