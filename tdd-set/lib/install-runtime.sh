#!/bin/bash
# Standalone bootstrap and private installed-payload verification helpers.
# A separately trusted local manifest is required; hashes are not signatures.
ir_die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
ir_abs() {
  local path=$1 depth=${2:-0} parent leaf target
  [ "$depth" -lt 40 ] || ir_die 'install: too many path components or symlinks'
  case "$path" in /*) ;; *) path=$PWD/$path ;; esac
  while [ "$path" != / ] && [[ $path == */ ]]; do path=${path%/}; done
  if [ -d "$path" ]; then (cd "$path" && pwd -P); return; fi
  parent=$(dirname "$path"); leaf=$(basename "$path")
  parent=$(ir_abs "$parent" "$((depth + 1))") || return
  case "$leaf" in .) printf '%s\n' "$parent"; return ;; ..) dirname "$parent"; return ;; esac
  path=${parent%/}/$leaf
  if [ -L "$path" ]; then
    target=$(readlink "$path") || return
    case "$target" in /*) ;; *) target=$parent/$target ;; esac
    ir_abs "$target" "$((depth + 1))"
  else printf '%s\n' "$path"; fi
}
ir_manifest() {
  jq -ces --arg version "$2" '
    def hex($n): type=="string" and test("\\A[0-9a-f]{\($n)}\\z");
    def version: type=="string" and test("\\A(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-(0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(\\.(0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?\\z");
    if length==1 and (.[0]|type)=="object" then .[0] else error("one manifest object required") end
    | select(.manifest_version==1 and .artifact==("sobaya-"+$version+".tar.gz")
      and .runtime.version==$version and (.runtime.version|version)
      and (.runtime.commit|hex(40)) and (.runtime.sha256|hex(64)))
  ' "$1" || ir_die 'manifest: invalid release identity'
}
ir_hash() { shasum -a 256 "$1" | awk '{print $1}'; }
ir_allowed() {
  case "$1" in
    sobaya/|sobaya/bin/|sobaya/.githooks/|sobaya/scripts/|sobaya/tdd-set/) ;;
    sobaya/AGENTS.md|sobaya/bin/sobaya|sobaya/.githooks/pre-commit) ;;
    sobaya/scripts/brain-index.sh|sobaya/scripts/formatter-listing.awk|sobaya/scripts/index-render.awk|sobaya/scripts/probe.sh|sobaya/scripts/setup.sh|sobaya/scripts/tools-common.sh|sobaya/scripts/workspace-check.sh) ;;
    sobaya/tdd-set/AGENTS.md|sobaya/tdd-set/README.md|sobaya/tdd-set/spec-template.md|sobaya/tdd-set/failed-test-template.md|sobaya/tdd-set/worker-result.schema.json) ;;
    sobaya/tdd-set/bin/|sobaya/tdd-set/bin/*|sobaya/tdd-set/lib/|sobaya/tdd-set/lib/*|sobaya/tdd-set/hooks/|sobaya/tdd-set/hooks/*|sobaya/tdd-set/policies/|sobaya/tdd-set/policies/*|sobaya/tdd-set/skills/|sobaya/tdd-set/skills/*) ;;
    *) return 1 ;;
  esac
}
ir_unpack() {
  local archive=$1 manifest=$2 stage=$3 expected commit name detail type permission path
  unset TAR_OPTIONS
  export LC_ALL=C
  expected=$(jq -r .runtime.sha256 <<< "$manifest")
  [ "$(ir_hash "$archive")" = "$expected" ] || ir_die 'hash: archive does not match manifest'
  gzip -cd "$archive" > "$stage/raw.tar" || ir_die 'archive: invalid gzip stream'
  commit=$(git get-tar-commit-id < "$stage/raw.tar") || ir_die 'archive: missing Git commit marker'
  [ "$commit" = "$(jq -r .runtime.commit <<< "$manifest")" ] || ir_die 'archive: commit marker mismatch'
  tar -tf "$stage/raw.tar" > "$stage/names" || ir_die 'archive: cannot list members'
  tar -tvf "$stage/raw.tar" > "$stage/details" || ir_die 'archive: cannot inspect types'
  [ -s "$stage/names" ] || ir_die 'archive: empty payload'
  [ "$(wc -l < "$stage/names")" -eq "$(wc -l < "$stage/details")" ] || ir_die 'archive: ambiguous members'
  sed 's|/$||' "$stage/names" | sort | uniq -d > "$stage/duplicates"
  [ ! -s "$stage/duplicates" ] || ir_die 'archive: duplicate members'
  exec 8< "$stage/details"
  while IFS= read -r name; do
    [[ $name =~ ^[a-zA-Z0-9._/-]+$ ]] || ir_die 'archive: unsupported member name'
    case "/$name" in *//*/|*//*) ir_die 'archive: repeated path separator' ;; esac
    case "/$name/" in */../*|*/./*) ir_die 'archive: escaping member' ;; esac
    ir_allowed "$name" || ir_die "archive: unexpected member $name"
    IFS= read -r detail <&8 || ir_die 'archive: missing member type'
    type=${detail:0:1}; permission=${detail:0:10}
    case "$type" in
      d) [[ $name == */ ]] || ir_die 'archive: malformed directory' ;;
      -) [[ $name != */ ]] || ir_die 'archive: malformed file' ;;
      *) ir_die 'archive: only regular files and directories allowed' ;;
    esac
    case "$detail" in *" $name") ;; *) ir_die 'archive: ambiguous member listing' ;; esac
    case "$permission" in *s*|*S*|*t*|*T*) ir_die 'archive: special permissions forbidden' ;; esac
    printf '%s %s\n' "$permission" "$name" >> "$stage/members"
  done < "$stage/names"
  exec 8<&-
  for path in AGENTS.md bin/sobaya .githooks/pre-commit scripts/brain-index.sh scripts/formatter-listing.awk scripts/index-render.awk scripts/probe.sh scripts/setup.sh scripts/tools-common.sh scripts/workspace-check.sh tdd-set/AGENTS.md tdd-set/README.md tdd-set/spec-template.md tdd-set/failed-test-template.md tdd-set/worker-result.schema.json; do
    grep -Eq "^-.* sobaya/$path$" "$stage/members" || ir_die "archive: required file missing: $path"
  done
  for path in bin lib hooks policies skills; do
    grep -Fq " sobaya/tdd-set/$path/" "$stage/members" || ir_die "archive: required directory missing: $path"
  done
  mkdir "$stage/runtime"
  # Headers never control extraction destinations, links, owners or modes.
  while IFS=' ' read -r permission name; do
    path=$stage/runtime/${name#sobaya/}
    if [ "${permission:0:1}" = d ]; then mkdir -p "$path"; chmod 755 "$path"
    else
      mkdir -p "$(dirname "$path")"
      tar -xOf "$stage/raw.tar" "$name" > "$path" || ir_die 'archive: cannot read member'
      case "$permission" in *x*) chmod 755 "$path" ;; *) chmod 644 "$path" ;; esac
    fi
  done < "$stage/members"
}
ir_tree() {
  local root=$1 name mode
  (cd "$root"
    find . -print | LC_ALL=C sort > "$2/paths"
    while IFS= read -r name; do
      if [ -L "$name" ]; then ir_die 'install: symlink in installed runtime'
      elif [ -d "$name" ]; then mode=d
      elif [ -f "$name" ]; then mode=$(ir_hash "$name")
      else ir_die 'install: special file in installed runtime'; fi
      printf '%s %s\n' "$name" "$mode"
      for mode in 4000 2000 1000 400 200 100 040 020 010 004 002 001; do
        find "$name" -prune -perm "-$mode" -print | sed "s|^|$mode |"
      done
    done < "$2/paths"
  )
}
ir_existing() {
  local dest=$1 manifest=$2 stage=$3 retained
  [ -d "$dest" ] && [ ! -L "$dest" ] && [ -d "$dest/runtime" ] && [ ! -L "$dest/runtime" ] || ir_die 'install: destination already exists'
  for name in manifest.json archive.tar.gz; do
    [ -f "$dest/$name" ] && [ ! -L "$dest/$name" ] || ir_die 'install: incomplete destination'
  done
  retained=$(ir_manifest "$dest/manifest.json" "$(jq -r .runtime.version <<< "$manifest")") || ir_die 'install: invalid retained manifest'
  [ "$(jq -cS .runtime <<< "$retained")" = "$(jq -cS .runtime <<< "$manifest")" ] || ir_die 'install: different release identity already exists'
  [ "$(ir_hash "$dest/archive.tar.gz")" = "$(jq -r .runtime.sha256 <<< "$manifest")" ] || ir_die 'install: retained archive is altered'
  ir_tree "$dest/runtime" "$stage" > "$stage/actual"
  ir_tree "$stage/runtime" "$stage" > "$stage/expected"
  cmp -s "$stage/actual" "$stage/expected" || ir_die 'install: installed runtime is altered'
}
ir_launcher() {
  printf '#!/bin/bash\n# Sobaya managed launcher v1\nexec /bin/bash '
  printf '%q' "$1/runtimes/$2/runtime/bin/sobaya"
  printf ' "$@"\n'
}
ir_verified_path() (
  set -eu; set -o pipefail
  local store=$1 version=$2 expected=${3:-} manifest stage dest
  dest=$store/runtimes/$version
  [ -d "$dest" ] && [ ! -L "$dest" ] && [ -f "$dest/manifest.json" ] && [ ! -L "$dest/manifest.json" ] || ir_die 'install: selected runtime is not installed'
  manifest=$(ir_manifest "$dest/manifest.json" "$version")
  if [ -n "$expected" ]; then
    [ "$(jq -cS .runtime <<< "$manifest")" = "$(jq -cS . <<< "$expected")" ] || ir_die 'install: lock does not match installed identity'
  fi
  stage=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-verify.XXXXXX")
  trap 'rm -rf "$stage"' EXIT
  [ -f "$dest/archive.tar.gz" ] && [ ! -L "$dest/archive.tar.gz" ] || ir_die 'install: retained archive missing'
  cp "$dest/archive.tar.gz" "$stage/archive.tar.gz"
  ir_unpack "$stage/archive.tar.gz" "$manifest" "$stage"
  ir_existing "$dest" "$manifest" "$stage"
  printf '%s\n' "$dest/runtime"
)
ir_install() (
  set -eu; set -o pipefail
  local_root= store= version= manifest_path= archive=
  while [ "$#" -gt 0 ]; do
    [ "$#" -ge 2 ] || ir_die "install: missing value for $1"
    case "$1" in
      --root) [ -z "$local_root" ] || ir_die 'install: duplicate root'; local_root=$2 ;;
      --install-root) [ -z "$store" ] || ir_die 'install: duplicate install-root'; store=$2 ;;
      --version) [ -z "$version" ] || ir_die 'install: duplicate version'; version=$2 ;;
      --manifest) [ -z "$manifest_path" ] || ir_die 'manifest: duplicate argument'; manifest_path=$2 ;;
      --archive) [ -z "$archive" ] || ir_die 'archive: duplicate argument'; archive=$2 ;;
      *) ir_die "install: unknown argument $1" ;;
    esac
    shift 2
  done
  [ -d "$local_root" ] && [ -n "$store" ] && [ -n "$version" ] && [ -f "$manifest_path" ] || ir_die 'install: root, install-root, version and manifest are required'
  for tool in jq git gzip tar shasum; do command -v "$tool" >/dev/null || ir_die "install: missing $tool"; done
  local_root=$(ir_abs "$local_root"); store=$(ir_abs "$store")
  case "$store/" in "${local_root%/}/"*) ir_die 'install: store must be outside consumer' ;; esac
  manifest=$(ir_manifest "$manifest_path" "$version")
  stage=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-install.XXXXXX")
  trap 'rm -rf "$stage"' EXIT
  dest=$store/runtimes/$version
  # Refuse incomplete/conflicting paths before downloading or publishing.
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    [ -d "$dest" ] && [ ! -L "$dest" ] && [ -f "$dest/manifest.json" ] && [ ! -L "$dest/manifest.json" ] || ir_die 'install: destination already exists'
    [ "$(jq -cS .runtime "$dest/manifest.json")" = "$(jq -cS .runtime <<< "$manifest")" ] || ir_die 'install: conflicting release identity'
  fi
  for path in "$store/runtimes" "$store/bin"; do
    [ ! -L "$path" ] || ir_die 'install: managed path is a symlink'
    [ ! -e "$path" ] || [ -d "$path" ] || ir_die 'install: managed directory conflict'
  done
  if [ -e "$store/bin/sobaya" ] || [ -L "$store/bin/sobaya" ]; then
    [ -f "$store/launcher-version" ] && [ ! -L "$store/launcher-version" ] && [ ! -L "$store/bin/sobaya" ] && [ -f "$store/bin/sobaya" ] && [ -x "$store/bin/sobaya" ] || ir_die 'install: launcher conflict'
    ir_launcher "$store" "$(cat "$store/launcher-version")" > "$stage/launcher"
    cmp -s "$stage/launcher" "$store/bin/sobaya" || ir_die 'install: launcher conflict'
    anchor=$store/runtimes/$(cat "$store/launcher-version")
    ir_manifest "$anchor/manifest.json" "$(cat "$store/launcher-version")" >/dev/null || ir_die 'install: incomplete launcher runtime'
    [ -d "$anchor" ] && [ ! -L "$anchor" ] && [ -d "$anchor/runtime" ] && [ ! -L "$anchor/runtime" ] && [ -f "$anchor/runtime/bin/sobaya" ] && [ ! -L "$anchor/runtime/bin/sobaya" ] && [ -x "$anchor/runtime/bin/sobaya" ] || ir_die 'install: incomplete launcher runtime'
  elif [ -e "$store/launcher-version" ] || [ -L "$store/launcher-version" ] || [ -e "$dest" ]; then ir_die 'install: incomplete launcher'; fi
  if [ -n "$archive" ]; then cp "$archive" "$stage/archive.tar.gz" || ir_die 'archive: cannot read local file'
  else
    curl --fail --location --proto '=https' --proto-redir '=https' --output "$stage/archive.tar.gz" "https://github.com/team-poem/sobaya/releases/download/v$version/sobaya-$version.tar.gz" >&2 || ir_die 'download: release archive failed'
  fi
  ir_unpack "$stage/archive.tar.gz" "$manifest" "$stage"
  if [ -e "$dest" ] || [ -L "$dest" ]; then ir_existing "$dest" "$manifest" "$stage"
  else
    mkdir -p "$store/runtimes" "$store/bin"
    pending=$(mktemp -d "$store/runtimes/.pending.XXXXXX")
    trap 'rm -rf "$stage"; [ -z "${pending:-}" ] || rm -rf "$pending"' EXIT
    mv "$stage/runtime" "$pending/runtime"
    cp "$stage/archive.tar.gz" "$pending/archive.tar.gz"
    printf '%s\n' "$manifest" > "$pending/manifest.json"
    [ ! -e "$dest" ] && [ ! -L "$dest" ] || ir_die 'install: destination conflict'
    mv "$pending" "$dest"; pending=
    if [ ! -f "$store/bin/sobaya" ]; then
      ir_launcher "$store" "$version" > "$store/bin/sobaya"
      chmod 755 "$store/bin/sobaya"
      printf '%s\n' "$version" > "$store/launcher-version"
    fi
  fi
  jq -cn --argjson pin "$(jq -c .runtime <<< "$manifest")" --arg path "$dest/runtime" '{runtime:$pin,runtime_path:$path}'
)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then ir_install "$@"; fi
