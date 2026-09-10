#!/bin/bash
# Bash 3.2 process supervisor. Source sb_run; subprocess traps never leak to callers.
SB_COMMON_FILE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh
sb_error() { printf '%s\n' "$*" >&2; }
sb_group_alive() {
  local message
  case "$1" in ''|*[!0-9]*|0|1) sb_error 'Invalid process group; treating it as alive'; return 0;; esac
  if message=$(LC_ALL=C kill -0 -- "-$1" 2>&1); then return 0; fi
  case "$message" in *'No such process'*) return 1;; esac
  sb_error "Cannot establish process group $1 stopped: $message"
  return 0
}
sb_assert_no_orphan() {
  [ -e "$1" ] || return 0
  local pid
  pid=$(jq -er '.pid | select(type=="number" and .>1 and floor==.)' "$1") || { sb_error 'Invalid process record; inspect before continuing'; return 1; }
  if sb_group_alive "$pid"; then sb_error "Prior process group $pid is still alive; refusing another writer"; return 1; fi
  rm -f "$1"
}
sb_run() {
  local sb_supervisor sb_cancelled=0 sb_rc sb_old_int sb_old_term
  sb_old_int=$(trap -p INT); sb_old_term=$(trap -p TERM)
  /bin/bash "$SB_COMMON_FILE" __run "$@" <&0 &
  sb_supervisor=$!
  trap 'sb_cancelled=1; kill -TERM "$sb_supervisor" 2>/dev/null || :' INT TERM
  if wait "$sb_supervisor"; then sb_rc=0; else sb_rc=$?; fi
  if [ "$sb_cancelled" -eq 1 ]; then
    wait "$sb_supervisor" 2>/dev/null || :
    sb_rc=130
  fi
  trap - INT TERM
  [ -z "$sb_old_int" ] || eval "$sb_old_int"
  [ -z "$sb_old_term" ] || eval "$sb_old_term"
  return "$sb_rc"
}
sb_supervise() {
  local timeout=$1 out=$2 err=$3 input=$4 cwd=$5
  shift 5; [ "${1:-}" = -- ] || { sb_error 'sb_run requires -- before argv'; return 1; }; shift
  [ "$#" -gt 0 ] || return 1
  awk -v n="$timeout" 'BEGIN {exit !(n ~ /^[0-9]+([.][0-9]+)?$/ && n+0>0)}' || { sb_error 'Invalid timeout'; return 1; }
  local child='' timer='' temporary rc=1 cancelled=0 record=${SOBAYA_WORKER_RECORD:-}
  [ -z "$record" ] || sb_assert_no_orphan "$record" || return 1
  temporary=$(mktemp -d) || return 1
  sb_stop_group() {
    [ -n "$1" ] || return 0
    kill -TERM -- "-$1" 2>/dev/null || :
    kill -KILL -- "-$1" 2>/dev/null || :
  }
  sb_supervisor_cleanup() {
    trap '' INT TERM
    sb_stop_group "$child"; sb_stop_group "$timer"
    [ -z "$child" ] || wait "$child" 2>/dev/null || :
    [ -z "$timer" ] || wait "$timer" 2>/dev/null || :
    if [ -n "$record" ] && [ -n "$child" ]; then
      local remaining=50
      while sb_group_alive "$child" && [ "$remaining" -gt 0 ]; do sleep 0.02; remaining=$((remaining-1)); done
      if ! sb_group_alive "$child"; then
        [ "$(jq -r '.pid // empty' "$record" 2>/dev/null)" != "$child" ] || rm -f "$record"
      fi
    fi
    rm -rf "$temporary"
  }
  trap 'cancelled=1; sb_stop_group "$child"' INT TERM
  trap sb_supervisor_cleanup EXIT
  cd "$cwd" || exit 1
  set -m
  if [ "$input" = - ]; then (unset SOBAYA_WORKER_RECORD; exec "$@") >"$out" 2>"$err" <&0 &
  else (unset SOBAYA_WORKER_RECORD; exec "$@") >"$out" 2>"$err" <"$input" & fi
  child=$!
  if [ -n "$record" ]; then
    mkdir -p "$(dirname "$record")" || exit 1
    jq -n --argjson pid "$child" --arg run_id "${SOBAYA_RUN_ID:-}" --arg worker "${SOBAYA_WORKER:-}" '{pid:$pid,pgid:$pid,run_id:$run_id,worker:$worker}' >"$record.pending.$$" && mv "$record.pending.$$" "$record" || exit 1
  fi
  (sleep "$timeout"; : >"$temporary/timeout"; kill -TERM -- "-$child" 2>/dev/null || :; sleep 0.1; kill -KILL -- "-$child" 2>/dev/null || :) &
  timer=$!
  set +m
  if wait "$child" 2>/dev/null; then rc=0; else rc=$?; fi
  [ "$cancelled" -eq 0 ] || rc=130
  [ ! -e "$temporary/timeout" ] || { sb_error "Command timed out after ${timeout}s"; rc=124; }
  # Stop descendants even after a normally exited leader, preserving its status.
  sb_stop_group "$child"; sb_stop_group "$timer"
  exit "$rc"
}
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  [ "${1:-}" = __run ] || exit 1
  shift; sb_supervise "$@"; exit $?
fi
