#!/bin/sh
# Unit tests for Sobaya hooks. Run: sh tests/hooks-test.sh
# Plain POSIX, no framework. Exits 1 on any failure.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
fail=0

check() { # usage: check <0-for-pass> <name>
  if [ "$1" -eq 0 ]; then
    echo "ok   - $2"
  else
    echo "FAIL - $2"
    fail=1
  fi
}

INJECT="$ROOT/.claude/hooks/inject-brain.sh"

# --- inject-brain: with an index present, prints header + index body ---
proj="$TMP/p1"
mkdir -p "$proj/brain"
printf '# Brain\n\n## Backlog\n- [[todos]]\n' > "$proj/brain/index.md"
out=$(CLAUDE_PROJECT_DIR="$proj" sh "$INJECT" 2>/dev/null)
rc=$?
check "$rc" "inject: exits 0 with index present"
case "$out" in
  *"Brain vault index"*"[[todos]]"*) check 0 "inject: prints header and index body" ;;
  *) check 1 "inject: prints header and index body" ;;
esac

# --- inject-brain: missing brain dir is silent and exit 0 ---
proj="$TMP/p2"
mkdir -p "$proj"
out=$(CLAUDE_PROJECT_DIR="$proj" sh "$INJECT" 2>/dev/null)
rc=$?
check "$rc" "inject: exits 0 with no brain"
[ -z "$out" ]; check $? "inject: silent with no brain"

# --- inject-brain: unreadable index is silent and exit 0 (fail-open) ---
proj="$TMP/p3"
mkdir -p "$proj/brain"
printf '# Brain\n' > "$proj/brain/index.md"
chmod 000 "$proj/brain/index.md"
out=$(CLAUDE_PROJECT_DIR="$proj" sh "$INJECT" 2>/dev/null)
rc=$?
check "$rc" "inject: exits 0 with unreadable index"
[ -z "$out" ]; check $? "inject: silent with unreadable index"
chmod 644 "$proj/brain/index.md"

AUTOIDX="$ROOT/.claude/hooks/auto-index-brain.sh"

# Helper: build a seeded fake vault. $1 = project dir.
seed_vault() {
  mkdir -p "$1/brain/principles" "$1/brain/codebase" \
    "$1/brain/plans/01-x" "$1/brain/archive/plans/00-old"
  printf '# Vision\n'      > "$1/brain/vision.md"
  printf '# Principles\n'  > "$1/brain/principles.md"
  printf '# P\n'           > "$1/brain/principles/prove-it-works.md"
  printf '# N\n'           > "$1/brain/codebase/noodle-reference.md"
  printf '# Apps\n'        > "$1/brain/apps.md"
  printf '# Todos\n'       > "$1/brain/todos.md"
  printf '# Plans\n'       > "$1/brain/plans/index.md"
  printf '# Done\n'        > "$1/brain/archive/completed_todos.md"
  printf '# nested\n'      > "$1/brain/plans/01-x/overview.md"
  printf '# nested-old\n'  > "$1/brain/archive/plans/00-old/overview.md"
}

payload() { # $1 = file_path to embed
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$1"
}

# --- auto-index: non-brain path is a no-op ---
proj="$TMP/p3"
seed_vault "$proj"
printf '# stale\n' > "$proj/brain/index.md"
payload "$proj/apps/foo/main.go" | CLAUDE_PROJECT_DIR="$proj" sh "$AUTOIDX" 2>/dev/null
rc=$?
check "$rc" "autoidx: exits 0 on non-brain path"
grep -q '^# stale$' "$proj/brain/index.md"; check $? "autoidx: non-brain path leaves index untouched"

# --- auto-index: malformed JSON is a no-op ---
printf 'this is not json' | CLAUDE_PROJECT_DIR="$proj" sh "$AUTOIDX" 2>/dev/null
rc=$?
check "$rc" "autoidx: exits 0 on malformed input"
grep -q '^# stale$' "$proj/brain/index.md"; check $? "autoidx: malformed input leaves index untouched"

# --- auto-index: missing brain dir is a no-op ---
proj4="$TMP/p4"
mkdir -p "$proj4"
payload "$proj4/brain/todos.md" | CLAUDE_PROJECT_DIR="$proj4" sh "$AUTOIDX" 2>/dev/null
check $? "autoidx: exits 0 when brain dir missing"

# --- auto-index: brain path rebuilds index to the golden expectation ---
proj="$TMP/p5"
seed_vault "$proj"
payload "$proj/brain/todos.md" | CLAUDE_PROJECT_DIR="$proj" sh "$AUTOIDX" 2>/dev/null
rc=$?
check "$rc" "autoidx: exits 0 on brain path"

golden="$TMP/golden.md"
cat > "$golden" <<'EOF'
# Brain

## Vision
- [[vision]]

## Principles
- [[principles]]
- [[principles/prove-it-works]]

## Apps
- [[apps]]

## Codebase
- [[codebase/noodle-reference]]

## Backlog
- [[todos]]

## Plans
- [[plans/index]]

## Archive
- [[archive/completed_todos]]
EOF
diff -u "$golden" "$proj/brain/index.md" >/dev/null 2>&1
check $? "autoidx: rebuilt index matches golden (plan-nested files excluded)"

# --- auto-index: idempotent — second run takes the fast path, no rewrite ---
touch -t 200001010000 "$proj/brain/index.md"
marker="$TMP/marker"
touch "$marker"
payload "$proj/brain/todos.md" | CLAUDE_PROJECT_DIR="$proj" sh "$AUTOIDX" 2>/dev/null
check $? "autoidx: exits 0 on no-change rerun"
if [ "$proj/brain/index.md" -nt "$marker" ]; then
  check 1 "autoidx: fast path does not rewrite an up-to-date index"
else
  check 0 "autoidx: fast path does not rewrite an up-to-date index"
fi

# --- auto-index: unknown top-level files land in Other ---
printf '# misc\n' > "$proj/brain/scratchpad.md"
payload "$proj/brain/scratchpad.md" | CLAUDE_PROJECT_DIR="$proj" sh "$AUTOIDX" 2>/dev/null
check $? "autoidx: exits 0 after adding unknown file"
grep -q '^## Other$' "$proj/brain/index.md" && grep -q '\[\[scratchpad\]\]' "$proj/brain/index.md"
check $? "autoidx: unknown file indexed under Other"

GUARD="$ROOT/.claude/hooks/guard-fable-only.sh"
GITGATE="$ROOT/.githooks/commit-msg"

# Helper: guard hook stdin JSON. $1 = file_path, $2 = transcript_path.
guard_payload() {
  printf '{"session_id":"t","transcript_path":"%s","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$2" "$1"
}

proj="$TMP/g1"
mkdir -p "$proj/apps/demo" "$proj/brain"
tr_fable="$TMP/tr-fable.jsonl"
printf '{"type":"assistant","message":{"model":"claude-fable-5"}}\n' > "$tr_fable"
tr_opus="$TMP/tr-opus.jsonl"
printf '{"type":"assistant","message":{"model":"claude-opus-4-8-20260101"}}\n' > "$tr_opus"

# --- guard: non-Fable model editing a root file is blocked (exit 2) ---
guard_payload "$proj/CLAUDE.md" "$tr_opus" | CLAUDE_PROJECT_DIR="$proj" sh "$GUARD" 2>/dev/null
[ $? -eq 2 ]; check $? "guard: blocks non-Fable edit to root file"

# --- guard: Fable editing a root file passes ---
guard_payload "$proj/CLAUDE.md" "$tr_fable" | CLAUDE_PROJECT_DIR="$proj" sh "$GUARD" 2>/dev/null
check $? "guard: allows Fable edit to root file"

# --- guard: non-Fable editing under apps/ passes ---
guard_payload "$proj/apps/demo/main.py" "$tr_opus" | CLAUDE_PROJECT_DIR="$proj" sh "$GUARD" 2>/dev/null
check $? "guard: allows non-Fable edit under apps/"

# --- guard: brain/ counts as root territory ---
guard_payload "$proj/brain/todos.md" "$tr_opus" | CLAUDE_PROJECT_DIR="$proj" sh "$GUARD" 2>/dev/null
[ $? -eq 2 ]; check $? "guard: blocks non-Fable edit to brain/"

# --- guard: missing transcript fails open ---
guard_payload "$proj/CLAUDE.md" "$TMP/nope.jsonl" | CLAUDE_PROJECT_DIR="$proj" sh "$GUARD" 2>/dev/null
check $? "guard: fails open when transcript is missing"

# --- guard: path outside the workspace is ignored ---
guard_payload "$TMP/elsewhere.md" "$tr_opus" | CLAUDE_PROJECT_DIR="$proj" sh "$GUARD" 2>/dev/null
check $? "guard: ignores paths outside the workspace"

WGUARD="$ROOT/.claude/hooks/guard-workspace-rules.sh"

# Workspace: registered app "demo", unregistered app "rogue".
wproj="$TMP/w1"
mkdir -p "$wproj/brain" "$wproj/apps/demo" "$wproj/apps/rogue"
printf '# Apps\n\n| App | Git |\n|---|---|\n| demo | local |\n' > "$wproj/brain/apps.md"

wpayload() { # $1 = file_path
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$1"
}

# --- wguard: brain/index.md hand-edit is blocked (exit 2) ---
wpayload "$wproj/brain/index.md" | CLAUDE_PROJECT_DIR="$wproj" sh "$WGUARD" 2>/dev/null
[ $? -eq 2 ]; check $? "wguard: blocks hand-edit of brain/index.md"

# --- wguard: other brain files pass ---
wpayload "$wproj/brain/todos.md" | CLAUDE_PROJECT_DIR="$wproj" sh "$WGUARD" 2>/dev/null
check $? "wguard: allows edits to other brain files"

# --- wguard: NEW project marker at the root is blocked ---
wpayload "$wproj/package.json" | CLAUDE_PROJECT_DIR="$wproj" sh "$WGUARD" 2>/dev/null
[ $? -eq 2 ]; check $? "wguard: blocks new project marker outside apps/"

# --- wguard: EXISTING root marker is untouched (only creation policed) ---
printf '{}\n' > "$wproj/package.json"
wpayload "$wproj/package.json" | CLAUDE_PROJECT_DIR="$wproj" sh "$WGUARD" 2>/dev/null
check $? "wguard: allows edit of pre-existing root marker"
rm -f "$wproj/package.json"

# --- wguard: NEW marker nested in apps/<name>/app/ is blocked ---
wpayload "$wproj/apps/demo/app/package.json" | CLAUDE_PROJECT_DIR="$wproj" sh "$WGUARD" 2>/dev/null
[ $? -eq 2 ]; check $? "wguard: blocks new marker in nested app/"

# --- wguard: NEW marker nested in apps/<name>/apps/ is blocked ---
wpayload "$wproj/apps/demo/apps/inner/package.json" | CLAUDE_PROJECT_DIR="$wproj" sh "$WGUARD" 2>/dev/null
[ $? -eq 2 ]; check $? "wguard: blocks new marker in nested apps/"

# --- wguard: registered app is grandfathered ---
wpayload "$wproj/apps/demo/main.py" | CLAUDE_PROJECT_DIR="$wproj" sh "$WGUARD" 2>/dev/null
check $? "wguard: allows work in a registered app"

# --- wguard: unregistered app without .git is blocked ---
wpayload "$wproj/apps/rogue/main.py" | CLAUDE_PROJECT_DIR="$wproj" sh "$WGUARD" 2>/dev/null
[ $? -eq 2 ]; check $? "wguard: blocks work in unregistered app without .git"

# --- wguard: scaffold files are always writable ---
wpayload "$wproj/apps/rogue/CLAUDE.md" | CLAUDE_PROJECT_DIR="$wproj" sh "$WGUARD" 2>/dev/null
check $? "wguard: allows scaffold files in unregistered app"

# --- wguard: unregistered app with .git but no Test: line (tdd-set not installed) is blocked ---
mkdir -p "$wproj/apps/rogue/.git"
printf '# Rogue\n' > "$wproj/apps/rogue/AGENTS.md"
wpayload "$wproj/apps/rogue/main.py" | CLAUDE_PROJECT_DIR="$wproj" sh "$WGUARD" 2>/dev/null
[ $? -eq 2 ]; check $? "wguard: blocks unregistered app lacking a Test: line"

# --- wguard: unregistered app with .git + Test: line passes ---
printf '# Rogue\n\n## App facts\n- Test: `go test ./...`\n' > "$wproj/apps/rogue/AGENTS.md"
wpayload "$wproj/apps/rogue/main.py" | CLAUDE_PROJECT_DIR="$wproj" sh "$WGUARD" 2>/dev/null
check $? "wguard: allows git-initialized app with tdd-set installed"

# --- wguard: malformed input fails open ---
printf 'not json' | CLAUDE_PROJECT_DIR="$wproj" sh "$WGUARD" 2>/dev/null
check $? "wguard: fails open on malformed input"

# --- wguard: path outside the workspace is ignored ---
wpayload "$TMP/elsewhere/package.json" | CLAUDE_PROJECT_DIR="$wproj" sh "$WGUARD" 2>/dev/null
check $? "wguard: ignores paths outside the workspace"

# --- commit gate: non-Fable agent trailer rejected ---
msg="$TMP/msg1"
printf 'feat: x\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\n' > "$msg"
sh "$GITGATE" "$msg" 2>/dev/null
[ $? -ne 0 ]; check $? "gate: rejects Opus trailer"

# --- commit gate: Codex trailer rejected ---
msg="$TMP/msg2"
printf 'feat: x\n\nCo-Authored-By: Codex <codex@openai.com>\n' > "$msg"
sh "$GITGATE" "$msg" 2>/dev/null
[ $? -ne 0 ]; check $? "gate: rejects Codex trailer"

# --- commit gate: Fable trailer passes ---
msg="$TMP/msg3"
printf 'feat: x\n\nCo-Authored-By: Claude Fable 5 <noreply@anthropic.com>\n' > "$msg"
sh "$GITGATE" "$msg" 2>/dev/null
check $? "gate: allows Fable trailer"

# --- commit gate: human commit without trailer passes ---
msg="$TMP/msg4"
printf 'chore: manual tweak\n' > "$msg"
sh "$GITGATE" "$msg" 2>/dev/null
check $? "gate: allows human commit without trailer"

# --- tdd-set gate: Node tests appended to one shared file pass the test-line check ---
GATE="$ROOT/tdd-set/bin/gate.sh"
ag="$TMP/appendgate"; mkdir -p "$ag/tests"
( cd "$ag" && git init -q && git config user.email t@t && git config user.name t
  printf '{"name":"ag","type":"module"}\n' > package.json
  printf '# ag\n\n## App facts\n- Test: `true`\n' > AGENTS.md
  printf '# p\n\n- [ ] addAdds — 1+2=3\n- [ ] addZero — 0+5=5\n' > failed-test.md
  printf 'import { test } from "node:test"\ntest("oldOne: existed before the loop", () => {})\n' > tests/old.test.js
  git add -A && git commit -qm start
  printf '// file: tests/add.test.js\nimport { test } from "node:test"\n' > tests/add.test.js
  printf '\ntest("addAdds: 1+2=3", () => {})\n' >> tests/add.test.js
  sed 's/- \[ \] addAdds/- [x] addAdds/' failed-test.md > f && mv f failed-test.md
  git add -A && git commit -qm one
  printf '\ntest("addZero: 0+5=5", () => {})\n' >> tests/add.test.js
  sed 's/- \[ \] addZero/- [x] addZero/' failed-test.md > f && mv f failed-test.md
  git add -A && git commit -qm two ) >/dev/null 2>&1
agstart=$(git -C "$ag" rev-list --max-parents=0 HEAD)
bash "$GATE" "$ag" "$agstart" >/dev/null 2>&1
check $? "tdd-set gate: header + appended Node entries pass (no changed lines, names matched)"

# --- tdd-set gate: editing a helper in the test dir during the loop is rejected ---
( cd "$ag" && printf 'export const startServer = () => ({ post: () => ({ status: 400 }) })\n' > tests/helper.mjs && git add -A && git commit -qm helper-before-loop ) >/dev/null 2>&1
agstart2=$(git -C "$ag" rev-parse HEAD)
( cd "$ag" && printf 'export const startServer = () => ({ post: () => ({ status: 200 }) })\n' > tests/helper.mjs && git commit -qam helper-edited ) >/dev/null 2>&1
bash "$GATE" "$ag" "$agstart2" >/dev/null 2>&1
[ $? -ne 0 ]; check $? "tdd-set gate: rejects a modified helper in the test dir"
( cd "$ag" && git revert --no-edit HEAD >/dev/null 2>&1 )
bash "$GATE" "$ag" "$agstart2" >/dev/null 2>&1
check $? "tdd-set gate: helper untouched again passes"

# --- tdd-set gate: editing a test line that existed before the loop is rejected ---
( cd "$ag" && sed 's/existed before/was edited during/' tests/old.test.js > f && mv f tests/old.test.js && git commit -qam edit ) >/dev/null 2>&1
bash "$GATE" "$ag" "$agstart" >/dev/null 2>&1
[ $? -ne 0 ]; check $? "tdd-set gate: rejects a modified test line"

# --- usage.sh: record logs one JSONL line per iteration and prints the agent's result; summary totals a run ---
USAGE="$ROOT/tdd-set/bin/usage.sh"
ua="$TMP/usageapp"; mkdir -p "$ua/.git"
res=$(printf '{"type":"result","result":"one line report","usage":{"input_tokens":12,"output_tokens":34,"cache_read_input_tokens":500,"cache_creation_input_tokens":60},"total_cost_usd":0.0123,"num_turns":3,"duration_ms":4200,"modelUsage":{"claude-sonnet-5":{}},"subagent_stats":{"spawned":0},"is_error":false}' \
  | bash "$USAGE" record "$ua" abc123 1)
[ "$res" = "one line report" ]; check $? "usage: record prints the agent result"
printf '{"type":"result","result":"x","usage":{"input_tokens":8,"output_tokens":2,"cache_read_input_tokens":100,"cache_creation_input_tokens":0},"total_cost_usd":0.0007,"num_turns":1,"duration_ms":900,"modelUsage":{"claude-sonnet-5":{}},"subagent_stats":{"spawned":2},"is_error":false}' \
  | bash "$USAGE" record "$ua" abc123 2 >/dev/null
[ "$(wc -l < "$ua/.git/sobaya-loop-usage.log")" -eq 2 ]; check $? "usage: one log line per iteration"
grep -q '"iter":1,"model":"claude-sonnet-5","in":12,"out":34,"cache_read":500,"cache_create":60,"cost":0.0123,"turns":3,"subagents":0' "$ua/.git/sobaya-loop-usage.log"
check $? "usage: log line carries tokens, cost, turns, subagents"
sum=$(bash "$USAGE" summary "$ua" abc123)
case "$sum" in *"total: 2 iterations, \$0.013, in 20, out 36, cache_read 600, cache_create 60; max iteration \$0.012"*) check 0 "usage: summary totals the run" ;; *) echo "$sum"; check 1 "usage: summary totals the run" ;; esac
raw=$(printf 'not json at all' | bash "$USAGE" record "$ua" abc123 3)
[ "$raw" = "not json at all" ] && [ "$(wc -l < "$ua/.git/sobaya-loop-usage.log")" -eq 2 ]
check $? "usage: non-JSON output is passed through and not logged"

echo
if [ "$fail" -eq 0 ]; then
  echo "ALL PASS"
else
  echo "FAILURES PRESENT"
  exit 1
fi
