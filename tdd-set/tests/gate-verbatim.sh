#!/usr/bin/env bash
# gate.sh: a checked entry passes only when its code block sits in the committed suite verbatim;
# a rewritten test (same name, weaker assertion) fails. Run: bash tdd-set/tests/gate-verbatim.sh
set -u
gate=$(cd "$(dirname "$0")/../bin" && pwd)/gate.sh
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
fail=0
check() { if [ "$1" -eq 0 ]; then echo "ok   - $2"; else echo "FAIL - $2"; fi; [ "$1" -eq 0 ] || fail=1; }
( cd "$d" && git init -q && git config user.email t@t && git config user.name t && git config commit.gpgsign false
  printf '# fixture\n\n## App facts\n- Test: `true`\n' > AGENTS.md
  printf 'package calc\n\nimport "testing"\n\nfunc TestOld(t *testing.T) {}\n' > calc_test.go
  printf '# p\n\n## Small feature 1: add\n\n- [ ] TestAdd_Sum — 1+2=3.\n```go\nfunc TestAdd_Sum(t *testing.T) {\n\tif Add(1, 2) != 3 {\n\t\tt.Fatal("bad")\n\t}\n}\n```\n\n## Notes\n- prose\n```go\nnot an entry block\n```\n' > failed-test.md
  git add -A && git commit -qm start ) >/dev/null 2>&1
start=$(git -C "$d" rev-parse HEAD)
( cd "$d" && printf '\nfunc TestAdd_Sum(t *testing.T) {\n\tif Add(1, 2) != 3 {\n\t\tt.Fatal("bad")\n\t}\n}\n' >> calc_test.go
  sed 's/- \[ \] TestAdd_Sum/- [x] TestAdd_Sum/' failed-test.md > f && mv f failed-test.md && git add -A && git commit -qm verbatim ) >/dev/null 2>&1
out=$(bash "$gate" "$d" "$start" 2>&1); check $? "gate: verbatim entry passes ($(tail -1 <<<"$out"))"
( cd "$d" && git checkout -q "$start" -- calc_test.go && printf '\nfunc TestAdd_Sum(t *testing.T) {\n\tif Add(1, 2) == 0 {\n\t\tt.Fatal("bad")\n\t}\n}\n' >> calc_test.go && git commit -qam rewritten ) >/dev/null 2>&1
out=$(bash "$gate" "$d" "$start" 2>&1); rc=$?
[ $rc -ne 0 ] && grep -q 'not verbatim in the committed suite: TestAdd_Sum' <<<"$out"; check $? "gate: same name with a rewritten body fails as not verbatim"
[ $fail -eq 0 ] && echo "ALL PASS" || { echo "FAILURES PRESENT"; exit 1; }
