#!/usr/bin/env bash
# next.sh: prints only the next unchecked entry (heading, Node header block, checkbox line, code
# block) and checks exactly one line. Run: bash tdd-set/tests/next-entry.sh
set -u
next=$(cd "$(dirname "$0")/../bin" && pwd)/next.sh
tpl=$(cd "$(dirname "$0")/.." && pwd)/failed-test-template.md
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
cp "$tpl" "$d/failed-test.md"
fail=0
check() { if [ "$1" -eq 0 ]; then echo "ok   - $2"; else echo "FAIL - $2"; fail=1; fi; }

out=$(bash "$next" "$d"); check $? "next: exits 0 with an unchecked entry"
[ "$(head -1 <<<"$out")" = "## Small feature 1: <name>" ]; check $? "next: starts with the section heading"
[ "$(sed -n 2p <<<"$out")" = "- [ ] TestAdd_SumsTwoPositives — 1 + 2 = 3." ]; check $? "next: then the first unchecked line"
[ "$(tail -1 <<<"$out")" = '```' ] && grep -q 'func TestAdd_SumsTwoPositives' <<<"$out"; check $? "next: then its code block, closed"
! grep -q 'TestAdd_ZeroIsIdentity' <<<"$out"; check $? "next: nothing from the second entry"
[ "$(wc -l <<<"$out")" -eq 9 ]; check $? "next: 9 lines, not the whole file"

bash "$next" "$d" check TestAdd_SumsTwoPositives; check $? "check: exits 0 on an unchecked name"
[ "$(grep -c '^- \[x\]' "$d/failed-test.md")" -eq 1 ] && grep -q '^- \[x\] TestAdd_SumsTwoPositives — 1 + 2 = 3.$' "$d/failed-test.md"
check $? "check: flips that line only"
diff <(grep -v 'TestAdd_SumsTwoPositives —' "$tpl") <(grep -v 'TestAdd_SumsTwoPositives —' "$d/failed-test.md") >/dev/null
check $? "check: every other line untouched"
bash "$next" "$d" check TestAdd_SumsTwoPositives >/dev/null 2>&1; [ $? -eq 1 ]; check $? "check: exits 1 when already checked"
bash "$next" "$d" check TestAdd >/dev/null 2>&1; [ $? -eq 1 ]; check $? "check: a name prefix does not match"

out=$(bash "$next" "$d"); grep -q '^- \[ \] TestAdd_ZeroIsIdentity' <<<"$out"; check $? "next: moves on to the second entry"
for n in TestAdd_ZeroIsIdentity TestAdd_Overflow Test...; do bash "$next" "$d" check "$n" >/dev/null; done
out=$(bash "$next" "$d")
[ "$(sed -n 2p <<<"$out")" = '```ts' ] && grep -q '^// file: tests/add.test.ts$' <<<"$out" && grep -q "^test('addAdds" <<<"$out"
check $? "next: Node entry carries the section header block before the entry"
! grep -q 'addZeroIsIdentity' <<<"$out"; check $? "next: Node header block is not repeated with later entries"
for n in addAdds addZeroIsIdentity; do bash "$next" "$d" check "$n" >/dev/null; done
out=$(bash "$next" "$d"); rc=$?; [ $rc -eq 1 ] && [ -z "$out" ]; check $? "next: exit 1, silent, when every box is checked"

[ $fail -eq 0 ] && echo "ALL PASS" || { echo "FAILURES PRESENT"; exit 1; }
