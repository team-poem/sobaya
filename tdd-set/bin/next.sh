#!/usr/bin/env bash
# The loop's O(1) view of failed-test.md: print only the next unchecked entry, or check one box.
# A cycle must never read the whole file — with N entries that is O(N²) tokens over the run.
# usage: tdd-set/bin/next.sh <dir>                  print: the section heading, the section's header
#                                                   block (Node `// file:` fence, if any), the
#                                                   `- [ ] Name — ...` line and its code block.
#                                                   exit 1 when nothing is left unchecked
#        tdd-set/bin/next.sh <dir> check <TestName>  flip `- [ ] TestName` to `- [x]` in place, that
#                                                   line only. exit 1 if no such unchecked entry
set -u
dir=${1:?usage: next.sh <dir> [check <TestName>]}; f=${dir%/}/failed-test.md
[ -f "$f" ] || { echo "no $f"; exit 2; }

if [ "${2:-}" = check ]; then
  name=${3:?usage: next.sh <dir> check <TestName>}
  grep -qE "^- \[ \] $name( |$)" "$f" || { echo "no unchecked entry $name in $f"; exit 1; }
  tmp=$(mktemp) || exit 1
  # ponytail: awk + cat back instead of sed -i, which differs between BSD and GNU
  awk -v n="$name" '!done && $0 ~ "^- \\[ \\] " n "( |$)" { sub(/^- \[ \]/, "- [x]"); done = 1 } { print }' "$f" > "$tmp" \
    && cat "$tmp" > "$f"; rc=$?
  rm -f "$tmp"; exit $rc
fi
[ -z "${2:-}" ] || { echo "usage: next.sh <dir> [check <TestName>]"; exit 2; }

awk '
  printing {
    if (!fence && ($0 ~ /^- \[/ || $0 ~ /^## /)) exit      # next entry or section: this one had no code block
    print
    if ($0 ~ /^```/) { fence = !fence; if (!fence) exit }  # closing fence ends the entry
    next
  }
  /^## / { heading = $0; header = ""; seen = 0; hfence = 0; next }
  /^- \[[ x]\] / {
    seen = 1
    if ($0 ~ /^- \[ \] /) { if (heading != "") print heading; printf "%s", header; print; printing = 1; found = 1 }
    next
  }
  !seen && (hfence || $0 ~ /^```/) { header = header $0 "\n"; if ($0 ~ /^```/) hfence = !hfence }
  END { exit !found }
' "$f"
