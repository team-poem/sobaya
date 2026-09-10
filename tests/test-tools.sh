#!/bin/bash
# Bash 3.2 integration tests: real Git hooks, setup/index and Go/Node probes.
set -u
set -o pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
D=$(mktemp -d "${TMPDIR:-/tmp}/sobaya tools ' XXXX") || exit 1
trap 'rm -rf "$D"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
fail=0; tests=0
check() { tests=$((tests+1)); if [ "$1" = 0 ]; then printf 'ok %d - %s\n' "$tests" "$2"; else printf 'FAIL %d - %s\n' "$tests" "$2"; fail=$((fail+1)); fi; }
run() { rc=0; "$@" > "$D/output" 2>&1 || rc=$?; }
repo() { mkdir -p "$1"; git -C "$1" init -q; git -C "$1" config user.name Fixture; git -C "$1" config user.email fixture@example.invalid; git -C "$1" config commit.gpgsign false; }
agents() { printf '# Fixture\n- Test: `node --test`\n' > "$1/AGENTS.md"; }
commit() { git -C "$1" add -A; git -C "$1" commit -qm fixture; }
install() { "$ROOT/tdd-set/bin/install.sh" "$1"; }
setup_root() { repo "$1"; cp -R "$ROOT/scripts" "$ROOT/.githooks" "$1/"; }
contains() { grep -qF -- "$1" "$D/output"; }

vault=$D/vault
for note in vision principles principles/prove-it-works apps codebase/note todos plans/index archive/done plans/01-work/detail archive/plans/00-work/detail scratchpad; do mkdir -p "$vault/brain/$(dirname "$note")"; printf '# Note\n' > "$vault/brain/$note.md"; done
run "$ROOT/scripts/brain-index.sh" "$vault"
[ "$rc" = 0 ] && grep -q '\[\[scratchpad\]\]' "$vault/brain/index.md" && ! grep -q detail "$vault/brain/index.md"; check $? 'brain groups unknown notes and excludes plan details'
touch -t 200001010000 "$vault/brain/index.md"; cp -p "$vault/brain/index.md" "$D/index-copy"
run "$ROOT/scripts/brain-index.sh" "$vault"
[ "$rc" = 0 ] && [ ! "$vault/brain/index.md" -nt "$D/index-copy" ]; check $? 'brain generation is idempotent without rewriting'
run "$ROOT/scripts/brain-index.sh" "$vault" --check; check "$rc" 'brain check accepts current index'
mkdir -p "$D/missing/brain"
run "$ROOT/scripts/brain-index.sh" "$D/missing" --check
[ "$rc" = 1 ] && [ ! -e "$D/missing/brain/index.md" ]; check $? 'brain check is read-only'
printf preserved > "$D/external"; ln -s "$D/external" "$D/missing/brain/index.md"
run "$ROOT/scripts/brain-index.sh" "$D/missing"
[ "$rc" = 1 ] && [ "$(cat "$D/external")" = preserved ]; check $? 'brain refuses symlink index without changing target'

r=$D/markers; repo "$r"; printf '{}' > "$r/package.json"; git -C "$r" add .
run "$ROOT/scripts/workspace-check.sh" "$r" --staged
[ "$rc" = 1 ] && contains 'new projects belong'; check $? 'new root marker rejected'
commit "$r"; printf '{"name":"old"}' > "$r/package.json"; git -C "$r" add .
mkdir -p "$r/references/demo"; printf '{}' > "$r/references/demo/package.json"; git -C "$r" add .
run "$ROOT/scripts/workspace-check.sh" "$r" --staged; check "$rc" 'existing root markers and references preserved'
r=$D/rename; repo "$r"; printf '{}' > "$r/example.txt"; commit "$r"; git -C "$r" mv example.txt package.json
run "$ROOT/scripts/workspace-check.sh" "$r" --staged; [ "$rc" = 1 ]; check $? 'rename to marker cannot bypass checks'

r=$D/staged; repo "$r"; mkdir "$r/brain"; printf '# Vision' > "$r/brain/vision.md"; "$ROOT/scripts/brain-index.sh" "$r" >/dev/null; git -C "$r" add .
printf unstaged > "$r/brain/unstaged.md"
run "$ROOT/scripts/workspace-check.sh" "$r" --staged; check "$rc" 'staged index uses staged notes, ignores unstaged notes'
printf handwritten > "$r/brain/index.md"; git -C "$r" add brain/index.md
run "$ROOT/scripts/workspace-check.sh" "$r" --staged
[ "$rc" = 1 ] && contains 'generated index'; check $? 'handwritten staged index rejected'

r=$D/workspace; repo "$r"; a=$D/unregistered; repo "$a"
run "$ROOT/scripts/workspace-check.sh" "$r" --app "$a"; [ "$rc" = 1 ]; check $? 'unregistered app requires actual Test command'
agents "$a"; run "$ROOT/scripts/workspace-check.sh" "$r" --app "$a"; check "$rc" 'own repository and Test command accepted'
mkdir "$a/app"; printf '{}' > "$a/app/package.json"; git -C "$a" add .
run "$ROOT/scripts/workspace-check.sh" "$r" --app "$a" --staged; [ "$rc" = 1 ]; check $? 'new nested app marker rejected'
mkdir "$r/brain" "$D/legacy"; printf '| legacy | imported |\n' > "$r/brain/apps.md"
run "$ROOT/scripts/workspace-check.sh" "$r" --app "$D/legacy"; check "$rc" 'registered legacy apps grandfathered'
r=$D/appwarn; repo "$r"; mkdir -p "$r/apps/legacy"
run "$ROOT/scripts/workspace-check.sh" "$r"; check "$rc" 'default doctor does not scan ignored apps'
run "$ROOT/scripts/workspace-check.sh" "$r" --apps; [ "$rc" = 0 ] && contains WARN; check $? 'existing app violations are opt-in warnings'

r=$D/root-hook; setup_root "$r"; git -C "$r" config core.hooksPath .githooks; mkdir "$r/brain"; printf note > "$r/brain/vision.md"; printf handwritten > "$r/brain/index.md"; git -C "$r" add .
run git -C "$r" commit -qm invalid; [ "$rc" != 0 ] && contains 'generated index'; check $? 'real root hook rejects manual index'
"$ROOT/scripts/brain-index.sh" "$r" >/dev/null; git -C "$r" add brain/index.md
run git -C "$r" commit -qm valid; check "$rc" 'real root hook accepts generated index'

r=$D/setup; setup_root "$r"; cp "$r/.git/config" "$D/config"
run "$ROOT/scripts/setup.sh" "$r" --check
[ "$rc" = 1 ] && cmp -s "$D/config" "$r/.git/config"; check $? 'setup check is read-only when inactive'
run "$ROOT/scripts/setup.sh" "$r"; [ "$rc" = 0 ] && [ "$(git -C "$r" config core.hooksPath)" = .githooks ]; check $? 'setup activates root hooks'
cp -p "$r/.git/config" "$D/config"; run "$ROOT/scripts/setup.sh" "$r"
[ "$rc" = 0 ] && cmp -s "$D/config" "$r/.git/config" && [ ! "$r/.git/config" -nt "$D/config" ]; check $? 'setup repeated activation does not rewrite config'
run "$ROOT/scripts/setup.sh" "$r" --check; check "$rc" 'active root setup verified'
git -C "$r" config core.hooksPath "$r/.githooks"; run "$ROOT/scripts/setup.sh" "$r" --check; check "$rc" 'absolute hooksPath accepted'
git -C "$r" config core.hooksPath .githooks; commit "$r" >/dev/null
wt=$D/linked-root; git -C "$r" worktree add -qb isolated "$wt"
run "$ROOT/scripts/setup.sh" "$wt" --check; [ "$rc" = 0 ] && [ -f "$wt/.git" ]; check $? 'linked root worktree setup works'
r=$D/custom-setup; setup_root "$r"; git -C "$r" config core.hooksPath 'user hooks'; cp "$r/.git/config" "$D/config"
run "$ROOT/scripts/setup.sh" "$r"; [ "$rc" = 1 ] && cmp -s "$D/config" "$r/.git/config"; check $? 'setup preserves conflicting custom hooks configuration'
r=$D/default-hook; setup_root "$r"; printf '#!/bin/sh\necho user\n' > "$r/.git/hooks/commit-msg"; cp "$r/.git/config" "$D/config"
run "$ROOT/scripts/setup.sh" "$r"; [ "$rc" = 1 ] && contains 'would be shadowed' && cmp -s "$D/config" "$r/.git/config"; check $? 'setup does not shadow default user Git hooks'
r=$D/disabled-hook; setup_root "$r"; chmod 644 "$r/.githooks/pre-commit"
run "$ROOT/scripts/setup.sh" "$r"; [ "$rc" = 1 ]; check $? 'setup rejects nonexecutable root hook'
chmod 755 "$r/.githooks/pre-commit"; "$ROOT/scripts/setup.sh" "$r" >/dev/null; rm "$r/.githooks/pre-commit"
run "$ROOT/scripts/setup.sh" "$r" --check; [ "$rc" = 1 ]; check $? 'setup detects missing root hook'

a=$D/unknown; repo "$a"; run install "$a"
[ "$rc" = 0 ] && grep -q '<declare the actual test command>' "$a/AGENTS.md" && ! grep -q 'go test\|Lint:' "$a/AGENTS.md" && [ ! -e "$a/CLAUDE.md" ]; check $? 'installer does not invent unknown stack commands or provider instructions'
printf 'human goal' > "$a/spec.md"; printf 'human tests' > "$a/failed-test.md"; cp -p "$a/.git/hooks/pre-commit" "$D/hook-before"
run install "$a"
[ "$rc" = 0 ] && cmp -s "$D/hook-before" "$a/.git/hooks/pre-commit" && [ ! "$a/.git/hooks/pre-commit" -nt "$D/hook-before" ] && [ "$(cat "$a/spec.md")" = 'human goal' ] && [ "$(cat "$a/failed-test.md")" = 'human tests' ]; check $? 'install preserves docs and identical managed hook'
a=$D/node-scripts; repo "$a"; printf '{"scripts":{"test":"node --test"},"devDependencies":{"prettier":"1"}}' > "$a/package.json"; run install "$a"
[ "$rc" = 0 ] && grep -q 'npm test' "$a/AGENTS.md" && ! grep -q 'Lint:\|Format:' "$a/AGENTS.md"; check $? 'installer declares only present Node scripts'
a=$D/custom-install; repo "$a"; git -C "$a" config core.hooksPath 'custom hooks'; mkdir "$a/custom hooks"; printf '#!/bin/sh\necho user\n' > "$a/custom hooks/pre-commit"; cp "$a/custom hooks/pre-commit" "$D/user-hook"
run install "$a"
[ "$rc" = 1 ] && cmp -s "$D/user-hook" "$a/custom hooks/pre-commit" && [ ! -e "$a/AGENTS.md" ] && [ ! -e "$a/spec.md" ]; check $? 'installer preserves custom hook before writing docs'
a=$D/custom-empty; repo "$a"; git -C "$a" config core.hooksPath 'custom hooks'; run install "$a"
[ "$rc" = 0 ] && [ -x "$a/custom hooks/pre-commit" ]; check $? 'empty app-contained custom hooks directory supported'
a=$D/worktree-source; repo "$a"; agents "$a"; commit "$a"; wt=$D/linked-app; git -C "$a" worktree add -qb isolated "$wt"; cp "$wt/.git" "$D/git-pointer"
run install "$wt"
[ "$rc" = 0 ] && cmp -s "$D/git-pointer" "$wt/.git"; check $? 'installer supports linked app without changing git metadata pointer'

legacy_interpreter=$(printf 'py%sthon3' '')
a=$D/legacy-hook; repo "$a"; printf '#!/bin/sh\n# Sobaya app pre-commit v1\nexec %s old-helper.py\n' "$legacy_interpreter" > "$a/.git/hooks/pre-commit"; run install "$a"
[ "$rc" = 0 ] && grep -q 'pre-commit v2' "$a/.git/hooks/pre-commit" && ! grep -q "$legacy_interpreter" "$a/.git/hooks/pre-commit"; check $? 'legacy managed interpreter hook upgrades to shell v2'
a=$D/formatter; repo "$a"; agents "$a"; printf '%s\n' '- Format: `printf "All matched files are formatted\n"`' '- Lint: `printf "lint passed\n"`' >> "$a/AGENTS.md"; install "$a" >/dev/null; git -C "$a" add .
run git -C "$a" commit -qm valid
[ "$rc" = 0 ] && contains 'All matched files'; check $? 'real app commit accepts formatter success chatter with quoted paths'
a=$D/lint-failure; repo "$a"; agents "$a"; printf '%s\n' '- Lint: `exit 7`' >> "$a/AGENTS.md"; install "$a" >/dev/null; git -C "$a" add .
run git -C "$a" commit -qm invalid; [ "$rc" != 0 ] && contains 'Lint check failed'; check $? 'real app commit rejects lint exit'
if command -v gofmt >/dev/null; then
  a=$D/gofmt; repo "$a"; agents "$a"; printf '%s\n' '- Format: `gofmt -l "source dir"`' >> "$a/AGENTS.md"; mkdir "$a/source dir"; printf 'package demo\nfunc Add(a,b int)int{return a+b}\n' > "$a/source dir/main.go"; install "$a" >/dev/null; git -C "$a" add .
  run git -C "$a" commit -qm invalid; [ "$rc" != 0 ] && contains 'Format check failed'; check $? 'gofmt listing adapter rejects formatting drift with quoted path'
  gofmt -w "$a/source dir/main.go"; git -C "$a" add .; run git -C "$a" commit -qm valid; check "$rc" 'gofmt listing adapter accepts no output'
fi

r=$D/setup-app; setup_root "$r"; mkdir "$r/tdd-set"; cp -R "$ROOT/tdd-set/bin" "$ROOT/tdd-set/hooks" "$r/tdd-set/"; cp "$ROOT/tdd-set/"*template.md "$r/tdd-set/"; "$ROOT/scripts/setup.sh" "$r" >/dev/null
a=$D/verified-app; repo "$a"; agents "$a"; "$r/tdd-set/bin/install.sh" "$a" >/dev/null
run "$ROOT/scripts/setup.sh" "$r" --check --app "$a"; check "$rc" 'setup verifies exact shell app wrapper for its harness'
chmod 644 "$a/.git/hooks/pre-commit"; run "$ROOT/scripts/setup.sh" "$r" --check --app "$a"; [ "$rc" = 1 ]; check $? 'setup detects disabled app hook'
chmod 755 "$a/.git/hooks/pre-commit"; install "$a" >/dev/null
run "$ROOT/scripts/setup.sh" "$r" --check --app "$a"; [ "$rc" = 1 ] && contains 'not the managed hook'; check $? 'setup detects app hook pointing to another harness'

if command -v node >/dev/null; then
  a=$D/probe-node; mkdir "$a"; printf '{"type":"commonjs"}' > "$a/package.json"
  probe_node() { printf '%s\n' "$1" > "$D/snippet"; run "$ROOT/scripts/probe.sh" "$a" "$D/snippet"; }
  pre='const test=require("node:test"); const assert=require("node:assert/strict");'
  probe_node "$pre test(\"green\",()=>assert.equal(1,1));"; [ "$rc" = 1 ] && contains GREEN; check $? 'Node green probe'
  printf '{"pid":%s}\n' "$$" > "$D/outer-process.json"
  cp "$D/outer-process.json" "$D/outer-before"
  SOBAYA_WORKER_RECORD="$D/outer-process.json" probe_node "$pre test(\"nested\",()=>assert.equal(1,1));"
  [ "$rc" = 1 ] && contains GREEN && cmp -s "$D/outer-before" "$D/outer-process.json"; check $? 'nested probe keeps outer worker process record intact'
  probe_node "$pre test(\"red\",()=>assert.equal(1,2));"; [ "$rc" = 0 ] && contains RED; check $? 'Node assertion is RED'
  probe_node "$pre test(\"syntax\",()=>{ broken syntax });"; [ "$rc" = 2 ] && contains ERROR; check $? 'Node syntax error is ERROR'
  probe_node "$pre test(\"newApi\",()=>MissingApi());"; [ "$rc" = 2 ]; check $? 'undefined symbol requires explicit intent'
  export SOBAYA_PROBE_ALLOW_UNDEFINED=1
  probe_node "$pre test(\"newApi\",()=>MissingApi());"; [ "$rc" = 0 ] && contains 'explicitly allowed'; check $? 'explicit new symbol may be RED'
  probe_node "$pre require(\"missing-sobaya-dependency\"); test(\"newApi\",()=>MissingApi());"; [ "$rc" = 2 ] && contains 'Cannot find module'; check $? 'missing dependency remains ERROR with undefined opt-in'
  unset SOBAYA_PROBE_ALLOW_UNDEFINED
  probe_node "$pre test(\"skipped\",{skip:true},()=>{});"; [ "$rc" = 2 ]; check $? 'skipped Node candidate is ERROR'
  probe_node "$pre test(\"custom\",()=>{throw new Error(\"requirement\")});"; [ "$rc" = 0 ]; check $? 'explicit thrown candidate failure is RED'
  export SOBAYA_PROBE_TIMEOUT=0.5
  probe_node "$pre test(\"stuck\",()=>{while(true){}});"; [ "$rc" = 2 ] && contains timeout; check $? 'hung Node probe times out with ERROR'
  unset SOBAYA_PROBE_TIMEOUT
  printf '{"devDependencies":{"vitest":"1"}}' > "$a/package.json"
  probe_node 'test("candidate",()=>{});'; [ "$rc" = 2 ] && contains 'not installed locally' && [ ! -d "$a/node_modules" ]; check $? 'missing local Vitest never auto-installs'
  [ -z "$(find "$a" -name 'zz_sobaya_probe_*' -print)" ]; check $? 'probe temporary files always cleaned'
fi

# Path normalization prevents an app-local spelling from escaping via missing/../ components.
a=$D/escaped-hooks; repo "$a"; git -C "$a" config core.hooksPath 'missing/../../outside hooks'
run install "$a"
[ "$rc" = 1 ] && [ ! -e "$a/AGENTS.md" ] && [ ! -d "$D/outside hooks" ]; check $? 'installer refuses normalized shared hooks path without creating it'
if command -v gofmt >/dev/null; then
  a=$D/quoted-formatter; repo "$a"; agents "$a"
  printf '%s\n' "- Format: \`'gofmt' '-l' \"source dir\"\`" >> "$a/AGENTS.md"
  mkdir "$a/source dir"; printf 'package demo\nfunc Add(a,b int)int{return a+b}\n' > "$a/source dir/main.go"
  install "$a" >/dev/null; git -C "$a" add .
  run git -C "$a" commit -qm invalid
  [ "$rc" != 0 ] && contains 'Format check failed'; check $? 'formatter adapter parses quoted executable and flag without evaluation'
fi
# The same recognizer is shared by contract checkpoints and app Git hooks.
printf '%s\n' '"/some path/gofmt" -s -l "source dir"' | awk -f "$ROOT/scripts/formatter-listing.awk"; check $? 'formatter parser recognizes absolute executable and separate flags'
printf '%s\n' 'gofmt -sl .' | awk -f "$ROOT/scripts/formatter-listing.awk"; check $? 'formatter parser recognizes combined listing flag'
if printf '%s\n' 'gofmt "source dir" -l' | awk -f "$ROOT/scripts/formatter-listing.awk"; then check 1 'formatter parser stops at first positional path'; else check 0 'formatter parser stops at first positional path'; fi
if printf '%s\n' 'gofmt -cpuprofile /tmp/profile .' | awk -f "$ROOT/scripts/formatter-listing.awk"; then check 1 'profile option is not mistaken for listing'; else check 0 'profile option is not mistaken for listing'; fi
# Mask an app runtime while keeping the standard shell tools available.
a=$D/no-runtime; mkdir "$a" "$D/restricted-bin"; printf '{}' > "$a/package.json"; printf 'test("candidate",()=>{});' > "$D/snippet"
for tool in dirname basename pwd readlink mktemp cat rm jq grep awk sed wc tr; do toolpath=$(command -v "$tool"); case "$toolpath" in /*) ln -s "$toolpath" "$D/restricted-bin/$tool" ;; esac; done
rc=0; PATH="$D/restricted-bin" /bin/bash "$ROOT/scripts/probe.sh" "$a" "$D/snippet" > "$D/output" 2>&1 || rc=$?
[ "$rc" = 2 ] && contains 'missing runtime: node'; check $? 'missing runtime is ERROR, never RED'
if command -v go >/dev/null; then
  a=$D/probe-go; mkdir "$a"; printf 'module fixture\n\ngo 1.22\n' > "$a/go.mod"; printf 'package fixture\n' > "$a/app.go"
  probe_go() { printf '%s\n' "$1" > "$D/snippet"; run "$ROOT/scripts/probe.sh" "$a" "$D/snippet"; }
  export SOBAYA_PROBE_ALLOW_UNDEFINED=1
  probe_go 'func TestSyntax(t *testing.T) { broken syntax }'; [ "$rc" = 2 ]; check $? 'Go syntax remains ERROR with undefined opt-in'
  probe_go 'func TestSkip(t *testing.T) { t.Skip("not run") }'; [ "$rc" = 2 ]; check $? 'Go skipped candidate is ERROR'
  probe_go 'import ("testing"; "fmt")
func TestMixed(t *testing.T) { MissingApi() }'; [ "$rc" = 2 ]; check $? 'mixed undefined and unused import is ERROR'
  unset SOBAYA_PROBE_ALLOW_UNDEFINED
  run /bin/bash "$ROOT/tdd-set/tests/probe-go-imports.sh"; check "$rc" 'Go import/green/red regression suite'
fi
# Fail loudly if any utility falls back to an interpreter being removed.
mkdir "$D/forbidden"
for tool in $(printf 'py%sthon py%sthon3' '' ''); do printf '#!/bin/sh\necho forbidden-interpreter >&2\nexit 97\n' > "$D/forbidden/$tool"; chmod +x "$D/forbidden/$tool"; done
rc=0; PATH="$D/forbidden:$PATH" "$ROOT/scripts/setup.sh" "$D/setup" --check > "$D/output" 2>&1 || rc=$?
[ "$rc" = 0 ] && ! contains forbidden-interpreter; check $? 'setup smoke with interpreter calls forbidden'
if grep -En '(^|[[:space:]])(exec[[:space:]]+)?python[0-9]*([[:space:]]|$)' "$ROOT/scripts/"*.sh "$ROOT/tdd-set/bin/install.sh" "$ROOT/tdd-set/bin/probe.sh" "$ROOT/tdd-set/hooks/pre-commit.sh" "$ROOT/.githooks/pre-commit" > "$D/interpreter-residue"; then check 1 'shell utility sources contain no interpreter invocation'; cat "$D/interpreter-residue"; else check 0 'shell utility sources contain no interpreter invocation'; fi
printf '%s tests; %s failures\n' "$tests" "$fail"
[ "$fail" = 0 ]
