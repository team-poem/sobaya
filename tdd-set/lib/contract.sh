#!/bin/bash
# Acceptance authority is the approved Git commit; execution evidence is runner output.
CONTRACT_LIB=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$CONTRACT_LIB/common.sh"
contract_git_dir() { git -C "$1" rev-parse --absolute-git-dir; }
contract_index_safe() {
  local listing hidden
  # -v lowercases assume-unchanged entries; S marks skip-worktree. These
  # flags can make git status and git add hide a different working file.
  listing=$(set -o pipefail; git -C "$1" ls-files -v -z | jq -Rs 'split("\u0000")[:-1]') || return 1
  hidden=$(printf '%s' "$listing" | jq -r '.[]|select(test("^[a-zS] "))') || return 1
  [ -z "$hidden" ] || { sb_error "Unsafe index flags hide tracked files (skip-worktree/assume-unchanged): $hidden"; return 1; }
}
contract_clean() {
  local app top status
  app=$(cd "$1" && pwd -P) || return 1
  top=$(git -C "$app" rev-parse --show-toplevel) || return 1
  [ "$app" = "$(cd "$top" && pwd -P)" ] || { sb_error 'App must be the Git repository root'; return 1; }
  contract_index_safe "$app" || return 1
  status=$(git -C "$app" status --porcelain=v1 --untracked-files=all) || return 1
  [ -z "$status" ] || { sb_error "A clean working tree and index are required (including untracked files): $status"; return 1; }
}
contract_baseline() {
  local app=$1 baseline=${2:-} commit
  case "$baseline" in ''|-*) sb_error 'An approved baseline commit is required'; return 1;; esac
  commit=$(git -C "$app" rev-parse --verify "$baseline^{commit}") || return 1
  git -C "$app" merge-base --is-ancestor "$commit" HEAD || { sb_error 'Baseline must be an ancestor of HEAD'; return 1; }
  printf '%s\n' "$commit"
}
contract_saved_baseline() {
  local metadata baseline
  metadata=$(contract_git_dir "$1") || return 1
  [ -f "$metadata/sobaya/state.json" ] || { sb_error 'No approved baseline; approve the plan before running the gate'; return 1; }
  baseline=$(jq -er '.baseline|select(type=="string" and length>0)' "$metadata/sobaya/state.json") || { sb_error 'Invalid approval state'; return 1; }
  contract_baseline "$1" "$baseline"
}
_contract_text() {
  if [ -n "${3:-}" ]; then git -C "$1" show "$3:$2"
  else [ -f "$1/$2" ] && [ ! -L "$1/$2" ] || { sb_error "Cannot read regular file $2"; return 1; }; cat "$1/$2"; fi
}
contract_plan() (
  set -o pipefail
  local tmp
  tmp=$(mktemp -d) || exit 1; trap "rm -rf -- $(printf '%q' "$tmp")" EXIT
  _contract_text "$1" failed-test.md "${2:-}" >"$tmp/plan" || exit 1
  awk -f "$CONTRACT_LIB/plan.awk" "$tmp/plan" | jq -s .
)
_contract_normalize() { awk '/^```/ {fenced=!fenced} !fenced {sub(/^- \[x\]/,"- [ ]")} {print}' "$1"; }
contract_validate() (
  set -o pipefail
  local app=$1 baseline=$2 complete=${3:-false} tmp old new oldcommands newcommands
  baseline=$(contract_baseline "$app" "$baseline") || exit 1
  tmp=$(mktemp -d) || exit 1; trap "rm -rf -- $(printf '%q' "$tmp")" EXIT
  _contract_text "$app" failed-test.md "$baseline" >"$tmp/old" && _contract_text "$app" failed-test.md HEAD >"$tmp/new" || exit 1
  contract_plan "$app" "$baseline" >"$tmp/before.json" && contract_plan "$app" HEAD >"$tmp/after.json" || exit 1
  _contract_normalize "$tmp/old" >"$tmp/old.normal"; _contract_normalize "$tmp/new" >"$tmp/new.normal"
  jq -ne --rawfile old "$tmp/old.normal" --rawfile new "$tmp/new.normal" '($old|sub("\n+$";"")) as $a|($new|sub("\n+$";"")) as $b|$a==$b or ($b|startswith($a+"\n"))' >/dev/null || { sb_error 'Approved plan text, code, and headers must not change or disappear'; exit 1; }
  jq -ne --slurpfile old "$tmp/before.json" --slurpfile new "$tmp/after.json" '
    $old[0] as $a|$new[0] as $b|($b|length)>=($a|length) and all(range(0;$a|length); . as $i|$a[$i].name==$b[$i].name and (($a[$i].checked|not) or $b[$i].checked))' >/dev/null || { sb_error 'Approved plan order and completed entries must not change'; exit 1; }
  jq -ne --slurpfile old "$tmp/before.json" --slurpfile new "$tmp/after.json" '$new[0][($old[0]|length):]|all(.checked|not)' >/dev/null || { sb_error 'Unapproved appended entries cannot be checked'; exit 1; }
  if [ "$complete" = true ]; then jq -e 'all(.checked)' "$tmp/after.json" >/dev/null || { sb_error 'Unchecked plan entries remain'; exit 1; }; fi
  _contract_text "$app" spec.md "$baseline" >"$tmp/spec.old" && _contract_text "$app" spec.md HEAD >"$tmp/spec.new" || exit 1
  cmp -s "$tmp/spec.old" "$tmp/spec.new" || { sb_error 'Approved spec.md must not change'; exit 1; }
  _contract_text "$app" AGENTS.md "$baseline" >"$tmp/agents.old" && _contract_text "$app" AGENTS.md HEAD >"$tmp/agents.new" || exit 1
  awk '/^- (Test|Test-File|Format|Lint|Bench):/' "$tmp/agents.old" >"$tmp/commands.old"
  awk '/^- (Test|Test-File|Format|Lint|Bench):/' "$tmp/agents.new" >"$tmp/commands.new"
  cmp -s "$tmp/commands.old" "$tmp/commands.new" || { sb_error 'Approved AGENTS.md commands must not change'; exit 1; }
  if grep -Eq '(^|[^[:alnum:]_])(npm|npx|vitest)([^[:alnum:]_]|$)' "$tmp/commands.old"; then
    _contract_text "$app" package.json "$baseline" >"$tmp/pkg.old" && _contract_text "$app" package.json HEAD >"$tmp/pkg.new" || exit 1
    jq -e 'type=="object"' "$tmp/pkg.old" >/dev/null && jq -e 'type=="object"' "$tmp/pkg.new" >/dev/null || exit 1
    jq -Sc '.scripts//{}' "$tmp/pkg.old" >"$tmp/scripts.old" && jq -Sc '.scripts//{}' "$tmp/pkg.new" >"$tmp/scripts.new" || exit 1
    cmp -s "$tmp/scripts.old" "$tmp/scripts.new" || { sb_error 'Approved package.json scripts must not change'; exit 1; }
  fi
  cat "$tmp/after.json"
)
contract_protected() {
  case "/$1" in */test/*|*/tests/*|*/__tests__/*|*/fixtures/*|*/testdata/*|*_test.go|*_test.py|*/test_*.py|*.test.*|*.spec.*|*/conftest.py) return 0;; esac
  return 1
}
_contract_test_source() { case "$1" in *_test.go|*_test.py|test_*.py|*/test_*.py|*.test.*|*.spec.*) return 0;; esac; return 1; }
_contract_tree() {
  git -C "$1" ls-tree -rz "$2" | jq -Rs 'split("\u0000")[:-1]|map(capture("^(?<mode>[^ ]+) (?<kind>[^ ]+) (?<oid>[^\t]+)\t(?<path>.*)$";"s"))|map({key:.path,value:{mode,kind,oid}})|from_entries'
}
_contract_additions() {
  local name=$1 old=$2 new=$3 explicit=$4 tmp=$5 total first bytes last
  cmp -s "$old" "$new" && return 0
  { _contract_test_source "$name" || [ "$explicit" = true ]; } || return 1
  LC_ALL=C tr -d '\000' <"$old" >"$tmp/no-nul"; cmp -s "$old" "$tmp/no-nul" || return 1
  LC_ALL=C tr -d '\000' <"$new" >"$tmp/no-nul"; cmp -s "$new" "$tmp/no-nul" || return 1
  bytes=$(wc -c <"$old" | tr -d ' '); last=$(tail -c 1 "$old" | od -An -tu1 | tr -d ' \n')
  if [ "$bytes" -eq 0 ] || [ "$last" = 10 ]; then head -c "$bytes" "$new" >"$tmp/prefix"; cmp -s "$old" "$tmp/prefix" && return 0; fi
  case "$name" in *_test.go) ;; *) return 1;; esac
  total=$(awk 'END{print NR}' "$old"); first=$(awk '/^func[[:space:]]/{print NR-1;found=1;exit}END{if(!found)print NR}' "$old")
  local rc
  if diff -U0 "$old" "$new" >"$tmp/diff"; then rc=0; else rc=$?; fi
  [ "$rc" -le 1 ] || return 1
  awk -v total="$total" -v firstfunc="$first" -f "$CONTRACT_LIB/go-additions.awk" "$tmp/diff"
}
contract_sources() (
  set -o pipefail
  local app=$1 baseline=$2 entries=$3 tmp path oldinfo newinfo explicit entry name target matches candidate
  tmp=$(mktemp -d) || exit 1; trap "rm -rf -- $(printf '%q' "$tmp")" EXIT
  _contract_tree "$app" "$baseline" >"$tmp/before" && _contract_tree "$app" HEAD >"$tmp/after" || exit 1
  while IFS= read -r -d '' path; do
    explicit=false; jq -e --arg p "$path" 'any(.target==$p)' "$entries" >/dev/null && explicit=true
    { contract_protected "$path" || [ "$explicit" = true ]; } || continue
    oldinfo=$(jq -c --arg p "$path" '.[$p]' "$tmp/before"); newinfo=$(jq -c --arg p "$path" '.[$p]' "$tmp/after")
    [ "$(printf '%s' "$newinfo" | jq -r '[.mode,.kind]|join(" ")')" = "$(printf '%s' "$oldinfo" | jq -r '[.mode,.kind]|join(" ")')" ] || { sb_error "Protected test/fixture removed, renamed, or changed type: $path"; exit 1; }
    if [ "$(printf '%s' "$oldinfo" | jq -r .oid)" != "$(printf '%s' "$newinfo" | jq -r .oid)" ]; then
      git -C "$app" show "$baseline:$path" >"$tmp/old" && git -C "$app" show "HEAD:$path" >"$tmp/new" || exit 1
      _contract_additions "$path" "$tmp/old" "$tmp/new" "$explicit" "$tmp" || { sb_error "Protected test/fixture modified: $path"; exit 1; }
    fi
  done < <(jq -j 'keys[]+"\u0000"' "$tmp/before")
  while IFS= read -r entry; do
    name=$(printf '%s' "$entry"|jq -r .name); target=$(printf '%s' "$entry"|jq -r '.target//empty')
    printf '%s' "$entry" | jq -j .code >"$tmp/code"; printf '%s' "$entry"|jq -j .header >"$tmp/header"
    if [ -n "$target" ]; then printf '%s\0' "$target" >"$tmp/candidates"
    else jq -j 'keys[]|select(endswith("_test.go"))|.+"\u0000"' "$tmp/after" >"$tmp/candidates"; fi
    matches=false
    while IFS= read -r -d '' candidate; do
      jq -e --arg p "$candidate" '.[$p]|(.mode=="100644" or .mode=="100755") and .kind=="blob"' "$tmp/after" >/dev/null || continue
      git -C "$app" show "HEAD:$candidate" >"$tmp/source" || exit 1
      if jq -ne --rawfile source "$tmp/source" --rawfile code "$tmp/code" '$source|contains($code)' >/dev/null; then
        matches=true
        if [ -n "$target" ] && [ -s "$tmp/header" ]; then
          jq -ne --rawfile source "$tmp/source" --rawfile header "$tmp/header" '$source|startswith($header)' >/dev/null || { sb_error "Approved test header is not verbatim: $name"; exit 1; }
        fi
        break
      fi
    done <"$tmp/candidates"
    [ "$matches" = true ] || { sb_error "Approved test is not verbatim in its committed file: $name"; exit 1; }
  done < <(jq -c '.[]|select(.checked)' "$entries")
)
_contract_words() { awk -f "$CONTRACT_LIB/shell-words.awk" "$1" | jq -Rs 'split("\u0000")[:-1]'; }
_contract_command() (
  set -o pipefail
  local app=$1 tmp argv exe second script extras
  tmp=$(mktemp -d) || exit 1; trap "rm -rf -- $(printf '%q' "$tmp")" EXIT
  _contract_text "$app" AGENTS.md >"$tmp/agents" || exit 1
  awk '/^- Test:/{n++;line=$0}END{if(n!=1||line!~/^- Test:[[:space:]]*`[^`]+`[[:space:]]*$/)exit 1;sub(/^- Test:[[:space:]]*`/,"",line);sub(/`[[:space:]]*$/,"",line);print line}' "$tmp/agents" >"$tmp/command" || { sb_error 'AGENTS.md must declare exactly one - Test: `command`'; exit 1; }
  argv=$(_contract_words "$tmp/command") || exit 1
  exe=$(printf '%s' "$argv"|jq -r '.[0]//empty'); second=$(printf '%s' "$argv"|jq -r '.[1]//empty')
  if [ "$exe" = npm ]; then
    case "$second" in test) script=test; extras=$(printf '%s' "$argv"|jq '.[2:]');; run|run-script) script=$(printf '%s' "$argv"|jq -r '.[2]//empty'); extras=$(printf '%s' "$argv"|jq '.[3:]');; *) sb_error 'Unsupported npm Test command'; exit 1;; esac
    jq -er --arg s "$script" '.scripts as $scripts|if ($scripts[$s]|type)!="string" then error("npm script missing") elif (($scripts["pre"+$s]//"")!="" or ($scripts["post"+$s]//"")!="") then error("unsupported npm lifecycle hooks") else $scripts[$s] end' "$app/package.json" >"$tmp/command" || exit 1
    argv=$(_contract_words "$tmp/command") || exit 1
    argv=$(jq -n --argjson a "$argv" --argjson b "$extras" '$a+(if $b[0]=="--" then $b[1:] else $b end)') || exit 1
  fi
  argv=$(printf '%s' "$argv"|jq 'if .[0:2]==["npx","vitest"] then .[1:] else . end') || exit 1
  exe=$(printf '%s' "$argv"|jq -r '.[0]//empty'); second=$(printf '%s' "$argv"|jq -r '.[1]//empty')
  case "$exe" in
    go) [ "$second" = test ] || exit 1; printf '%s' "$argv"|jq '{runner:"go",argv:(.+["-json","-count=1"])}';;
    node)
      printf '%s' "$argv"|jq -e 'index("--test")!=null and all(.[];startswith("--test-reporter")|not)' >/dev/null || { sb_error 'Unsupported Node Test command/reporter'; exit 1; }
      printf '%s' "$argv"|jq '{runner:"node",argv:((index("--test")+1) as $i|.[:$i]+["--test-reporter=tap"]+.[$i:])}';;
    vitest|./node_modules/.bin/vitest|node_modules/.bin/vitest)
      [ "$second" = run ] && [ -f "$app/node_modules/.bin/vitest" ] || { sb_error 'Vitest must be installed locally and invoked with run'; exit 1; }
      printf '%s' "$argv"|jq -e 'all(.[];test("^--(reporter|outputFile|watch)")|not)' >/dev/null || exit 1
      printf '%s' "$argv"|jq --arg bin "$app/node_modules/.bin/vitest" '{runner:"vitest",argv:([$bin]+.[1:])}';;
    *) sb_error 'Unsupported Test command: use go test, node --test, or local vitest run'; exit 1;;
  esac
)
contract_hygiene() {
  local app=$1 timeout=${2:-300} tmp kind command rc listing_rc
  tmp=$(mktemp -d) || return 1
  _contract_text "$app" AGENTS.md >"$tmp/agents" || { rm -rf "$tmp"; return 1; }
  for kind in Format Lint; do
    awk -v kind="$kind" '$0~"^- "kind":"{n++;line=$0}END{if(n>1)exit 1;if(!n)exit 0;sub("^- "kind":[[:space:]]*","",line);if(line~/^`/){if(line!~/`[[:space:]]*$/)exit 1;sub(/^`/,"",line);sub(/`[[:space:]]*$/,"",line)}if(line!~/[^[:space:]]/)exit 1;print line}' "$tmp/agents" >"$tmp/cmd" || { sb_error "Invalid $kind command"; rm -rf "$tmp"; return 1; }
    [ -s "$tmp/cmd" ] || continue
    command=$(cat "$tmp/cmd")
    if sb_run "$timeout" "$tmp/out" "$tmp/err" /dev/null "$app" -- /bin/sh -c "$command"; then rc=0; else rc=$?; fi
    cat "$tmp/out" "$tmp/err" >&2
    if [ "$rc" -ne 0 ]; then sb_error "$kind check failed (exit $rc)"; rm -rf "$tmp"; [ "$rc" -ne 130 ] || return 130; return 1; fi
    if [ "$kind" = Format ]; then
      if printf '%s\n' "$command" | awk -f "$CONTRACT_LIB/../../scripts/formatter-listing.awk"; then listing_rc=0; else listing_rc=$?; fi
      [ "$listing_rc" -le 1 ] || { sb_error 'Cannot classify formatter output'; rm -rf "$tmp"; return 1; }
      if [ "$listing_rc" -eq 0 ] && { [ -s "$tmp/out" ] || [ -s "$tmp/err" ]; }; then
        sb_error 'Format needed: gofmt listed unformatted files'; rm -rf "$tmp"; return 1
      fi
    fi
  done
  rm -rf "$tmp"
}
contract_suite() {
  local app=$1 timeout=${2:-300} tmp command runner rc valid=false result name names argv=()
  app=$(cd "$app" && pwd -P) || return 1
  tmp=$(mktemp -d) || return 1
  command=$(_contract_command "$app") || { rm -rf "$tmp"; return 1; }
  runner=$(printf '%s' "$command"|jq -r .runner)
  while IFS= read -r -d '' name; do argv[${#argv[@]}]=$name; done < <(printf '%s' "$command"|jq -j '.argv[]+"\u0000"')
  if [ "$runner" = vitest ]; then argv[${#argv[@]}]='--reporter=json'; argv[${#argv[@]}]="--outputFile=$tmp/vitest.json"; fi
  if sb_run "$timeout" "$tmp/out" "$tmp/err" /dev/null "$app" -- "${argv[@]}"; then rc=0; else rc=$?; fi
  cat "$tmp/out" "$tmp/err" >"$tmp/output"
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 130 ] || [ "$rc" -eq 127 ]; then cat "$tmp/output" >&2; rm -rf "$tmp"; [ "$rc" -ne 130 ] || return 130; return 1; fi
  case "$runner" in
    go)
      jq -Rn '[inputs|fromjson?|select(type=="object")]|{valid:any(.Action!=null),passed:[.[]|select(.Test and .Action=="pass")|.Test]|unique,failed:[.[]|select(.Test and .Action=="fail")|.Test]|unique,skipped:[.[]|select(.Test and .Action=="skip")|.Test]|unique}' <"$tmp/output" >"$tmp/evidence" || { rm -rf "$tmp"; return 1; };;
    node)
      jq -Rn '[inputs] as $lines|{valid:(any($lines[];test("^TAP version [0-9]+$")) and any($lines[];test("^1\\.\\.[0-9]+\\s*$"))),events:[$lines[]|capture("^\\s*(?<status>not ok|ok) [0-9]+ - (?<name>.*?)(?:\\s+#\\s*(?<skip>SKIP|TODO)\\b.*)?$";"i")]}|{valid,passed:[.events[]|select(.status=="ok" and .skip==null)|.name]|unique,failed:[.events[]|select(.status=="not ok" and .skip==null)|.name]|unique,skipped:[.events[]|select(.skip!=null)|.name]|unique}' <"$tmp/output" >"$tmp/evidence" || { rm -rf "$tmp"; return 1; }
      : >"$tmp/omit"
      while IFS= read -r -d '' name; do case "$name" in /*) printf '%s\0' "$name" >>"$tmp/omit";; *) [ ! -f "$app/$name" ] || printf '%s\0' "$name" >>"$tmp/omit";; esac; done < <(jq -j '(.passed+.failed+.skipped)[]+"\u0000"' "$tmp/evidence")
      jq --rawfile omit "$tmp/omit" '($omit|split("\u0000")[:-1]) as $o|.passed-=$o|.failed-=$o|.skipped-=$o' "$tmp/evidence" >"$tmp/filtered" && mv "$tmp/filtered" "$tmp/evidence" || { rm -rf "$tmp"; return 1; };;
    vitest)
      if [ -f "$tmp/vitest.json" ]; then jq '{valid:(.testResults|type=="array"),passed:[.testResults[]?.assertionResults[]?|select(.status=="passed")|.title]|unique,failed:[.testResults[]?.assertionResults[]?|select(.status=="failed")|.title]|unique,skipped:[.testResults[]?.assertionResults[]?|select(.status|IN("pending","skipped","todo","disabled"))|.title]|unique}' "$tmp/vitest.json" >"$tmp/evidence" || { rm -rf "$tmp"; return 1; }
      else printf '{"valid":false,"passed":[],"failed":[],"skipped":[]}' >"$tmp/evidence"; fi;;
  esac
  valid=$(jq -r .valid "$tmp/evidence")
  result=$(jq --arg runner "$runner" --rawfile output "$tmp/output" '{runner:$runner,passed,failed,skipped,output:$output}' "$tmp/evidence") || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  if [ "$valid" != true ]; then
    [ "$rc" -eq 0 ] || { printf '%s\n' "$result"; return 11; }
    sb_error 'Test runner did not produce verifiable results'; return 1
  fi
  printf '%s\n' "$result"
  [ "$(printf '%s' "$result"|jq '.failed|length')" -eq 0 ] || return 10
  [ "$rc" -eq 0 ] || return 11
  return 0
}
contract_gate() {
  local app=$1 baseline=$2 complete=${3:-true} run_tests=${4:-true} tmp head result rc
  contract_clean "$app" || return 1
  head=$(git -C "$app" rev-parse HEAD) || return 1
  baseline=$(contract_baseline "$app" "$baseline") || return 1
  tmp=$(mktemp -d) || return 1
  contract_validate "$app" "$baseline" "$complete" >"$tmp/entries" || { rm -rf "$tmp"; return 1; }
  contract_sources "$app" "$baseline" "$tmp/entries" || { rm -rf "$tmp"; return 1; }
  result=null
  if [ "$run_tests" = true ]; then
    if contract_hygiene "$app"; then rc=0; else rc=$?; fi
    [ "$rc" -eq 0 ] || { rm -rf "$tmp"; [ "$rc" -ne 130 ] || return 130; return 1; }
    contract_clean "$app" || { rm -rf "$tmp"; return 1; }
    if contract_suite "$app" >"$tmp/suite"; then rc=0; else rc=$?; fi
    [ "$rc" -eq 0 ] || { cat "$tmp/suite" >&2; rm -rf "$tmp"; [ "$rc" -ne 130 ] || return 130; return 1; }
    jq -ne --slurpfile entries "$tmp/entries" --slurpfile results "$tmp/suite" '
      def named($n): .==$n or startswith($n+":") or startswith($n+" ") or startswith($n+"/");
      all($entries[0][]|select(.checked); .name as $n|any($results[0].passed[];named($n)) and all($results[0].skipped[];named($n)|not))' >/dev/null || { sb_error 'Approved test was not executed successfully (missing or skipped)'; rm -rf "$tmp"; return 1; }
    result=$(cat "$tmp/suite")
  fi
  rm -rf "$tmp"
  [ "$head" = "$(git -C "$app" rev-parse HEAD)" ] || { sb_error 'HEAD changed during verification'; return 1; }
  contract_clean "$app" || return 1
  printf '%s\n' "$result"
}
