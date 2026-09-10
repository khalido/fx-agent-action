#!/usr/bin/env bash
# 👀 on the comment that triggered the run, taken off again once the answer is
# posted. It is a spinner, not a badge: a run can take two minutes and silence
# reads as "nothing happened".
#
# Copied in spirit from shaftoe/pi-coding-agent-action, including the part that
# is easy to miss — an inline PR review comment is a different endpoint from a
# conversation comment.
set -euo pipefail

# Three places a reaction can go: an inline PR review comment, a conversation
# comment, or, when the trigger was the issue itself being opened or edited,
# the issue.
if [ -n "${COMMENT_ID:-}" ] && [ -n "${REVIEW_COMMENT:-}" ]; then
  path="repos/$GITHUB_REPOSITORY/pulls/comments/$COMMENT_ID/reactions"
elif [ -n "${COMMENT_ID:-}" ]; then
  path="repos/$GITHUB_REPOSITORY/issues/comments/$COMMENT_ID/reactions"
elif [ -n "${ISSUE_NUMBER:-}" ]; then
  path="repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/reactions"
else
  exit 0
fi
target="${COMMENT_ID:+comment $COMMENT_ID}"; target="${target:-issue #$ISSUE_NUMBER}"

case "${1:-add}" in
  add)
    # Never fatal: a missing reactions scope should not stop the actual work.
    id=$(gh api -X POST "$path" -f content=eyes --jq '.id' 2>/dev/null || true)
    echo "reaction_id=${id:-}" >> "$GITHUB_OUTPUT"
    [ -n "$id" ] && echo "Reacted 👀 to $target" >&2 || true
    ;;
  remove)
    [ -n "${REACTION_ID:-}" ] || exit 0
    gh api -X DELETE "$path/$REACTION_ID" >/dev/null 2>&1 || true
    ;;
  *)
    echo "react.sh takes 'add' or 'remove'" >&2
    exit 1
    ;;
esac
