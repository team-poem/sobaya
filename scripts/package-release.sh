#!/bin/bash
# Build a local runtime archive and manifest; never publish or install them.
set -eu
set -o pipefail

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
unset source_root version commit output
while [ "$#" -gt 0 ]; do
  [ "$#" -ge 2 ] || die "missing value for $1"
  case "$1" in
    --source) [ "${source_root+x}" != x ] || die 'duplicate source'; source_root=$2 ;;
    --version) [ "${version+x}" != x ] || die 'duplicate version'; version=$2 ;;
    --commit) [ "${commit+x}" != x ] || die 'duplicate commit'; commit=$2 ;;
    --output) [ "${output+x}" != x ] || die 'duplicate output'; output=$2 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift 2
done
[ -n "${source_root:-}" ] || die 'source is required'
[ -n "${version:-}" ] || die 'version is required'
[ -n "${commit:-}" ] || die 'commit is required'
[ -n "${output:-}" ] || die 'output is required'
for tool in git jq gzip shasum; do command -v "$tool" >/dev/null || die "missing $tool"; done
# A trailing slash must not conceal an existing dangling symlink from -L.
while [ "$output" != / ] && [[ $output == */ ]]; do output=${output%/}; done
[ ! -e "$output" ] && [ ! -L "$output" ] || die 'output already exists'
[ -d "$(dirname "$output")" ] || die 'output parent directory must exist'

# An invoking Git hook must not redirect the explicit source/private repository.
git_environment=$(git rev-parse --local-env-vars) || die 'cannot inspect Git environment'
for name in $git_environment; do unset "$name"; done
export GIT_NO_REPLACE_OBJECTS=1 GIT_NO_LAZY_FETCH=1

# The same exact SemVer grammar as config check, without branch/range aliases.
number='(0|[1-9][0-9]*)'
prerelease='(0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)'
version_pattern="^$number[.]$number[.]$number(-$prerelease([.]$prerelease)*)?([+][0-9A-Za-z-]+([.][0-9A-Za-z-]+)*)?$"
[[ $version =~ $version_pattern ]] || die 'version must be an exact release version without a v prefix'
[[ $commit =~ ^[0-9a-fA-F]{40}$ ]] || die 'commit must be a full 40-digit hexadecimal commit'
source "$(cd "$(dirname "$0")" && pwd)/tools-common.sh"
source_root=$(tools_repo "$source_root" 2>/dev/null) || die 'source must be a Git repository root'
output=$(tools_abs "$output" 2>/dev/null) || die 'cannot resolve output path'
case "$output/" in "${source_root%/}/"*) die 'output must be outside source' ;; esac
output_parent=$(dirname "$output")
[ -d "$output_parent" ] || die 'output parent directory must exist'
commit=$(printf '%s' "$commit" | tr 'A-F' 'a-f')
kind=$(git -C "$source_root" cat-file -t "$commit" 2>/dev/null) || die 'commit does not exist'
[ "$kind" = commit ] || die 'commit must identify a commit object'
tag_commit=$(git -C "$source_root" rev-parse --verify "refs/tags/v$version^{commit}" 2>/dev/null) || die 'version tag is missing or does not identify a commit'
[ "$tag_commit" = "$commit" ] || die 'version tag must match commit'

paths=(
  AGENTS.md bin/sobaya .githooks/pre-commit
  scripts/brain-index.sh scripts/formatter-listing.awk scripts/index-render.awk
  scripts/probe.sh scripts/setup.sh scripts/tools-common.sh scripts/workspace-check.sh
  tdd-set/AGENTS.md tdd-set/README.md tdd-set/spec-template.md
  tdd-set/failed-test-template.md tdd-set/worker-result.schema.json
  tdd-set/bin/ tdd-set/lib/ tdd-set/hooks/ tdd-set/policies/ tdd-set/skills/
)
for path in "${paths[@]}"; do
  kind=$(git -C "$source_root" cat-file -t "$commit:${path%/}" 2>/dev/null) || die "missing runtime path: $path"
  case "$path:$kind" in
    */:tree) ;;
    */:*) die "runtime directory required: $path" ;;
    *:blob) ;;
    *) die "runtime file required: $path" ;;
  esac
done
# Stage beside the output, outside the source even when TMPDIR points into it.
scratch=$(mktemp -d "${output_parent%/}/.sobaya-release.XXXXXX") || die 'cannot prepare output'
trap 'rm -rf "$scratch"' EXIT
git -C "$source_root" ls-tree -r -z "$commit" -- "${paths[@]}" > "$scratch/tree" || die 'cannot inspect runtime payload'
while IFS= read -r -d '' record; do
  mode=${record%% *}; path=${record#*$'\t'}
  case "$mode" in
    100644|100755) ;;
    *) die "runtime path must be a regular file: $path" ;;
  esac
done < "$scratch/tree"
artifact="sobaya-$version.tar.gz"
manifest="sobaya-$version.json"
# Override export attributes only in a private Git repository, preserving the
# source's configuration and the exact committed runtime bytes.
private="$scratch/repository"
git clone --bare --shared --template= --quiet -- "$source_root" "$private" || die 'cannot read source repository'
mkdir -p "$private/info" || die 'cannot prepare output repository'
printf '%s\n' '* -export-ignore -export-subst' > "$private/info/attributes" || die 'cannot prepare output attributes'
# Git starts tar modes at 0666/0777; 0022 restores committed 0644/0755 modes.
git -C "$private" -c core.attributesFile=/dev/null -c tar.umask=0022 archive --format=tar --prefix=sobaya/ "$commit" -- "${paths[@]}" |
  gzip -n > "$scratch/$artifact" || die 'cannot archive source runtime payload'
digest=$(shasum -a 256 "$scratch/$artifact") || die 'cannot hash output archive'
digest=${digest%% *}
jq -cn --arg artifact "$artifact" --arg version "$version" --arg commit "$commit" --arg sha256 "$digest" \
  '{manifest_version:1,artifact:$artifact,runtime:{version:$version,commit:$commit,sha256:$sha256}}' > "$scratch/$manifest" || die 'cannot write output manifest'
# mkdir claims only a new directory; never move a directory onto an existing one.
mkdir "$output" || die 'cannot create output directory'
mv "$scratch/$artifact" "$scratch/$manifest" "$output/" || die 'cannot publish output files'
cat "$output/$manifest" || die 'cannot read output manifest'
