#!/usr/bin/env bash
# Who asked, and may they? Two checks, before anything slow, and the run FAILS
# when either one rejects the actor. A silent skip would hide a misconfigured
# workflow; a red X on a stranger's comment is the point.
#
#   write access  On issue and pull request events, the actor must have write
#                 or admin on this repository. Anyone can comment on a public
#                 repo, and that must not be enough to spend the gateway key
#                 or direct an agent holding a token that can push.
#                 `allowed_non_write_users` names exceptions; `*` is anyone,
#                 which is only sane for a read-only run with a fixed prompt.
#                 Events no person authors (schedule) skip this check.
#
#   human actor   On every event, a bot is rejected unless it is listed in
#                 `allowed_bots` (or `*`). This is what keeps two bots from
#                 triggering each other forever. It covers scheduled runs too:
#                 GitHub attributes those to whoever last changed the cron
#                 line, and if that was a bot, list it.
#
# The same two checks anthropics/claude-code-action runs, in shell.
set -euo pipefail

actor="${ACTOR:?}"
event="${EVENT_NAME:?}"
mode="${MODE:-auto}"                  # the action's mode input
shell_tool="${SHELL_TOOL:-false}"     # the action's shell input
sender_type="${SENDER_TYPE:-}"        # github.event.sender.type, empty on schedule
err=$(mktemp)
allow_users="${ALLOWED_NON_WRITE_USERS:-}"
allow_bots="${ALLOWED_BOTS:-}"

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# `dependabot`, `dependabot[bot]` and `Dependabot` are the same allowance.
listed() {  # listed <name> <comma list>
  local name list item items
  name=$(lower "${1%\[bot\]}"); list=$(printf '%s' "$2" | tr -d ' ')
  [ -n "$list" ] || return 1
  [ "$list" = "*" ] && return 0
  IFS=',' read -ra items <<< "$list"
  for item in "${items[@]}"; do
    [ -n "$item" ] && [ "$(lower "${item%\[bot\]}")" = "$name" ] && return 0
  done
  return 1
}

# --- human actor --------------------------------------------------------------
# The payload says what kind of account acted, when there is a payload. On a
# schedule there is not, so ask the API; a 404 there is a GitHub App with no
# user behind it (Copilot's actor is plain "Copilot"), which is also a bot.
type="$sender_type"
case "$actor" in *"[bot]") type="Bot" ;; esac
if [ -z "$type" ]; then
  # gh prints the error body to STDOUT on a 4xx, so the fallback hangs off the
  # assignment, never `|| echo` inside the substitution. Only a 404 means "no
  # such user, so an App"; anything else is the API failing, and a check that
  # cannot run must fail closed and say why.
  if ! type=$(gh api "users/$actor" --jq '.type' 2>"$err"); then
    grep -q 'HTTP 404' "$err" && type="Bot" || { echo "::error::Could not look up $actor: $(head -c 300 "$err")" >&2; exit 1; }
  fi
fi

is_bot=''
[ "$type" = "User" ] || is_bot=1

if [ -n "$is_bot" ]; then
  if listed "$actor" "$allow_bots"; then
    echo "Bot $actor is in allowed_bots; continuing." >&2
  else
    echo "::error::Run triggered by a bot ($actor, type $type). Add it to allowed_bots, or '*' to allow any bot." >&2
    exit 1
  fi
fi

# --- write access -------------------------------------------------------------
# Besides pass/fail, say whether the actor has write access: memory is saved
# only from runs by people who do. A scheduled or manual run is the repo's own
# automation, so it counts as write.
passed() { echo "write_access=$1" >> "${GITHUB_OUTPUT:-/dev/null}"; exit 0; }

case "$event" in
  issues|issue_comment|pull_request|pull_request_target|pull_request_review|pull_request_review_comment) ;;
  *)
    echo "Actor $actor passed on a $event event, which has no write check." >&2
    passed true
    ;;
esac

# An allowed bot is an App installation, not a collaborator, so the permission
# endpoint has nothing to say about it. But on these events the bot's own text
# is the instruction, so it gets the same limits as an allowed stranger: read
# mode, no shell. (On a schedule nothing the bot wrote is in the prompt, which
# is why that case exited above.)
if [ -n "$is_bot" ]; then
  if [ "$mode" != "read" ] || [ "$shell_tool" = "true" ]; then
    echo "::error::Bot $actor is allowed by allowed_bots, but mode is '$mode' and shell is '$shell_tool'. On an issue or PR event a bot only combines with mode: read and no shell." >&2
    exit 1
  fi
  passed false
fi

# admin/write/read/none; maintain reads as write and triage as read. A 404 is
# "not a collaborator", which is what `none` means anyway; any other failure
# is the check not running, which is not the same as the actor lacking access.
if ! permission=$(gh api "repos/$GITHUB_REPOSITORY/collaborators/$actor/permission" --jq '.permission' 2>"$err"); then
  grep -q 'HTTP 404' "$err" && permission="none" || { echo "::error::Could not check $actor's access to $GITHUB_REPOSITORY: $(head -c 300 "$err")" >&2; exit 1; }
fi
case "$permission" in
  admin|write)
    echo "Actor $actor has $permission access." >&2
    passed true
    ;;
esac

if listed "$actor" "$allow_users"; then
  # The exception is for a fixed prompt in read mode with no shell. `auto`
  # would let this actor type `pr` and get the write tools, and a shell can
  # read the gateway key out of the environment, so neither combines with it.
  if [ "$mode" != "read" ] || [ "$shell_tool" = "true" ]; then
    echo "::error::$actor is allowed by allowed_non_write_users, but mode is '$mode' and shell is '$shell_tool'. That exception only combines with mode: read and no shell." >&2
    exit 1
  fi
  echo "::warning::$actor has $permission access and is allowed by allowed_non_write_users." >&2
  passed false
fi

echo "::error::$actor has $permission access to $GITHUB_REPOSITORY, and this run needs write. Add them to allowed_non_write_users to make an exception." >&2
exit 1
