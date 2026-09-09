#!/usr/bin/env bash
# Turn whatever the agent changed in the workspace into a branch and a pull
# request. Nothing here is fx's doing: fx edits files, this commits them.
#
# Runs only after a write-mode turn. If the agent changed nothing, that is a
# normal outcome — it thought and answered rather than typed — so this exits
# quietly and the comment step still posts the answer.
set -euo pipefail

if [ -z "$(git status --porcelain)" ]; then
  echo "The agent changed no files; nothing to open a pull request for." >&2
  echo "pr_url=" >> "$GITHUB_OUTPUT"
  exit 0
fi

branch="${BRANCH_PREFIX:-fx}/${ISSUE_NUMBER:-run}-$(date +%s)"
title="${PR_TITLE:-}"
if [ -z "$title" ]; then
  title="fx: $(git status --porcelain | wc -l | tr -d ' ') file(s) for #${ISSUE_NUMBER:-}"
fi

git config user.name "${GIT_USER_NAME:-github-actions[bot]}"
git config user.email "${GIT_USER_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"

git checkout -b "$branch"
git add -A

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
git push -q origin "$branch"

body_file="$RUNNER_TEMP/fx-pr-body.md"
{
  cat "$RESPONSE_PATH"
  [ -n "${ISSUE_NUMBER:-}" ] && printf '\n\nFor #%s.' "$ISSUE_NUMBER"
  printf '%s' "$workflow_note"
  printf '\n\n---\nOpened by [fx](https://fx.sh) · [run](%s/%s/actions/runs/%s). Nobody has reviewed this yet.\n' \
    "${GITHUB_SERVER_URL:-https://github.com}" "$GITHUB_REPOSITORY" "${GITHUB_RUN_ID:-}"
} > "$body_file"

url=$(gh pr create --repo "$GITHUB_REPOSITORY" --head "$branch" \
  --title "$title" --body-file "$body_file" 2>&1 | tail -1)

echo "pr_url=$url" >> "$GITHUB_OUTPUT"
echo "Opened $url" >&2
