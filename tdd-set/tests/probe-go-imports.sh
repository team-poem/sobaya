#!/usr/bin/env bash
# probe.sh (Go): a snippet with its own import block builds, so GREEN means "behavior exists"
# again instead of "import missing" (issue #3). Needs the go toolchain. Run: bash tdd-set/tests/probe-go-imports.sh
set -u
probe=$(cd "$(dirname "$0")/../bin" && pwd)/probe.sh
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
mkdir -p "$d/calc"
printf 'module probefixture\n\ngo 1.22\n' > "$d/go.mod"
printf 'package calc\n\nfunc Add(a, b int) int { return a + b }\n' > "$d/calc/calc.go"
fail=0
check() { if [ "$1" -eq 0 ]; then echo "ok   - $2"; else echo "FAIL - $2"; fail=1; fi; }
run() { out=$(printf '%s\n' "$1" | bash "$probe" "$d/calc" - 2>&1); rc=$?; }

run 'import (
	"strconv"
	"testing"
)

func TestAdd_ViaStrconv(t *testing.T) {
	if got := strconv.Itoa(Add(1, 2)); got != "3" {
		t.Fatalf("got %s", got)
	}
}'
[ $rc -eq 1 ] && grep -q '^GREEN  TestAdd_ViaStrconv' <<<"$out"; check $? "probe: snippet with its own import block builds and reports GREEN ($out)"

run 'func TestAdd_Plain(t *testing.T) {
	if Add(1, 2) != 3 {
		t.Fatal("bad")
	}
}'
[ $rc -eq 1 ] && grep -q '^GREEN  TestAdd_Plain' <<<"$out"; check $? "probe: snippet without imports still gets import \"testing\" ($out)"

run 'import (
	"strconv"
	"testing"
)

func TestMul_Missing(t *testing.T) {
	if strconv.Itoa(Mul(2, 3)) != "6" {
		t.Fatal("bad")
	}
}'
[ $rc -eq 0 ] && grep -q '^RED    TestMul_Missing  (does not build' <<<"$out"; check $? "probe: an undefined symbol is still RED (does not build) ($out)"

run 'import (
	"strconv"
	"testing"
)

func TestAdd_WrongExpectation(t *testing.T) {
	if got := strconv.Itoa(Add(1, 2)); got != "4" {
		t.Fatalf("got %s", got)
	}
}'
[ $rc -eq 0 ] && grep -q '^RED    TestAdd_WrongExpectation  (fails' <<<"$out"; check $? "probe: a failing assertion is RED (fails), not a build failure ($out)"
[ ! -e "$d/calc/zz_probe_test.go" ]; check $? "probe: temporary file removed"

[ $fail -eq 0 ] && echo "ALL PASS" || { echo "FAILURES PRESENT"; exit 1; }
