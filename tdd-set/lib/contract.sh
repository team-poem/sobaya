#!/bin/bash
# Real suite evidence and app commands; no frozen approval baseline.
CONTRACT_LIB=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$CONTRACT_LIB/common.sh"
contract_git_dir() { git -C "$1" rev-parse --absolute-git-dir; }
contract_index_safe() {
  local listing hidden
  # -v lowercases assume-unchanged entries; S marks skip-worktree. These
  # flags can make git status and git add hide a different working file.
  # jq 1.6 raw slurp trims terminal NULs; keep a disposable final record.
  listing=$(set -o pipefail; { git -C "$1" ls-files -v -z || exit; printf '.'; } | jq -Rs 'split("\u0000")[:-1]') || return 1
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
contract_protected() {
  case "/$1" in */test/*|*/tests/*|*/__tests__/*|*/fixtures/*|*/testdata/*|*_test.go|*_test.py|*/test_*.py|*.test.*|*.spec.*|*/conftest.py) return 0;; esac
  return 1
}
_contract_words() (
  set -o pipefail
  { awk -f "$CONTRACT_LIB/shell-words.awk" "$1" || exit; printf '.'; } | jq -Rs 'split("\u0000")[:-1]'
)
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
contract_snapshot() (
  set -o pipefail
  local app=$1 path mode value
  git -C "$app" ls-files -z --cached --others --exclude-standard |
  while IFS= read -r -d '' path; do
    if [ -L "$app/$path" ]; then value="symlink:$(readlink "$app/$path")"
    elif [ -f "$app/$path" ]; then
      if mode=$(stat -f '%Lp' "$app/$path" 2>/dev/null) && [[ "$mode" =~ ^[0-7]+$ ]]; then :
      else mode=$(stat -c '%a' "$app/$path"); fi
      if command -v sha256sum >/dev/null 2>&1; then value=$(sha256sum < "$app/$path")
      else value=$(shasum -a 256 < "$app/$path"); fi
      value="$mode:$value"
    elif [ -e "$app/$path" ]; then value=directory
    else value=missing; fi
    jq -nc --arg path "$path" --arg value "$value" '{key:$path,value:$value}'
  done | jq -sc 'from_entries'
)
contract_gate() {
  local app=$1 tmp rc before after head index
  app=$(cd "$app" && pwd -P) || return 1
  [ "$(git -C "$app" rev-parse --show-toplevel)" = "$app" ] || { sb_error 'App must be a Git repository root'; return 1; }
  contract_index_safe "$app" || return 1
  before=$(contract_snapshot "$app") || return 1
  head=$(git -C "$app" rev-parse HEAD) || return 1
  index=$(git -C "$app" write-tree) || return 1
  tmp=$(mktemp -d) || return 1
  if contract_hygiene "$app" && contract_suite "$app" >"$tmp/suite"; then rc=0; else rc=$?; fi
  cat "$tmp/suite" 2>/dev/null || :
  rm -rf "$tmp"
  after=$(contract_snapshot "$app") || return 1
  contract_index_safe "$app" || return 1
  if [ "$before" != "$after" ] || [ "$head" != "$(git -C "$app" rev-parse HEAD)" ] || [ "$index" != "$(git -C "$app" write-tree)" ]; then
    sb_error 'Checks changed source files or Git state; edits preserved, result is not GREEN.'
    return 1
  fi
  return "$rc"
}
# unclebob's crapper, dryer and mutator run as subprocesses; this code stays Bash.
_contract_tool() {
  local dir=$1 tmp=$2 app=$3 name=$4; shift 4
  sb_run 3600 "$tmp/$name.out" "$tmp/$name.err" /dev/null "$app" -- "$dir/$name/$name" "$@"
}
# crap.edn has no file or lines; mutator's forms do, keyed by the same namespace and name.
_contract_forms() {
  find "$1/.metrics/mutate" -type f -name '*.edn' -exec awk '
    FNR==1{ns=""} !ns && match($0,/:namespace "[^"]*"/){ns=substr($0,RSTART+12,RLENGTH-13)}
    {s=$0; while(match(s,/\{:id "[^"]*" [^{}]*\}/)){f=substr(s,RSTART,RLENGTH); s=substr(s,RSTART+RLENGTH)
      match(f,/:id "[^"]*"/); id=substr(f,RSTART+5,RLENGTH-6); sub(/^[^\/]*\//,"",id)
      match(f,/:file "[^"]*"/); file=substr(f,RSTART+7,RLENGTH-8)
      match(f,/ :line [0-9]+/); a=substr(f,RSTART+7,RLENGTH-7); match(f,/:end-line [0-9]+/); b=substr(f,RSTART+10,RLENGTH-10)
      print ns "\t" id "\t" file "\t" a "\t" b}}' {} + 2>/dev/null
}
# Unescaped :outcomes keys whose value is :survived, one per line.
_contract_survivors() {
  awk '{s=$0; while(match(s,/"([^"\\]|\\.)*" :survived/)){k=substr(s,RSTART+1,RLENGTH-12); s=substr(s,RSTART+RLENGTH)
    gsub(/\\"/,"\"",k); gsub(/\\\\/,"\\",k); print k}}' "$@" | sort -u
}
# Whether lines START..END of FILE differ from HEAD, the baseline contract_gate uses.
_contract_lines_changed() {
  git -C "$1" ls-files --error-unmatch -- "$2" >/dev/null 2>&1 || return 0
  git -C "$1" diff -U0 HEAD -- "$2" | awk -v a="$3" -v b="$4" '/^@@/{split($3,h,","); s=substr(h[1],2)+0; n=(h[2]=="")?1:h[2]+0; e=s+(n?n:1)-1; if(s<=b+0 && e>=a+0) f=1} END{exit !f}'
}
contract_quality() {
  local app dir tool missing='' tmp before after rc failed=0 sites
  app=$(cd "$1" && pwd -P) || return 1
  dir=${SOBAYA_UNCLEBOB_DIR:-$CONTRACT_LIB/../../references/unclebob}
  grep -qx -- '- Quality: required' "$app/AGENTS.md" 2>/dev/null || { sb_error "Quality checks are not enabled for this app (add '- Quality: required' to its AGENTS.md)"; return 0; }
  for tool in mutator crapper dryer; do [ -x "$dir/$tool/$tool" ] || missing="$missing $tool"; done
  [ -z "$missing" ] || { sb_error "Quality checks required by AGENTS.md but not found in $dir:$missing (set SOBAYA_UNCLEBOB_DIR)"; return 1; }
  tmp=$(mktemp -d) || return 1
  rm -f "$app/.metrics/crap.edn" "$app/.metrics/dry.edn"
  before=$(contract_snapshot "$app") || { rm -rf "$tmp"; return 1; }
  : >"$tmp/marker"
  if _contract_tool "$dir" "$tmp" "$app" mutator --changed; then rc=0; else rc=$?; fi
  [ "$rc" -ne 130 ] || { rm -rf "$tmp"; return 130; }
  case "$rc" in
    0|3) ;;
    *) cat "$tmp/mutator.out" "$tmp/mutator.err" >&2; sb_error "mutator failed (exit $rc)"; failed=1;;
  esac
  find "$app/.metrics/mutate" -type f -name '*.edn' -newer "$tmp/marker" -exec cat {} + >"$tmp/mutate.edn" 2>/dev/null || :
  # Survivors come from the outcome keys, not the exit code, so listed equivalent mutants can pass.
  { git -C "$app" diff --name-only HEAD; git -C "$app" ls-files --others --exclude-standard; } >"$tmp/changed"
  _contract_survivors "$tmp/mutate.edn" | awk 'NR==FNR{c[$0]=1; next} match($0,/^\["[^"]*"/) && c[substr($0,3,RLENGTH-3)]' "$tmp/changed" - >"$tmp/survived"
  sed -e 's/[[:space:]]*$//' -e '/^#/d' -e '/^$/d' "$app/.sobaya-equivalent-mutants" 2>/dev/null | sort -u >"$tmp/equivalent"
  comm -23 "$tmp/survived" "$tmp/equivalent" >"$tmp/unlisted"
  if [ -s "$tmp/unlisted" ] || { [ "$rc" -eq 3 ] && [ ! -s "$tmp/survived" ]; }; then
    cat "$tmp/mutator.out" "$tmp/mutator.err" >&2
    sb_error 'mutator: surviving mutants; add a scenario, delete dead code, or list an equivalent mutant in .sobaya-equivalent-mutants with a # reason:'
    sed 's/^/  /' "$tmp/unlisted" >&2; failed=1
  fi
  find "$app/.metrics/mutate" -type f -name '*.edn' -exec cat {} + 2>/dev/null | _contract_survivors | comm -23 "$tmp/equivalent" - >"$tmp/stale"
  [ ! -s "$tmp/stale" ] || { sb_error 'mutator: stale entries in .sobaya-equivalent-mutants, no longer surviving; delete them:'; sed 's/^/  /' "$tmp/stale" >&2; }
  if sites=$(awk '{s=$0; while(match(s,/:sites [0-9]+/)){n+=substr(s,RSTART+7,RLENGTH-7); s=substr(s,RSTART+RLENGTH)}
      s=$0; while(match(s,/:uncovered [0-9]+/)){u+=substr(s,RSTART+11,RLENGTH-11); s=substr(s,RSTART+RLENGTH)}}
      END{print n+0; exit !(n>0 && u==n)}' "$tmp/mutate.edn"); then
    sb_error "mutator: all $sites mutation sites are uncovered, so coverage measured nothing (for Go, the checkout directory name must match the module path)"; failed=1
  fi
  if _contract_tool "$dir" "$tmp" "$app" crapper --changed; then rc=0; else rc=$?; fi
  [ "$rc" -ne 130 ] || { rm -rf "$tmp"; return 130; }
  [ "$rc" -eq 0 ] || { cat "$tmp/crapper.out" "$tmp/crapper.err" >&2; sb_error "crapper failed (exit $rc)"; failed=1; }
  _contract_forms "$app" >"$tmp/forms"
  awk 'match($0,/:crap [0-9.]+/){c=substr($0,RSTART+6,RLENGTH-6); if(c+0>=10){match($0,/:namespace "[^"]*"/); ns=substr($0,RSTART+12,RLENGTH-13); match($0,/:name "[^"]*"/); print ns "\t" substr($0,RSTART+7,RLENGTH-8) "\t" c}}' \
    "$app/.metrics/crap.edn" 2>/dev/null |
  while IFS=$'\t' read -r ns name crap; do
    # A function mutator does not locate stays in: crapper --changed already limited it to changed files.
    located=0 changed=0
    while IFS=$'\t' read -r _ _ file start end; do
      located=1; ! _contract_lines_changed "$app" "$file" "$start" "$end" || changed=1
    done < <(awk -F '\t' -v ns="$ns" -v name="$name" '$1==ns && $2==name' "$tmp/forms")
    [ "$located" -eq 1 ] && [ "$changed" -eq 0 ] || printf '  %s %s CRAP %s\n' "$ns" "$name" "$crap"
  done >"$tmp/crap.high"
  [ ! -s "$tmp/crap.high" ] || { sb_error 'crapper: changed functions at CRAP 10 or more; split them, test them further, or both:'; cat "$tmp/crap.high" >&2; failed=1; }
  if _contract_tool "$dir" "$tmp" "$app" dryer --threshold 0.8; then rc=0; else rc=$?; fi
  [ "$rc" -ne 130 ] || { rm -rf "$tmp"; return 130; }
  [ "$rc" -eq 0 ] || { cat "$tmp/dryer.out" "$tmp/dryer.err" >&2; sb_error "dryer failed (exit $rc)"; failed=1; }
  if awk 'match($0,/:score [0-9.]+/){if(substr($0,RSTART+7,RLENGTH-7)+0>=0.8)f=1}END{exit !f}' "$app/.metrics/dry.edn" 2>/dev/null; then
    cat "$tmp/dryer.out" >&2; sb_error 'dryer: duplicate pairs at similarity 0.8 or more; remove the duplication'; failed=1
  fi
  after=$(contract_snapshot "$app") || { rm -rf "$tmp"; return 1; }
  if [ "$before" != "$after" ]; then
    sb_error "Quality tools changed files Git does not ignore; ignore their outputs (.metrics/, coverage reports): $(jq -rn --argjson a "$before" --argjson b "$after" '[($a+$b)|keys[]|select($a[.]!=$b[.])]|join(", ")')"
    failed=1
  fi
  rm -rf "$tmp"
  [ "$failed" -eq 0 ] || return 1
  echo 'Quality: no surviving mutant, no CRAP 10 or more, no duplicate pair at 0.8 or more.'
}
