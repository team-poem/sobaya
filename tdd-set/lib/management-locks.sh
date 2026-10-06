#!/bin/bash
# Cooperate with runner.sh's app locks; never lock again from a commit hook.
im_paths=(); im_methods=(); im_fds=()
im_child=; ib_pending=false
im_lock() {
  local path=$1 n fd old
  for ((n=0;n<${#im_paths[@]};n++)); do [ "${im_paths[$n]}" != "$path" ] || return 0; done
  [ ! -L "$path" ] && { [ ! -e "$path" ] || [ -f "$path" ]; } || i_die 'active: conflicting lock path'
  mkdir -p "$(dirname "$path")"
  n=${#im_paths[@]}
  if command -v shlock >/dev/null 2>&1; then
    shlock -p "$$" -f "$path" || i_die 'active: another Sobaya operation owns this workspace or app'
    im_methods[$n]=shlock; im_fds[$n]=''
  elif command -v flock >/dev/null 2>&1; then
    fd=$((20+n))
    # Only our numeric descriptor is interpolated as code, never a path.
    eval "exec $fd>>\"\$path\""
    if ! flock -n "$fd"; then eval "exec $fd>&-"; i_die 'active: another Sobaya operation owns this workspace or app'; fi
    im_methods[$n]=flock; im_fds[$n]=$fd
  else i_die 'active: install shlock (macOS/BSD) or flock (Linux)'; fi
  im_paths[$n]=$path
}
im_close_fds() {
  local fd n
  for ((n=0;n<${#im_fds[@]};n++)); do fd=${im_fds[$n]}; [ -z "$fd" ] || eval "exec $fd>&-"; done
}
im_cleanup() {
  local rc=$? n path
  trap - EXIT INT TERM
  if [ -n "$im_child" ]; then kill -TERM "$im_child" 2>/dev/null || :; wait "$im_child" 2>/dev/null || :; fi
  if [ "$ib_pending" = true ]; then
    if ! ib_restore; then
      printf 'ERROR: rollback incomplete; original pins retained at %s\n' "$i_tmp" >&2
      rc=2
    else ib_pending=false; fi
  fi
  for ((n=${#im_paths[@]}-1;n>=0;n--)); do
    path=${im_paths[$n]}
    if [ "${im_methods[$n]}" = shlock ] && [ "$(cat "$path" 2>/dev/null || :)" = "$$" ]; then rm -f "$path"; fi
  done
  im_close_fds
  [ "$ib_pending" = true ] || rm -rf "$i_tmp"
  exit "$rc"
}
trap im_cleanup EXIT
trap 'printf "ERROR: validation interrupted; restoring original pins\n" >&2; exit 2' INT TERM
