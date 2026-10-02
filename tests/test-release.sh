#!/bin/bash
# DRAFT: release packaging tests require human approval before implementation.
set -eu
set -o pipefail
for tool in git jq tar gzip shasum; do command -v "$tool" >/dev/null || { printf 'NOT PROBED: missing %s\n' "$tool" >&2; exit 2; }; done
ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
PACKAGER=${SOBAYA_PACKAGER:-"$ROOT/scripts/package-release.sh"}
case "$PACKAGER" in /*) ;; *) printf 'NOT PROBED: absolute SOBAYA_PACKAGER required\n' >&2; exit 2 ;; esac
[ -f "$PACKAGER" ] || { printf 'NOT PROBED: package-release.sh is absent\n' >&2; exit 2; }
export SOBAYA_PACKAGER="$PACKAGER" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
tree_snapshot() {
  (cd "$1"; find . -print; find . -type f -exec cksum {} \;
    for mask in 4000 2000 1000 400 200 100 040 020 010 004 002 001; do
      find . ! -type l -perm "-$mask" -print | sed "s|^|mode:$mask |"
    done
    while IFS= read -r -d '' link; do printf '%s -> %s\n' "$link" "$(readlink "$link")"; done < <(find . -type l -print0)
  ) | LC_ALL=C sort > "$2"
}
snapshot() {
  tree_snapshot "$SOURCE" "$1"
}
output_snapshot() {
  {
    details=$(LC_ALL=C ls -ld "$OUT")
    printf 'mode %s\n' "${details%% *}"
    if [ -L "$OUT" ]; then printf 'link %s\n' "$(readlink "$OUT")"; fi
    if [ -d "$OUT" ]; then
      tree_snapshot "$OUT" "$WORK/output-tree"
      cat "$WORK/output-tree"
    else
      cksum "$OUT"
    fi
  } > "$1"
}
setup() {
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-package-draft.XXXXXX")
  trap 'rm -rf "$WORK"' EXIT
}
fixture() {
  rm -rf "$WORK/source's path" "$WORK/release" "$WORK/again" "$WORK/unpacked" "$WORK/consumer" "$WORK/target"
  SOURCE="$WORK/source's path"; ARG_SOURCE="$SOURCE"; OUT="$WORK/release"; VERSION=1.0.0-rc.1
  mkdir -p "$SOURCE"
  git -C "$ROOT" archive HEAD | tar -xf - -C "$SOURCE"
  git -C "$SOURCE" init -q
  mkdir -p "$SOURCE/brain" "$SOURCE/apps/private-app" "$SOURCE/references" "$SOURCE/.source-hooks"
  printf 'private brain fixture\n' > "$SOURCE/brain/private.md"
  printf 'private app fixture\n' > "$SOURCE/apps/private-app/private.txt"
  printf 'private reference fixture\n' > "$SOURCE/references/private.txt"
  printf 'human-owned specification\n' > "$SOURCE/spec.md"
  printf 'human-approved plan\n' > "$SOURCE/failed-test.md"
  printf '{}\n' > "$SOURCE/sobaya.json"
  printf '{}\n' > "$SOURCE/sobaya.lock"
  printf '#!/bin/sh\nexit 77\n' > "$SOURCE/.source-hooks/pre-commit"
  chmod 755 "$SOURCE/.source-hooks/pre-commit"
  git -C "$SOURCE" config core.hooksPath .source-hooks
  git -C "$SOURCE" add -f -A .
  git -C "$SOURCE" -c core.hooksPath=/dev/null -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm fixture
  COMMIT=$(git -C "$SOURCE" rev-parse HEAD)
  git -C "$SOURCE" tag "v$VERSION" "$COMMIT"
  mkdir -p "$SOURCE/.git/sobaya"
  printf '{"version":1,"calls":7,"active":null}\n' > "$SOURCE/.git/sobaya/state.json"
}
retag() {
  git -C "$SOURCE" add -f -A .
  git -C "$SOURCE" -c core.hooksPath=/dev/null -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm changed
  COMMIT=$(git -C "$SOURCE" rev-parse HEAD)
  git -C "$SOURCE" tag -f "v$VERSION" "$COMMIT" >/dev/null
}
selected_paths() {
  git -C "$SOURCE" ls-tree -r --name-only "$COMMIT" -- \
    AGENTS.md bin/sobaya .githooks/pre-commit \
    scripts/brain-index.sh scripts/formatter-listing.awk scripts/index-render.awk \
    scripts/probe.sh scripts/setup.sh scripts/tools-common.sh scripts/workspace-check.sh \
    tdd-set/AGENTS.md tdd-set/README.md tdd-set/spec-template.md \
    tdd-set/failed-test-template.md tdd-set/worker-result.schema.json \
    tdd-set/bin/ tdd-set/lib/ tdd-set/hooks/ tdd-set/policies/ tdd-set/skills/
}
invoke() {
  snapshot "$WORK/before"
  if (cd "$WORK"; /bin/bash "$PACKAGER" --source "$ARG_SOURCE" --version "$VERSION" --commit "$COMMIT" --output "$OUT") > "$WORK/stdout" 2> "$WORK/stderr"; then RC=0; else RC=$?; fi
  snapshot "$WORK/after"
  cmp -s "$WORK/before" "$WORK/after" || fail 'packaging changed the source repository'
}
expect_package() {
  invoke
  [ "$RC" -eq 0 ] || fail "valid package returned $RC"
  [ ! -s "$WORK/stderr" ] || fail 'successful package wrote stderr'
  ARCHIVE="$OUT/sobaya-$VERSION.tar.gz"; MANIFEST="$OUT/sobaya-$VERSION.json"
  [ -f "$ARCHIVE" ] && [ -f "$MANIFEST" ] || fail 'release artifacts are missing'
  count=$(find "$OUT" -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')
  [ "$count" -eq 2 ] || fail 'unexpected release output'
  digest=$(shasum -a 256 "$ARCHIVE"); digest=${digest%% *}
  expected=$(jq -cn --arg version "$VERSION" --arg commit "$COMMIT" --arg sha256 "$digest" '{manifest_version:1,artifact:("sobaya-"+$version+".tar.gz"),runtime:{version:$version,commit:$commit,sha256:$sha256}}')
  for file in "$MANIFEST" "$WORK/stdout"; do
    jq -e -s --argjson expected "$expected" 'length == 1 and .[0] == $expected' "$file" >/dev/null || fail 'incorrect release manifest or stdout'
  done
}
expect_invalid() {
  invoke
  [ "$RC" -eq 2 ] || fail "invalid package returned $RC instead of 2"
  [ ! -s "$WORK/stdout" ] || fail 'invalid package wrote stdout'
  grep -Fq -- "$1" "$WORK/stderr" || fail "diagnostic must identify $1"
  [ ! -e "$OUT" ] && [ ! -L "$OUT" ] || fail 'invalid input published output'
}
package_pins_runtime_and_manifest() {
  fixture
  expect_package
  selected_paths | sed 's|^|sobaya/|' | LC_ALL=C sort > "$WORK/expected-paths"
  tar -tzf "$ARCHIVE" | sed '/\/$/d' | LC_ALL=C sort > "$WORK/archive-paths"
  cmp -s "$WORK/expected-paths" "$WORK/archive-paths" || fail 'archive does not match runtime file set'
  mkdir -p "$WORK/unpacked"
  tar -xzf "$ARCHIVE" -C "$WORK/unpacked"
  while IFS= read -r path; do
    file="$WORK/unpacked/sobaya/$path"
    [ -f "$file" ] && [ ! -L "$file" ] || fail "not a regular runtime file: $path"
    git -C "$SOURCE" show "$COMMIT:$path" > "$WORK/blob"
    cmp -s "$WORK/blob" "$file" || fail "wrong committed content: $path"
    mode=$(git -C "$SOURCE" ls-tree "$COMMIT" -- "$path" | awk '{print $1}')
    case "$mode" in 100755) [ -x "$file" ] || fail "executable bit lost: $path" ;; 100644) [ ! -x "$file" ] || fail "unexpected executable: $path" ;; *) fail "unsupported source mode: $path" ;; esac
  done < <(selected_paths)
  mkdir "$WORK/consumer"
  jq -n --arg version "$VERSION" '{config_version:1,mode:"dependency",runtime:{version:$version}}' > "$WORK/consumer/sobaya.json"
  jq '{lock_version:1,runtime:.runtime}' "$MANIFEST" > "$WORK/consumer/sobaya.lock"
  [ ! -e "$WORK/unpacked/sobaya/.git" ] || fail 'Git metadata leaked'
  (cd "$WORK"; "$WORK/unpacked/sobaya/bin/sobaya" config check --root "$WORK/consumer") > "$WORK/check-out" 2> "$WORK/check-err"
  [ ! -s "$WORK/check-err" ] || fail 'unpacked config check wrote stderr'
  expected=$(jq '{config_version:1,mode:"dependency",runtime:.runtime}' "$MANIFEST")
  jq -e -s --argjson expected "$expected" 'length == 1 and .[0] == $expected' "$WORK/check-out" >/dev/null || fail 'unpacked config check failed'
}
package_is_repeatable_from_pinned_commit() {
  fixture
  expect_package
  first="$OUT"
  printf 'dirty working file\n' > "$SOURCE/bin/sobaya"
  printf 'untracked private fixture\n' > "$SOURCE/private-untracked.txt"
  OUT="$WORK/again"
  expect_package
  cmp -s "$first/sobaya-$VERSION.tar.gz" "$ARCHIVE" || fail 'archive changed for the same commit'
  cmp -s "$first/sobaya-$VERSION.json" "$MANIFEST" || fail 'manifest changed for the same commit'
  git -C "$SOURCE" tag -d "v$VERSION" >/dev/null
  git -C "$SOURCE" -c user.name=Fixture -c user.email=fixture@example.invalid tag -a "v$VERSION" -m release "$COMMIT"
  rm -rf "$OUT"
  expect_package
  cmp -s "$first/sobaya-$VERSION.tar.gz" "$ARCHIVE" || fail 'annotated tag changed pinned archive'
  fixture
  printf 'bin/sobaya export-ignore\nAGENTS.md export-subst\n' > "$SOURCE/.gitattributes"
  printf '\n$Format:%%H$\n' >> "$SOURCE/AGENTS.md"
  retag
  expect_package
  for path in bin/sobaya AGENTS.md; do
    tar -xOzf "$ARCHIVE" "sobaya/$path" > "$WORK/archived-blob"
    git -C "$SOURCE" show "$COMMIT:$path" > "$WORK/source-blob"
    cmp -s "$WORK/source-blob" "$WORK/archived-blob" || fail 'export attributes changed runtime bytes'
  done
}
package_rejects_invalid_identity_and_payload() {
  fixture
  for VERSION in latest main '^1.0.0' v1.0.0 01.0.0 '../escape' ''; do expect_invalid version; done
  VERSION=1.0.0-rc.1
  pinned=$COMMIT
  for COMMIT in HEAD main "${pinned:0:7}" 0000000000000000000000000000000000000000; do expect_invalid commit; done
  COMMIT=$pinned
  for ARG_SOURCE in "$WORK/absent" "$SOURCE/tdd-set"; do expect_invalid source; done
  ARG_SOURCE=$SOURCE
  git -C "$SOURCE" tag -d "v$VERSION" >/dev/null
  expect_invalid tag
  git -C "$SOURCE" tag "v$VERSION" "$COMMIT"
  git -C "$SOURCE" -c core.hooksPath=/dev/null -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -qm next
  COMMIT=$(git -C "$SOURCE" rev-parse HEAD)
  expect_invalid tag
  for shape in missing symlink; do
    fixture
    rm "$SOURCE/bin/sobaya"
    if [ "$shape" = symlink ]; then
      printf 'outside fixture\n' > "$WORK/outside-file"
      ln -s "$WORK/outside-file" "$SOURCE/bin/sobaya"
    fi
    retag
    expect_invalid bin/sobaya
  done
  fixture
  git -C "$SOURCE" update-index --add --cacheinfo "160000,$COMMIT,tdd-set/lib/foreign"
  git -C "$SOURCE" -c core.hooksPath=/dev/null -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm gitlink
  COMMIT=$(git -C "$SOURCE" rev-parse HEAD)
  git -C "$SOURCE" tag -f "v$VERSION" "$COMMIT" >/dev/null
  expect_invalid tdd-set/lib/foreign
}
package_preserves_existing_output_and_source() {
  for shape in empty directory file symlink; do
    fixture
    case "$shape" in
      empty) mkdir "$OUT" ;;
      directory) mkdir "$OUT"; printf 'keep\n' > "$OUT/keep" ;;
      file) printf 'keep\n' > "$OUT" ;;
      symlink) mkdir "$WORK/target"; printf 'keep\n' > "$WORK/target/keep"; ln -s "$WORK/target" "$OUT" ;;
    esac
    output_snapshot "$WORK/output-before"
    invoke
    [ "$RC" -eq 2 ] && [ ! -s "$WORK/stdout" ] || fail 'existing output was accepted'
    grep -Fq output "$WORK/stderr" || fail 'missing output diagnostic'
    output_snapshot "$WORK/output-after"
    cmp -s "$WORK/output-before" "$WORK/output-after" || fail 'existing output changed'
  done
  fixture
  OUT="$SOURCE/release"
  expect_invalid output
}
if [ "${1:-}" = __case ]; then
  setup
  "$2"
  exit
fi
failures=0
for name in package_pins_runtime_and_manifest package_is_repeatable_from_pinned_commit package_rejects_invalid_identity_and_payload package_preserves_existing_output_and_source; do
  if /bin/bash "$0" __case "$name"; then
    printf 'PASS: %s\n' "$name"
  else
    printf 'FAIL: %s\n' "$name"
    failures=$((failures + 1))
  fi
done
[ "$failures" -eq 0 ]
