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

{
  printf '%s\n' "$MARKER"
  if [ -n "${RESPONSE_PATH:-}" ] && [ -s "${RESPONSE_PATH:-}" ]; then
    if [ "$(wc -c < "$RESPONSE_PATH")" -gt "$LIMIT" ]; then
      head -c "$LIMIT" "$RESPONSE_PATH"
      printf '\n\n*Answer truncated — the rest is in the [step summary](%s/%s/actions/runs/%s).*\n' \
        "${GITHUB_SERVER_URL:-https://github.com}" "$repo" "${GITHUB_RUN_ID:-}"
    else
      cat "$RESPONSE_PATH"
    fi
  else
    printf 'The run failed before there was an answer. The [log](%s/%s/actions/runs/%s) says why.\n' \
      "${GITHUB_SERVER_URL:-https://github.com}" "$repo" "${GITHUB_RUN_ID:-}"
  fi
  [ -n "${PR_URL:-}" ] && printf '\n\nOpened %s — nobody has reviewed it yet.\n' "$PR_URL"
  [ "${RUN_FAILED:-success}" = "failure" ] && printf '\n\n*The run itself failed; the answer above may be partial.*\n'
  printf '\n\n---\n'
  printf '[fx](https://fx.sh) `%s`' "${MODEL:-}"
  [ -n "${DURATION:-}" ] && printf ' · %ss' "$DURATION"
  [ -n "${COST:-}" ] && printf ' · $%s' "$COST"
  [ -n "${FX_VERSION:-}" ] && printf ' · v%s' "$FX_VERSION"
  printf ' · [run](%s/%s/actions/runs/%s)\n' "${GITHUB_SERVER_URL:-https://github.com}" "$repo" "${GITHUB_RUN_ID:-}"
} > "$body"

# Ours is a comment whose body starts with the marker. Paginated because a long
# thread would otherwise hide it past the first page.
existing=$(gh api "repos/$repo/issues/$ISSUE_NUMBER/comments" --paginate \
  --jq "[.[] | select((.body // \"\") | startswith(\"$MARKER\")) | .id] | last // empty" 2>/dev/null || true)

if [ -n "$existing" ]; then
  url=$(gh api -X PATCH "repos/$repo/issues/comments/$existing" \
    -F "body=@$body" --jq '.html_url')
  echo "Updated comment $existing" >&2
else
  url=$(gh api -X POST "repos/$repo/issues/$ISSUE_NUMBER/comments" \
    -F "body=@$body" --jq '.html_url')
  echo "Posted a new comment" >&2
fi

echo "url=$url" >> "$GITHUB_OUTPUT"
echo "$url" >&2
