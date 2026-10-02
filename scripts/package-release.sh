#!/bin/bash
# Build a local runtime archive and manifest; never publish or install them.
set -eu
set -o pipefail

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
source_root= version= commit= output=
while [ "$#" -gt 0 ]; do
  [ "$#" -ge 2 ] || die "missing value for $1"
  case "$1" in
    --source) [ -z "$source_root" ] || die 'duplicate source'; source_root=$2 ;;
    --version) [ -z "$version" ] || die 'duplicate version'; version=$2 ;;
    --commit) [ -z "$commit" ] || die 'duplicate commit'; commit=$2 ;;
    --output) [ -z "$output" ] || die 'duplicate output'; output=$2 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift 2
done
[ -n "$source_root" ] || die 'source is required'
[ -n "$version" ] || die 'version is required'
[ -n "$commit" ] || die 'commit is required'
[ -n "$output" ] || die 'output is required'
for tool in git jq gzip shasum; do command -v "$tool" >/dev/null || die "missing $tool"; done
[ ! -e "$output" ] && [ ! -L "$output" ] || die 'output already exists'

paths=(
  AGENTS.md bin/sobaya .githooks/pre-commit
  scripts/brain-index.sh scripts/formatter-listing.awk scripts/index-render.awk
  scripts/probe.sh scripts/setup.sh scripts/tools-common.sh scripts/workspace-check.sh
  tdd-set/AGENTS.md tdd-set/README.md tdd-set/spec-template.md
  tdd-set/failed-test-template.md tdd-set/worker-result.schema.json
  tdd-set/bin/ tdd-set/lib/ tdd-set/hooks/ tdd-set/policies/ tdd-set/skills/
)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-release.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
artifact="sobaya-$version.tar.gz"
manifest="sobaya-$version.json"
# Override export attributes only in a private Git repository, preserving the
# source's configuration and the exact committed runtime bytes.
private="$scratch/repository"
git clone --bare --shared --template= --quiet -- "$source_root" "$private"
mkdir -p "$private/info"
printf '%s\n' '* -export-ignore -export-subst' > "$private/info/attributes"
git -C "$private" -c core.attributesFile=/dev/null archive --format=tar --prefix=sobaya/ "$commit" -- "${paths[@]}" |
  gzip -n > "$scratch/$artifact"
digest=$(shasum -a 256 "$scratch/$artifact"); digest=${digest%% *}
jq -cn --arg artifact "$artifact" --arg version "$version" --arg commit "$commit" --arg sha256 "$digest" \
  '{manifest_version:1,artifact:$artifact,runtime:{version:$version,commit:$commit,sha256:$sha256}}' > "$scratch/$manifest"
mkdir "$output" || die 'cannot create output directory'
mv "$scratch/$artifact" "$scratch/$manifest" "$output/"
cat "$output/$manifest"
