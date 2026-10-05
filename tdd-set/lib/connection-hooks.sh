#!/bin/bash
# Private init helpers; originals run with Git's original argv/cwd/environment.
ih_path() {
  local path
  path=$(git -C "$i_app" rev-parse --git-path hooks)
  case "$path" in /*) ;; *) path=$i_app/$path ;; esac
  ir_abs "$path"
}
ih_wrapper() {
  local hook=$1 original=$2
  printf '#!/bin/bash\n# Sobaya connected hook v1\n'
  if [ "$hook" = pre-commit ]; then
    printf 'if [ -x '; printf '%q' "$original/$hook"; printf ' ]; then\n  '
    printf '%q' "$original/$hook"; printf ' "$@" || exit "$?"\nfi\n'
    printf 'exec /bin/bash '; printf '%q' "$i_store/bin/sobaya"
    printf ' __hook --root '; printf '%q' "$i_root"
    printf ' --install-root '; printf '%q' "$i_store"
    printf ' --app '; printf '%q' "$i_app"; printf '\n'
  else
    printf '[ -x '; printf '%q' "$original/$hook"; printf ' ] || exit 0\nexec '
    printf '%q' "$original/$hook"; printf ' "$@"\n'
  fi
}
ih_prepare() {
  local common git_dir raw hook file
  ih_scope=--local
  git_dir=$(git -C "$i_app" rev-parse --absolute-git-dir)
  common=$(git -C "$i_app" rev-parse --git-common-dir)
  case "$common" in /*) ;; *) common=$i_app/$common ;; esac
  common=$(ir_abs "$common")
  if [ "$(git -C "$i_app" config --bool extensions.worktreeConfig || :)" = true ]; then ih_scope=--worktree
  elif [ "$(ir_abs "$git_dir")" != "$common" ] || [ "$(git -C "$i_app" worktree list --porcelain | awk '/^worktree / {n++} END {print n+0}')" -gt 1 ]; then
    i_die 'connection: linked worktree requires existing extensions.worktreeConfig'
  fi
  ih_descriptor=$i_meta/original-hooks.json
  ih_directory=$i_meta/hooks
  if [ -e "$ih_descriptor" ] || [ -L "$ih_descriptor" ]; then
    [ -f "$ih_descriptor" ] && [ ! -L "$ih_descriptor" ] || i_die 'connection: original hook metadata conflict'
    ih_original=$(jq -er --arg scope "$ih_scope" 'select(.hook_version==1 and .scope==$scope)|.original|select(type=="string" and startswith("/"))' "$ih_descriptor") || i_die 'connection: invalid original hook metadata'
    [ "$(ih_path)" = "$ih_directory" ] || i_die 'connection: hook configuration changed outside Sobaya'
  else
    [ ! -e "$ih_directory" ] && [ ! -L "$ih_directory" ] || i_die 'connection: unmanaged hook directory conflict'
    ih_original=$(ih_path)
    [ "$ih_original" != "$ih_directory" ] || i_die 'connection: recursive hook path'
  fi
  [ "$ih_original" = /dev/null ] || [ ! -e "$ih_original" ] || [ -d "$ih_original" ] || i_die 'connection: original hooks path is not a directory'
  for file in "$ih_original"/* "$ih_original"/.[!.]* "$ih_original"/..?*; do
    [ -f "$file" ] && [ -x "$file" ] || continue
    hook=$(basename "$file")
    case "$hook" in
      *.sample|pre-commit|applypatch-msg|pre-applypatch|post-applypatch|pre-merge-commit|prepare-commit-msg|commit-msg|post-commit|pre-rebase|post-checkout|post-merge|pre-push|post-rewrite|reference-transaction|pre-auto-gc|post-index-change|sendemail-validate|fsmonitor-watchman) ;;
      *) i_die "connection: unsupported executable hook $hook" ;;
    esac
  done
  mkdir "$i_tmp/hooks"
  for hook in pre-commit applypatch-msg pre-applypatch post-applypatch pre-merge-commit prepare-commit-msg commit-msg post-commit pre-rebase post-checkout post-merge pre-push post-rewrite reference-transaction pre-auto-gc post-index-change sendemail-validate fsmonitor-watchman; do
    if [ "$hook" = pre-commit ] || [ -x "$ih_original/$hook" ]; then
      ih_wrapper "$hook" "$ih_original" > "$i_tmp/hooks/$hook"
      chmod 755 "$i_tmp/hooks/$hook"
    fi
  done
  if [ -e "$ih_directory" ] || [ -L "$ih_directory" ]; then
    [ -d "$ih_directory" ] && [ ! -L "$ih_directory" ] || i_die 'connection: managed hooks conflict'
    for file in "$ih_directory"/*; do
      [ -f "$file" ] && [ ! -L "$file" ] && [ -x "$file" ] && [ -f "$i_tmp/hooks/$(basename "$file")" ] || i_die 'connection: managed hook changed'
      cmp -s "$file" "$i_tmp/hooks/$(basename "$file")" || i_die 'connection: managed hook changed'
    done
    for file in "$i_tmp/hooks"/*; do [ -f "$ih_directory/$(basename "$file")" ] || i_die 'connection: managed hook missing'; done
  fi
  jq -n --arg scope "$ih_scope" --arg original "$ih_original" '{hook_version:1,scope:$scope,original:$original}' > "$i_tmp/original-hooks.json"
}
ih_apply() {
  if [ ! -d "$ih_directory" ]; then cp -R "$i_tmp/hooks" "$ih_directory"; fi
  i_write "$i_tmp/original-hooks.json" "$ih_descriptor"
  if [ "$(ih_path)" != "$ih_directory" ]; then git -C "$i_app" config "$ih_scope" core.hooksPath "$ih_directory"; fi
}
