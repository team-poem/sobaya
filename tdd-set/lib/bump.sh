#!/bin/bash
# Explicit candidate validation, with reviewable pins and unchanged approval.
ib_metas=()
ib_configs=()
ib_mode() {
  local mode
  if mode=$(stat -f '%Lp' "$1" 2>/dev/null) && [[ $mode =~ ^[0-7]+$ ]]; then :; else mode=$(stat -c '%a' "$1") || return; fi
  printf '%s\n' "$mode"
}
ib_state_check() {
  local meta=$1 state pid
  if [ -e "$meta/state.json" ] || [ -L "$meta/state.json" ]; then
    [ -f "$meta/state.json" ] && [ ! -L "$meta/state.json" ] || i_die 'active: invalid approval state path'
    state=$(jq -ces 'if length==1 then .[0] else error("multiple states") end | select(type=="object" and .version==1 and (.baseline|type)=="string" and (.calls|type)=="number" and .calls>=0 and has("active"))' "$meta/state.json") || i_die 'active: invalid approval state'
    jq -e '.active==null' <<< "$state" >/dev/null || i_die 'active: finish or resolve the current entry before bump'
  fi
  if [ -e "$meta/worker.json" ] || [ -L "$meta/worker.json" ]; then
    [ -f "$meta/worker.json" ] && [ ! -L "$meta/worker.json" ] || i_die 'active: invalid worker record'
    pid=$(jq -ers 'select(length==1)|.[0].pid|select(type=="number" and .>1 and floor==.)' "$meta/worker.json") || i_die 'active: invalid worker record'
    if sb_group_alive "$pid"; then i_die 'active: prior worker group is alive or cannot be verified'; fi
  fi
}
ib_restore() {
  # Preserve bytes and permissions, including when a check replaced a pin.
  local name rc=0
  for name in sobaya.json sobaya.lock; do
    if [ -d "$i_root/$name" ] && [ ! -L "$i_root/$name" ]; then rc=1; continue; fi
    rm -f "$i_root/$name" && cp -p "$i_tmp/original-$name" "$i_root/$name" || rc=1
  done
  ib_restore_metadata || rc=1
  ib_restore_configs || rc=1
  return "$rc"
}
ib_collect_configs() {
  local app gitdir common path n found
  for app in "${ib_repos[@]}"; do
    gitdir=$(git -C "$app" rev-parse --absolute-git-dir) || return
    common=$(git -C "$app" rev-parse --git-common-dir) || return
    case "$common" in /*) ;; *) common=$app/$common ;; esac
    common=$(ir_abs "$common") || return
    for path in "$common/config" "$gitdir/config.worktree"; do
      [ ! -L "$path" ] && { [ ! -e "$path" ] || [ -f "$path" ]; } || return 1
      found=false
      for ((n=0;n<${#ib_configs[@]};n++)); do [ "${ib_configs[$n]}" != "$path" ] || found=true; done
      [ "$found" = true ] || ib_configs+=("$path")
    done
  done
}
ib_backup_configs() {
  local n path
  for ((n=0;n<${#ib_configs[@]};n++)); do
    path=${ib_configs[$n]}
    [ ! -f "$path" ] || cp -p "$path" "$i_tmp/git-config-$n" || return
  done
}
ib_restore_configs() {
  local n path rc=0
  for ((n=0;n<${#ib_configs[@]};n++)); do
    path=${ib_configs[$n]}
    if [ -d "$path" ] && [ ! -L "$path" ]; then rc=1; continue; fi
    rm -f "$path" || { rc=1; continue; }
    [ ! -f "$i_tmp/git-config-$n" ] || cp -p "$i_tmp/git-config-$n" "$path" || rc=1
  done
  return "$rc"
}
ib_backup_metadata() {
  local app meta n=0
  for app in "${ib_repos[@]}"; do
    meta=$(git -C "$app" rev-parse --absolute-git-dir)/sobaya
    [ -d "$meta" ] && [ ! -L "$meta" ] || return 1
    cp -pR "$meta" "$i_tmp/meta-$n" || return
    ib_metas[$n]=$meta; n=$((n+1))
  done
}
ib_restore_metadata() {
  local n meta backup path relative rc=0
  for ((n=0;n<${#ib_metas[@]};n++)); do
    meta=${ib_metas[$n]}; backup=$i_tmp/meta-$n
    [ -d "$meta" ] && [ ! -L "$meta" ] && [ -f "$meta/lock.shell" ] && [ ! -L "$meta/lock.shell" ] || { rc=1; continue; }
    # Keep the live lock inode. Restore only protected metadata, never app edits.
    find "$meta" -depth -print0 > "$i_tmp/restore-paths" || { rc=1; continue; }
    while IFS= read -r -d '' path; do
      [ "$path" != "$meta" ] && [ "$path" != "$meta/lock.shell" ] || continue
      relative=${path#"$meta/"}
      if [ -d "$path" ] && [ ! -L "$path" ]; then
        if [ ! -d "$backup/$relative" ] || [ -L "$backup/$relative" ]; then rmdir "$path" || rc=1; fi
      else rm -f "$path" || rc=1; fi
    done < "$i_tmp/restore-paths"
    find "$backup" -mindepth 1 -maxdepth 1 -print0 > "$i_tmp/restore-paths" || { rc=1; continue; }
    while IFS= read -r -d '' path; do
      [ "$path" != "$backup/lock.shell" ] || continue
      cp -pR "$path" "$meta/" || rc=1
    done < "$i_tmp/restore-paths"
    chmod "$(ib_mode "$backup")" "$meta" || rc=1
  done
  return "$rc"
}
ib_path() {
  local file=$1 value
  if [ -L "$file" ]; then value="link:$(readlink "$file")"
  elif [ -f "$file" ]; then value=$(i_pin_stamp "$file") || return
  elif [ -d "$file" ]; then value="directory:$(ib_mode "$file")"
  elif [ -e "$file" ]; then value=special
  else value=missing; fi
  jq -cn --arg path "$file" --arg value "$value" '{path:$path,value:$value}'
}
ib_snapshot() {
  local app meta file n
  for app in "${ib_repos[@]}"; do
    git -C "$app" rev-parse HEAD || return
    git -C "$app" ls-files --stage -z | shasum -a 256 || return
    git -C "$app" ls-files --cached --others --exclude-standard -z > "$i_tmp/paths" || return
    while IFS= read -r -d '' file; do
      if [ "$app" = "$i_root" ]; then case "$file" in sobaya.json|sobaya.lock) continue ;; esac; fi
      ib_path "$app/$file" || return
    done < "$i_tmp/paths"
    meta=$(git -C "$app" rev-parse --absolute-git-dir)/sobaya
    if [ -d "$meta" ]; then
      find "$meta" -print0 > "$i_tmp/paths" || return
      while IFS= read -r -d '' file; do ib_path "$file" || return; done < "$i_tmp/paths"
    fi
  done
  for ((n=0;n<${#ib_configs[@]};n++)); do ib_path "${ib_configs[$n]}" || return; done
}
ib_validate() {
  im_close_fds
  unset SOBAYA_WORKER_RECORD SOBAYA_SELECTED_CONFIG_SHA SOBAYA_SELECTED_LOCK_SHA
  export SOBAYA_WORKSPACE_ROOT="$i_root" SOBAYA_CONNECTION_MODE="$i_mode" SOBAYA_CONNECTION_STORE="$i_store"
  exec /bin/bash -c '
    set -eu; set -o pipefail
    . "$1/tdd-set/lib/contract.sh"
    shift
    for app in "$@"; do
      contract_suite "$app"
      contract_hygiene "$app"
    done
  ' sobaya-candidate "$ib_runtime" "${ib_apps[@]}"
}
i_bump() {
  [ "${#i_args[@]}" -eq 0 ] && [ -z "$i_mode$i_app" ] && [ -n "$i_version" ] && [ -f "$i_manifest" ] || i_die 'bump: version and trusted manifest are required'
  local target=$i_version original_config original_lock app meta registry rc=0
  i_config
  original_config=$i_config_digest; original_lock=$i_lock_digest
  tools_repo "$i_root" >/dev/null || i_die 'bump: workspace repository required'
  im_lock "$(git -C "$i_root" rev-parse --absolute-git-dir)/sobaya-management.lock"
  ib_apps=(); ib_repos=("$i_root")
  if [ "$i_mode" = dependency ]; then
    i_select_app; i_connection_check; ib_apps=("$i_app")
  else
    registry=$(git -C "$i_root" rev-parse --absolute-git-dir)/sobaya/connections.json
    [ -f "$registry" ] && [ ! -L "$registry" ] && [ ! -L "$(dirname "$registry")" ] || i_die 'connection: missing project registry'
    jq -es 'length==1 and (.[0]|type)=="array" and (.[0]|length)>0 and all(.[0][];type=="string" and length>0 and (explode|all(.>=32)))' "$registry" >/dev/null || i_die 'connection: invalid project registry'
    jq -j 'unique[]+"\u0000"' "$registry" > "$i_tmp/apps"
    while IFS= read -r -d '' app; do
      i_app=$app; i_select_app; i_connection_check
      [ "$i_app" = "$app" ] || i_die 'connection: registry paths must be canonical'
      ib_apps+=("$i_app"); ib_repos+=("$i_app")
    done < "$i_tmp/apps"
  fi
  # Workspace registration is frozen; now own all repositories before any pin changes.
  for app in "${ib_repos[@]}"; do
    meta=$(git -C "$app" rev-parse --absolute-git-dir)/sobaya
    [ -d "$meta" ] && [ ! -L "$meta" ] || i_die 'connection: invalid metadata path'
    im_lock "$meta/lock.shell"
  done
  [ "$original_config" = "$(ir_hash "$i_root/sobaya.json")" ] && [ "$original_lock" = "$(ir_hash "$i_root/sobaya.lock")" ] || i_die 'protected: workspace pin changed before bump acquired locks'
  . "$i_lib/contract.sh"
  for app in "${ib_apps[@]}"; do
    meta=$(git -C "$app" rev-parse --absolute-git-dir)/sobaya
    ib_state_check "$meta"
  done
  for app in "${ib_repos[@]}"; do contract_clean "$app" >/dev/null || i_die 'validation: commit or resolve workspace edits before bump'; done
  if [ -n "$i_archive" ]; then
    ir_install --root "$i_root" --install-root "$i_store" --version "$target" --manifest "$i_manifest" --archive "$i_archive" > "$i_tmp/candidate.json"
  else ir_install --root "$i_root" --install-root "$i_store" --version "$target" --manifest "$i_manifest" > "$i_tmp/candidate.json"; fi
  ib_runtime=$(jq -r .runtime_path "$i_tmp/candidate.json")
  cp -p "$i_root/sobaya.json" "$i_tmp/original-sobaya.json"
  cp -p "$i_root/sobaya.lock" "$i_tmp/original-sobaya.lock"
  cp -p "$i_root/sobaya.json" "$i_tmp/candidate-sobaya.json"
  cp -p "$i_root/sobaya.lock" "$i_tmp/candidate-sobaya.lock"
  jq --arg version "$target" '.runtime.version=$version' "$i_root/sobaya.json" > "$i_tmp/candidate-sobaya.json"
  jq --argjson pin "$(jq -c .runtime "$i_tmp/candidate.json")" '.runtime=$pin' "$i_root/sobaya.lock" > "$i_tmp/candidate-sobaya.lock"
  ib_collect_configs || i_die 'validation: unsupported Git config path'
  ib_snapshot > "$i_tmp/before" || i_die 'validation: cannot snapshot consumer'
  ib_backup_metadata || i_die 'validation: cannot preserve approval metadata'
  ib_backup_configs || i_die 'validation: cannot preserve hook configuration'
  ib_pending=true
  cp -p "$i_tmp/candidate-sobaya.json" "$i_root/sobaya.json"
  cp -p "$i_tmp/candidate-sobaya.lock" "$i_root/sobaya.lock"
  ib_validate > "$i_tmp/validation.out" 2> "$i_tmp/validation.err" < /dev/null &
  im_child=$!
  wait "$im_child" || rc=$?
  im_child=
  cat "$i_tmp/validation.err" >&2
  if [ "$rc" -ne 0 ]; then cat "$i_tmp/validation.out" >&2; i_die 'validation: candidate suite or hygiene failed'; fi
  for app in sobaya.json sobaya.lock; do
    [ "$(i_pin_stamp "$i_root/$app")" = "$(i_pin_stamp "$i_tmp/candidate-$app")" ] || i_die 'validation: candidate changed the protected pin'
  done
  ib_snapshot > "$i_tmp/after" || i_die 'validation: cannot verify consumer preservation'
  cmp -s "$i_tmp/before" "$i_tmp/after" || i_die 'validation: candidate changed consumer files, Git state or approval metadata; inspect preserved app edits'
  ib_pending=false
  cat "$i_tmp/candidate.json"
}
