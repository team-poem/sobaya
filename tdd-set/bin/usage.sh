#!/usr/bin/env bash
# Token/cost log for the loop. Two modes:
#   usage.sh record <app> <run> <iter>   reads one `claude -p --output-format json` result on stdin,
#                                        appends a JSONL line to <app>/.git/sobaya-loop-usage.log,
#                                        prints the agent's text result so the terminal still shows it
#   usage.sh summary <app> [run]         per-iteration table + totals for one run (default: last run)
# A run is identified by the loop's start commit. Needs jq; without it, record prints the raw output.
set -u
mode=${1:?usage: usage.sh record|summary <app> ...}; app=${2:?app dir}; app=${app%/}
log="$app/.git/sobaya-loop-usage.log"

case "$mode" in
record)
  run=${3:?run id}; iter=${4:?iteration}
  out=$(cat)
  if ! command -v jq >/dev/null 2>&1 || ! printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
    printf '%s\n' "$out"; exit 0     # not JSON (claude crashed, or no jq): show it, log nothing
  fi
  printf '%s' "$out" | jq -r '.result // empty'
  printf '%s' "$out" | jq -c --arg run "$run" --argjson iter "$iter" --arg ts "$(date -u +%FT%TZ)" '{
    ts: $ts, run: $run, iter: $iter,
    model: ((.modelUsage // {}) | keys | join("+")),
    in: (.usage.input_tokens // 0), out: (.usage.output_tokens // 0),
    cache_read: (.usage.cache_read_input_tokens // 0), cache_create: (.usage.cache_creation_input_tokens // 0),
    cost: (.total_cost_usd // 0), turns: (.num_turns // 0),
    subagents: (.subagent_stats.spawned // 0), ms: (.duration_ms // 0), error: (.is_error // false)
  }' >> "$log"
  ;;
summary)
  [ -f "$log" ] || { echo "no usage log at $log"; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }
  run=${3:-$(tail -1 "$log" | jq -r .run)}
  jq -r --arg run "$run" 'select(.run == $run) |
    "\(.iter)\t\(.model)\t\(.in)\t\(.out)\t\(.cache_read)\t\(.cache_create)\t\(.cost * 1000 | round / 1000)\t\(.turns)\t\(.subagents)\t\(.ms / 1000 | round)s"' "$log" \
    | { printf 'iter\tmodel\tin\tout\tcache_read\tcache_create\tusd\tturns\tsubagents\ttime\n'; cat; } | column -t -s $'\t'
  jq -s -r --arg run "$run" 'map(select(.run == $run)) |
    "total: \(length) iterations, $\(map(.cost) | add | . * 1000 | round / 1000), in \(map(.in) | add), out \(map(.out) | add), cache_read \(map(.cache_read) | add), cache_create \(map(.cache_create) | add); max iteration $\(map(.cost) | max | . * 1000 | round / 1000)"' "$log"
  ;;
*) echo "unknown mode $mode"; exit 2 ;;
esac
