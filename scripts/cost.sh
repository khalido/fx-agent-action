#!/usr/bin/env bash
# What this run has cost so far, in US dollars, and who served it.
#
# Prints lines for $GITHUB_OUTPUT: `cost=<dollars>`, `cost_estimated=true|false`,
# `providers=<comma-separated provider slugs>`.
#
# Source, in order:
#   1. fx's ledger (`fx usage --json`), when it has dollars.
#   2. The gateway's own record of each generation, looked up by the ids fx
#      writes to ~/.fx/usage.jsonl. A BYOK key makes the gateway bill nothing,
#      so the ledger says zero, but the record still carries the provider's
#      real charge (`upstream_inference_cost`), the provider that served the
#      request, and the latency. Exact, peak pricing included.
#   3. Tokens times the catalog's list price, marked estimated, if the lookups
#      fail. Never fails the run: nothing to say prints nothing.
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

# --- 2. the gateway's per-generation records --------------------------------
ledger="$HOME/.fx/usage.jsonl"
if [ -s "$ledger" ] && [ -n "${AI_GATEWAY_API_KEY:-}" ]; then
  ids=$(jq -r 'select(.kind == "generation") | .fact.id // empty' "$ledger" 2>/dev/null | sort -u | head -200 || true)
  if [ -n "$ids" ]; then
    records="${RUNNER_TEMP:-/tmp}/fx-generations.jsonl"
    : > "$records"
    while IFS= read -r id; do
      curl -fsS --max-time 10 "https://ai-gateway.vercel.sh/v1/generation?id=$id" \
        -H "Authorization: Bearer $AI_GATEWAY_API_KEY" 2>/dev/null >> "$records" || true
      echo >> "$records"
    done <<< "$ids"
    summary=$(jq -sc '
      [ .[] | .data? // empty ] as $g
      | if ($g | length) == 0 then empty else
        { cost: ([ $g[] | (.total_cost // 0) + (if (.total_cost // 0) == 0 then (.upstream_inference_cost // 0) else 0 end) ] | add),
          providers: ([ $g[] | .provider_name // empty ] | unique | join(",")),
          n: ($g | length) }
        end' "$records" 2>/dev/null || true)
    if [ -n "$summary" ]; then
      printf 'cost=%s\ncost_estimated=false\nproviders=%s\n' \
        "$(printf '%s' "$summary" | jq -r '.cost')" "$(printf '%s' "$summary" | jq -r '.providers')"
      echo "cost: $(printf '%s' "$summary" | jq -r '.n') generations looked up on the gateway; served by $(printf '%s' "$summary" | jq -r '.providers')" >&2
      exit 0
    fi
  fi
fi

# --- 3. list price from tokens ---------------------------------------------
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
