#!/usr/bin/env bash
# Put the answer on the issue as ONE comment, updating the last one this action
# wrote rather than stacking a new one under every run.
#
# The comment is found by a hidden HTML marker on its first line: invisible in
# rendered markdown, and unmistakable, so a re-run never edits a person's
# comment. GitHub keeps the edit history, so nothing is lost by overwriting.
#
# Runs under always(). A failed run is exactly when someone wants to be told
# why, and a red X with no comment is the worst outcome for a person who typed
# a command and walked away.
set -euo pipefail

# COMMENT_KEY keeps two fx jobs on one thread apart: an issue note and a /fx
# answer are different comments, each updated in place, not one overwriting
# the other. The marker is matched whole, so `fx-agent-action -->` never
# matches `fx-agent-action:note -->`.
MARKER="<!-- fx-agent-action${COMMENT_KEY:+:$COMMENT_KEY} -->"
LIMIT=60000   # GitHub rejects a comment body over 65,536 characters with a 422
body="$RUNNER_TEMP/fx-comment.md"
repo="${GITHUB_REPOSITORY}"
run_url="${GITHUB_SERVER_URL:-https://github.com}/$repo/actions/runs/${GITHUB_RUN_ID:-}"

# Ours is a comment whose body starts with the marker. Paginated because a long
# thread would otherwise hide it past the first page. The body comes back too:
# it carries the run ledger below.
existing=$(gh api "repos/$repo/issues/$ISSUE_NUMBER/comments" --paginate \
  --jq "[.[] | select((.body // \"\") | startswith(\"$MARKER\"))] | last // empty" 2>/dev/null || true)
existing_id=$(printf '%s' "$existing" | jq -r '.id // empty' 2>/dev/null || true)

# --- the run ledger -----------------------------------------------------------
# A comment that is rewritten on every edit would otherwise show only the last
# run's cost. So each run is appended to a hidden JSON line under the marker,
# capped at the last six, and the footer renders them: the newest in full, the
# earlier ones as one short line each, and a total. The script does the adding;
# the model is never asked to.
previous=$(printf '%s' "$existing" | jq -r '.body // ""' 2>/dev/null \
  | sed -n 's/^<!-- fx-runs \(.*\) -->$/\1/p' | head -n1)
[ -n "$previous" ] && printf '%s' "$previous" | jq -e 'type == "array"' >/dev/null 2>&1 || previous='[]'
this_run=$(jq -nc --arg m "${MODEL:-}" --arg c "${COST:-}" --arg s "${DURATION:-}" \
  --arg i "${IN_TOKENS:-}" --arg o "${OUT_TOKENS:-}" --arg u "$run_url" --arg mem "${MEMORY:-}" \
  '{m:$m, c:($c|tonumber? // null), s:($s|tonumber? // null), i:($i|tonumber? // null), o:($o|tonumber? // null), u:$u}
   + (if $mem == "updated" or $mem == "compacted" then {mem:$mem} else {} end)')
runs=$(printf '%s' "$previous" | jq -c --argjson r "$this_run" '. + [$r] | .[-6:]')

# Cents with one decimal; dollars from $1. Tokens in k from a thousand.
footer=$(printf '%s' "$runs" | jq -r '
  def cents: if . == null then "?" elif . >= 1 then "$" + (. * 100 | round / 100 | tostring) else ((. * 1000 | round) / 10 | tostring) + "¢" end;
  def k: if . == null then "?" elif . >= 1000 then ((. / 100 | round) / 10 | tostring) + "k" else tostring end;
  def secs: if . == null then "" else " · " + (tostring) + "s" end;
  def mem: if .mem == "updated" then " · memory updated" elif .mem == "compacted" then " · memory compacted" else "" end;
  (.[-1]) as $n
  | ["[fx](https://fx.sh) `\($n.m)` · \($n.i | k) in / \($n.o | k) out · \($n.c | cents)\($n.s | secs)\($n | mem) · [run](\($n.u))"]
  + [ .[:-1] | reverse | .[] | "earlier · \(.c | cents)\(.s | secs) · [run](\(.u))" ]
  + (if length > 1 then ["\(length) runs · \([.[].c | select(. != null)] | add | cents) total"] else [] end)
  | .[]')

{
  printf '%s\n' "$MARKER"
  printf '<!-- fx-runs %s -->\n' "$runs"
  if [ -n "${RESPONSE_PATH:-}" ] && [ -s "${RESPONSE_PATH:-}" ]; then
    if [ "$(wc -c < "$RESPONSE_PATH")" -gt "$LIMIT" ]; then
      head -c "$LIMIT" "$RESPONSE_PATH"
      printf '\n\n*Answer truncated — the rest is in the [step summary](%s).*\n' "$run_url"
    else
      cat "$RESPONSE_PATH"
    fi
  else
    printf 'The run failed before there was an answer. The [log](%s) says why.\n' "$run_url"
  fi
  [ -n "${PR_URL:-}" ] && printf '\n\nOpened %s — nobody has reviewed it yet.\n' "$PR_URL"
  [ "${RUN_FAILED:-success}" = "failure" ] && printf '\n\n*The run itself failed; the answer above may be partial.*\n'
  printf '\n\n---\n%s\n' "$footer"
} > "$body"

if [ -n "$existing_id" ]; then
  url=$(gh api -X PATCH "repos/$repo/issues/comments/$existing_id" \
    -F "body=@$body" --jq '.html_url')
  echo "Updated comment $existing_id (run $(printf '%s' "$runs" | jq length))" >&2
else
  url=$(gh api -X POST "repos/$repo/issues/$ISSUE_NUMBER/comments" \
    -F "body=@$body" --jq '.html_url')
  echo "Posted a new comment" >&2
fi

echo "url=$url" >> "$GITHUB_OUTPUT"
echo "$url" >&2
