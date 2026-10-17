#!/usr/bin/env bash
# What this run has cost at most, in US dollars, and who served it.
#
# Usage: cost.sh <fx ask --json result>...  (the main run, plus a memory
# compaction when there was one). Prints lines for $GITHUB_OUTPUT:
# `cost=<dollars>`, `cost_estimated=true`, `providers=<comma-separated slugs>`.
#
# A ceiling, not a price: each result's input and output tokens times the
# gateway catalog's list price. Since 0.0.14 fx keeps no per-generation ledger
# and `fx usage` reads the gateway's spend report, which needs a paid plan and
# covers a whole period, so tokens are all there is. They come without the
# cache-read share, so all input is priced in full: on deepseek-v4.1-flash,
# 91% cache reads at 1/43 of the input price, that overstates about 9×. It
# also leaves out what `fx ask` does not count (the auto reviewer, Exa).
# Never fails the run: nothing to say prints nothing.
set -euo pipefail

[ "$#" -gt 0 ] || exit 0
tmp="${RUNNER_TEMP:-/tmp}"
catalog="$tmp/fx-gateway-models.json"
# Kept across calls: memory.sh calls this again after a compaction.
if [ ! -s "$catalog" ]; then
  curl -fsSL --max-time 15 https://ai-gateway.vercel.sh/v1/models > "$catalog" 2>/dev/null || rm -f "$catalog"
fi
[ -s "$catalog" ] || exit 0

summary=$(jq -sc --slurpfile cat "$catalog" '
  ($cat[0].data | map({key: .id, value: .pricing}) | from_entries) as $price
  | select(length > 0)
  | map({m: .model, p: (.resolved_provider // ""), i: (.usage.input_tokens // 0), o: (.usage.output_tokens // 0)})
  | if any(.[]; $price[.m] == null and (.i + .o) > 0) then empty else . end
  | {cost: (map(.i * ($price[.m].input // "0" | tonumber) + .o * ($price[.m].output // "0" | tonumber)) | add),
     providers: ([.[].p | select(. != "")] | unique | join(","))}' "$@" 2>/dev/null || true)
[ -n "$summary" ] || exit 0

printf 'cost=%s\ncost_estimated=true\nproviders=%s\n' \
  "$(printf '%s' "$summary" | jq -r '.cost')" \
  "$(printf '%s' "$summary" | jq -r '.providers')"
