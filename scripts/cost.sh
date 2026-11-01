#!/usr/bin/env bash
# About what this run cost, in US dollars, and who served it.
#
# Usage: cost.sh <fx ask --json result>...  (the main run, plus a memory
# compaction when there was one). Prints lines for $GITHUB_OUTPUT:
# `cost=<dollars>`, `cost_estimated=true`, `providers=<comma-separated slugs>`.
#
# An estimate at list price: each result's tokens times the price of the
# provider that served it (`resolved_provider`, from the gateway's per-model
# endpoints list), or the catalog's headline price when that lookup fails, with
# a warning when the list loaded but did not name the provider. DeepSeek's
# hosts range from $0.035 to $0.30 per million input, so the headline price is
# only right for some of them. A host's peak-hour multiplier applies, to every
# rate, when this script runs inside the window, which is close enough to when
# the run did; `holiday_calendar` and `discount` (0 everywhere so far) are
# ignored. Cache reads and writes go at their own rates when fx reports them
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

# Per-provider prices, one file per model, kept across calls like the catalog.
endpoints=()
for model in $(jq -r '.model // empty' "$@" 2>/dev/null | sort -u); do
  f="$tmp/fx-endpoints-${model//\//_}.json"
  [ -s "$f" ] || curl -fsSL --max-time 15 "https://ai-gateway.vercel.sh/v1/models/$model/endpoints" > "$f" 2>/dev/null || rm -f "$f"
  [ -s "$f" ] && endpoints+=("$f")
done

over=$(jq -r 'select((.usage.cache_read_tokens // 0) + (.usage.cache_write_tokens // 0) > (.usage.input_tokens // 0))
  | "\(.model): \(.usage.cache_read_tokens // 0) read + \(.usage.cache_write_tokens // 0) written > \(.usage.input_tokens // 0) input"' "$@" 2>/dev/null || true)
if [ -n "$over" ]; then
  echo "::warning::No cost: cached tokens exceed input_tokens, so fx's usage fields changed meaning. $(printf '%s' "$over" | tr '\n' ' ')" >&2
  exit 0
fi

summary=$(jq -sc --slurpfile cat "$catalog" --slurpfile ep <(cat /dev/null ${endpoints[@]+"${endpoints[@]}"}) '
  ($cat[0].data | map({key: .id, value: .pricing}) | from_entries) as $price
  # minute of the UTC day and weekday (0 = Sunday) now, for peak windows
  | (now | gmtime) as $t | ($t[3] * 60 + $t[4]) as $min | ($t[6]) as $dow
  | ($ep | map(.data.id)) as $listed
  | ($ep | map(.data | .id as $id | .endpoints[]? | {key: "\($id)|\(.provider_name)", value: (.pricing as $p
      # a window whose end is before its start runs past midnight
      | ([$p.peak_pricing.windows[]? | select((if .start_minute_utc <= .end_minute_utc
            then $min >= .start_minute_utc and $min < .end_minute_utc
            else $min >= .start_minute_utc or $min < .end_minute_utc end)
          and (.days_of_week == null or (.days_of_week | index($dow))))] | if length > 0 then $p.peak_pricing.multiplier else 1 end) as $x
      | {input: $p.prompt, output: $p.completion, input_cache_read: $p.input_cache_read, input_cache_write: $p.input_cache_write}
      | map_values(select(. != null) | tonumber * $x))}) | from_entries) as $host
  | def rate($m; $prov; $k): $host["\($m)|\($prov)"] as $h
      | if $h != null then ($h[$k] // $h.input // 0)
        else ($price[$m][$k] // $price[$m].input // "0") | tonumber end;
  select(length > 0)
  | map({m: .model, p: (.resolved_provider // ""), i: (.usage.input_tokens // 0), o: (.usage.output_tokens // 0),
         r: (.usage.cache_read_tokens // 0), w: (.usage.cache_write_tokens // 0)})
  | if any(.[]; $price[.m] == null and (.i + .o) > 0) then empty else . end
  | {cost: (map((.i - .r - .w) * rate(.m; .p; "input") + .r * rate(.m; .p; "input_cache_read")
                + .w * rate(.m; .p; "input_cache_write") + .o * rate(.m; .p; "output")) | add),
     providers: ([.[].p | select(. != "")] | unique | join(",")),
     unlisted: ([.[] | select(.p != "" and (.m as $m | $listed | index([$m])) and $host["\(.m)|\(.p)"] == null) | "\(.m) via \(.p)"] | unique | join(", "))}' "$@" 2>/dev/null || true)
[ -n "$summary" ] || exit 0

unlisted=$(printf '%s' "$summary" | jq -r '.unlisted')
[ -z "$unlisted" ] || echo "::warning::Priced at the catalog's headline price: the gateway's endpoints list has no such provider for $unlisted." >&2

printf 'cost=%s\ncost_estimated=true\nproviders=%s\n' \
  "$(printf '%s' "$summary" | jq -r '.cost')" \
  "$(printf '%s' "$summary" | jq -r '.providers')"
