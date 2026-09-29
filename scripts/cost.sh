#!/usr/bin/env bash
# What this run has cost so far, in US dollars, and who served it.
#
# Prints lines for $GITHUB_OUTPUT: `cost=<dollars>`, `cost_estimated=true|false`,
# `providers=<comma-separated provider slugs>`.
#
# Priced per generation, from the ids fx writes to ~/.fx/usage.jsonl:
#   1. The ledger's own `total_cost`, when it is above zero: the gateway billed
#      it.
#   2. Zero means a BYOK key: the gateway billed nothing, but its record of the
#      generation (`GET /v1/generation?id=`) carries the provider's real charge
#      (`upstream_inference_cost`) and who served it. Exact, peak pricing
#      included.
#   3. Tokens times the catalog's list price, cache reads at theirs, marked
#      estimated, for any generation the lookup could not answer.
# Per generation, because one run can be both: a gateway-billed helper (the
# auto reviewer) next to a BYOK main model. Summing only the ledger's spend
# once dropped the BYOK half entirely. Never fails the run: nothing to say
# prints nothing.
set -euo pipefail

ledger="$HOME/.fx/usage.jsonl"
tmp="${RUNNER_TEMP:-/tmp}"
gens="$tmp/fx-cost-generations.jsonl"
jq -c 'select(.kind == "generation") | .fact | select(.id != null)
       | {id, model, i: (.input_tokens // 0), r: (.cache_read_tokens // 0), o: (.output_tokens // 0), c: (.total_cost // 0)}' \
  "$ledger" 2>/dev/null | jq -sc 'unique_by(.id) | .[]' > "$gens" 2>/dev/null || true

if [ ! -s "$gens" ]; then
  # No per-generation ledger (an older fx): the totals are all there is.
  # `env -u GH_TOKEN`: memory.sh calls this from a step that holds a token,
  # and no fx process gets one.
  spend=$(env -u GH_TOKEN fx usage --json 2>/dev/null | jq -r '.totals.spend // 0' 2>/dev/null || echo 0)
  [ "$(printf '%s' "$spend" | jq -r '. > 0' 2>/dev/null)" = "true" ] && printf 'cost=%s\ncost_estimated=false\n' "$spend"
  exit 0
fi

# --- 2. the gateway's record of each zero-cost generation ---------------------
# A record 404s for a while after the generation, so two retry passes.
# Kept across calls: memory.sh calls this again after a compaction, and only
# the compaction's generation is new by then.
records="$tmp/fx-cost-records.jsonl"
touch "$records"
lookup() {
  curl -fsS --max-time 10 "https://ai-gateway.vercel.sh/v1/generation?id=$1" \
    -H "Authorization: Bearer $AI_GATEWAY_API_KEY" 2>/dev/null \
    | jq -c --arg id "$1" '.data // empty | select(.upstream_inference_cost != null or .total_cost != null)
        | {id: $id, u: (.upstream_inference_cost // .total_cost), p: (.provider_name // "")}' 2>/dev/null
}
unpriced() {
  jq -rn --slurpfile g "$gens" --slurpfile r "$records" \
    '($r | map(.id)) as $done | limit(200; $g[] | select(.c == 0 and (.i + .o) > 0) | .id | select(. as $x | $done | index($x) | not))'
}
missing=$(unpriced || true)
if [ -n "${AI_GATEWAY_API_KEY:-}" ]; then
  for wait in 0 5 15; do
    [ -n "$missing" ] || break
    sleep "$wait"
    while IFS= read -r id; do
      lookup "$id" >> "$records" || true
    done <<< "$missing"
    missing=$(unpriced || true)
  done
fi

# --- 3. list price for whatever is still unpriced ------------------------------
catalog="$tmp/fx-gateway-models.json"
if [ -n "$missing" ] && [ ! -s "$catalog" ]; then
  curl -fsSL --max-time 15 https://ai-gateway.vercel.sh/v1/models > "$catalog" 2>/dev/null || rm -f "$catalog"
fi
[ -s "$catalog" ] || echo '{"data":[]}' > "$catalog"

summary=$(jq -sc --slurpfile r "$records" --slurpfile cat "$catalog" '
  ($r | map({key: .id, value: .}) | from_entries) as $rec
  | ($cat[0].data | map({key: .id, value: .pricing}) | from_entries) as $price
  | map(
      if .c > 0 then {cost: .c, est: false}
      elif $rec[.id] then {cost: $rec[.id].u, est: false, p: $rec[.id].p}
      elif (.i + .o) == 0 then {cost: 0, est: false}
      elif $price[.model] then
        # Cached input at its own price when the catalog has one: most of an
        # agent run input is cache reads, and full price overstates it tenfold.
        ($price[.model]) as $p
        | {cost: ((.i - .r) * ($p.input // "0" | tonumber)
                  + .r * ($p.input_cache_read // $p.input // "0" | tonumber)
                  + .o * ($p.output // "0" | tonumber)), est: true}
      else {cost: 0, est: true}
      end)
  | {cost: (map(.cost) | add), est: any(.[]; .est), providers: ([.[].p // empty | select(. != "")] | unique | join(",")),
     looked_up: ([.[] | select(.p != null)] | length)}' "$gens" 2>/dev/null || true)
[ -n "$summary" ] || exit 0

printf 'cost=%s\ncost_estimated=%s\nproviders=%s\n' \
  "$(printf '%s' "$summary" | jq -r '.cost')" \
  "$(printf '%s' "$summary" | jq -r '.est')" \
  "$(printf '%s' "$summary" | jq -r '.providers')"
n=$(printf '%s' "$summary" | jq -r '.looked_up')
[ "$n" -gt 0 ] && echo "cost: $n BYOK generations priced from the gateway; served by $(printf '%s' "$summary" | jq -r '.providers')" >&2
exit 0
