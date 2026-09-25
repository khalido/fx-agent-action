# Changelog

What changed, newest first, in the format of
[Keep a Changelog](https://keepachangelog.com/en/2.0.0/). Versions are
[SemVer](https://semver.org): `uses: khalido/fx-agent-action@v1` is a
compatibility promise. `.claude/skills/release/SKILL.md` says what counts as a
break and how a release is cut.

## [Unreleased]

Checked against fx 0.0.11.

### Added

- `timeout_minutes`, default 10. Since 0.0.11 fx waits indefinitely for a
  model endpoint it cannot reach, so a gateway outage ran until the job's own
  limit, which cancels the job and posts nothing. Now the run fails and the
  comment says why. The memory compaction gets five minutes. `triage.yml`'s
  job limit goes from 10 to 15 minutes to stay above it.
- `provider_order`, the gateway providers to try first. The action always
  writes it, empty or not, because a checkout's `.fx.json` can set it too and
  `fx status` does not report it.

### Changed

- Answers cite code as permalinks at the commit the agent read, and the
  footer names that commit, so a line number in an old comment still points
  at the right line.
- Answers to a question have a ceiling, 250 words, and come in short
  paragraphs with the answer on the first line.

### Fixed

- A run that fails before fx does anything, a bad key or a spent gateway
  budget, is red. It used to post fx's error line as the answer on a green
  run. The log now shows fx's own error instead of "Error field: none".

## [1.1.0] - 2026-09-16

The agent decides. `/fx pr` is gone as a phrase: a run in `agent` mode, the
default, or in `answer` mode is the same agent with a shell, and in `agent`
mode it opens a draft pull request when it judges a request is one it can do
well in a single run, or leaves a note saying what it would change and what a
stronger agent should pick up. `read` mode has no shell, as before.

**The default changed under every job, on every event.** In 1.0.0 an unset
`mode` was `auto`, which resolved to read unless the comment said `pr`, and
`shell` defaulted to off, so a workflow written from `action.yml` ran notes
and plain `/fx` questions with no shell; the shipped example set
`shell: true`, so a workflow copied from it already had one on every run. Now
an unset `mode` is `agent`: a shell, edits, and a draft pull request when the
agent decides one is warranted. New for everyone is that a plain request can
end in a pull request. New for a workflow that never set `shell` is the shell
itself, which can read the runner's environment, gateway key included. The
write-access check on the actor is unchanged, so who can reach a shell is who
could already run `/fx pr`. Set `mode: read` for a run with no shell, or
`mode: answer` for the shell with no pull request.

**This release removes inputs, and moves `@v1` across that.** By the rules in
`.claude/skills/release/SKILL.md` it is a MAJOR and would be 2.0.0. It ships
as 1.1.0 on purpose: the action is a week old, its first release two days
old, and still moving daily; the README, every example and the guide pin
`@main`, seven pins in all; `@v1` is offered, in this file's header and in
the guide, and nobody has taken it up, since every repository this action
runs in rides `@main`. Nobody is holding the promise this breaks. If you did
pin `@v1`, read Removed first: passing `shell` or `pr_model`, or `mode: auto`
or `mode: write`, now fails the run on its first step and names the
replacement, before anything is billed.

### Changed

- **An unset `mode` is `agent`, on every event.** It was `auto`, which was
  read unless `pr` was typed. The paragraph above has the consequences.
- **One agent, and the pull request is its call.** Every `agent` or `answer`
  run has a shell and edits; `read` denies both. A question gets an answer;
  "fix this" or "add that" gets the change, tested, as a draft pull request
  when the agent judges it fits one run, and a note saying what it would
  change and what a stronger agent should pick up when it does not. The
  mechanics are the new `open-pr` skill: the agent writes `.agent-pr.md`,
  title then body, and the action does the branch, push and draft PR. No
  file, or an unchanged tree, and nothing opens. With `skills: false` the
  prompt states that contract itself instead of naming a skill that is not
  there. fx still never holds a GitHub token, and the `fx pr` drafting call
  is gone.
- **Each `/fx` comment gets its own reply**, keyed to the comment, rewritten
  when the comment is edited; the workflow needs
  `issue_comment: types: [created, edited]` for the edit half. An issue note
  still refreshes in place.
- **`examples/fx.yml` runs on `workflow_dispatch` too**, with an issue number
  and a prompt: a run by hand on any issue, without commenting. In this
  repository the workflow is `uses: ./`, so dispatching it from a branch is
  how a change to the action is tried before it lands; a copy that pins
  `@main` runs main's action whichever branch it is dispatched from.
- **`compare-models` works without a shell**, fetching the catalog with the
  web tool, and the dogfood run no longer copies the repo's own `skills/`
  onto itself.
- **Three modes, each one a step down**: `agent` ships, `answer` verifies and
  never opens anything, `read` only reads. Two capabilities come apart, a
  shell and a pull request, and three of the four combinations are worth
  having.
- **Two off switches for pull requests, at different levels.** `mode: answer`
  means the agent is never told to ship: it still makes the change, to find
  out whether it works, and reports what it found, but nothing is committed or
  opened. `contents: read` on the job means it cannot
  push whatever it decides: the work is discarded and the comment says so,
  instead of a red step under an answer that says "shipped". A repo that never
  wants a PR should set both.

### Removed

- Inputs `shell` and `pr_model`, and `mode` values `auto` and `write`. `mode`
  is now `agent` (default), `answer` or `read`. **If you ran `mode: read` with
  `shell: true`, use `mode: answer`**: that pair was the old scratch mode, and
  `mode: read` alone now denies the shell, so a note would keep its shape and
  quietly stop verifying anything. `read` stays the only mode that combines
  with `allowed_non_write_users` or `allowed_bots` on issue and PR events.
- **Passing any of them fails the run on its first step, with the migration in
  the error.** GitHub only warns on an input an action does not declare, and a
  warning on a green run is a line in a log nobody reads, so `shell` and
  `pr_model` are still declared purely to refuse them — including
  `shell: false`, whose migration is `mode: read` and not "drop the line".
  The declared stubs go for good in 2.0.0.
- `/fx pr` as the phrase that turned writing on. Nothing strips the word now:
  `/fx pr add X` still runs, and the agent reads the request as `pr add X`.

### Fixed

- **A comment that was never addressed to the agent is a skip, not a red X.**
  The workflow's `if:` is a substring test and the action's trigger match is a
  whole word outside quoted lines, so the two can disagree and a correct
  workflow lands in the gap — a comment merely mentioning a path like
  `.github/fx/issue.md` was enough. Every failed run this action ever had on
  its own repo, three of three, was that. It now warns, says how to tighten
  the gate, and posts nothing. The shipped examples use the tighter gate:
  `startsWith(body, '/fx') || contains(body, ' /fx')`.
- **The push refuses to target the default branch.** It never did — the branch
  name is built here — but that was an emergent property rather than an
  asserted one, and a private repo on the free plan cannot have branch
  protection to fall back on: GitHub answers 403 to both the
  branch-protection and the ruleset APIs. Several of this action's consumers
  are in that position and one deploys its default branch on push.
- **A bot listed in `allowed_bots` no longer counts as write access on a
  `schedule` or `workflow_dispatch` run**, so it cannot write the memory
  branch that every later run reads. The memory half of that check hung off an
  event switch that waves through everything which is not an issue or PR
  event. A bot is still limited to `mode: read` only where its own text is the
  instruction, since a scheduled prompt comes from the workflow.
- Every write-mode prompt build had failed since 2026-09-11 on a broken
  heredoc line, so `/fx pr` went red at "Build the prompt" with no comment
  (#14). CI now builds the comment path in all three modes.
- A `read` run is now told that the instructions below it may name commands it
  cannot run, so a note says a claim is unverified rather than keeping the
  shape of one that checked (#16).
- The secret scrub on pull request text no longer depends on the drafting
  call succeeding, and a scrub that fails stops the push (#15, first two
  gaps).
- In 1.0.0 the `fx usage` ledger reads after a memory compaction and after
  opening a pull request ran inside steps that hold the job's token, so an fx
  process had `GH_TOKEN` in its environment. A ledger read runs no tools, but the
  rule is that no fx process holds one, and now none does.

## [1.0.0] - 2026-09-14

First release. An agent on your issues: open one and [fx](https://fx.sh)
reads the code and leaves a note; comment `/fx` with a question and it
answers; `/fx pr …` gets a draft pull request. It runs in your own runner,
with no app to install and no service in the middle.

Copy [`examples/fx.yml`](examples/fx.yml), add the `AI_GATEWAY_API_KEY`
secret, and for `/fx pr` switch on Settings → Actions → General → "Allow
GitHub Actions to create and approve pull requests".

**Pinning.** The examples say `@main` on purpose while this is young — a fix
reaches you the day it lands. Pin `@v1` if you would rather have the
compatibility promise: it moves to each `v1.x` as it ships, and this file says
what changed.

### Added

- **One job, three jobs' worth of behaviour.** The action tells a new issue
  from a `/fx` comment by the event, and a question from `/fx pr` by the word
  after the trigger, so the workflow does not have to. The note and the answer
  are keyed as separate comments on the same issue.
- **One comment per job**, found by a hidden marker and edited in place, with
  a footer: fx, model, tokens, cost in cents, seconds, run link, and earlier
  runs stacked with a total when a comment is rewritten. Under a BYOK key the
  gateway bills nothing and fx's ledger records zero, so the action looks up
  each generation on the gateway, sums the provider's real charge, and names
  the provider that served the run; a list-price estimate, marked `≈`, is the
  fallback.
- **`/fx` as the trigger**, a whole word anywhere in a comment, quoted lines
  skipped; `trigger` takes several phrases. `/fx pr …` is the only phrase that
  turns writing on, and it ends in a draft pull request carrying what fx
  changed, measured as a tree diff — minus its memory file and anything under
  `.github/workflows/`, which the workflow's token cannot push.
- **Two checks before anything runs**, and a no fails the run rather than
  skipping it: write access on issue and PR events, a human actor on every
  event. `allowed_non_write_users` and `allowed_bots` are the exceptions; on
  issue and PR events both are read mode only.
- **A built-in note prompt**, [`prompts/issue.md`](prompts/issue.md), used on
  issue events when the workflow gives no prompt of its own. It leaves a head
  start rather than a filled-in form: where this lives and what the code does
  there today, what is already here that you were about to rebuild, the
  question to settle before anyone starts — or the answer itself, when the
  issue turns out to be a question. `.github/fx/issue.md` in a repo replaces
  it whole. Facts about your repo go in `AGENTS.md`, which fx already holds in
  context and which the base block says may add to or adjust the task.
- **Three modes.** Read: the edit and shell tools are hidden by rule, so the
  model never spends a step discovering it cannot write. Scratch
  (`shell: true`): read plus a shell and edits that are thrown away, so the
  agent can run the tests or try a fix before it answers. Write (`pr`): the
  full tool set in the runner, and the workflow makes the branch, the commit
  and the draft PR.
- **Memory, on by default.** One `MEMORY.md` on an `agent-memory` branch,
  fetched before the run, edited by the agent with its ordinary file tools,
  pushed back after, three-way merged on a concurrent write, and compacted by
  one extra model call when it grows past `memory_lines`. Saved only from runs
  whose actor has write access: a run allowed through `allowed_non_write_users`,
  or a bot on an issue or PR event, reads it and cannot change it. A scheduled
  or manually dispatched run counts as the repo's own automation and can save.
  `memory_repo` gives an org one shared memory; delete the branch to forget.
- **Skills.** The action ships `skills/compare-models` and copies it, with a
  repo's `.github/fx/skills/`, into fx's skill directory on the runner — so a
  skill exists for this agent in this run and for nothing else.
- **The session as one HTML file** on the run, kept a week, including web
  searches with the exact date window and domain filter that were sent.
- **Inputs**: `prompt`, `prompt_file`, `model`, `pr_model`, `mode`, `shell`,
  `memory`, `memory_branch`, `memory_repo`, `memory_lines`, `skills`,
  `trigger`, `allowed_non_write_users`, `allowed_bots`, `branch_prefix`,
  `max_steps`, `effort`, `post`, `comment_key`, `issue_number`,
  `include_thread`, `include_diff`, `max_cost`, `github_token`,
  `session_artifact`, `working_directory`. Default model is
  `deepseek/deepseek-v4.1-flash`; `pr_model` puts write runs on a stronger one.
- **Outputs**: `response`, `cost`, `steps`, `comment_url`, `pr_url`,
  `session_id`.
- **No fx process holds a GitHub token.** The run that reads your issue has
  none; the two later fx calls — drafting the pull request text, and
  compacting the memory file — sit in steps that do hold one, and the token
  is stripped from their environment. Before any run that can write to disk,
  the action also fingerprints its own `action.yml` and `scripts/` per file,
  and a mismatch afterwards stops the pull request, memory and comment steps
  and names the file.
- **Untrusted text is fenced and stripped.** Hidden markup — HTML comments,
  zero-width characters, image alt text, hidden attributes — comes out of the
  thread, the diff and `issues.json` titles before the model sees them, and
  the action's instructions always sit above that block. Secrets are scrubbed
  from the answer, from fx's drafted pull request text before its title becomes
  a commit message, and from the session artifact. What the agent writes into a
  file is not scanned; the gateway key is budgeted for that reason.
- **A run that is misconfigured fails before it spends anything.** Settings fx
  cannot parse are dropped whole and silently by fx, so the mode, model, step
  limit and permission rules are read back and asserted before the model is
  called.
- **👀** on the trigger comment or issue while the run is going, taken off at
  the end.
- **Docs**: [`examples/fx.yml`](examples/fx.yml), the one file to copy, run by
  this repo on itself; five more examples;
  [`docs/guide.md`](docs/guide.md) for the rest; and
  [`docs/prior-art.md`](docs/prior-art.md) and
  [`docs/agent-memory.md`](docs/agent-memory.md) as the surveys behind the
  choices.

[Unreleased]: https://github.com/khalido/fx-agent-action/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/khalido/fx-agent-action/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/khalido/fx-agent-action/releases/tag/v1.0.0
