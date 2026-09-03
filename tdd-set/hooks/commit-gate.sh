#!/usr/bin/env bash
# PreToolUse hook (Bash): before `git commit`, run the hygiene commands the app CLAUDE.md
# declares — the same spot Kent Beck kept `cargo fmt` / `cargo test` in agent.md:
#   - Format: `gofmt -l .`      (must print nothing)
#   - Lint:   `go vet ./...`    (must exit 0)
# Any failing command blocks the commit (exit 2). No lines declared → Go defaults if go.mod exists.
cmd=$(sed -n 's/.*"command":"\([^"]*\)".*/\1/p' | head -1)
grep -qE '(^|[;&| ])git( -C [^ ]+)? commit' <<<"$cmd" || exit 0
# `git -C <dir> commit` from the Sobaya root: gate that app, not the root
dir=$(sed -nE 's/.*git -C ([^ ]+) .*/\1/p' <<<"$cmd" | head -1)
[ -n "$dir" ] && cd "$dir" 2>/dev/null
[ -f CLAUDE.md ] || exit 0

fmt_cmd=$(sed -nE 's/^- Format: `?([^`]+)`?.*/\1/p' CLAUDE.md | head -1)
lint_cmd=$(sed -nE 's/^- Lint: `?([^`]+)`?.*/\1/p' CLAUDE.md | head -1)
if [ -z "$fmt_cmd$lint_cmd" ]; then
  [ -f go.mod ] || exit 0
  fmt_cmd='gofmt -l .'; lint_cmd='go vet ./...'
fi

if [ -n "$fmt_cmd" ]; then
  out=$(eval "$fmt_cmd" 2>&1) || { echo "Format failed ($fmt_cmd):" >&2; echo "$out" >&2; exit 2; }
  [ -z "$out" ] || { echo "Format needed ($fmt_cmd):" >&2; echo "$out" >&2; exit 2; }
fi
if [ -n "$lint_cmd" ]; then
  eval "$lint_cmd" >&2 || { echo "Lint failed ($lint_cmd)" >&2; exit 2; }
fi
exit 0
