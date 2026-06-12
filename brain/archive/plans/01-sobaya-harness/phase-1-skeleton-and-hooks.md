# Sobaya Harness Implementation Plan — Phase 1: Skeleton & Hooks

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the workspace skeleton and the two deterministic hooks (brain index injection, brain index auto-rebuild) with a self-contained test script proving them.

**Architecture:** Sobaya is a conventions+skills harness, not a framework (spec D1). The only executable code is two fail-open POSIX shell hooks. Everything else in later phases is markdown. Tests are plain POSIX shell with no framework dependency.

**Tech Stack:** POSIX sh (no bash-isms, no jq), git, Claude Code hooks (`.claude/settings.json`).

**Spec:** `brain/plans/01-sobaya-harness/overview.md` (approved 2026-06-12). Phases: **1 skeleton+hooks** → 2 brain seeding → 3 skills → 4 identity & docs.

**Working directory:** All commands run from `/Users/amazon/lunch.cancelled/sobaya`. The shell cwd persists between Bash calls and `references/noodle/` is a foreign git repo — if there is any chance the cwd drifted, prefix git commands with `git -C /Users/amazon/lunch.cancelled/sobaya`.

---

### Task 1: Directory skeleton

**Files:**
- Create: `apps/.gitkeep`
- Create: `docs/` (directory, content arrives in phase 4)
- Create: `tests/` (directory)
- Create: `.claude/hooks/` (directory)

- [x] **Step 1: Create the directories and keep-file**

```bash
cd /Users/amazon/lunch.cancelled/sobaya
mkdir -p apps docs tests .claude/hooks .claude/skills brain/codebase brain/principles brain/archive/plans
touch apps/.gitkeep
```

- [x] **Step 2: Verify the tree**

Run: `find apps docs tests .claude brain -type d | sort`
Expected output contains: `apps`, `docs`, `tests`, `.claude/hooks`, `.claude/skills`, `brain/archive/plans`, `brain/codebase`, `brain/principles`, `brain/plans/01-sobaya-harness`.

Run: `git -C /Users/amazon/lunch.cancelled/sobaya status --short`
Expected: `?? apps/.gitkeep` and nothing from `references/` (gitignored). Empty directories (docs, tests, .claude) won't show — that's fine, they get content in later tasks.

- [x] **Step 3: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add apps/.gitkeep
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "chore(workspace): Add apps/ skeleton

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: inject-brain.sh (SessionStart hook)

**Files:**
- Create: `tests/hooks-test.sh`
- Create: `.claude/hooks/inject-brain.sh`

- [x] **Step 1: Write the failing test**

Create `tests/hooks-test.sh` with exactly:

```sh
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

echo
if [ "$fail" -eq 0 ]; then
  echo "ALL PASS"
else
  echo "FAILURES PRESENT"
  exit 1
fi
```

- [x] **Step 2: Run the test to verify it fails**

Run: `sh tests/hooks-test.sh`
Expected: FAIL lines (the inject script does not exist yet, `sh` returns non-zero), final line `FAILURES PRESENT`, exit code 1.

- [x] **Step 3: Write the hook**

Create `.claude/hooks/inject-brain.sh` with exactly:

```sh
#!/bin/sh
# SessionStart hook: surface the brain index so every session starts with the
# knowledge map. Fail-open: a missing vault produces no output and exit 0.

BRAIN_INDEX="${CLAUDE_PROJECT_DIR:-.}/brain/index.md"

if [ -f "$BRAIN_INDEX" ] && [ -r "$BRAIN_INDEX" ]; then
  echo "Brain vault index — read the relevant files before acting:"
  echo
  cat "$BRAIN_INDEX"
fi

exit 0
```

Then make it executable:

```bash
chmod +x .claude/hooks/inject-brain.sh
```

- [x] **Step 4: Run the test to verify it passes**

Run: `sh tests/hooks-test.sh`
Expected: 6 `ok` lines, final line `ALL PASS`, exit code 0.

- [x] **Step 5: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add tests/hooks-test.sh .claude/hooks/inject-brain.sh
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(hooks): Inject brain index at session start

Ported from noodle's inject-brain.sh. Fail-open POSIX shell.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: auto-index-brain.sh (PostToolUse hook)

**Files:**
- Modify: `tests/hooks-test.sh` (append scenarios before the final `echo` block)
- Create: `.claude/hooks/auto-index-brain.sh`

- [x] **Step 1: Extend the test with failing scenarios**

In `tests/hooks-test.sh`, insert the following block **after** the last inject-brain scenario (the unreadable-index checks ending `chmod 644 "$proj/brain/index.md"`) and **before** the final summary `echo` block:

```sh
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
```

- [x] **Step 2: Run the test to verify the new scenarios fail**

Run: `sh tests/hooks-test.sh`
Expected: inject checks still `ok`; every `autoidx:` check FAILs (script missing); final line `FAILURES PRESENT`, exit 1.

- [x] **Step 3: Write the hook**

Create `.claude/hooks/auto-index-brain.sh` with exactly:

```sh
#!/bin/sh
# PostToolUse(Edit|Write) hook: rebuild brain/index.md when a brain file
# changes. Deterministic POSIX shell, no LLM, no jq. Fail-open: every anomaly
# exits 0 so a broken vault never breaks a session.
#
# Note: Claude Code hook matchers match TOOL NAMES, not paths (noodle wired
# this with matcher "brain/", which never fires). We match Edit|Write in
# settings.json and filter the file_path here instead.

LC_ALL=C
export LC_ALL

input=$(cat 2>/dev/null) || exit 0

case "$input" in
  *'"file_path"'*) ;;
  *) exit 0 ;;
esac

fp=$(printf '%s' "$input" \
  | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -n 1 \
  | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')

case "$fp" in
  */brain/*) ;;
  *) exit 0 ;;
esac

BRAIN_DIR="${CLAUDE_PROJECT_DIR:-.}/brain"
INDEX="$BRAIN_DIR/index.md"
[ -d "$BRAIN_DIR" ] || exit 0
if [ -e "$INDEX" ] && [ ! -f "$INDEX" ]; then exit 0; fi

# Vault entries: vault-relative, .md stripped. Excludes index.md itself and
# anything nested inside a plan directory (plans/index survives the filter —
# plan dirs are indexed via plans/index.md by convention).
disk=$(find "$BRAIN_DIR" -type f -name '*.md' ! -path "$INDEX" 2>/dev/null \
  | sed "s|^$BRAIN_DIR/||; s|\.md$||" \
  | grep -v '^plans/[^/]*/' \
  | grep -v '^archive/plans/[^/]*/' \
  | sort)

indexed=$(sed -n 's/.*\[\[\([^]]*\)\]\].*/\1/p' "$INDEX" 2>/dev/null | sort)

# Fast path: index already reflects disk — do not rewrite.
[ "$disk" = "$indexed" ] && exit 0

tmp=$(mktemp "$INDEX.tmp.XXXXXX" 2>/dev/null) || exit 0
trap 'rm -f "$tmp"' EXIT

emit() { # emit <Title> <grep -E pattern>
  m=$(printf '%s\n' "$disk" | grep -E "$2")
  [ -n "$m" ] || return 0
  printf '\n## %s\n' "$1"
  printf '%s\n' "$m" | sed 's/.*/- [[&]]/'
}

known='^vision$|^principles$|^principles/|^apps$|^codebase/|^todos$|^plans/index$|^archive/'

{
  printf '# Brain\n'
  emit "Vision"     '^vision$'
  emit "Principles" '^principles$|^principles/'
  emit "Apps"       '^apps$'
  emit "Codebase"   '^codebase/'
  emit "Backlog"    '^todos$'
  emit "Plans"      '^plans/index$'
  emit "Archive"    '^archive/'
  other=$(printf '%s\n' "$disk" | grep -Ev "$known")
  if [ -n "$other" ]; then
    printf '\n## Other\n'
    printf '%s\n' "$other" | sed 's/.*/- [[&]]/'
  fi
} > "$tmp" 2>/dev/null || exit 0

chmod 644 "$tmp" 2>/dev/null
mv "$tmp" "$INDEX" 2>/dev/null
exit 0
```

Then make it executable:

```bash
chmod +x .claude/hooks/auto-index-brain.sh
```

- [x] **Step 4: Run the test to verify everything passes**

Run: `sh tests/hooks-test.sh`
Expected: all `ok` (6 inject + 11 autoidx checks), final line `ALL PASS`, exit 0.

- [x] **Step 5: Run it twice more to prove the suite itself is idempotent**

Run: `sh tests/hooks-test.sh && sh tests/hooks-test.sh`
Expected: `ALL PASS` both times (fresh mktemp sandbox each run).

- [x] **Step 6: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add tests/hooks-test.sh .claude/hooks/auto-index-brain.sh
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(hooks): Auto-rebuild brain index on brain writes

Ported from noodle's auto-index-brain.sh with a wiring fix: Claude Code
hook matchers match tool names, so the path filter lives in the script.
Atomic write (mktemp + mv), fast-path no-op, fail-open everywhere.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Hook wiring + spec tree amendment

**Files:**
- Create: `.claude/settings.json`
- Modify: `brain/plans/01-sobaya-harness/overview.md` (architecture tree)
- Modify: `brain/plans/01-sobaya-harness/overview.ko.md` (architecture tree)

- [x] **Step 1: Write the settings**

Create `.claude/settings.json` with exactly:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/inject-brain.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/auto-index-brain.sh"
          }
        ]
      }
    ]
  }
}
```

- [x] **Step 2: Validate the JSON parses**

Run: `python3 -c "import json,sys; json.load(open('.claude/settings.json')); print('valid')"`
Expected: `valid`

- [x] **Step 3: Amend both spec trees with tests/**

In `brain/plans/01-sobaya-harness/overview.md`, in the Architecture tree, replace:

```
├── apps/                      # independent git repos, gitignored from root
│   └── .gitkeep
```

with:

```
├── apps/                      # independent git repos, gitignored from root
│   └── .gitkeep
├── tests/
│   └── hooks-test.sh          # POSIX test suite for the hooks
```

In `brain/plans/01-sobaya-harness/overview.ko.md`, in the 구조 tree, replace:

```
├── apps/                      # 독립 git 저장소들, 루트에서 gitignore
│   └── .gitkeep
```

with:

```
├── apps/                      # 독립 git 저장소들, 루트에서 gitignore
│   └── .gitkeep
├── tests/
│   └── hooks-test.sh          # 훅용 POSIX 테스트 스위트
```

- [x] **Step 4: Note for this session (no action): hooks load at session start**

The hooks in `.claude/settings.json` will NOT fire in the session that creates them — Claude Code reads hook config at session start. Phase 2 therefore runs the index generator manually (Task 9), and the SessionStart injection is verified at the next session start (spec: Verification → "Hooks, e2e").

- [x] **Step 5: Commit**

```bash
git -C /Users/amazon/lunch.cancelled/sobaya add .claude/settings.json brain/plans/01-sobaya-harness/overview.md brain/plans/01-sobaya-harness/overview.ko.md
git -C /Users/amazon/lunch.cancelled/sobaya commit -m "feat(hooks): Wire SessionStart and PostToolUse hooks

Spec trees amended with tests/ (as-built accuracy).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
