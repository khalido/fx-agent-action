#!/usr/bin/env bash
# Turn whatever the agent changed in the workspace into a branch and a pull
# request. Nothing here is fx's doing: fx edits files, this commits them.
#
# Runs only after a write-mode turn. If the agent changed nothing, that is a
# normal outcome — it thought and answered rather than typed — so this exits
# quietly and the comment step still posts the answer.
set -euo pipefail

# Only what THIS run touched. A previous step may have left build output or a
# cache in the workspace, and `git add -A` would sweep that into the pull
# request. `fx-tree-before.txt` is the porcelain listing taken just before fx
# ran; anything in it is somebody else's mess.
before="$RUNNER_TEMP/fx-tree-before.txt"
[ -f "$before" ] || : > "$before"
changed="$RUNNER_TEMP/fx-tree-changed.txt"
git status --porcelain | grep -vxF -f "$before" > "$changed" || true

if [ ! -s "$changed" ]; then
  echo "The agent changed no files; nothing to open a pull request for." >&2
  echo "pr_url=" >> "$GITHUB_OUTPUT"
  exit 0
fi

# The porcelain line is a two-character status, a space, then the path. A rename
# reads `R  old -> new`; take the new name.
paths="$RUNNER_TEMP/fx-paths.txt"
sed -E 's/^.{3}//; s/^.* -> //; s/^"(.*)"$/\1/' "$changed" > "$paths"

branch="${BRANCH_PREFIX:-fx}/${ISSUE_NUMBER:-run}-$(date +%s)"

# `fx pr` drafts a title and body from the diff — but it reads the UNCOMMITTED
# working tree (verified on 0.0.8: it runs `git diff` and changes nothing), so
# it has to run here, before the commit below. It has no --json, so the prose is
# parsed loosely and anything unexpected falls back to the agent's own answer.
draft="$RUNNER_TEMP/fx-pr-draft.md"
title=''
if fx pr < /dev/null > "$draft" 2>/dev/null; then
  title=$(grep -m1 -E '^[[:space:]]*(\*\*)?Title:' "$draft" \
    | sed -E 's/^[[:space:]]*(\*\*)?Title:(\*\*)?[[:space:]]*//; s/[[:space:]]*$//')
fi
if [ -z "$title" ]; then
  # The agent's first line, when it reads like a title rather than a paragraph.
  first=$(head -n1 "$RESPONSE_PATH" | sed -E 's/^#+[[:space:]]*//; s/[[:space:]]*$//')
  if [ -n "$first" ] && [ "${#first}" -le 72 ]; then
    title="$first"
  else
    title="fx: changes for #${ISSUE_NUMBER:-}"
  fi
fi

git config user.name "${GIT_USER_NAME:-github-actions[bot]}"
git config user.email "${GIT_USER_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"

git checkout -b "$branch"
xargs -a "$paths" -d '\n' -r git add --

# The workflow token cannot push a change to .github/workflows — GitHub refuses
# it whatever the permissions say. Drop those rather than fail the whole run,
# and say so in the body.
workflow_note=''
if ! git diff --cached --quiet -- .github/workflows 2>/dev/null; then
  git restore --staged .github/workflows 2>/dev/null || true
  git checkout -- .github/workflows 2>/dev/null || true
  workflow_note=$'\n\nSkipped changes under `.github/workflows/`: the workflow token is not allowed to push them. Apply those by hand, or give the action a GitHub App token whose app has the Workflows permission.'
  if [ -z "$(git diff --cached --name-only)" ]; then
    echo "::warning::Only workflow files changed, which this token cannot push." >&2
    echo "pr_url=" >> "$GITHUB_OUTPUT"
    exit 0
  fi
fi

git commit -q -m "$title" -m "Opened by fx from #${ISSUE_NUMBER:-} · run ${GITHUB_RUN_ID:-}"
# Pushed with the token in the URL rather than through the remote, so this
# works with `persist-credentials: false` — which every example sets, so the
# checkout leaves no credential on disk for the agent to find.
git push -q "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "HEAD:$branch"

body_file="$RUNNER_TEMP/fx-pr-body.md"
{
  # fx's drafted body when we got one, else what the agent told the commenter.
  if [ -s "$draft" ] && [ -n "$(sed -n '/^[[:space:]]*\(\*\*\)\?Title:/,$p' "$draft" | tail -n +2)" ]; then
    sed -n '/^[[:space:]]*\(\*\*\)\?Title:/,$p' "$draft" | tail -n +2
  else
    cat "$RESPONSE_PATH"
  fi
  [ -n "${ISSUE_NUMBER:-}" ] && printf '\n\nFor #%s.' "$ISSUE_NUMBER"
  printf '%s' "$workflow_note"
  printf '\n\n---\nOpened by [fx](https://fx.sh) · [run](%s/%s/actions/runs/%s). Nobody has reviewed this yet.\n' \
    "${GITHUB_SERVER_URL:-https://github.com}" "$GITHUB_REPOSITORY" "${GITHUB_RUN_ID:-}"
} > "$body_file"

# stderr stays on stderr: merged into stdout, a gh warning would become the
# "URL" and end up rendered in the comment.
# Draft, always. Nobody has read this yet, and a draft cannot be merged by
# accident — the same reason anthropics/claude-code-action stops at a branch and
# makes a person click "create pull request".
url=$(gh pr create --repo "$GITHUB_REPOSITORY" --head "$branch" --draft \
  --title "$title" --body-file "$body_file" | tail -1)

echo "pr_url=$url" >> "$GITHUB_OUTPUT"
echo "Opened $url" >&2
