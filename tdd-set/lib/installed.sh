#!/bin/bash
# Management and dispatch for an explicitly connected consumer workspace.
set -eu
set -o pipefail
i_lib=$(cd "$(dirname "$0")" && pwd -P)
. "$i_lib/install-runtime.sh"
. "$i_lib/../../scripts/tools-common.sh"
. "$i_lib/connection-hooks.sh"
i_die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
[ "$#" -gt 0 ] || i_die 'usage: sobaya COMMAND --root PATH --install-root STORE'
i_command=$1; shift
i_root= i_store= i_mode= i_version= i_app= i_manifest= i_archive=
i_args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root|--install-root|--mode|--version|--app|--manifest|--archive)
      [ "$#" -ge 2 ] && [ -n "$2" ] || i_die "missing value for $1"
      case "$1" in
        --root) [ -z "$i_root" ] || i_die 'duplicate root'; i_root=$2 ;;
        --install-root) [ -z "$i_store" ] || i_die 'duplicate install-root'; i_store=$2 ;;
        --mode) [ -z "$i_mode" ] || i_die 'duplicate mode'; i_mode=$2 ;;
        --version) [ -z "$i_version" ] || i_die 'duplicate version'; i_version=$2 ;;
        --app) [ -z "$i_app" ] || i_die 'duplicate app'; i_app=$2 ;;
        --manifest) [ -z "$i_manifest" ] || i_die 'duplicate manifest'; i_manifest=$2 ;;
        --archive) [ -z "$i_archive" ] || i_die 'duplicate archive'; i_archive=$2 ;;
      esac
      shift 2 ;;
    *) i_args+=("$1"); shift ;;
  esac
done
[ -d "$i_root" ] && [ -n "$i_store" ] || i_die 'root and install-root are required'
i_root=$(ir_abs "$i_root"); i_store=$(ir_abs "$i_store")
case "$i_store/" in "${i_root%/}/"*) i_die 'install: store must be outside consumer' ;; esac
for i_name in $(git rev-parse --local-env-vars); do unset "$i_name"; done
i_tmp=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-manage.XXXXXX")
trap 'rm -rf "$i_tmp"' EXIT
i_write() {
  local source=$1 dest=$2
  [ ! -L "$dest" ] || i_die "connection: symlink conflict: $dest"
  if [ -e "$dest" ]; then
    [ -f "$dest" ] || i_die "connection: file conflict: $dest"
    cmp -s "$source" "$dest" && return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$source" "$dest"
}
i_config() {
  for i_name in sobaya.json sobaya.lock; do
    [ -f "$i_root/$i_name" ] && [ ! -L "$i_root/$i_name" ] || i_die "config: regular $i_name required"
  done
  i_config_digest=$(ir_hash "$i_root/sobaya.json")
  i_lock_digest=$(ir_hash "$i_root/sobaya.lock")
  i_config_json=$(/bin/bash "$i_lib/config-check.sh" "$i_root") || exit 2
  [ "$i_config_digest" = "$(ir_hash "$i_root/sobaya.json")" ] && [ "$i_lock_digest" = "$(ir_hash "$i_root/sobaya.lock")" ] || i_die 'protected workspace pin changed while resolving'
  i_mode=$(jq -r .mode <<< "$i_config_json")
  i_version=$(jq -r .runtime.version <<< "$i_config_json")
}
i_select_app() {
  case "$i_mode" in
    dependency)
      [ -z "$i_app" ] || [ "$(ir_abs "$i_app")" = "$i_root" ] || i_die 'connection: dependency app must be the consumer'
      i_app=$i_root ;;
    project)
      [ -d "$i_app" ] || i_die 'connection: project mode needs --app'
      i_app=$(ir_abs "$i_app")
      [ "$(dirname "$i_app")" = "$i_root/apps" ] || i_die 'connection: project app must be directly under apps'
      [ -d "$i_root/brain" ] || i_die 'connection: project workspace requires brain' ;;
    *) i_die 'connection: mode must be project or dependency' ;;
  esac
  i_app=$(tools_repo "$i_app") || i_die 'connection: app repository required'
  i_meta=$(git -C "$i_app" rev-parse --absolute-git-dir)/sobaya
}
i_connection_check() {
  [ -f "$i_meta/connection.json" ] && [ ! -L "$i_meta" ] && [ ! -L "$i_meta/connection.json" ] || i_die 'connection: app is not connected'
  jq -e --arg root "$i_root" --arg store "$i_store" --arg app "$i_app" --arg mode "$i_mode" '.connection_version==1 and .root==$root and .store==$store and .app==$app and .mode==$mode' "$i_meta/connection.json" >/dev/null || i_die 'connection: workspace/store does not match local connection'
}
i_pin_stamp() {
  local file=$1 mode
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  if mode=$(stat -f '%Lp' "$file" 2>/dev/null) && [[ $mode =~ ^[0-7]+$ ]]; then :; else mode=$(stat -c '%a' "$file") || return; fi
  printf '%s:%s\n' "$mode" "$(ir_hash "$file")"
}
i_dispatch() {
  [ -z "$i_mode$i_version$i_manifest$i_archive" ] || i_die 'runtime command: unexpected management options'
  i_config; i_select_app; i_connection_check
  i_runtime=$(ir_verified_path "$i_store" "$i_version" "$(jq -c .runtime <<< "$i_config_json")")
  export SOBAYA_WORKSPACE_ROOT="$i_root" SOBAYA_CONNECTION_MODE="$i_mode" SOBAYA_CONNECTION_STORE="$i_store"
  export SOBAYA_SELECTED_CONFIG_SHA="$i_config_digest" SOBAYA_SELECTED_LOCK_SHA="$i_lock_digest"
  if [ "$i_command" = gate ]; then
    config_stamp=$(i_pin_stamp "$i_root/sobaya.json"); lock_stamp=$(i_pin_stamp "$i_root/sobaya.lock")
    [ "${config_stamp#*:}" = "$i_config_digest" ] && [ "${lock_stamp#*:}" = "$i_lock_digest" ] || i_die 'protected workspace pin changed before gate runtime selection completed'
    gate_rc=0
    if [ "${#i_args[@]}" -gt 0 ]; then /bin/bash "$i_runtime/tdd-set/bin/gate.sh" "$i_app" "${i_args[@]}" > "$i_tmp/gate.out" 2> "$i_tmp/gate.err" || gate_rc=$?
    else /bin/bash "$i_runtime/tdd-set/bin/gate.sh" "$i_app" > "$i_tmp/gate.out" 2> "$i_tmp/gate.err" || gate_rc=$?; fi
    cat "$i_tmp/gate.err" >&2
    [ "$config_stamp" = "$(i_pin_stamp "$i_root/sobaya.json")" ] && [ "$lock_stamp" = "$(i_pin_stamp "$i_root/sobaya.lock")" ] || i_die 'protected workspace pin changed during gate'
    cat "$i_tmp/gate.out"; return "$gate_rc"
  fi
  rm -rf "$i_tmp"; trap - EXIT
  if [ "${#i_args[@]}" -gt 0 ]; then exec /bin/bash "$i_runtime/tdd-set/lib/runner.sh" "$i_command" "$i_app" "${i_args[@]}"
  else exec /bin/bash "$i_runtime/tdd-set/lib/runner.sh" "$i_command" "$i_app"; fi
}
i_init() {
  [ "${#i_args[@]}" -eq 0 ] && [ -z "$i_manifest$i_archive" ] || i_die 'init: unexpected arguments'
  [ -n "$i_version" ] || i_die 'init: version is required'
  i_select_app
  tools_repo "$i_root" >/dev/null || i_die 'connection: workspace repository required'
  for i_name in AGENTS.md spec.md failed-test.md; do
    [ -f "$i_app/$i_name" ] && [ ! -L "$i_app/$i_name" ] || i_die "connection: existing regular $i_name required"
  done
  root_meta=$(git -C "$i_root" rev-parse --absolute-git-dir)/sobaya
  for private_dir in "$i_meta" "$root_meta"; do
    [ ! -L "$private_dir" ] || i_die 'connection: metadata directory is a symlink'
    [ ! -e "$private_dir" ] || [ -d "$private_dir" ] || i_die 'connection: metadata directory conflict'
  done
  printf '%s\n' 'Use the workspace sobaya.json and sobaya.lock to select the installed runtime.' 'The runtime supplies its exact tdd-set/AGENTS.md path to each worker; existing app instructions remain authoritative.' > "$i_tmp/instructions"
  if [ -e "$i_meta/connection.md" ] || [ -L "$i_meta/connection.md" ]; then
    [ -f "$i_meta/connection.md" ] && [ ! -L "$i_meta/connection.md" ] && cmp -s "$i_tmp/instructions" "$i_meta/connection.md" || i_die 'connection: local instructions conflict'
  fi
  i_runtime=$(ir_verified_path "$i_store" "$i_version")
  i_pin=$(jq -c .runtime "$i_store/runtimes/$i_version/manifest.json")
  jq -n --arg mode "$i_mode" --arg version "$i_version" '{config_version:1,mode:$mode,runtime:{version:$version}}' > "$i_tmp/config"
  jq -n --argjson pin "$i_pin" '{lock_version:1,runtime:$pin}' > "$i_tmp/lock"
  if [ -e "$i_root/sobaya.json" ] || [ -L "$i_root/sobaya.json" ] || [ -e "$i_root/sobaya.lock" ] || [ -L "$i_root/sobaya.lock" ]; then
    wanted_mode=$i_mode; wanted_version=$i_version
    i_config
    [ "$i_mode" = "$wanted_mode" ] && [ "$i_version" = "$wanted_version" ] && [ "$(jq -cS .runtime <<< "$i_config_json")" = "$(jq -cS . <<< "$i_pin")" ] || i_die 'connection: existing configuration conflicts; use explicit bump'
  fi
  jq -n --arg root "$i_root" --arg store "$i_store" --arg mode "$i_mode" --arg app "$i_app" '{connection_version:1,root:$root,store:$store,mode:$mode,app:$app}' > "$i_tmp/connection"
  if [ -e "$i_meta/connection.json" ] || [ -L "$i_meta/connection.json" ]; then
    [ -f "$i_meta/connection.json" ] && [ ! -L "$i_meta/connection.json" ] && cmp -s "$i_tmp/connection" "$i_meta/connection.json" || i_die 'connection: existing local connection conflicts'
  fi
  registry=$root_meta/connections.json
  if [ -e "$registry" ] || [ -L "$registry" ]; then
    [ -f "$registry" ] && [ ! -L "$registry" ] || i_die 'connection: registry conflict'
    jq -e 'type=="array" and all(.[];type=="string")' "$registry" >/dev/null || i_die 'connection: invalid registry'
    jq --arg app "$i_app" '.+[$app]|unique' "$registry" > "$i_tmp/registry"
  else jq -n --arg app "$i_app" '[$app]' > "$i_tmp/registry"; fi
  ih_prepare
  if [ ! -e "$i_root/sobaya.json" ]; then i_write "$i_tmp/config" "$i_root/sobaya.json"; i_write "$i_tmp/lock" "$i_root/sobaya.lock"; fi
  i_write "$i_tmp/connection" "$i_meta/connection.json"
  i_write "$i_tmp/registry" "$registry"
  i_write "$i_tmp/instructions" "$i_meta/connection.md"
  ih_apply
  jq -cn --arg mode "$i_mode" --arg app "$i_app" --argjson pin "$i_pin" '{mode:$mode,app:$app,runtime:$pin}'
}
case "$i_command" in
  init) i_init ;;
  doctor|approve|step|loop|gate|status|next|review|usage) i_dispatch ;;
  __hook)
    i_config; i_select_app; i_connection_check
    i_runtime=$(ir_verified_path "$i_store" "$i_version" "$(jq -c .runtime <<< "$i_config_json")")
    unset SOBAYA_WORKER_RECORD
    . "$i_runtime/tdd-set/lib/contract.sh"
    contract_hygiene "$i_app" ;;
  *) i_die "unimplemented installed command: $i_command" ;;
esac
