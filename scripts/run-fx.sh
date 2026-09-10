#!/usr/bin/env bash
# Run fx once, noninteractively, and pull the answer out of its JSON.
#
# `fx ask --json` separates `final_output` (the finished answer) from `output`
# (everything the model said along the way). Posting `final_output` is why this
# action needs no "stop narrating" rule in its prompt and works with any model.
set -euo pipefail

if [ -z "${AI_GATEWAY_API_KEY:-}" ]; then
  echo "::error::AI_GATEWAY_API_KEY is not set. Pass it as an env var on the step that uses this action." >&2
  exit 1
fi

out="$RUNNER_TEMP/fx-result.json"
response_path="$RUNNER_TEMP/fx-response.md"
started=$(date +%s)

set +e
# Not --no-save: the saved session is what the HTML artifact is rendered from,
# and the runner is thrown away at the end of the job anyway.
fx ask --json --no-color < "$PROMPT_PATH" > "$out" 2>"$RUNNER_TEMP/fx-stderr.log"
fx_status=$?
set -e
duration=$(( $(date +%s) - started ))

if [ ! -s "$out" ]; then
  echo "::error::fx produced no output (exit $fx_status). Last lines of its log:" >&2
  tail -20 "$RUNNER_TEMP/fx-stderr.log" >&2 || true
  exit 1
fi

exit_code=$(jq -r '.exit_code // 0' "$out")
session_id=$(jq -r '.session_id // empty' "$out")
model=$(jq -r '.model // "unknown"' "$out")
steps=$(jq -r '.steps // 0' "$out")
in_tokens=$(jq -r '.usage.input_tokens // 0' "$out")
out_tokens=$(jq -r '.usage.output_tokens // 0' "$out")

# `final_output` is empty when the run ended before the model finished — a step
# cap, a denied tool it could not work around, a provider error. Fall back to
# the accumulated output so the comment says something rather than nothing.
jq -r 'if (.final_output // "") != "" then .final_output else (.output // "") end' "$out" > "$response_path"

if [ ! -s "$response_path" ]; then
  echo "::error::fx returned no answer (exit_code $exit_code). Error field: $(jq -r '.error // "none"' "$out")" >&2
  exit 1
fi

# Scrub secrets out of the answer, here, once, before anything downstream reads
# the file. See scripts/redact.py for why this is not covered by GitHub's log
# masking.
python3 -c "import sys; sys.path.insert(0, '$(dirname "$0")'); import redact; \
  found = redact.redact_file(sys.argv[1]); \
  [print(f'::warning::Removed {n} from the agent answer before posting it.') for n in found]" \
  "$response_path"

# `fx ask --json` reports tokens but no price. `fx usage` does report dollars —
# it keeps a local ledger — and the runner's HOME is new every job, so the only
# spend in it is this run's. That is where the footer's figure comes from.
# Tokens from the same ledger, when it has them: `fx ask` counts only the
# main agent, while the ledger includes helper models and provider tools,
# which is what the dollars cover. One source for both numbers in the footer.
usage=$(fx usage --json 2>/dev/null || true)
cost=$(printf '%s' "$usage" | jq -r '.totals.spend // empty' 2>/dev/null || true)
ledger_in=$(printf '%s' "$usage" | jq -r '.totals.input_tokens // empty' 2>/dev/null || true)
ledger_out=$(printf '%s' "$usage" | jq -r '.totals.output_tokens // empty' 2>/dev/null || true)
[ -n "$ledger_in" ] && in_tokens="$ledger_in"
[ -n "$ledger_out" ] && out_tokens="$ledger_out"
fx_version=$(fx --version 2>/dev/null | head -1 || echo unknown)

# A random delimiter, not a fixed one. The payload is model output: with a fixed
# `FX_EOF` an answer containing that line could close the block early and append
# its own key=value pairs, and later keys win — which would let it redirect
# `response_path` at any file on the runner.
delim="FX_EOF_$(openssl rand -hex 12 2>/dev/null || date +%s%N)"

{
  echo "response_path=$response_path"
  echo "result_path=$out"
  echo "cost=$cost"
  echo "steps=$steps"
  echo "duration=$duration"
  echo "fx_version=$fx_version"
  echo "session_id=$session_id"
  echo "input_tokens=$in_tokens"
  echo "output_tokens=$out_tokens"
  # The answer itself, for a workflow that wants it inline rather than as a
  # file. Delimited, because it is markdown and will contain newlines.
  echo "response<<$delim"
  cat "$response_path"
  echo ""
  echo "$delim"
} >> "$GITHUB_OUTPUT"

{
  echo "### fx"
  echo ""
  echo "Model \`$model\` · $steps steps · ${duration}s · ${in_tokens} in / ${out_tokens} out"
  echo ""
  cat "$response_path"
} >> "$GITHUB_STEP_SUMMARY"

echo "fx finished: $steps steps, ${duration}s, ${in_tokens} in / ${out_tokens} out" >&2

if [ -n "$cost" ] && [ "${MAX_COST:-0}" != "0" ]; then
  if awk -v c="$cost" -v m="$MAX_COST" 'BEGIN { exit (c + 0 > m + 0) ? 0 : 1 }'; then
    echo "::error::fx run cost \$$cost, over the \$$MAX_COST limit." >&2
    exit 1
  fi
fi

if [ "$exit_code" != "0" ]; then
  echo "::warning::fx reported exit_code $exit_code; the answer above may be partial." >&2
fi
