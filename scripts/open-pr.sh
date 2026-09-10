#!/usr/bin/env bash
# Turn whatever the agent changed in the workspace into a branch and a pull
# request. Nothing here is fx's doing: fx edits files, this commits them.
#
# Runs only after a write-mode turn. If the agent changed nothing, that is a
# normal outcome — it thought and answered rather than typed — so this exits
# quietly and the comment step still posts the answer.
set -euo pipefail

# Pathspecs below are repo-root relative, and so is everything git prints, so
# work from the root whatever `working_directory` was.
cd "$(git rev-parse --show-toplevel)"

# Only what THIS run touched. A previous step may have left build output in the
# workspace, and staging everything would sweep that into the pull request.
#
# The comparison is between two TREE OBJECTS, not two `git status` listings.
# Text-diffing porcelain looks equivalent and is not: ` M foo.txt` is
# byte-identical before and after fx edits a file that was already dirty, so
# that edit would vanish from the PR; and a pre-existing untracked directory
# collapses to one `?? sub/` line that masks everything fx creates inside it.
# A tree records content, so both cases come out right.
before=$(cat "$RUNNER_TEMP/fx-tree-before" 2>/dev/null || true)
if [ -z "$before" ]; then
  echo "::warning::No pre-run tree snapshot; committing every change in the workspace." >&2
  before=$(git hash-object -t tree /dev/null)
fi

GIT_INDEX_FILE="$RUNNER_TEMP/fx-index-after" git add -A -- .
after=$(GIT_INDEX_FILE="$RUNNER_TEMP/fx-index-after" git write-tree)

# NUL-delimited the whole way. A path with a space, a quote or a non-ASCII
# character comes out of porcelain C-quoted (`"caf\303\251.txt"`), and feeding
# that to a pathspec fails the match and, under `set -e`, throws away work fx
# has already done.
changed="$RUNNER_TEMP/fx-changed.z"
git diff --name-only -z "$before" "$after" > "$changed"

if [ ! -s "$changed" ]; then
  echo "The agent changed no files; nothing to open a pull request for." >&2
  echo "pr_url=" >> "$GITHUB_OUTPUT"
  exit 0
fi

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
  first=$(head -n1 "${RESPONSE_PATH:-/dev/null}" 2>/dev/null | sed -E 's/^#+[[:space:]]*//; s/[[:space:]]*$//')
  if [ -n "$first" ] && [ "${#first}" -le 72 ]; then
    title="$first"
  else
    title="fx: changes for #${ISSUE_NUMBER:-}"
  fi
fi

# A model-written title starting with "-" would be read as a flag by `gh`.
title=$(printf '%s' "$title" | sed -E 's/^[-[:space:]]+//')
[ -n "$title" ] || title="fx: changes for #${ISSUE_NUMBER:-}"

# The commit identity is the bot's, always. An App token changes who COMMENTS;
# GitHub attributes a commit by the email inside it.
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git checkout -b "$branch"
git add --pathspec-from-file="$changed" --pathspec-file-nul --

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
# GITHUB_SERVER_URL rather than a hard-coded github.com, so this works on
# GitHub Enterprise Server too.
host="${GITHUB_SERVER_URL:-https://github.com}"; host="${host#https://}"
git push -q "https://x-access-token:${GH_TOKEN}@${host}/${GITHUB_REPOSITORY}.git" "HEAD:$branch"

# `fx pr` was a second billed model request, after run-fx.sh read the ledger.
# Read it again here so the footer and max_cost see the true total; the
# runner's HOME is fresh, so the ledger holds only this job's spend.
cost=$(fx usage --json 2>/dev/null | jq -r '.totals.spend // empty' || true)
[ -n "$cost" ] && echo "cost=$cost" >> "$GITHUB_OUTPUT"

# The draft is model output and has not been through run-fx.sh's scrubber.
python3 -c "import sys; sys.path.insert(0, sys.argv[2]); import redact; redact.redact_file(sys.argv[1])" \
  "$draft" "$(dirname "$0")" 2>/dev/null || true

body_file="$RUNNER_TEMP/fx-pr-body.md"
{
  # fx's drafted body when we got one, else what the agent told the commenter.
  if [ -s "$draft" ] && [ -n "$(sed -n '/^[[:space:]]*\(\*\*\)\?Title:/,$p' "$draft" | tail -n +2)" ]; then
    sed -n '/^[[:space:]]*\(\*\*\)\?Title:/,$p' "$draft" | tail -n +2
  elif [ -n "${RESPONSE_PATH:-}" ] && [ -s "${RESPONSE_PATH:-}" ]; then
    cat "$RESPONSE_PATH"
  else
    printf 'The run ended before the agent wrote a note. These are its edits; read them closely.\n'
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
