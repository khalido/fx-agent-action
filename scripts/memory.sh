#!/usr/bin/env bash
# The agent's memory across runs: one MEMORY.md on an orphan branch, copied
# into the workspace before the run and pushed back after it if it changed.
#
#   memory.sh fetch   branch → .agent-memory/MEMORY.md, remembering the blob sha
#   memory.sh save    if the file changed: compact when over the cap, then PUT
#                     it back with that sha; on 409 merge with what landed
#                     meanwhile and retry once. Never fails the run.
#
# The agent edits the file with its ordinary tools and knows nothing of this.
# The contents API does the writing, so there is no second checkout and no git
# credential on the runner; a stale sha comes back as 409, which is a real
# compare-and-swap. Everything about the branch is deletable with
# `git push origin --delete agent-memory`.
set -euo pipefail

verb="${1:?usage: memory.sh fetch|save}"
repo="${MEMORY_REPO:-$GITHUB_REPOSITORY}"
branch="${MEMORY_BRANCH:-agent-memory}"
cap="${MEMORY_LINES:-80}"
dir=".agent-memory"
file="$dir/MEMORY.md"
state="$RUNNER_TEMP/fx-memory"
api="repos/$repo/contents/MEMORY.md"
mkdir -p "$state"

out() { echo "$1" >> "${GITHUB_OUTPUT:-/dev/null}"; }

# gh api prints a 4xx body to stdout and exits 1; the body carries "status".
api_get() {
  local resp
  if resp=$(gh api "$api?ref=$branch" 2>/dev/null); then
    printf '%s' "$resp"; return 0
  fi
  printf '%s' "$resp"; return 1
}

status_of() { printf '%s' "$1" | jq -r '.status // empty' 2>/dev/null; }

starter() {
  cat <<EOF
# Agent memory

What earlier agent runs learned about this repository: how it is laid out,
what recurs, what its people prefer, decisions and why, traps. Dated, edited
in place, under $cap lines. A model of the repo, not a diary of runs.
EOF
}

case "$verb" in
fetch)
  mkdir -p "$dir"
  if resp=$(api_get); then
    printf '%s' "$resp" | jq -r '.content' | base64 -d > "$file"
    printf '%s' "$resp" | jq -r '.sha' > "$state/sha"
    echo "memory: $(wc -l < "$file" | tr -d ' ') lines from $repo@$branch" >&2
    out "memory=fetched"
  elif [ "$(status_of "$resp")" = "404" ]; then
    starter > "$file"
    : > "$state/sha"
    echo "memory: no $branch branch in $repo yet; starting fresh" >&2
    out "memory=new"
  else
    # Leave any existing file alone: the agent may run this script itself in
    # a scratch run, and an API hiccup must not delete its memory copy.
    echo "::warning::memory: could not read $repo@$branch: $(printf '%s' "$resp" | jq -r '.message // .' 2>/dev/null | head -c 200). Running without memory." >&2
    [ -f "$file" ] || rmdir "$dir" 2>/dev/null || true
    out "memory=unavailable"
    exit 0
  fi
  cp "$file" "$state/before.md"
  out "memory_path=$file"
  ;;

save)
  [ -f "$file" ] && [ -f "$state/before.md" ] || { out "memory=unchanged"; exit 0; }
  if cmp -s "$file" "$state/before.md"; then
    echo "memory: unchanged" >&2
    out "memory=unchanged"
    exit 0
  fi
  status=updated

  # Over the cap: one cheap model call rewrites the file. No tools, no session
  # saved. If the answer is empty or still too long, keep the agent's version
  # and say so; the next run tries again.
  lines=$(wc -l < "$file" | tr -d ' ')
  if [ "$lines" -gt "$cap" ] && command -v fx >/dev/null; then
    prompt="$state/compact-prompt.md"
    {
      printf 'Rewrite the memory file below so it stays useful and fits in %s lines.\n' "$cap"
      printf 'Keep the first heading and its short description. Merge duplicates. Drop\n'
      printf 'lines that were true for one run only, or that later lines contradict.\n'
      printf 'Keep the dated lines from the most recent runs. Newest first. Plain\n'
      printf 'Markdown, one fact per line, paths and issue numbers kept exactly.\n'
      printf 'Output only the new file contents. No preamble, no fences.\n\n'
      cat "$file"
    } > "$prompt"
    if compacted=$(fx ask --json --no-save --quiet -- "$(cat "$prompt")" 2>/dev/null | jq -r '.final_output // empty') \
       && [ -n "$compacted" ] && [ "$(printf '%s\n' "$compacted" | wc -l | tr -d ' ')" -le "$((cap + 5))" ]; then
      printf '%s\n' "$compacted" > "$file"
      status=compacted
      echo "memory: compacted $lines → $(wc -l < "$file" | tr -d ' ') lines" >&2
    else
      echo "::warning::memory: compaction did not produce a usable file; keeping the agent's version at $lines lines." >&2
    fi
    # The compaction was a billed request; the footer should carry it.
    spend=$(fx usage --json 2>/dev/null | jq -r '.totals.spend // empty')
    [ -n "$spend" ] && out "cost=$spend"
  fi

  sha=$(cat "$state/sha" 2>/dev/null || true)
  content=$(base64 < "$file" | tr -d '\n')
  msg="agent memory: run $GITHUB_RUN_ID${GITHUB_EVENT_NAME:+ ($GITHUB_EVENT_NAME)}"

  if [ -z "$sha" ]; then
    # No branch yet. The contents API cannot create one, so build an orphan
    # commit through the git data API: blob → tree → commit with no parents →
    # ref. Four calls, once per repository, ever.
    if ! gh api "repos/$repo/branches/$branch" >/dev/null 2>&1; then
      blob=$(gh api -X POST "repos/$repo/git/blobs" -f content="$content" -f encoding=base64 --jq .sha) \
        && tree=$(gh api -X POST "repos/$repo/git/trees" \
             --input <(jq -nc --arg b "$blob" '{tree:[{path:"MEMORY.md",mode:"100644",type:"blob",sha:$b}]}') --jq .sha) \
        && commit=$(gh api -X POST "repos/$repo/git/commits" -f message="$msg" -f tree="$tree" --jq .sha) \
        && gh api -X POST "repos/$repo/git/refs" -f ref="refs/heads/$branch" -f sha="$commit" >/dev/null \
        && { echo "memory: created $repo@$branch" >&2; out "memory=$status"; exit 0; }
      echo "::notice::memory: the agent edited its memory but the job cannot push to $repo. Give the job \`contents: write\`, or set \`memory: false\` to stop trying." >&2
      out "memory=unsaved"
      exit 0
    fi
    # Branch exists but the file did not; a plain create.
  fi

  put() {
    gh api -X PUT "$api" -f message="$msg" -f branch="$branch" -f content="$content" \
      ${sha:+-f sha="$sha"} 2>/dev/null
  }
  if put >/dev/null; then
    echo "memory: saved to $repo@$branch ($status)" >&2
    out "memory=$status"
    exit 0
  fi

  # 409: another run wrote first. Three-way merge: ours, the copy we started
  # from, theirs. Clean merge → retry once. Conflict → warn, keep theirs.
  if resp=$(api_get); then
    theirs="$state/theirs.md"
    printf '%s' "$resp" | jq -r '.content' | base64 -d > "$theirs"
    sha=$(printf '%s' "$resp" | jq -r '.sha')
    if merged=$(git merge-file -p "$file" "$state/before.md" "$theirs" 2>/dev/null); then
      printf '%s\n' "$merged" > "$file"
      content=$(base64 < "$file" | tr -d '\n')
      if put >/dev/null; then
        echo "memory: merged with a concurrent run and saved" >&2
        out "memory=$status"
        exit 0
      fi
    fi
  fi
  echo "::warning::memory: another run changed MEMORY.md at the same time and the merge did not apply cleanly. This run's memory is lost; the branch is untouched." >&2
  out "memory=unsaved"
  ;;

*)
  echo "usage: memory.sh fetch|save" >&2
  exit 2
  ;;
esac
