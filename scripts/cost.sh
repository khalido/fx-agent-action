#!/usr/bin/env bash
# What this run has cost so far, in US dollars, from fx's local ledger.
#
# Prints two lines for $GITHUB_OUTPUT: `cost=<dollars>` and
# `cost_estimated=true|false`. The ledger's own dollars when it has them.
# When it says zero but tokens were used, which is what a BYOK key looks like
# (the gateway bills nothing, the provider bills you), the figure is worked
# out from the ledger's per-model tokens and the gateway's public list
# prices, and marked estimated. Peak-hour multipliers and cached-token
# discounts are not in that estimate, so it is the list price, not the bill.
#
# Never fails: a missing ledger or catalog prints nothing.
set -euo pipefail

usage=$(fx usage --json 2>/dev/null || true)
[ -n "$usage" ] || exit 0

spend=$(printf '%s' "$usage" | jq -r '.totals.spend // 0' 2>/dev/null || echo 0)
tokens=$(printf '%s' "$usage" | jq -r '.totals.total_tokens // 0' 2>/dev/null || echo 0)

if [ "$(printf '%s' "$spend" | jq -r '. > 0')" = "true" ]; then
  printf 'cost=%s\ncost_estimated=false\n' "$spend"
  exit 0
fi
[ "$tokens" -gt 0 ] 2>/dev/null || exit 0

# One catalog fetch per job, no key needed.
catalog="${RUNNER_TEMP:-/tmp}/fx-gateway-models.json"
if [ ! -s "$catalog" ]; then
  curl -fsSL --max-time 15 https://ai-gateway.vercel.sh/v1/models > "$catalog" 2>/dev/null || { rm -f "$catalog"; exit 0; }
fi

estimate=$(printf '%s' "$usage" | jq -r --slurpfile cat "$catalog" '
  ($cat[0].data | map({key: .id, value: .pricing}) | from_entries) as $price
  | [ .models[]?
      | ($price[.model] // empty) as $p
      | ((.totals.input_tokens // 0) * (($p.input // "0") | tonumber))
        + ((.totals.output_tokens // 0) * (($p.output // "0") | tonumber)) ]
  | add // empty' 2>/dev/null || true)

[ -n "$estimate" ] || exit 0
printf 'cost=%s\ncost_estimated=true\n' "$estimate"
