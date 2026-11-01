#!/usr/bin/env bash
# About what this run cost, in US dollars, and who served it.
#
# Usage: cost.sh <fx ask --json result>...  (the main run, plus a memory
# compaction when there was one). Prints lines for $GITHUB_OUTPUT:
# `cost=<dollars>`, `cost_estimated=true`, `providers=<comma-separated slugs>`.
#
# An estimate at list price: each result's tokens times the gateway catalog's
# price, with cache reads and writes at their own rates when fx reports them
# (`usage.cache_read_tokens` and `cache_write_tokens`, since 0.0.16, and
# included in `input_tokens`). Since 0.0.14 fx keeps no per-generation ledger
# and `fx usage` reads the gateway's spend report, which needs a paid plan and
# covers a whole period, so tokens are all there is. They are the main agent's
# only: the auto reviewer, subagents and Exa are not in them, so the figure
# runs low by that much. Cached tokens that exceed the input total mean fx
# changed what `input_tokens` counts (measured inclusive on 0.0.16, DeepSeek
# and Claude): that warns and prints no cost rather than a wrong one. Never
# fails the run: nothing to say prints nothing.
set -euo pipefail

[ "$#" -gt 0 ] || exit 0
tmp="${RUNNER_TEMP:-/tmp}"
catalog="$tmp/fx-gateway-models.json"
# Kept across calls: memory.sh calls this again after a compaction.
if [ ! -s "$catalog" ]; then
  curl -fsSL --max-time 15 https://ai-gateway.vercel.sh/v1/models > "$catalog" 2>/dev/null || rm -f "$catalog"
fi
[ -s "$catalog" ] || exit 0

over=$(jq -r 'select((.usage.cache_read_tokens // 0) + (.usage.cache_write_tokens // 0) > (.usage.input_tokens // 0))
  | "\(.model): \(.usage.cache_read_tokens // 0) read + \(.usage.cache_write_tokens // 0) written > \(.usage.input_tokens // 0) input"' "$@" 2>/dev/null || true)
if [ -n "$over" ]; then
  echo "::warning::No cost: cached tokens exceed input_tokens, so fx's usage fields changed meaning. $(printf '%s' "$over" | tr '\n' ' ')" >&2
  exit 0
fi

summary=$(jq -sc --slurpfile cat "$catalog" '
  ($cat[0].data | map({key: .id, value: .pricing}) | from_entries) as $price
  | def rate($m; $k): ($price[$m][$k] // $price[$m].input // "0") | tonumber;
  select(length > 0)
  | map({m: .model, p: (.resolved_provider // ""), i: (.usage.input_tokens // 0), o: (.usage.output_tokens // 0),
         r: (.usage.cache_read_tokens // 0), w: (.usage.cache_write_tokens // 0)})
  | if any(.[]; $price[.m] == null and (.i + .o) > 0) then empty else . end
  | {cost: (map((.i - .r - .w) * rate(.m; "input") + .r * rate(.m; "input_cache_read")
                + .w * rate(.m; "input_cache_write") + .o * rate(.m; "output")) | add),
     providers: ([.[].p | select(. != "")] | unique | join(","))}' "$@" 2>/dev/null || true)
[ -n "$summary" ] || exit 0

printf 'cost=%s\ncost_estimated=true\nproviders=%s\n' \
  "$(printf '%s' "$summary" | jq -r '.cost')" \
  "$(printf '%s' "$summary" | jq -r '.providers')"
