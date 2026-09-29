#!/usr/bin/env bash
# Turn what the agent changed in the workspace into a branch and a draft pull
# request, when the agent asked for one. fx edits files; this commits them.
#
# The agent asks by writing `.agent-pr.md` at the repository root: first line
# the title, the rest the body. That file is the open-pr skill's whole
# mechanism. No file, no pull request — the agent answered, or experimented
# and decided not to ship, both normal outcomes. A file with an unchanged tree
# opens nothing either, so prose alone can never open a pull request.
#
# fx never holds a GitHub token. This step does, for the push, and it reads a
# file the agent wrote; the integrity check before this step is what makes
# reading scripts from the action directory safe.
set -euo pipefail

# Pathspecs below are repo-root relative, and so is everything git prints, so
# work from the root whatever `working_directory` was.
cd "$(git rev-parse --show-toplevel)"

signal=".agent-pr.md"

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
# The memory file goes to its own branch through memory.sh, the signal file
# is the pull request's text, not part of it, and __pycache__ is what running
# a Python repo's checks leaves behind: the first live PR carried a .pyc.
skip="(^|/)\.agent-memory/|(^|/)__pycache__/|^$signal\$"
if grep -qzE "$skip" "$changed" 2>/dev/null; then
  grep -zvE "$skip" "$changed" > "$changed.f" || true
  mv "$changed.f" "$changed"
fi

if [ ! -f "$signal" ]; then
  if [ -s "$changed" ]; then
    echo "The agent changed $(tr -cd '\0' < "$changed" | wc -c | tr -d ' ') file(s) and did not ask for a pull request (no $signal); the checkout is thrown away." >&2
  else
    echo "The agent asked for no pull request and changed no files." >&2
  fi
  echo "pr_url=" >> "$GITHUB_OUTPUT"
  exit 0
fi
if [ ! -s "$changed" ]; then
  echo "::warning::The agent wrote $signal but changed no files; nothing to open a pull request for." >&2
  echo "pr_url=" >> "$GITHUB_OUTPUT"
  exit 0
fi

# Scrub before anything is read out of it: the title becomes the commit
# message and is pushed before the body is used. Not `|| true`: a scrub that
# fails must stop the push, not let an unscrubbed title through.
python3 "$(dirname "$0")/redact.py" "$signal" "the pull request text"

# First non-empty line is the title, minus any heading marks or bold the model
# added; everything after it is the body.
title=$(grep -m1 -v '^[[:space:]]*$' "$signal" | sed -E 's/^[[:space:]]*#+[[:space:]]*//; s/^\*\*(.*)\*\*$/\1/; s/[[:space:]]*$//')
body_text=$(awk 'found { print; next } !/^[[:space:]]*$/ { found = 1 }' "$signal" | sed '/./,$!d')
if [ -z "$title" ]; then
  # The agent's first answer line, when it reads like a title rather than a paragraph.
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

branch="${BRANCH_PREFIX:-fx}/${ISSUE_NUMBER:-run}-$(date +%s)"

# No git hooks, for every git call below. A repo's hooks are for its laptops:
# one wired through `core.hooksPath` by an npm `prepare` script ran its
# pre-push `npm run ci` under the runner's Node and refused the push (seen on
# sfl-parts, 2026-09-29). The agent ran the repo's checks before it asked for
# this pull request; CI on the pull request runs them again.
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null

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

# The push target is a branch this script computed, so it is never the default
# branch — and this asserts it rather than trusting it. Branch protection is
# the real guard and a private repo on the free plan cannot have one: GitHub
# answers 403 "Upgrade to GitHub Pro" to both the branch-protection and the
# ruleset APIs. Several of this action's consumers are in that position and
# one of them deploys the default branch to production on push, so the cost of
# this being wrong once is someone's live site. Asked for by the
# syntechfibres.dev session, 2026-09-15.
default_branch="${DEFAULT_BRANCH:-}"
[ -n "$default_branch" ] || default_branch=$(gh api "repos/$GITHUB_REPOSITORY" --jq .default_branch 2>/dev/null || true)
if [ -n "$default_branch" ] && [ "$branch" = "$default_branch" ]; then
  echo "::error::Refusing to push: the branch this run built ('$branch') is the repository's default branch. This action only ever pushes to a new branch; something upstream of here is wrong." >&2
  exit 1
fi

# A job with `contents: read` cannot push, and that is the off switch for pull
# requests: say so in the comment rather than fail a step the answer already
# describes as shipped. Any other push failure is still an error.
if ! push_err=$(git push -q "https://x-access-token:${GH_TOKEN}@${host}/${GITHUB_REPOSITORY}.git" "HEAD:$branch" 2>&1); then
  if printf '%s' "$push_err" | grep -qiE '403|permission|not permitted|write access'; then
    echo "::warning::The agent asked for a pull request but the job's token cannot push a branch (give the job contents: write). Its edits are thrown away." >&2
    { echo "pr_url="; echo "pr_unpushed=true"; } >> "$GITHUB_OUTPUT"
    exit 0
  fi
  echo "::error::git push failed: $(printf '%s' "$push_err" | sed "s#x-access-token:[^@]*@#x-access-token:***@#" | head -c 300)" >&2
  exit 1
fi

body_file="$RUNNER_TEMP/fx-pr-body.md"
{
  # The agent's body when it wrote one, else what it told the commenter.
  if [ -n "$(printf '%s' "$body_text" | tr -d '[:space:]')" ]; then
    printf '%s\n' "$body_text"
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
# Against the branch the workflow ran on, so a workflow_dispatch run from a
# feature branch (how a change to this action is tried) targets that branch
# and not the default one. On a pull_request event the ref is a merge ref, and
# then gh's default, the repo's default branch, is the only sane base.
base=''
case "${GITHUB_REF_TYPE:-}:${GITHUB_REF_NAME:-}" in
  branch:*/merge|branch:|:*) ;;
  branch:*) base="$GITHUB_REF_NAME" ;;
esac
url=$(gh pr create --repo "$GITHUB_REPOSITORY" --head "$branch" --draft ${base:+--base "$base"} \
  --title "$title" --body-file "$body_file" | tail -1)

echo "pr_url=$url" >> "$GITHUB_OUTPUT"
echo "Opened $url" >&2
