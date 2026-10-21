#!/usr/bin/env bash
# Sobaya coordinator. Bash 3.2 + jq + Git; workers never own acceptance.
set -euo pipefail
r_root=$(cd "$(dirname "$0")/../.." && pwd -P)
. "$r_root/tdd-set/lib/contract.sh"
r_state='' r_meta='' r_lock='' r_expected='' r_row='' r_started=0 r_progress=false
r_tmp=$(mktemp -d "${TMPDIR:-/tmp}/sobaya-runner.XXXXXX")
r_die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
r_atomic() {
    local dest=$1 temp
    mkdir -p "$(dirname "$dest")"
    temp=$(mktemp "$(dirname "$dest")/.pending.XXXXXX")
    if ! jq . > "$temp"; then rm -f "$temp"; r_die "Invalid JSON for $dest"; fi
    mv -f "$temp" "$dest"
}
r_save() { printf '%s\n' "$r_state" | r_atomic "$r_meta/state.json"; }
r_log_finish() {
    [ -n "$r_row" ] || return 0
    local seconds
    seconds=$(( $(date +%s) - r_started ))
    printf '%s\n' "$r_row" | jq -c --argjson elapsed "$seconds" '. + {duration_seconds:$elapsed}' >> "$r_meta/usage.jsonl"
    r_row=''
}
r_cleanup() {
    local status=$?
    trap - EXIT INT TERM
    if [ -n "$r_expected" ] && [ -f "$r_expected" ]; then
        if ! cmp -s "$r_expected" "$r_meta/state.json"; then cat "$r_expected" | r_atomic "$r_meta/state.json"; fi
    fi
    r_log_finish || :
    if [ "$r_lock" = shlock ] && [ "$(cat "$r_meta/lock.shell" 2>/dev/null || :)" = "$$" ]; then rm -f "$r_meta/lock.shell"; fi
    rm -rf "$r_tmp"
    exit "$status"
}
trap r_cleanup EXIT
trap 'printf "Stopped; edits and execution evidence preserved.\n" >&2; exit 130' INT TERM
r_git() { git -C "$r_app" "$@"; }
r_clean() {
    [ "$(r_git rev-parse --show-toplevel)" = "$r_app" ] || r_die 'app must be the Git repository root'
    contract_index_safe "$r_app"
    [ -z "$(r_git status --porcelain=v1 --untracked-files=all)" ] || r_die 'A clean working tree and index are required (including untracked files).'
}
r_load() {
    if [ ! -f "$r_meta/state.json" ]; then
        r_state=$(jq -nc --arg head "$(r_git rev-parse HEAD)" --argjson now "$(date +%s)" '{version:2,baseline:$head,started_at:$now,calls:0,active:null,receipts:[],status:"ready"}')
        return
    fi
    r_state=$(jq -e 'select(type=="object" and (.version==1 or .version==2) and (.calls|type)=="number" and .calls>=0)' "$r_meta/state.json") || r_die 'Invalid execution state; inspect before continuing.'
    [ "$(jq -r .version <<< "$r_state")" = 2 ] || r_die 'Legacy approval state: run migrate.sh APP to preserve history and convert future tests to scenarios.'
}

r_policy_load() {
    r_policy=$(jq -e '
      def positive: type=="number" and floor==. and .>0;
      def string: type=="string" and test("\\S") and ((explode|index(0))==null);
      select(type=="object" and .version==1 and (.mode=="selected" or .mode=="quality" or .mode=="economy"))
      | select((.max_calls|positive) and (.timeout_seconds|positive))
      | select((.workers|type)=="object" and (.workers|length)>0)
      | select(all(.workers[]; type=="object" and (.adapter=="codex" or .adapter=="command") and (.model|string)
         and ((.guidance//"concise")=="concise" or .guidance=="guided")
         and (if .adapter=="command" then (.command|type)=="array" and (.command|length)>0 and all(.command[];string) else true end)))
      | select((.escalation//[]|type)=="array" and all((.escalation//[])[];type=="string"))
      | . as $p | select(all(([.default_worker,(.review_worker//.default_worker)]+(.escalation//[]))[]; type=="string" and $p.workers[.]!=null))
    ' "$r_policy_path") || r_die 'Invalid policy: explicit allowed workers, argv commands, positive call budget and timeout are required.'
    r_timeout=$(jq -r .timeout_seconds <<< "$r_policy")
    r_worker=${r_worker:-$(jq -r .default_worker <<< "$r_policy")}
    jq -e --arg name "$r_worker" '.workers|has($name)' <<< "$r_policy" >/dev/null || r_die 'Selected worker is not allowed by this policy.'
}
r_acquire() {
    mkdir -p "$r_meta"
    if command -v shlock >/dev/null 2>&1; then
        shlock -p "$$" -f "$r_meta/lock.shell" || r_die 'Another Sobaya operation owns this worktree; no second writer is allowed.'
        r_lock=shlock
    elif command -v flock >/dev/null 2>&1; then
        exec 9>"$r_meta/lock.shell"
        flock -n 9 || r_die 'Another Sobaya operation owns this worktree; no second writer is allowed.'
        r_lock=flock
    else
        r_die 'Install shlock (macOS/BSD) or flock (Linux) for an atomic process lock.'
    fi
    if [ -n "${SOBAYA_WORKSPACE_ROOT:-}" ]; then
        [ -f "$SOBAYA_WORKSPACE_ROOT/sobaya.json" ] && [ ! -L "$SOBAYA_WORKSPACE_ROOT/sobaya.json" ] && [ -f "$SOBAYA_WORKSPACE_ROOT/sobaya.lock" ] && [ ! -L "$SOBAYA_WORKSPACE_ROOT/sobaya.lock" ] || r_die 'Protected workspace pin changed before acquiring the app lock.'
        [ "$(r_hash < "$SOBAYA_WORKSPACE_ROOT/sobaya.json")" = "$SOBAYA_SELECTED_CONFIG_SHA" ] && [ "$(r_hash < "$SOBAYA_WORKSPACE_ROOT/sobaya.lock")" = "$SOBAYA_SELECTED_LOCK_SHA" ] || r_die 'Protected workspace pin changed before acquiring the app lock; retry explicit runtime selection.'
    fi
    sb_assert_no_orphan "$r_meta/worker.json" || r_die 'Prior worker group is still alive or cannot be verified; inspect worker.json before continuing.'
}
r_hash() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi | awk '{print $1}'
}
r_snapshot() {
    local protected=${1:-false} name value mode targets
    targets=$(contract_plan "$r_app" | jq -c '[.[].target|select(.!=null)]') || return 1
    r_git ls-files -z --cached --others --exclude-standard > "$r_tmp/snapshot-paths" || return 1
    {
    while IFS= read -r -d '' name; do
        if [ "$protected" = true ]; then
            case "/$name" in
                /spec.md|/failed-test.md|/AGENTS.md|/package.json|*/tests/*|*/test/*|*/__tests__/*|*/fixtures/*|*/testdata/*|*_test.go|*_test.py|*/test_*.py|*.test.*|*.spec.*|*conftest.py) ;;
                *) jq -e --arg path "$name" 'index($path)!=null' <<< "$targets" >/dev/null || continue ;;
            esac
        fi
        if [ -L "$r_app/$name" ]; then value="symlink:$(readlink "$r_app/$name")"
        elif [ -f "$r_app/$name" ]; then
            if mode=$(stat -f '%Lp' "$r_app/$name" 2>/dev/null) && [[ "$mode" =~ ^[0-7]+$ ]]; then :
            else mode=$(stat -c '%a' "$r_app/$name"); fi
            value="$((8#$mode)):$(r_hash < "$r_app/$name")"
        elif [ -e "$r_app/$name" ]; then value=directory
        else value=missing; fi
        jq -nc --arg key "$name" --arg value "$value" '{key:$key,value:$value}'
    done < "$r_tmp/snapshot-paths"
    if [ -n "${SOBAYA_WORKSPACE_ROOT:-}" ]; then
        for name in "$SOBAYA_WORKSPACE_ROOT/sobaya.json" "$SOBAYA_WORKSPACE_ROOT/sobaya.lock"; do
            if [ -L "$name" ]; then value="symlink:$(readlink "$name")"
            elif [ -f "$name" ]; then
                if mode=$(stat -f '%Lp' "$name" 2>/dev/null) && [[ "$mode" =~ ^[0-7]+$ ]]; then :; else mode=$(stat -c '%a' "$name"); fi
                value="$((8#$mode)):$(r_hash < "$name")"
            elif [ -e "$name" ]; then value=directory
            else value=missing; fi
            jq -nc --arg key "$name" --arg value "$value" '{key:$key,value:$value}'
        done
    fi
    } | jq -sc 'from_entries'
}
r_same() { jq -e --argjson b "$2" '.==$b' <<< "$1" >/dev/null; }
r_verify_active() {
    contract_index_safe "$r_app"
    [ "$(r_git rev-parse HEAD)" = "$(jq -r .active.head <<< "$r_state")" ] || r_die 'Worker changed HEAD; preserve and inspect its commits.'
    r_same "$(r_snapshot true)" "$(jq -c .active.protected <<< "$r_state")" || r_die 'Protected test, fixture, plan, or instruction content changed; edits preserved.'
}
r_materialize() {
    local entry=$1 target lang packages segment cursor
    target=$(jq -r '.target//empty' <<< "$entry")
    lang=$(jq -r .language <<< "$entry")
    if [ -z "$target" ] && [ "$lang" = go ]; then
        target=$(sed -n 's/^- Test-File: *`\{0,1\}\([^`]*\)`\{0,1\}$/\1/p' "$r_app/AGENTS.md")
        target=${target:-sobaya_test.go}
        if jq -e '.header==""' <<< "$entry" >/dev/null; then
            packages=$(awk '/^package[[:space:]]/{print $2}' "$r_app"/*.go 2>/dev/null | sort -u)
            [[ "$packages" =~ ^[a-zA-Z_][a-zA-Z_0-9]*$ ]] || r_die 'Go plan needs an explicit // file: header with package/imports.'
            entry=$(jq --arg package "$packages" '.header="package "+$package+"\n\nimport \"testing\"\n"' <<< "$entry")
        fi
    fi
    [ -n "$target" ] || r_die 'Entry needs a // file: section header.'
    case "/$target/" in //*/|*/../*|*/.git/*|/spec.md/|/failed-test.md/|/AGENTS.md/) r_die 'Planned test target must stay inside the app.';; esac
    cursor=$r_app
    while IFS= read -r segment; do
        cursor="$cursor/$segment"
        [ ! -L "$cursor" ] || r_die 'Planned test target or parent is a symlink.'
    done < <(printf '%s' "$target" | tr '/' '\n'; printf '\n')
    mkdir -p "$(dirname "$r_app/$target")"
    if [ ! -e "$r_app/$target" ]; then jq -j .header <<< "$entry" > "$r_app/$target"; fi
    [ -f "$r_app/$target" ] || r_die 'Test target must be a regular file.'
    # Read the selected blocks directly with jq so shell substitution cannot trim them.
    if ! jq -e --rawfile existing "$r_app/$target" '.code as $code|$existing|contains($code)' <<< "$entry" >/dev/null; then
        if [ -s "$r_app/$target" ] && [ "$(tail -c 1 "$r_app/$target" | od -An -tu1 | tr -d ' ')" = 10 ]; then printf '\n' >> "$r_app/$target"; else printf '\n\n' >> "$r_app/$target"; fi
        jq -j .code <<< "$entry" >> "$r_app/$target"
    fi
    printf '%s\n' "$target"
}
r_named_filter='def named($n): .==$n or startswith($n+":") or startswith($n+" ") or startswith($n+"/");'
r_build_red() {
    local target=$1
    [ -n "$target" ] || return 1
    jq -e --arg target "$target" --rawfile source "$r_app/$target" '
      select(.runner=="go") | [.output|split("\n")[] | . as $line | (try fromjson catch null) as $event |
      if ($event|type)=="object" then ($event.Output//empty|split("\n")[]) elif $event==null then $line else empty end] as $lines |
      [$lines[]|select(test("\\.go:[0-9]+:[0-9]+:"))] as $diagnostics |
      ($diagnostics|length)>0 and all($diagnostics[];
        ((try capture("^(?<file>.+):[0-9]+:[0-9]+: undefined: (?<name>[A-Za-z_][A-Za-z_0-9]*)$") catch null)//null) as $match |
        if $match==null then false else ($match.file|ltrimstr("./"))==$target and ($source|test("\\b"+$match.name+"\\s*\\.")|not) end)
      and ($lines|join("\n")|test("no required module|cannot find package|syntax error|too many errors")|not)
    ' <<< "$r_suite" >/dev/null
}
r_checked_suite() {
    local name=$1 target=${2:-} before rc evidence selected_passed=false reason=suite-failed
    before=$(r_snapshot)
    if contract_suite "$r_app" "$r_timeout" > "$r_tmp/suite.json" 2> "$r_tmp/suite.stderr"; then rc=0; else rc=$?; fi
    cat "$r_tmp/suite.stderr" >&2
    if [ "$rc" -eq 0 ]; then
        reason=selected-test-not-passed
        if jq -e --arg name "$name" "$r_named_filter"'any(.passed[];named($name)) and (any(.skipped[];named($name))|not)' "$r_tmp/suite.json" >/dev/null; then selected_passed=true; fi
    fi
    if [ "$selected_passed" = false ] && [ "$(jq -r .active.phase <<< "$r_state")" = implement ]; then
        evidence="$r_meta/runs/$r_run_id/$(jq -r .calls <<< "$r_state")/suite-failure.json"
        jq -n --arg entry "$name" --arg head "$(r_git rev-parse HEAD)" --arg run "$r_run_id" --arg reason "$reason" \
          --argjson call "$(jq -r .calls <<< "$r_state")" --argjson code "$rc" --slurpfile suite "$r_tmp/suite.json" --rawfile stderr "$r_tmp/suite.stderr" \
          '{version:1,stage:"implementation-verification",entry:$entry,head:$head,run_id:$run,call:$call,exit_code:$code,reason:$reason,suite:$suite[0],stderr:$stderr}' | r_atomic "$evidence"
        printf 'Failed suite evidence: %s\n' "$evidence" >&2
    fi
    r_same "$before" "$(r_snapshot)" || r_die 'Test execution changed source files; inspect before continuing.'
    r_suite=$(cat "$r_tmp/suite.json")
    case "$rc" in
        0) [ "$selected_passed" = true ] || r_die "Selected test $name did not execute and pass."
           r_verdict=green ;;
        10) jq -e --arg name "$name" "$r_named_filter"'(.failed|length)>0 and all(.failed[];named($name))' <<< "$r_suite" >/dev/null || r_die 'Tests failed outside the selected entry; investigate baseline/environment.'
           r_verdict=red ;;
        11) r_build_red "$target" || { jq -r '.output//empty' <<< "$r_suite" >&2; r_die 'Test runner failed without an executed failing test (build/infrastructure error).'; }
           r_verdict=build-red ;;
        130) exit 130 ;;
        *) r_die 'Test runner could not establish execution evidence.' ;;
    esac
}
r_prompt() {
    local name=$1 role=$2 entry=$3
    if [ -n "${SOBAYA_WORKSPACE_ROOT:-}" ]; then
        printf 'Installed connection (%s): read %s/tdd-set/AGENTS.md, %s/AGENTS.md and %s/AGENTS.md. The workspace selects the pinned runtime; preserve its sobaya.json and sobaya.lock.\n' "$SOBAYA_CONNECTION_MODE" "$r_root" "$SOBAYA_WORKSPACE_ROOT" "$r_app"
    fi
    if [ "$role" = review ]; then
        printf 'Read %s/AGENTS.md and the app AGENTS.md. Review %s from %s to HEAD. Read only; do not edit or commit. Examine correctness, scope and useful test coverage. Pending scenarios are future choices, not automatically missing requirements. Return JSON {status: done|handoff|defect, summary: string, reason: string} with concrete findings. This is an optional review, not a prerequisite for the next test.\n' "$r_root" "$r_app" "$r_app" "$(jq -r .baseline <<< "$r_state")"
    else
        printf 'Read %s/AGENTS.md and %s/AGENTS.md. Work only in %s. Make the failing test %s pass with the smallest coherent implementation. The runner has inserted this one test and measured RED. During this RED-to-GREEN attempt keep spec.md, failed-test.md, AGENTS.md, tests/helpers/fixtures and Git metadata unchanged; do not weaken assertions to obtain GREEN. Do not commit or choose another scenario. At GREEN the orchestrator may refactor source and tests while preserving behavior. If the test has an error, report the concrete reason for diagnosis; no separate human approval is required for ordinary corrections within existing intent. Human decisions are needed for changed product intent or ambiguous expectations. Return JSON {status: done|handoff|defect, summary: string, reason: string}.\n\nCurrent test:\n' "$r_root" "$r_app" "$r_app" "$(jq -r .name <<< "$entry")"
        jq -j .code <<< "$entry"
        if [ "$(jq -r --arg name "$name" '.workers[$name].guidance//"concise"' <<< "$r_policy")" = guided ]; then
            printf '\nSteps: inspect the failing behavior and source; make this case pass; run relevant tests; inspect the diff; report evidence. Stop before another scenario.\n'
        fi
        if [ -f "$r_meta/handoff.json" ]; then printf '\nPrevious diagnostic evidence:\n'; cat "$r_meta/handoff.json"; fi
    fi
}

r_invoke() {
    local name=$1 role=$2 entry=${3:-null} calls budget model adapter folder last rc arg status
    local argv=()
    calls=$(jq -r .calls <<< "$r_state"); budget=$(jq -r .max_calls <<< "$r_policy")
    [ "$calls" -lt "$budget" ] || r_die 'Worker call budget exhausted for this execution session; select an explicitly revised policy to extend it.'
    calls=$((calls+1)); folder="$r_meta/runs/$r_run_id/$calls"; mkdir -p "$folder"
    model=$(jq -r --arg name "$name" '.workers[$name].model' <<< "$r_policy")
    adapter=$(jq -r --arg name "$name" '.workers[$name].adapter' <<< "$r_policy")
    last="$folder/result.json"
    r_prompt "$name" "$role" "$entry" > "$folder/prompt.txt"
    if [ "$adapter" = codex ]; then
        local sandbox=workspace-write; [ "$role" != review ] || sandbox=read-only
        argv=(codex exec --cd "$r_app" --model "$model" --sandbox "$sandbox" -c 'approval_policy="never"' --json --output-schema "$r_root/tdd-set/worker-result.schema.json" --output-last-message "$last" -)
    else
        while IFS= read -r -d '' arg; do argv+=("$arg"); done < <(jq -j --arg name "$name" '.workers[$name].command[]|.,"\u0000"' <<< "$r_policy")
    fi
    r_state=$(jq '.calls+=1' <<< "$r_state"); r_save
    r_expected="$r_tmp/expected-state.json"; cp "$r_meta/state.json" "$r_expected"
    r_started=$(date +%s)
    r_row=$(jq -nc --arg run "$r_run_id" --arg baseline "$(jq -r .baseline <<< "$r_state")" --arg worker "$name" --arg model "$model" --arg role "$role" --argjson entry "$entry" '{run_id:$run,baseline:$baseline,worker:$worker,model:$model,role:$role,entry:$entry.name}')
    printf 'Worker %s (%s), %s, call %s/%s\n' "$name" "$model" "$role" "$calls" "$budget"
    if SOBAYA_RUN_ID="$r_run_id" SOBAYA_WORKER="$name" SOBAYA_WORKER_RECORD="$r_meta/worker.json" sb_run "$r_timeout" "$folder/stdout.log" "$folder/stderr.log" "$folder/prompt.txt" "$r_app" -- env \
        SOBAYA_APP="$r_app" SOBAYA_BASELINE="$(jq -r .baseline <<< "$r_state")" SOBAYA_RUN_ID="$r_run_id" \
        SOBAYA_WORKER="$name" SOBAYA_MODEL="$model" SOBAYA_ENTRY="$(jq -r '.name//empty' <<< "$entry")" SOBAYA_ROLE="$role" \
        "${argv[@]}"; then rc=0; else rc=$?; fi
    if ! cmp -s "$r_expected" "$r_meta/state.json"; then r_save; r_log_finish; r_expected=''; r_die 'Worker changed execution state; original state restored, source edits preserved.'; fi
    r_expected=''
    [ "$rc" -ne 130 ] || { r_log_finish; exit 130; }
    [ "$rc" -ne 124 ] || { r_log_finish; r_die "Worker timed out; inspect $folder."; }
    [ "$rc" -eq 0 ] || { r_log_finish; r_die "Worker exited $rc; inspect $folder/stderr.log. No blind retry."; }
    if [ "$adapter" = codex ]; then
        r_result=$(jq -e . "$last") || r_die "Worker returned invalid JSON; inspect $folder."
        jq -Rc 'fromjson?|select(type=="object")' "$folder/stdout.log" | jq -s . > "$r_tmp/events.json"
        if jq -e 'any(.[];.type=="turn.failed" or .type=="error")' "$r_tmp/events.json" >/dev/null; then r_die "Codex reported an error; inspect $folder."; fi
        r_row=$(jq --slurpfile events "$r_tmp/events.json" '.usage=([$events[0][]|select(.type=="turn.completed")|.usage][-1]//{})' <<< "$r_row")
    else
        awk 'NF{last=$0} END{print last}' "$folder/stdout.log" > "$r_tmp/response.json"
        r_result=$(jq -e . "$r_tmp/response.json") || r_die "Worker returned invalid JSON; inspect $folder."
        r_row=$(jq --argjson result "$r_result" '.usage=(if ($result|type)=="object" then $result.usage//{} else {} end)' <<< "$r_row")
    fi
    jq -e 'type=="object" and (.status=="done" or .status=="handoff" or .status=="defect") and (.summary|type)=="string" and (.reason|type)=="string" and (.status=="done" or (.reason|test("\\S")))' <<< "$r_result" >/dev/null || r_die 'Worker result must contain status, summary, and diagnostic reason.'
    printf '%s\n' "$r_result" | r_atomic "$last"
    r_row=$(jq --arg status "$(jq -r .status <<< "$r_result")" '.status=$status' <<< "$r_row")
    r_log_finish
}
r_handoff() {
    local name=$1
    jq -n --argjson state "$r_state" --argjson result "$r_result" --arg worker "$name" --arg head "$(r_git rev-parse HEAD)" --arg diff "$(r_git diff HEAD --stat)" '{baseline:$state.baseline,head:$head,entry:$state.active.entry,worker:$worker,status:$result.status,summary:$result.summary,reason:$result.reason,diff:$diff}' | r_atomic "$r_meta/handoff.json"
    r_state=$(jq --argjson result "$r_result" '.status="handoff"' <<< "$r_state"); r_save
}
r_commit_active() {
    local head old tree name
    contract_index_safe "$r_app"
    r_same "$(r_snapshot)" "$(jq -c .active.verified_content <<< "$r_state")" || r_die 'Verified content changed after GREEN; inspect before resuming.'
    head=$(r_git rev-parse HEAD); old=$(jq -r .active.head <<< "$r_state"); name=$(jq -r .active.entry <<< "$r_state")
    if [ "$head" = "$old" ]; then
        r_git add --all
        tree=$(r_git write-tree)
        r_state=$(jq --arg tree "$tree" '.active.tree=$tree' <<< "$r_state"); r_save
        r_git commit -m "feat: satisfy $name"
        head=$(r_git rev-parse HEAD)
    fi
    [ "$(r_git rev-list --parents -n 1 "$head")" = "$head $old" ] && [ "$(r_git rev-parse 'HEAD^{tree}')" = "$(jq -r .active.tree <<< "$r_state")" ] || r_die 'Committed tree or parent differs from the verified checkpoint; inspect without resetting baseline.'
    if [ -n "${SOBAYA_WORKSPACE_ROOT:-}" ]; then
        r_same "$(r_snapshot)" "$(jq -c .active.verified_content <<< "$r_state")" || r_die 'Protected checkpoint content changed during commit hooks; inspect preserved edits.'
    fi
    r_clean
    r_state=$(jq --arg head "$head" '.receipts += [(.active.receipt+{head:$head,before:.active.head})] | .active=null | .review=null | .status="checkpoint"' <<< "$r_state"); r_save
    r_progress=true
    printf 'Checkpoint %s: %s\n' "$name" "$head"
}
r_finish() {
    local entry=$1 name before
    name=$(jq -r .name <<< "$entry")
    r_verify_active
    before=$(r_snapshot)
    contract_hygiene "$r_app" "$r_timeout"
    r_same "$before" "$(r_snapshot)" || r_die 'Hygiene checks changed source files; inspect and resume after formatting implementation.'
    r_checked_suite "$name"
    [ "$r_verdict" = green ] || r_die "Entry $name is still RED; inspect and resume explicitly."
    printf 'GREEN %s\n' "$name"
    # Preserve every byte except the selected checkbox outside fenced blocks.
    jq -nj --rawfile plan "$r_app/failed-test.md" --arg name "$name" '
      reduce ($plan|split("\n")[]) as $line ({f:false,n:0,lines:[]};
        if ($line|startswith("```")) then .f=(.f|not) else . end |
        if (.f|not) and .n==0 and ($line|test("^- \\[ \\] "+$name+"(\\s|$)"))
        then .n+=1 | .lines+=[$line|sub("^- \\[ \\]";"- [x]")] else .lines+=[$line] end)
      | if .n==1 then .lines|join("\n") else error("selected checkbox missing") end
    ' > "$r_tmp/checked-plan"
    cp "$r_tmp/checked-plan" "$r_app/failed-test.md"
    r_state=$(jq --argjson protected "$(r_snapshot true)" --argjson verified "$(r_snapshot)" --argjson suite "$r_suite" --argjson result "$r_result" '.active.protected=$protected | .active.verified_content=$verified | .active.phase="committing" | .active.receipt={entry:.active.entry,red:.active.red,green:$suite.passed,summary:$result.summary}' <<< "$r_state")
    r_save; r_commit_active
}
# A candidate plan can be uncommitted; unrelated user edits must not be swept into a commit.
r_ready() {
    contract_index_safe "$r_app"
    local paths
    paths=$(r_git status --porcelain=v1 --untracked-files=all)
    [ -z "$paths" ] || [ "$(printf '%s\n' "$paths" | cut -c4- | sort -u)" = failed-test.md ] || r_die 'Commit or isolate existing source edits before step; only the scenario plan may be uncommitted.'
}
r_step() {
    local entry name entries target before choices choice
    if jq -e '.active!=null' <<< "$r_state" >/dev/null; then
        [ "$r_resume" = true ] || r_die 'An unfinished attempt is preserved. Diagnose it, then use --resume; use restart.sh after correcting a test.'
        if [ "$(jq -r .active.phase <<< "$r_state")" = committing ]; then r_commit_active; return; fi
        r_verify_active
        name=$(jq -r .active.entry <<< "$r_state")
        entry=$(contract_plan "$r_app" | jq -ce --arg name "$name" '.[]|select(.name==$name and (.checked|not))') || r_die 'Active scenario changed; diagnose and restart the attempt.'
    else
        r_ready
        entries=$(contract_plan "$r_app")
        jq -e '[.[]|select((.checked|not) and .code!="")]|length<=1' <<< "$entries" >/dev/null || r_die 'Future tests are prewritten. Run migrate.sh APP to retain scenarios and draft only the next test.'
        entry=$(jq -ce '[.[]|select(.checked|not)][0]//empty' <<< "$entries") || { printf 'No pending scenarios. Assess the feature outcome and learning before choosing more work.\n'; return; }
        name=$(jq -r .name <<< "$entry")
        [ -n "$(jq -r .code <<< "$entry")" ] || r_die "Next scenario $name needs one concrete test. Write/probe it, then step; no test approval is required."
        if [ "$(jq -r .language <<< "$entry")" = go ]; then
            before=$(r_snapshot); contract_suite "$r_app" "$r_timeout" > "$r_tmp/baseline-suite.json" || { cat "$r_tmp/baseline-suite.json" >&2; r_die 'Establish GREEN before adding the Go test.'; }
            r_same "$before" "$(r_snapshot)" || r_die 'Baseline tests modified source files.'
        fi
        r_state=$(jq --arg name "$name" --arg head "$(r_git rev-parse HEAD)" --argjson protected "$(r_snapshot true)" '.active={entry:$name,head:$head,phase:"preparing",protected:$protected,red:null} | .status="working"' <<< "$r_state"); r_save
    fi
    if [ "$(jq -r .active.phase <<< "$r_state")" = preparing ]; then
        target=$(r_materialize "$entry")
        r_state=$(jq --argjson protected "$(r_snapshot true)" '.active.protected=$protected' <<< "$r_state"); r_save
        r_checked_suite "$name" "$target"
        r_state=$(jq --arg verdict "$r_verdict" --argjson suite "$r_suite" '.active.red={status:$verdict,failed:$suite.failed,output:$suite.output} | .active.phase="implement"' <<< "$r_state"); r_save
        case "$r_verdict" in green) printf 'ALREADY GREEN %s\n' "$name"; r_result='{"summary":"Already green; no implementation change required."}'; r_finish "$entry"; return;; red) printf 'RED %s\n' "$name";; *) printf 'BUILD-RED %s\n' "$name";; esac
    fi
    choices=$(jq -nc --arg worker "$r_worker" --argjson policy "$r_policy" '[$worker]+(if $policy.mode=="selected" then [] else [($policy.escalation//[])[]|select(.!=$worker)] end)')
    while IFS= read -r choice; do
        r_invoke "$choice" implement "$entry"
        r_verify_active
        if [ "$(jq -r .status <<< "$r_result")" = done ]; then r_finish "$entry"; return; fi
        r_handoff "$choice"
        [ "$(jq -r .status <<< "$r_result")" != defect ] || r_die 'Test/requirement issue preserved for diagnosis. Correct within existing intent and restart; ask the human only if intent is unclear or changing.'
    done < <(jq -r '.[]' <<< "$choices")
    r_die "Diagnostic handoff saved at $r_meta/handoff.json; resume explicitly with an allowed worker."
}
r_review() {
    local worker=$1 head before
    r_clean
    jq -e '.active==null' <<< "$r_state" >/dev/null || r_die 'Finish or diagnose the active attempt before review.'
    before=$(r_snapshot)
    contract_gate "$r_app" > "$r_tmp/gate.json"
    r_same "$before" "$(r_snapshot)" || r_die 'Protected workspace pin or source changed during gate.'
    head=$(r_git rev-parse HEAD); before=$(r_snapshot)
    r_invoke "$worker" review
    r_same "$before" "$(r_snapshot)" && [ "$(r_git rev-parse HEAD)" = "$head" ] || r_die 'Review changed the repository; edits preserved.'
    r_clean
    [ "$(jq -r .status <<< "$r_result")" = done ] || { r_handoff "$worker"; r_die 'Review findings preserved in handoff.json.'; }
    r_state=$(jq --arg head "$head" --argjson result "$r_result" '.review={head:$head,summary:$result.summary}' <<< "$r_state"); r_save
    printf 'PASS — optional review finished.\n'
}
r_archive() {
    local folder="$r_meta/history/$r_run_id"
    mkdir -p "$folder"
    [ ! -f "$r_meta/state.json" ] || cp "$r_meta/state.json" "$folder/state.json"
    cp "$r_app/failed-test.md" "$folder/failed-test.md"
    printf '%s\n' "$folder"
}
r_restart() {
    # Restart abandons execution evidence, not files. The next invocation measures RED anew.
    jq -e '.active!=null' <<< "$r_state" >/dev/null || r_die 'No active attempt to restart.'
    local archived
    archived=$(r_archive)
    r_state=$(jq --arg archived "$archived" '.attempt_history=(.attempt_history//[])+[{archive:$archived,active:.active}] | .active=null | .status="ready"' <<< "$r_state"); r_save
    printf 'Attempt archived at %s; edits preserved. Correct the test and restore GREEN before preparing the next attempt.\n' "$archived"
}
r_migrate() {
    local archived before tree head verified
    r_clean
    if [ -f "$r_meta/state.json" ]; then
        r_state=$(jq -e 'select(.version==1 or .version==2)' "$r_meta/state.json") || r_die 'Invalid state; inspect before migration.'
        jq -e '.active==null' <<< "$r_state" >/dev/null || r_die 'An active legacy attempt remains. Diagnose it and use restart.sh APP to archive its evidence without discarding edits, then restore a GREEN revision before migration.'
    else
        r_load
    fi
    contract_plan "$r_app" > "$r_tmp/scenarios.json"
    archived=$(r_archive)
    before=$(r_git rev-parse HEAD)
    # Code remains in the archive and actual test files. Future expectations stay prose.
    awk '/^```/{f=!f;next} !f{print} END{if(f)exit 1}' "$r_app/failed-test.md" > "$r_tmp/scenarios.md"
    cp "$r_tmp/scenarios.md" "$r_app/failed-test.md"
    r_git add -- failed-test.md
    verified=$(r_snapshot)
    tree=$(r_git write-tree)
    if ! r_git diff --cached --quiet; then
        r_git commit -m 'chore: keep future tests as scenarios'
        head=$(r_git rev-parse HEAD)
        [ "$(r_git rev-list --parents -n 1 "$head")" = "$head $before" ] && [ "$(r_git rev-parse 'HEAD^{tree}')" = "$tree" ] || r_die "Migration commit changed the intended plan-only tree or parent. Edits preserved; originals are in $archived."
    fi
    r_same "$verified" "$(r_snapshot)" || r_die "Protected workspace pin or source changed during migration hooks. Edits preserved; originals are in $archived."
    r_clean
    r_state=$(jq --arg archive "$archived" '.version=2 | .legacy_history=(.legacy_history//[])+[$archive] | .active=null | .status="ready" | del(.acceptance_head,.acceptance_history,.approved_at,.allow_go_undefined_red,.checkpoint_reviews,.review)' <<< "$r_state"); r_save
    printf 'Converted the plan to mutable scenarios; original plan and state preserved at %s. No source or existing test file changed.\n' "$archived"
}
r_usage() {
    local id=${1:-} rows='[]'
    [ ! -f "$r_meta/usage.jsonl" ] || rows=$(jq -s . "$r_meta/usage.jsonl")
    jq --arg id "$id" '(( $id|select(.!=""))//.[-1].run_id) as $chosen | [.[]|select(.run_id==$chosen)] | {run_id:$chosen,calls:length,duration_seconds:([.[].duration_seconds]|add//0),usage:[.[]|.usage//{}]}' <<< "$rows"
}
# Parse argv without shell evaluation. Commands never infer a paid model upgrade.
[ "$#" -ge 2 ] || r_die 'usage: runner.sh COMMAND APP [--policy PATH] [--worker NAME] [--resume]'
r_command=$1; r_app=$(cd "$2" && pwd -P); shift 2
r_policy_path="$r_root/tdd-set/policies/default.json" r_worker='' r_explicit_worker=false r_resume=false r_limit=''
while [ "$#" -gt 0 ]; do
    case "$1" in
        --policy|--worker) [ "$#" -ge 2 ] || r_die "Missing value for $1"; if [ "$1" = --policy ]; then r_policy_path=$2; else r_worker=$2; r_explicit_worker=true; fi; shift 2;;
        --resume) r_resume=true; shift;;
        *) if [ "$r_command" = usage ] && [ -z "$r_limit" ]; then r_limit=$1; shift; continue; fi
           r_die "Unsupported argument $1. Approval/append/replacement/checkpoint-review gates have been retired.";;
    esac
done
if [ "$r_command" = approve ]; then r_die 'Test approval is retired. Select one scenario, write its test, and use step.sh APP.'; fi
if [ "$r_command" = next ]; then
    contract_plan "$r_app" | jq -er '[.[]|select(.checked|not)][0]//empty | (if .heading!="" then .heading+"\n" else "" end)+(if .header!="" and .code!="" then "```"+.language+"\n"+.header+"```\n" else "" end)+"- [ ] "+.name+" — "+.description+(if .code!="" then "\n```"+.language+"\n"+.code+"```" else "" end)' || exit 1
    exit 0
fi
[ "$(r_git rev-parse --show-toplevel)" = "$r_app" ] || r_die 'App must be its own Git repository root.'
r_meta="$(r_git rev-parse --absolute-git-dir)/sobaya"
r_run_id="$(date +%s)-$$-$RANDOM"
case "$r_command" in
    usage) r_usage "$r_limit"; exit;;
    status)
        if [ -f "$r_meta/state.json" ]; then r_state=$(cat "$r_meta/state.json"); else r_load; fi
        jq --arg head "$(r_git rev-parse HEAD)" --argjson entries "$(contract_plan "$r_app")" --arg dirty "$(r_git status --porcelain)" '.+{head:$head,pending:[$entries[]|select(.checked|not)|.name],dirty:($dirty!=""),legacy:(.version==1)}' <<< "$r_state"; exit;;
    doctor)
        r_policy_load
        if [ -n "${SOBAYA_WORKSPACE_ROOT:-}" ]; then
            if [ "$SOBAYA_CONNECTION_MODE" = project ]; then
                bash "$r_root/scripts/workspace-check.sh" "$SOBAYA_WORKSPACE_ROOT" --app "$r_app"
            fi
        else
            bash "$r_root/scripts/workspace-check.sh" "$r_root"
            bash "$r_root/scripts/setup.sh" "$r_root" --check --app "$r_app"
        fi
        while IFS= read -r arg; do (cd "$r_app" && command -v "$arg" >/dev/null) || r_die "Worker executable unavailable: $arg"; done < <(jq -r '.workers[]|if .adapter=="codex" then "codex" else .command[0] end' <<< "$r_policy")
        r_ready; printf 'Local setup checks passed. No paid worker call was made.\n'; exit;;
    step|loop|review|migrate|restart) ;;
    *) r_die "Unknown command $r_command";;
esac
r_acquire
if [ "$r_command" = migrate ]; then r_migrate; exit; fi
if [ "$r_command" = restart ]; then
    [ -f "$r_meta/state.json" ] || r_die 'No active attempt to restart.'
    r_state=$(jq -e 'select(.version==1 or .version==2)' "$r_meta/state.json") || r_die 'Invalid state.'
    r_restart; exit
fi
r_load
r_policy_load
if [ "$r_command" = review ]; then
    r_review_choice=$r_worker
    [ "$r_explicit_worker" = true ] || r_review_choice=$(jq -r '.review_worker//.default_worker' <<< "$r_policy")
    r_review "$r_review_choice"; exit
fi
r_step
if [ "$r_progress" = true ]; then
    printf 'Pause at GREEN: consider a useful refactor, update scenarios from what you learned, then choose the next test. At a feature boundary, assess the observed outcome.\n'
fi
r_usage "$r_run_id"
