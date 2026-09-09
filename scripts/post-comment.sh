#!/usr/bin/env bash
# Put the answer on the issue as ONE comment, updating the last one this action
# wrote rather than stacking a new one under every run.
#
# The comment is found by a hidden HTML marker on its first line: invisible in
# rendered markdown, and unmistakable, so a re-run never edits a person's
# comment. GitHub keeps the edit history, so nothing is lost by overwriting.
set -euo pipefail

MARKER='<!-- fx-agent-action -->'
body="$RUNNER_TEMP/fx-comment.md"
repo="${GITHUB_REPOSITORY}"

{
  printf '%s\n' "$MARKER"
  cat "$RESPONSE_PATH"
  [ -n "${PR_URL:-}" ] && printf '\n\nOpened %s — nobody has reviewed it yet.\n' "$PR_URL"
  printf '\n\n---\n'
  printf '[fx](https://fx.sh) `%s`' "${MODEL:-}"
  [ -n "${DURATION:-}" ] && printf ' · %ss' "$DURATION"
  [ -n "${COST:-}" ] && printf ' · $%s' "$COST"
  [ -n "${FX_VERSION:-}" ] && printf ' · %s' "$FX_VERSION"
  printf ' · [run](%s/%s/actions/runs/%s)\n' "${GITHUB_SERVER_URL:-https://github.com}" "$repo" "$GITHUB_RUN_ID"
} > "$body"

# Ours is a comment whose body starts with the marker. Paginated because a long
# thread would otherwise hide it past the first page.
existing=$(gh api "repos/$repo/issues/$ISSUE_NUMBER/comments" --paginate \
  --jq "[.[] | select(.body | startswith(\"$MARKER\")) | .id] | last // empty" 2>/dev/null || true)

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
