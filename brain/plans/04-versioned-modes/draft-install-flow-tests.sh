#!/bin/bash
# DRAFT: installation, connection and bump inputs require human review.
set -eu
set -o pipefail
for tool in git jq tar gzip shasum node mkfifo; do command -v "$tool" >/dev/null || { printf 'NOT PROBED: missing %s\n' "$tool" >&2; exit 2; }; done
ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
INSTALLER=${SOBAYA_INSTALLER:-"$ROOT/tdd-set/lib/install-runtime.sh"}
case "$INSTALLER" in /*) ;; *) printf 'NOT PROBED: absolute installer required\n' >&2; exit 2 ;; esac
[ -f "$INSTALLER" ] || { printf 'NOT PROBED: install-runtime.sh is absent\n' >&2; exit 2; }
export SOBAYA_INSTALLER="$INSTALLER" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
fail() { printf 'FAIL: %s\n' "$*" >&2; [ ! -f "${WORK:-}/stderr" ] || cat "$WORK/stderr" >&2; exit 1; }
same() { cmp -s "$1" "$2" || fail "changed or unequal: $1 / $2"; }
contains() { grep -Fq -- "$2" "$1" || fail "missing <$2> in $1"; }
snapshot() {
  (cd "$1"; find . -print; find . -type f -exec cksum {} \;
    for mask in 4000 2000 1000 400 200 100 040 020 010 004 002 001; do find . ! -type l -perm "-$mask" -print | sed "s|^|mode:$mask |"; done
    while IFS= read -r -d '' link; do printf '%s -> %s\n' "$link" "$(readlink "$link")"; done < <(find . -type l -print0)
  ) | LC_ALL=C sort > "$2"
}
invoke() { if "$@" > "$WORK/stdout" 2> "$WORK/stderr"; then RC=0; else RC=$?; fi; }
okay() { [ "$RC" -eq 0 ] || fail "command exited $RC"; }
invalid() { [ "$RC" -eq 2 ] && [ ! -s "$WORK/stdout" ] || fail 'invalid management command must return 2 without stdout'; contains "$WORK/stderr" "$1"; }
commit_app() {
  git -C "$APP" add -A
  if ! git -C "$APP" diff --cached --quiet; then git -C "$APP" -c core.hooksPath=/dev/null commit -qm fixture; fi
}
identity() { jq -cS .runtime "$1"; }
setup() {
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-flow-draft.XXXXXX")
  trap 'chmod -R u+w "$WORK"; rm -rf "$WORK"' EXIT
  SOURCE="$WORK/source's path"; STORE="$WORK/store with spaces"; CONSUMER="$WORK/consumer"
  V1=1.0.0-rc.1; V2=1.0.0-rc.2
  mkdir -p "$SOURCE" "$CONSUMER" "$WORK/releases" "$WORK/sentinel-bin"
  (cd "$ROOT"; tar -cf - AGENTS.md bin .githooks scripts tdd-set) | tar -xf - -C "$SOURCE"
  sed 's/^contract_suite() {/fixture_contract_suite() {/' "$SOURCE/tdd-set/lib/contract.sh" > "$WORK/contract.fixture"
  grep -q '^fixture_contract_suite() {' "$WORK/contract.fixture" || fail 'fixture cannot instrument the actual suite runner'
  cat "$WORK/contract.fixture" > "$SOURCE/tdd-set/lib/contract.sh"
  cat >> "$SOURCE/tdd-set/lib/contract.sh" <<'TRACE_SUITE'
contract_suite() {
  printf 'runtime-suite:%s\n' "$(cat "$(dirname "${BASH_SOURCE[0]}")/release-fixture-marker")" >> "$FIXTURE_LOG"
  fixture_contract_suite "$@"
}
TRACE_SUITE
  git -C "$SOURCE" init -q
  git -C "$SOURCE" config user.name Fixture
  git -C "$SOURCE" config user.email fixture@example.invalid
  git -C "$SOURCE" config core.hooksPath /dev/null
  for version in "$V1" "$V2"; do
    printf '%s\n' "$version" > "$SOURCE/tdd-set/lib/release-fixture-marker"
    git -C "$SOURCE" add -A; git -C "$SOURCE" commit -qm "$version"
    revision=$(git -C "$SOURCE" rev-parse HEAD)
    git -C "$SOURCE" tag "v$version" "$revision"
    /bin/bash "$ROOT/scripts/package-release.sh" --source "$SOURCE" --version "$version" --commit "$revision" --output "$WORK/releases/$version" >/dev/null
  done
  cat > "$WORK/sentinel-bin/curl" <<'SENTINEL'
#!/bin/bash
printf 'unexpected network\n' >> "$NETWORK_LOG"
exit 93
SENTINEL
  cp "$WORK/sentinel-bin/curl" "$WORK/sentinel-bin/codex"
  chmod 755 "$WORK/sentinel-bin/curl" "$WORK/sentinel-bin/codex"
  export NETWORK_LOG="$WORK/network.log" PATH="$WORK/sentinel-bin:$PATH"
  export FIXTURE_LOG="$WORK/events" FIXTURE_PROMPTS="$WORK/prompts" FIXTURE_ROOT="$CONSUMER"
  : > "$FIXTURE_LOG"; : > "$FIXTURE_PROMPTS"
  cat > "$WORK/worker.sh" <<'WORKER'
#!/bin/bash
set -eu
cat >> "$FIXTURE_PROMPTS"
printf 'worker:%s\n' "$SOBAYA_ROLE" >> "$FIXTURE_LOG"
if [ "$SOBAYA_ROLE" = implement ]; then
  printf 'exports.add = (a, b) => a + b;\n' > "$SOBAYA_APP/impl.js"
  if [ "${FIXTURE_TAMPER:-0}" = 1 ]; then
    jq '.runtime.version="9.0.0"' "$FIXTURE_ROOT/sobaya.json" > "$FIXTURE_ROOT/pin.tmp"
    mv "$FIXTURE_ROOT/pin.tmp" "$FIXTURE_ROOT/sobaya.json"
  fi
fi
printf '%s\n' '{"status":"done","summary":"Fixture implementation or independent review","reason":""}'
WORKER
  jq -n --arg worker "$WORK/worker.sh" '{version:1,mode:"selected",default_worker:"fixture",review_worker:"fixture",max_calls:5,timeout_seconds:20,workers:{fixture:{adapter:"command",command:["/bin/bash",$worker],model:"fixture",guidance:"guided"}},escalation:[]}' > "$WORK/policy.json"
}
manifest() { printf '%s/releases/%s/sobaya-%s.json\n' "$WORK" "$1" "$1"; }
archive() { printf '%s/releases/%s/sobaya-%s.tar.gz\n' "$WORK" "$1" "$1"; }
install_version() {
  invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$1" --manifest "$(manifest "$1")" --archive "$(archive "$1")"
  okay
  jq -e -s --argjson pin "$(identity "$(manifest "$1")")" --arg path "$STORE/runtimes/$1/runtime" 'length==1 and .[0].runtime==$pin and .[0].runtime_path==$path' "$WORK/stdout" >/dev/null || fail 'incorrect installed identity/path'
  [ -x "$STORE/bin/sobaya" ] || fail 'stable launcher is missing'
}
cli() { invoke "$STORE/bin/sobaya" "$1" --root "$CONSUMER" --install-root "$STORE" "${@:2}"; }
app_fixture() {
  MODE=$1
  if [ "$MODE" = project ]; then
    APP="$CONSUMER/apps/calculator"; mkdir -p "$CONSUMER/brain" "$APP"
    printf 'existing knowledge\n' > "$CONSUMER/brain/keep.md"
    printf '# Existing workspace instructions\n' > "$CONSUMER/AGENTS.md"
    git -C "$CONSUMER" init -q
    printf '/apps/\n' > "$CONSUMER/.gitignore"
    git -C "$CONSUMER" add .; git -C "$CONSUMER" -c user.name=Fixture -c user.email=fixture@example.invalid -c core.hooksPath=/dev/null commit -qm workspace
  else APP="$CONSUMER"; fi
  git -C "$APP" init -q
  git -C "$APP" config user.name Fixture
  git -C "$APP" config user.email fixture@example.invalid
  git -C "$APP" config commit.gpgsign false
  printf '# Existing app\n- Test: `node --test suite.test.js`\n- Lint: `node lint.cjs`\n' > "$APP/AGENTS.md"
  printf 'require("node:fs").appendFileSync(process.env.FIXTURE_LOG, "lint\\n"); process.exit(process.env.FIXTURE_LINT === "fail" ? 1 : 0);\n' > "$APP/lint.cjs"
  printf '# Goal\nAdd two positive integers.\n' > "$APP/spec.md"
  printf 'exports.add = (a, b) => 0;\n' > "$APP/impl.js"
  cat > "$APP/suite.test.js" <<'BASE_TEST'
// file: suite.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
test('existingBaseline', () => {
  const version = JSON.parse(fs.readFileSync(path.join(process.env.FIXTURE_ROOT, 'sobaya.json'))).runtime.version;
  fs.appendFileSync(process.env.FIXTURE_LOG, 'suite:' + version + '\n');
  fs.appendFileSync(process.env.FIXTURE_LOG, 'suite-app:' + __dirname + ':' + version + '\n');
  assert.notEqual(process.env.FIXTURE_SUITE, 'fail');
});
BASE_TEST
  cat > "$APP/failed-test.md" <<'PLAN'
# Plan
## Add
```js
// file: suite.test.js
```
- [ ] installedAdds — sums inputs
```js
test('installedAdds', () => assert.equal(require('./impl.js').add(1, 2), 3));
```
PLAN
  mkdir -p "$APP/apps/existing-subproject"
  printf 'existing layout\n' > "$APP/apps/existing-subproject/keep.txt"
  [ "$MODE" != dependency ] || printf '{"private":true}\n' > "$APP/apps/existing-subproject/package.json"
  commit_app
  META=$(git -C "$APP" rev-parse --absolute-git-dir)/sobaya
  export FIXTURE_LINT=pass FIXTURE_SUITE=pass FIXTURE_TAMPER=0
}
connect() {
  if [ "$MODE" = project ]; then cli init --mode "$MODE" --version "$V1" --app "$APP"
  else cli init --mode "$MODE" --version "$V1"; fi
  okay
}
seal_connection() {
  commit_app
  if [ "$MODE" = project ]; then
    git -C "$CONSUMER" add .
    if ! git -C "$CONSUMER" diff --cached --quiet; then git -C "$CONSUMER" -c user.name=Fixture -c user.email=fixture@example.invalid -c core.hooksPath=/dev/null commit -qm connection; fi
  fi
}
runtime_cli() {
  if [ "$MODE" = project ]; then cli "$1" --app "$APP" "${@:2}"
  else cli "$1" "${@:2}"; fi
}
assert_pin() { identity "$CONSUMER/sobaya.lock" > "$WORK/pin.actual"; identity "$(manifest "$1")" > "$WORK/pin.expected"; same "$WORK/pin.actual" "$WORK/pin.expected"; }
assert_no_network() { [ ! -e "$NETWORK_LOG" ] || fail 'local execution invoked network/provider'; }

install_pins_real_release_and_transport() {
  printf 'keep\n' > "$CONSUMER/AGENTS.md"
  snapshot "$CONSUMER" "$WORK/consumer.before"
  install_version "$V1"
  RUNTIME="$STORE/runtimes/$V1/runtime"
  [ ! -e "$RUNTIME/.git" ] || fail 'installed runtime contains Git metadata'
  contains "$RUNTIME/tdd-set/lib/release-fixture-marker" "$V1"
  same "$(archive "$V1")" "$STORE/runtimes/$V1/archive.tar.gz"
  tar -tzf "$(archive "$V1")" | sed '/\/$/d;s|^sobaya/||' > "$WORK/members"
  while IFS= read -r file; do tar -xOzf "$(archive "$V1")" "sobaya/$file" > "$WORK/blob"; same "$WORK/blob" "$RUNTIME/$file"; done < "$WORK/members"
  [ -x "$RUNTIME/bin/sobaya" ] && [ ! -x "$RUNTIME/AGENTS.md" ] || fail 'installed executable distinction changed'
  snapshot "$CONSUMER" "$WORK/consumer.after"; same "$WORK/consumer.before" "$WORK/consumer.after"
  snapshot "$STORE" "$WORK/store.before"; install_version "$V1"; snapshot "$STORE" "$WORK/store.after"; same "$WORK/store.before" "$WORK/store.after"
  cat > "$WORK/sentinel-bin/curl" <<'CURL'
#!/bin/bash
set -eu
printf '%s\n' "$@" > "$CURL_ARGS"
out=
while [ "$#" -gt 0 ]; do
  case "$1" in --output|-o) out=$2; shift 2 ;; *) url=$1; shift ;; esac
done
[ "$url" = "https://github.com/team-poem/sobaya/releases/download/v1.0.0-rc.2/sobaya-1.0.0-rc.2.tar.gz" ] || exit 94
cp "$CURL_ARCHIVE" "$out"
CURL
  export CURL_ARGS="$WORK/curl-args" CURL_ARCHIVE="$(archive "$V2")"
  invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V2" --manifest "$(manifest "$V2")"
  okay; contains "$CURL_ARGS" '--fail'; contains "$CURL_ARGS" '--proto'; contains "$CURL_ARGS" '=https'; contains "$CURL_ARGS" '--proto-redir'
  same "$(archive "$V2")" "$STORE/runtimes/$V2/archive.tar.gz"
}
install_rejects_identity_and_unsafe_payload() {
  install_version "$V1"; snapshot "$STORE" "$WORK/store.before"
  for filter in '.manifest_version=2' '.artifact="../escape"' '.runtime.version="latest"' '.runtime.commit="HEAD"' '.runtime.sha256="bad"' '.runtime.sha256=("0"*64)' '.runtime.commit=("0"*40)'; do
    jq "$filter" "$(manifest "$V2")" > "$WORK/bad.json"
    invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V2" --manifest "$WORK/bad.json" --archive "$(archive "$V2")"
    [ "$RC" -eq 2 ] && [ ! -s "$WORK/stdout" ] && [ -s "$WORK/stderr" ] || fail 'invalid release identity accepted'
    snapshot "$STORE" "$WORK/store.after"; same "$WORK/store.before" "$WORK/store.after"
  done
  cat "$(manifest "$V2")" "$(manifest "$V2")" > "$WORK/bad.json"
  invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V2" --manifest "$WORK/bad.json" --archive "$(archive "$V2")"
  invalid manifest
  for shape in missing symlink unexpected duplicate hardlink fifo traversal absolute; do
    git -C "$SOURCE" reset --hard -q "v$V2"
    case "$shape" in
      missing) rm "$SOURCE/bin/sobaya" ;;
      symlink) printf 'keep\n' > "$WORK/outside"; ln -s "$WORK/outside" "$SOURCE/tdd-set/lib/unsafe" ;;
      unexpected) printf 'private\n' > "$SOURCE/private.txt" ;;
    esac
    git -C "$SOURCE" add -A; git -C "$SOURCE" commit --allow-empty -qm "$shape"
    revision=$(git -C "$SOURCE" rev-parse HEAD)
    git -C "$SOURCE" ls-tree -r --name-only "$revision" -- \
      AGENTS.md bin/sobaya .githooks/pre-commit scripts/brain-index.sh \
      scripts/formatter-listing.awk scripts/index-render.awk scripts/probe.sh \
      scripts/setup.sh scripts/tools-common.sh scripts/workspace-check.sh \
      tdd-set/AGENTS.md tdd-set/README.md tdd-set/spec-template.md \
      tdd-set/failed-test-template.md tdd-set/worker-result.schema.json \
      tdd-set/bin/ tdd-set/lib/ tdd-set/hooks/ tdd-set/policies/ tdd-set/skills/ > "$WORK/payload-paths"
    payload=(); while IFS= read -r file; do payload+=("$file"); done < "$WORK/payload-paths"
    [ "$shape" != unexpected ] || payload+=(private.txt)
    git -C "$SOURCE" archive --format=tar --prefix=sobaya/ "$revision" -- "${payload[@]}" > "$WORK/unsafe.tar"
    extra="$WORK/member-$shape"; mkdir -p "$extra/sobaya/bin" "$extra/sobaya/tdd-set/lib"
    printf 'keep\n' > "$WORK/absolute-target"
    case "$shape" in
      duplicate)
        printf 'duplicate\n' > "$extra/sobaya/bin/sobaya"
        COPYFILE_DISABLE=1 tar -rf "$WORK/unsafe.tar" -C "$extra" sobaya/bin/sobaya
        [ "$(tar -tf "$WORK/unsafe.tar" | grep -Fxc sobaya/bin/sobaya)" -eq 2 ] || fail 'duplicate fixture did not contain two members' ;;
      hardlink)
        printf 'linked\n' > "$extra/sobaya/tdd-set/lib/link-source"
        ln "$extra/sobaya/tdd-set/lib/link-source" "$extra/sobaya/tdd-set/lib/unsafe"
        COPYFILE_DISABLE=1 tar -rf "$WORK/unsafe.tar" -C "$extra" sobaya/tdd-set/lib/link-source sobaya/tdd-set/lib/unsafe
        tar -tvf "$WORK/unsafe.tar" > "$WORK/listing"; grep -Eq '^h.*sobaya/tdd-set/lib/unsafe' "$WORK/listing" || fail 'hardlink fixture type missing' ;;
      fifo)
        mkfifo "$extra/sobaya/tdd-set/lib/unsafe"
        COPYFILE_DISABLE=1 tar -rf "$WORK/unsafe.tar" -C "$extra" sobaya/tdd-set/lib/unsafe
        tar -tvf "$WORK/unsafe.tar" > "$WORK/listing"; grep -Eq '^p.*sobaya/tdd-set/lib/unsafe' "$WORK/listing" || fail 'fifo fixture type missing' ;;
      traversal|absolute)
        printf 'escape\n' > "$extra/member-content"
        member=sobaya/../../outside; [ "$shape" != absolute ] || member="$WORK/absolute-target"
        case "$(tar --version)" in
          bsdtar*) COPYFILE_DISABLE=1 tar -rPf "$WORK/unsafe.tar" -s ",^member-content$,$member," -C "$extra" member-content ;;
          *'GNU tar'*) tar -rPf "$WORK/unsafe.tar" --transform="s,^member-content$,$member," -C "$extra" member-content ;;
          *) fail 'unsupported tar fixture generator' ;;
        esac
        tar -tf "$WORK/unsafe.tar" > "$WORK/listing"; grep -Fxq "$member" "$WORK/listing" || fail 'unsafe fixture path was normalized away' ;;
    esac
    [ "$(git get-tar-commit-id < "$WORK/unsafe.tar")" = "$revision" ] || fail 'unsafe fixture lost its commit marker'
    gzip -n < "$WORK/unsafe.tar" > "$WORK/unsafe.tar.gz"
    digest=$(shasum -a 256 "$WORK/unsafe.tar.gz"); digest=${digest%% *}
    jq --arg commit "$revision" --arg sha "$digest" '.runtime.commit=$commit|.runtime.sha256=$sha' "$(manifest "$V2")" > "$WORK/bad.json"
    invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V2" --manifest "$WORK/bad.json" --archive "$WORK/unsafe.tar.gz"
    invalid archive
    snapshot "$STORE" "$WORK/store.after"; same "$WORK/store.before" "$WORK/store.after"
    [ "$shape" != symlink ] || [ "$(cat "$WORK/outside")" = keep ] || fail 'archive followed outside symlink'
    [ "$(cat "$WORK/absolute-target")" = keep ] || fail 'archive wrote an absolute path'
  done
}
install_preserves_existing_paths_and_failed_downloads() {
  install_version "$V1"; snapshot "$STORE" "$WORK/store.before"
  for shape in directory file symlink dangling; do
    dest="$STORE/runtimes/$V2"
    case "$shape" in directory) mkdir "$dest" ;; file) printf 'keep\n' > "$dest" ;; symlink) mkdir "$WORK/target"; ln -s "$WORK/target" "$dest" ;; dangling) ln -s "$WORK/absent" "$dest" ;; esac
    snapshot "$STORE" "$WORK/conflict.before"
    invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V2" --manifest "$(manifest "$V2")" --archive "$(archive "$V2")"
    invalid install
    snapshot "$STORE" "$WORK/conflict.after"; same "$WORK/conflict.before" "$WORK/conflict.after"
    [ ! -e "$WORK/absent" ] || fail 'dangling target created'
    [ "$shape" != symlink ] || [ -z "$(ls -A "$WORK/target")" ] || fail 'symlink target changed'
    if [ -L "$dest" ] || [ -f "$dest" ]; then rm "$dest"; else rmdir "$dest"; fi
  done
  invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$CONSUMER/cache" --version "$V1" --manifest "$(manifest "$V1")" --archive "$(archive "$V1")"
  invalid install
  [ ! -e "$CONSUMER/cache" ] || fail 'consumer-contained store was created'
  cat > "$WORK/sentinel-bin/curl" <<'CURL_FAIL'
#!/bin/bash
while [ "$#" -gt 0 ]; do
  case "$1" in --output|-o) printf partial > "$2"; break ;; esac
  shift
done
exit 22
CURL_FAIL
  invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V2" --manifest "$(manifest "$V2")"
  invalid download
  snapshot "$STORE" "$WORK/store.after"; same "$WORK/store.before" "$WORK/store.after"
  [ -x "$STORE/runtimes/$V1/runtime/bin/sobaya" ] || fail 'previous runtime lost'
  jq --arg version "$V1" '.artifact=("sobaya-"+$version+".tar.gz")|.runtime.version=$version' "$(manifest "$V2")" > "$WORK/rebound.json"
  invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V1" --manifest "$WORK/rebound.json" --archive "$(archive "$V2")"
  invalid install
  snapshot "$STORE" "$WORK/store.after"; same "$WORK/store.before" "$WORK/store.after"
  chmod u+w "$STORE/runtimes/$V1/runtime/bin/sobaya"
  printf 'tampered installed executable\n' > "$STORE/runtimes/$V1/runtime/bin/sobaya"
  snapshot "$STORE" "$WORK/tampered.before"
  invoke /bin/bash "$INSTALLER" --root "$CONSUMER" --install-root "$STORE" --version "$V1" --manifest "$(manifest "$V1")" --archive "$(archive "$V1")"
  invalid install
  snapshot "$STORE" "$WORK/tampered.after"; same "$WORK/tampered.before" "$WORK/tampered.after"
}
init_connects_both_modes_without_rewriting_contracts() {
  install_version "$V1"
  for mode in dependency project; do
    CONSUMER="$WORK/$mode"; mkdir "$CONSUMER"; export FIXTURE_ROOT="$CONSUMER"
    app_fixture "$mode"
    cp "$CONSUMER/AGENTS.md" "$WORK/workspace-agents.saved"
    for file in AGENTS.md spec.md failed-test.md; do cp "$APP/$file" "$WORK/$file.saved"; done
    connect; assert_pin "$V1"
    jq -e --arg mode "$mode" --arg version "$V1" '.config_version==1 and .mode==$mode and .runtime.version==$version' "$CONSUMER/sobaya.json" >/dev/null || fail 'wrong mode configuration'
    for file in AGENTS.md spec.md failed-test.md; do same "$APP/$file" "$WORK/$file.saved"; done
    same "$CONSUMER/AGENTS.md" "$WORK/workspace-agents.saved"
    snapshot "$CONSUMER" "$WORK/connected.before"; connect; snapshot "$CONSUMER" "$WORK/connected.after"; same "$WORK/connected.before" "$WORK/connected.after"
    [ "$mode" != dependency ] || [ ! -e "$CONSUMER/brain" ] || fail 'dependency mode created brain'
    contains "$APP/apps/existing-subproject/keep.txt" 'existing layout'
    [ "$mode" != project ] || contains "$CONSUMER/brain/keep.md" 'existing knowledge'
    [ ! -e "$META/state.json" ] || fail 'init invented test approval'
  done
  assert_no_network
}
connected_hooks_preserve_original_behavior() {
  install_version "$V1"; app_fixture dependency
  mkdir "$APP/custom-hooks"
  cat > "$WORK/original-pre" <<'PRE'
#!/bin/bash
printf 'original-pre\n' >> "$FIXTURE_LOG"
[ "${FIXTURE_ORIGINAL:-pass}" != fail ] || exit 17
PRE
  chmod 755 "$WORK/original-pre"
  ln -s "$WORK/original-pre" "$APP/custom-hooks/pre-commit"
  cat > "$APP/custom-hooks/commit-msg" <<'MESSAGE_HOOK'
#!/bin/bash
set -eu
[ "$#" -eq 1 ] && [ -f "$1" ] || exit 18
printf 'original-message:%s\n' "$(head -n 1 "$1")" >> "$FIXTURE_LOG"
MESSAGE_HOOK
  chmod 755 "$APP/custom-hooks/commit-msg"
  git -C "$APP" config core.hooksPath custom-hooks
  commit_app; snapshot "$APP/custom-hooks" "$WORK/hooks.before"; cp "$WORK/original-pre" "$WORK/original.saved"
  connect; seal_connection
  before=$(git -C "$APP" rev-parse HEAD)
  printf 'user change\n' > "$APP/user.txt"; git -C "$APP" add user.txt
  : > "$FIXTURE_LOG"
  export FIXTURE_ORIGINAL=fail
  invoke git -C "$APP" commit -m blocked-original
  [ "$RC" -ne 0 ] && [ "$(git -C "$APP" rev-parse HEAD)" = "$before" ] || fail 'original pre-commit failure bypassed'
  printf 'original-pre\n' > "$WORK/expected-events"; same "$FIXTURE_LOG" "$WORK/expected-events"
  : > "$FIXTURE_LOG"
  export FIXTURE_ORIGINAL=pass FIXTURE_LINT=fail
  invoke git -C "$APP" commit -m blocked-lint
  [ "$RC" -ne 0 ] && [ "$(git -C "$APP" rev-parse HEAD)" = "$before" ] || fail 'Sobaya lint failure bypassed'
  printf 'original-pre\nlint\n' > "$WORK/expected-events"; same "$FIXTURE_LOG" "$WORK/expected-events"
  : > "$FIXTURE_LOG"
  export FIXTURE_LINT=pass
  invoke git -C "$APP" commit -m both-pass; okay
  head -n 2 "$FIXTURE_LOG" > "$WORK/actual-events"; same "$WORK/actual-events" "$WORK/expected-events"
  contains "$FIXTURE_LOG" original-message:both-pass
  snapshot "$APP/custom-hooks" "$WORK/hooks.after"; same "$WORK/hooks.before" "$WORK/hooks.after"; same "$WORK/original-pre" "$WORK/original.saved"
  assert_no_network
}
connection_keeps_linked_worktree_hooks_isolated() {
  install_version "$V1"; app_fixture dependency
  main=$APP
  mkdir "$WORK/main-hooks" "$WORK/linked-hooks"
  printf '#!/bin/bash\nprintf "main-hook\\n" >> "$FIXTURE_LOG"\n' > "$WORK/main-hooks/pre-commit"
  printf '#!/bin/bash\nprintf "linked-hook\\n" >> "$FIXTURE_LOG"\n' > "$WORK/linked-hooks/pre-commit"
  chmod 755 "$WORK/main-hooks/pre-commit" "$WORK/linked-hooks/pre-commit"
  git -C "$main" config extensions.worktreeConfig true
  git -C "$main" config --worktree core.hooksPath "$WORK/main-hooks"
  git -C "$main" worktree add -q -b fixture-linked "$WORK/linked"
  git -C "$WORK/linked" config --worktree core.hooksPath "$WORK/linked-hooks"
  cp "$main/.git/config" "$WORK/common-config.saved"
  cp "$main/.git/config.worktree" "$WORK/main-config.saved"
  CONSUMER="$WORK/linked"; APP=$CONSUMER; META=$(git -C "$APP" rev-parse --absolute-git-dir)/sobaya
  export FIXTURE_ROOT="$CONSUMER"
  connect; seal_connection
  same "$main/.git/config" "$WORK/common-config.saved"; same "$main/.git/config.worktree" "$WORK/main-config.saved"
  [ "$(git -C "$main" config --get core.hooksPath)" = "$WORK/main-hooks" ] || fail 'linked init changed main hook selection'
  : > "$FIXTURE_LOG"
  invoke git -C "$main" commit --allow-empty -m main-still-independent; okay
  printf 'main-hook\n' > "$WORK/expected-events"; same "$FIXTURE_LOG" "$WORK/expected-events"
  : > "$FIXTURE_LOG"
  invoke git -C "$APP" commit --allow-empty -m linked-connected; okay
  printf 'linked-hook\nlint\n' > "$WORK/expected-events"; same "$FIXTURE_LOG" "$WORK/expected-events"
  [ ! -e "$main/.git/sobaya/state.json" ] || fail 'connection created main approval'
  assert_no_network
}
installed_modes_execute_approved_cycle() {
  install_version "$V1"
  for mode in dependency project; do
    CONSUMER="$WORK/run-$mode"; mkdir "$CONSUMER"; export FIXTURE_ROOT="$CONSUMER"
    app_fixture "$mode"; connect; seal_connection
    baseline=$(git -C "$APP" rev-parse HEAD)
    runtime_cli doctor --policy "$WORK/policy.json"; okay
    runtime_cli approve; okay
    runtime_cli loop --policy "$WORK/policy.json"; okay
    contains "$WORK/stdout" RED; contains "$WORK/stdout" PASS
    runtime_cli gate; okay
    head=$(git -C "$APP" rev-parse HEAD)
    jq -e --arg baseline "$baseline" --arg head "$head" '.version==1 and .baseline==$baseline and .calls==2 and .status=="complete" and .review.head==$head' "$META/state.json" >/dev/null || fail 'checkpoint/review/usage continuity failed'
    contains "$APP/failed-test.md" '[x] installedAdds'
    contains "$FIXTURE_PROMPTS" "$STORE/runtimes/$V1/runtime/tdd-set/AGENTS.md"
    contains "$FIXTURE_PROMPTS" "$APP/AGENTS.md"
    [ -z "$(git -C "$APP" status --porcelain)" ] || fail 'completed app is dirty'
    snapshot "$META" "$WORK/state.before"; runtime_cli status; okay; snapshot "$META" "$WORK/state.after"; same "$WORK/state.before" "$WORK/state.after"
  done
  assert_no_network
}
dispatch_rejects_pin_drift_and_worker_mutation() {
  install_version "$V1"; install_version "$V2"; app_fixture dependency; connect; seal_connection
  runtime_cli approve; okay; baseline=$(git -C "$APP" rev-parse HEAD)
  cp "$CONSUMER/sobaya.lock" "$WORK/lock.saved"; snapshot "$META" "$WORK/state.before"
  jq '.runtime.sha256=("0"*64)' "$WORK/lock.saved" > "$CONSUMER/sobaya.lock"
  runtime_cli status
  [ "$RC" -ne 0 ] || fail 'uninstalled identity fell back to another runtime'
  snapshot "$META" "$WORK/state.after"; same "$WORK/state.before" "$WORK/state.after"
  cp "$WORK/lock.saved" "$CONSUMER/sobaya.lock"
  export FIXTURE_TAMPER=1
  runtime_cli step --policy "$WORK/policy.json"
  [ "$RC" -ne 0 ] || fail 'worker changed pinned version and passed checkpoint'
  grep -iq protect "$WORK/stderr" || fail 'pin mutation did not report protected-input rejection'
  [ "$(git -C "$APP" rev-parse HEAD)" = "$baseline" ] || fail 'pin mutation was committed'
  jq -e --arg baseline "$baseline" '.baseline==$baseline and .calls==1 and .active.entry=="installedAdds"' "$META/state.json" >/dev/null || fail 'pin mutation reset or advanced approval'
  contains "$APP/failed-test.md" '[ ] installedAdds'
  assert_no_network
}
sync_uses_reviewed_lock_without_repinning() {
  install_version "$V1"; app_fixture dependency; connect; seal_connection
  snapshot "$CONSUMER" "$WORK/consumer.before"
  original_store=$STORE; STORE="$WORK/second-store"
  invoke "$original_store/bin/sobaya" sync --root "$CONSUMER" --install-root "$STORE" --archive "$(archive "$V1")"
  okay; assert_pin "$V1"
  [ -x "$STORE/runtimes/$V1/runtime/bin/sobaya" ] || fail 'sync did not install the locked runtime'
  snapshot "$CONSUMER" "$WORK/consumer.after"; same "$WORK/consumer.before" "$WORK/consumer.after"
  STORE="$WORK/third-store"
  invoke "$original_store/bin/sobaya" sync --root "$CONSUMER" --install-root "$STORE" --archive "$(archive "$V2")"
  invalid hash
  [ ! -e "$STORE/runtimes/$V1" ] || fail 'sync published mismatched archive'
  snapshot "$CONSUMER" "$WORK/consumer.after"; same "$WORK/consumer.before" "$WORK/consumer.after"
  assert_no_network
}
bump_validates_candidate_and_preserves_approval() {
  install_version "$V1"; app_fixture dependency; connect; seal_connection
  runtime_cli approve; okay; runtime_cli loop --policy "$WORK/policy.json"; okay
  jq '.custom={keep:"yes"}' "$CONSUMER/sobaya.json" > "$WORK/config.new"; mv "$WORK/config.new" "$CONSUMER/sobaya.json"; commit_app
  snapshot "$META" "$WORK/state.before"; cp "$CONSUMER/sobaya.json" "$WORK/config.saved"; cp "$CONSUMER/sobaya.lock" "$WORK/lock.saved"
  before=$(git -C "$APP" rev-parse HEAD)
  : > "$FIXTURE_LOG"
  cli bump --version "$V2" --manifest "$(manifest "$V2")" --archive "$(archive "$V2")"; okay
  assert_pin "$V2"; contains "$FIXTURE_LOG" "suite:$V2"
  contains "$FIXTURE_LOG" "runtime-suite:$V2"
  contains "$FIXTURE_LOG" lint
  jq -e --arg version "$V2" '.runtime.version==$version and .mode=="dependency" and .custom.keep=="yes"' "$CONSUMER/sobaya.json" >/dev/null || fail 'bump damaged configuration'
  snapshot "$META" "$WORK/state.after"; same "$WORK/state.before" "$WORK/state.after"
  [ "$(git -C "$APP" rev-parse HEAD)" = "$before" ] || fail 'bump committed or reapproved automatically'
  git -C "$APP" diff --name-only | LC_ALL=C sort > "$WORK/changed"
  printf 'sobaya.json\nsobaya.lock\n' > "$WORK/expected-changed"; same "$WORK/changed" "$WORK/expected-changed"
  runtime_cli status; okay
  assert_no_network
}
bump_failure_and_active_entry_keep_previous_pin() {
  install_version "$V1"; app_fixture dependency; connect; seal_connection
  runtime_cli approve; okay
  cp "$CONSUMER/sobaya.json" "$WORK/config.saved"; cp "$CONSUMER/sobaya.lock" "$WORK/lock.saved"; snapshot "$META" "$WORK/state.before"
  for failure in suite lint; do
    export FIXTURE_SUITE=pass FIXTURE_LINT=pass
    if [ "$failure" = suite ]; then export FIXTURE_SUITE=fail; else export FIXTURE_LINT=fail; fi
    : > "$FIXTURE_LOG"
    cli bump --version "$V2" --manifest "$(manifest "$V2")" --archive "$(archive "$V2")"
    invalid validation; contains "$FIXTURE_LOG" "suite:$V2"
    contains "$FIXTURE_LOG" "runtime-suite:$V2"
    [ "$failure" != lint ] || contains "$FIXTURE_LOG" lint
    same "$CONSUMER/sobaya.json" "$WORK/config.saved"; same "$CONSUMER/sobaya.lock" "$WORK/lock.saved"
    snapshot "$META" "$WORK/state.after"; same "$WORK/state.before" "$WORK/state.after"
  done
  export FIXTURE_SUITE=pass FIXTURE_LINT=pass FIXTURE_TAMPER=1
  runtime_cli step --policy "$WORK/policy.json"
  [ "$RC" -ne 0 ] || fail 'expected a protected-input handoff'
  cp "$WORK/config.saved" "$CONSUMER/sobaya.json"
  snapshot "$META" "$WORK/active.before"
  cli bump --version "$V2" --manifest "$(manifest "$V2")" --archive "$(archive "$V2")"
  invalid active
  same "$CONSUMER/sobaya.json" "$WORK/config.saved"; same "$CONSUMER/sobaya.lock" "$WORK/lock.saved"
  snapshot "$META" "$WORK/active.after"; same "$WORK/active.before" "$WORK/active.after"
  runtime_cli status; okay
  assert_no_network
}
project_bump_checks_every_connected_app() {
  install_version "$V1"; app_fixture project; connect; seal_connection
  first=$APP; second="$CONSUMER/apps/second"
  git clone -q --no-hardlinks "$first" "$second"
  git -C "$second" config user.name Fixture; git -C "$second" config user.email fixture@example.invalid
  cat >> "$second/suite.test.js" <<'SECOND_TEST'
test('secondAppGuard', () => { fs.appendFileSync(process.env.FIXTURE_LOG, 'second-app-suite\n'); assert.notEqual(process.env.FIXTURE_SECOND, 'fail'); });
SECOND_TEST
  APP=$second; commit_app
  cli init --mode project --version "$V1" --app "$second"; okay
  commit_app
  before=$(git -C "$CONSUMER" rev-parse HEAD)
  : > "$FIXTURE_LOG"
  cli bump --version "$V2" --manifest "$(manifest "$V2")" --archive "$(archive "$V2")"; okay
  assert_pin "$V2"; contains "$FIXTURE_LOG" "runtime-suite:$V2"; contains "$FIXTURE_LOG" second-app-suite
  contains "$FIXTURE_LOG" "suite-app:$first:$V2"; contains "$FIXTURE_LOG" "suite-app:$second:$V2"
  [ "$(git -C "$CONSUMER" rev-parse HEAD)" = "$before" ] || fail 'project bump committed automatically'
  cp "$CONSUMER/sobaya.json" "$WORK/config.saved"; cp "$CONSUMER/sobaya.lock" "$WORK/lock.saved"
  git -C "$CONSUMER" add sobaya.json sobaya.lock
  git -C "$CONSUMER" -c user.name=Fixture -c user.email=fixture@example.invalid -c core.hooksPath=/dev/null commit -qm reviewed-bump
  export FIXTURE_SECOND=fail
  : > "$FIXTURE_LOG"
  cli bump --version "$V1" --manifest "$(manifest "$V1")" --archive "$(archive "$V1")"
  invalid validation; contains "$FIXTURE_LOG" second-app-suite
  same "$CONSUMER/sobaya.json" "$WORK/config.saved"; same "$CONSUMER/sobaya.lock" "$WORK/lock.saved"
  assert_no_network
}
if [ "${1:-}" = __case ]; then setup; "$2"; exit; fi
failures=0
for name in install_pins_real_release_and_transport install_rejects_identity_and_unsafe_payload install_preserves_existing_paths_and_failed_downloads init_connects_both_modes_without_rewriting_contracts connected_hooks_preserve_original_behavior connection_keeps_linked_worktree_hooks_isolated installed_modes_execute_approved_cycle dispatch_rejects_pin_drift_and_worker_mutation sync_uses_reviewed_lock_without_repinning bump_validates_candidate_and_preserves_approval bump_failure_and_active_entry_keep_previous_pin project_bump_checks_every_connected_app; do
  if /bin/bash "$0" __case "$name"; then printf 'PASS: %s\n' "$name"; else printf 'FAIL: %s\n' "$name"; failures=$((failures+1)); fi
done
[ "$failures" -eq 0 ]
