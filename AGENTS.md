# fx-agent-action — agent guide

A GitHub Action that runs [fx](https://fx.sh) on an issue or PR and posts one
comment. Read `README.md` for what it does; this file is how to work on it.

**fx is new and changes weekly. When working on this action, read fx's docs,
not your memory of them:** <https://fx.sh/llms.txt> is the index,
<https://fx.sh/llms-full.txt> is every page in one file (about 200 KB;
`curl -fsSL https://fx.sh/llms-full.txt > /tmp/fx.md` and grep it). Where the
docs and the installed binary disagree, `fx <command> --help` wins. The pages
this action leans on: `fx ask` (the JSON shape), Permissions (rules and
modes), Configuration (`~/.fx/settings.json` keys and the `FX_*` variables),
Usage and costs (`fx usage --json`), CLI (`fx pr`, `fx session`).

## Shape, and why

**A composite action, not a JavaScript one.** Every step is shell you can read
in the browser. There is no bundled `dist/` anyone has to trust, no build step
before a change ships, and `gh`, `jq` and `python3` are already on every runner.

| File | Does |
|---|---|
| `action.yml` | inputs, outputs, and the step sequence |
| `scripts/check-actor.sh` | write access and human-actor checks, first, and the run fails if either says no |
| `scripts/react.sh` | 👀 on the trigger comment, taken off at the end |
| `scripts/build-prompt.sh` | runtime block, instruction, then the thread — and it decides read vs write |
| `prompts/issue.md` | the built-in note prompt, used on `issues` events when the repo gives no other instruction |
| `skills/*/SKILL.md` | skills copied into `~/.fx/skills/` on the runner for every consuming repo; one folder per procedure |
| `scripts/session-html.py` | `fx session --json` → one readable HTML file |
| `scripts/sanitize.py` | strips hidden markup out of the untrusted block |
| `scripts/run-fx.sh` | one `fx ask --json`, pull out the answer, scrub secrets, record the spend |
| `scripts/redact.py` | the secret scrubber, shared by the answer and the session |
| `scripts/post-comment.sh` | upsert one comment, found by a hidden marker |
| `scripts/open-pr.sh` | branch, commit, push, open the draft PR |
| `scripts/cost.sh` | the run's dollars from fx's ledger, or a list-price estimate from tokens when the ledger says zero (BYOK); used after `fx ask`, `fx pr` and a memory compaction |
| `scripts/memory.sh` | `fetch` the memory file from its branch before the run, `save` it after, compacting when over the cap |

If a change wants another file, ask whether it belongs in the prompt instead.

## The decisions, and why each one

**The actor is checked inside the action, not only in the workflow's `if:`.**
Two checks, the same two `claude-code-action` runs: write access on issue and
PR events (`collaborators/{user}/permission`, which the default token can call
because it is under Metadata), and not-a-bot on every event. Exceptions are
explicit inputs, `allowed_non_write_users` and `allowed_bots`, and a rejection
fails the run rather than skipping it: a silent skip hides a misconfigured
workflow. `author_association` in the workflow `if:` stays as a cheap filter
that saves booting a runner, but `MEMBER` means org member, not write, so it
is not the check. `gh api` prints a 4xx body to *stdout*, so the fallback goes
in an `||` on the assignment, never `|| echo` inside the substitution.

**The trigger is a phrase matched anywhere in the comment, not a prefix.**
Whole word, any case, `(^|\s)(?:/fx|…)(?=[\s.,!?;:]|$)`, the same regex shape
`claude-code-action` uses for `@claude`; `trigger` may be a comma-separated
list and the earliest match wins. The request is what follows the phrase; text
before it is still in the thread block. Quoted lines are skipped, so a
maintainer quoting a stranger's `pr` request to refuse it does not run it. A
comment that lacks the phrase is an error, not a quiet skip, because a
composite action has no early exit and every example gates the job with
`if: contains(...)` anyway.

**The default is `/fx`, a slash phrase, not a mention.** `github.com/fx` is a
real person with 46 followers, and a mention in a public repo pages them. The
two actions in the same position, pi and opencode, chose `/pi` and `/oc` for
what is presumably the same reason; the two that use `@` own the handle.
`@fx-agent` was unclaimed when this was written and works as a `trigger` value
for anyone who prefers a mention.

**Two permission modes, and they are different mechanisms.** Read mode is
`auto` plus deny rules on `edit` and `shell` in `~/.fx/settings.json`; the rules
hide those tools, so the model never spends a step finding out and the run exits
0. Write mode is `full-access`, because the runner is a throwaway container and
**the real boundary is the workflow's `permissions:` block, not fx's review
layer** — which would only add latency and a billed model request per unresolved
call. Verified headless: no acknowledgement prompt. Never full-access in read
mode; it disables the checks the deny rules ride on, and a question has no
business running commands.

Two things fx does here that look like bugs and are not. Full access is stored
and reported as `yolo`: write `full-access`, and `fx status --json`,
`fx doctor --json` and `fx permissions --json` all say `yolo`, on purpose and
permanently. And rule keys are not validated: `{"edti":{"*":"deny"}}` is
accepted, stored and echoed back with no warning, so a renamed key would turn
read mode into write mode with nothing failing. That is why the Configure step
reads the mode, model, step limit and rules back and fails the run when they
are not what it wrote. A settings file fx cannot parse is dropped whole and
silently too, and the same read-back catches that.

**`shell: true` is scratch mode: read mode plus the shell and the edit tools,
both allowed by rule.** Allow rules rather than leaving it to `auto`, because
auto's review is a billed helper call per unresolved action. Edits are on
because a shell can write files anyway, and an agent that can try a fix and
run the tests gives a better answer than one that can only guess; nothing in
read mode is committed or opened, so the checkout is scratch paper and the
base block says so. What the shell does change is exposure: it can read the
gateway key out of the environment, so `check-actor.sh` refuses it together
with `allowed_non_write_users`, and `examples/fx.yml` restricts the note to
issues from people with write access instead. And because the agent can now
write to the runner's disk, the action-files fingerprint runs in this mode
too, not only in write mode.

**Rules go in the global settings file, not a workspace profile.** The checkout
path changes between runs, so a workspace-scoped rule silently would not apply.

**The model is set in the config file, not `FX_MODEL`.** One owner for the
value. `models` is keyed by provider; the gateway's is `models.gateway`.

**No version pin for fx.** It ships weekly and pinning an agent ages badly. The
release tag is resolved only to key the cache — through `gh api` with the job's
token, because anonymous `api.github.com` is 60 requests an hour per IP shared
with every other job on the runner — and a failed resolve falls back to a
*dated* key: `actions/cache` never overwrites an existing key, so a fixed
fallback would pin a stale binary forever. `FX_AUTO_UPGRADE=0` is set for the
job so the restored binary does not replace itself mid-run.

**Web search is provider-native, and restrictions travel as parameters.** On
the gateway the model calls `exa_search` and Exa runs it server-side; fx
records the call with `query`, `include_domains`, `start_published_date`,
`end_published_date` and the raw result on the call itself, with no
`tool_results` entry and no step counted in `fx ask --json`. Measured: "last
six months, news.ycombinator.com" in the prompt became a dated window and a
domain filter on the call. It works in read mode with no allow rule, so the
config does not name it. `session-html.py` renders these calls from
`provider_result`, since a note that cites a thread should show the search
that found it.

**The checkout is fx's workspace, and it contributes more than `AGENTS.md`.**
fx loads `~/.fx/AGENTS.md` and the primary workspace's files; on a runner HOME
is fresh and the workspace is the checkout, and this action's own checkout sits
under `_actions/`, outside it. Our runtime block in `build-prompt.sh` is the
per-mode instruction layer instead. Two more things come out of the checkout.
Skills: fx discovers `skills/`, `.claude/skills/`, `.agents/skills/`,
`.opencode/skills/`, `.codex/skills/` and `.claw/skills/` from the workspace
upward, and every skill's description sits in the request's catalog; the
instructions load only when one is invoked. On a PR event that is the PR's
skills, the same trust boundary as the PR's `AGENTS.md`, and the dogfood run
sees this repo's `release` skill. And `.fx.json`: fx honours `max_agent_steps`,
`max_tool_result_bytes` and `context` from it and refuses `model` and
`permission_mode` with `ignored_project_user_only_setting` on stderr. The
global profile beats `.fx.json`, so the Configure step writes all three,
which is why `max_steps` is an input and not something a repo can raise.
`working_directory` narrows the workspace but not the instructions: fx also
loads `AGENTS.md` from launch-ancestor directories, so the repo root's file
still applies.

**The note prompt lives in the action, not in the workflow, and one job does
everything.** The note was forty lines of YAML prose in `examples/fx.yml`,
frozen in every repo the day it was copied, and the example had two jobs whose
only real differences were the trigger and the prompt. Now `build-prompt.sh`
loads `prompts/issue.md` on an `issues` event, or the repo's
`.github/fx/issue.md` if it exists, and fetches the `issues.json` it cites;
`post-comment.sh` keys the comment `note` on issue events so notes and
answers stay separate comments. The cascade is: `prompt_file` if it exists,
inline `prompt`, `.github/fx/issue.md` on issue events, built-in note on
issue events, else the triggering comment. The repo file is checked by
event and not through `prompt_file`, because a `prompt_file` on a job that
also handles comments would swallow the comments. A repo file is
a whole-task replacement, not an addition, on purpose: an additive block in
front of a built-in task gives the model two output shapes to reconcile, and
a file of pure repo facts is what `AGENTS.md` already is. Gemini's second
opinion talked this repo out of a `.github/fx/about.md`; the reasoning held.

**Skills ship in the action and are copied, not discovered.** fx finds skills
from the workspace upward and in `~/.fx/skills/`; the action's checkout under
`_actions/` is neither, so `action.yml` copies `skills/` there before the run,
and a consuming repo's `.github/fx/skills/` with it. That path is the one
place a skill exists for this agent and no other; a root-level `.claude/skills/`
is shared with the laptop agents and needs no copy. A skill is for a
procedure that is rare and should be done the same way each time; two lines
in the base block would ride on every run instead. The first is
`compare-models`, because every consumer uses the gateway by construction.
Add a second when a second procedure repeats, not before. Frontmatter is
`name` and `description`, checked in `check.yml`.

**Memory is a file the agent edits, on a branch the action owns.** One
`MEMORY.md` on an orphan `agent-memory` branch, fetched into
`.agent-memory/` before the run through the contents API, quoted in the
prompt, pushed back after the run if changed, with the blob sha so a
concurrent run gets a 409 and a three-way merge rather than a lost write.
No MCP tool, because a tool the model may choose to call means some runs
write nothing; the agent uses its file tools and the action does the rest.
Only runs whose actor has write access save it: `check-actor.sh` outputs
`write_access`, the save step is gated on it, and the base block tells a
non-writer's run the memory is read-only. Deterministic, so a stranger
allowed through `allowed_non_write_users` cannot shape what future runs read.
The branch is created through the git data API on first save, since the
contents API cannot make one. Compaction is the action's decision, one
`fx ask` when the file is over `memory_lines`, so nobody wires a second
workflow. The prompt follows KO's own six-day memory-contract experiment in
`~/code/thinker`: a loose "add dated lines" contract produced diary-like
churn, an edit-in-place, delete-stale, earn-its-place contract produced
durable entries. `open-pr.sh` filters `.agent-memory/` out of the PR
pathspec. The survey behind the choice of store is `docs/agent-memory.md`.

**Under BYOK the ledger says zero, so `cost.sh` asks the gateway.** KO added
a DeepSeek key to the gateway (2026-09-11); the gateway then answers with
`cost: 0, is_byok: true` and fx's ledger records no spend. But
`~/.fx/usage.jsonl` keeps every generation id, and
`GET /v1/generation?id=<id>` on the gateway returns that generation's
`upstream_inference_cost`, `provider_name`, `latency` and token counts. So
the helper sums the real charges and the footer says which provider served
the run, which is the number to watch given how much the nine DeepSeek
providers differ. The list-price estimate from tokens, marked `≈`, is the
fallback when the lookups fail. The gateway budget no longer caps a BYOK
model; the provider's account does.

**Cost and tokens come from `fx usage --json`, not from `fx ask`.** `ask`
reports tokens and no price, and only the main agent's tokens: subagents, the
helper models (`auto` review, the vision fallback) and Exa are excluded. `fx
usage` keeps a local ledger with everything in it, dollars included, and the
runner's HOME is new every job, so the only spend in it is this run's.
`fx pr` is a second billed model request with its own saved session, and it
can run commands; `open-pr.sh` reads the ledger again after it so the footer
and the `cost` output cover both.

**Secrets are scrubbed from anything published.** fx never prints the key, but
in write mode its shell tool is a child process and inherits the environment —
measured, an agent-run `test -n "$AI_GATEWAY_API_KEY"` reports PRESENT. GitHub
masks secrets in logs, not in API bodies or artifacts. Hence `redact.py`, on
both the answer and the session HTML. It is a backstop, not the control: the
control is a gateway key with its own budget, so a leak costs the budget and one
rotation.

**Hidden markup is stripped from the untrusted block only.** HTML comments,
zero-width characters, image alt text, hidden attributes. The list came from
`anthropics/claude-code-action`, `docs/security.md`.

**Post `final_output`, not `output`.** The finished answer, not the running
commentary. This is what makes the action model-agnostic.

**One comment, updated.** A marker on the first line, invisible when rendered.
GitHub keeps the edit history, so overwriting loses nothing. The comment step
runs under `!cancelled()`: a red X with no comment is the worst outcome for
someone who typed a command and walked away, while a cancelled run, superseded
by a newer comment, should post nothing.

**Pull requests are drafts, and only carry what fx touched.** The draft state
is the human-oversight step — the same reason `claude-code-action` stops at a
branch and makes a person click the button.

**fx never holds a GitHub token, and the action checks its own files after
the run.** The `Run fx` step has no `GH_TOKEN`, the examples check out with
`persist-credentials: false`, and only `open-pr.sh` pushes, to a branch, with
the token in the URL. That leaves one route to the default branch in write
mode: fx, with a full shell, editing `open-pr.sh` under `_actions/` before it
runs. So before any run that can write to disk, `Fingerprint the action`
hashes the action's `action.yml` and `scripts/` per file into a step output,
which lives in the runner's memory, and an inline step after fx recomputes it
and fails the run on a mismatch, naming the file; the PR, memory and comment
steps are gated on it. Inline because a script would be read from the
directory being checked. `__pycache__` is skipped because the first live run
tripped on the agent running this repo's own `py_compile` check. With
`uses: ./` the action path is the checkout, so a scratch-mode note here that
edits `scripts/` gets a warning and continues; write mode stays strict on
every repo. Branch protection is still the real answer; this is for the
free-plan private repo that cannot have it. It does not defend against an
agent with `sudo` replacing `sha256sum`, and nothing on the runner could.

"What fx touched" is the difference between two **tree objects**, written to a
scratch index before and after the run. Diffing `git status` text instead looks
equivalent and is not, in two ways that both lose work silently: ` M foo.txt`
is byte-identical before and after fx edits a file that was already dirty, and
a pre-existing untracked directory collapses to one `?? sub/` line that masks
every file fx creates inside it. Everything downstream is NUL-delimited
(`git diff -z` → `--pathspec-from-file=- --pathspec-file-nul`) because a path
with a space or an accent comes out of git C-quoted, and feeding that back as a
pathspec fails the match and, under `set -e`, throws away work fx has done.

**`pr` is the only verb that turns writing on.** It was five — `do`, `build`,
`implement`, `fix` — and every one of those can start a question. "/fx do we
already have a retry helper?" parsed as a write request and handed a
full-access shell to a question. A word that can be the first word of a
question cannot also be the switch.

**`github_token` is an input defaulting to `github.token`.** Bring your own App
token for a named bot, and for CI to run on what it pushes. No hosted service,
ever — that is the line between this and the opencode model.

## fx facts checked against 0.0.8

Verified against the binary, so nobody re-checks them from memory. Recheck
when fx's version in a footer moves.

- **`fx ask --system` replaces fx's built-in base prompt**, it does not
  prepend. Moving the runtime block into `--system` would delete fx's own
  instructions. Prepending, as `build-prompt.sh` does, is right.
- **A checkout's `.mcp.json` is inert.** Project MCP servers start pending and
  stay disconnected until trusted from the profile, which is fresh every job.
  fx starts no process and reads no environment value for them. Do not "fix"
  this with `fx mcp trust approve-all`.
- **`fx background` does not exist**, though the CLI docs page lists it.
  `fx resume` and `fx replay` exist but are missing from `fx --help`. This is
  the concrete case behind "the binary's `--help` wins".
- **`fx pr --create` is not a substitute for `open-pr.sh`.** It publishes
  through `gh` with no branch, no `--draft`, no body file. Drafting the text
  with `fx pr` and creating with `gh pr create --draft` is the split.
- **Session JSON is `execution.schema_version` 3**, and `session-html.py`
  depends on that shape: `history[].user.text`, `history[].assistant`,
  `execution.tool_steps[].{assistant,tool_calls,tool_results}`,
  `tool_calls[].{id,name,arguments_json,provider_result}`,
  `tool_results[].{tool_call_id,tool_name,status,output,preview,truncated,
  output_bytes,stored_output_bytes,provider_native,permission_feedback}`.
  When the version moves, that file is what breaks.
- **`fx doctor --json` runs no model call** and names `.fx.json` in its
  `config` check when the checkout supplies one; the Configure step logs it.
- **Subagents inherit the parent's restrictions**, so there is nothing to deny
  for safety; they cost tokens the footer's `ask`-side counts miss, which is
  the other reason tokens come from `fx usage`.
- **fx exposes no gateway provider routing, tested.** The gateway picks among
  nine providers for a DeepSeek model, at different speeds, and honours
  `providerOptions.gateway.{order,only,sort}` per request: a direct call with
  `only: ["no-such-provider"]` errors and lists the nine. The same setting
  under `provider_options`, `providerOptions` or `gateway` in
  `~/.fx/settings.json` is ignored silently, the request succeeds, and fx
  warns about none of the unknown keys (2026-09-11, fx 0.0.8). BYOK for a
  provider makes the gateway use that provider first; that is the only pin
  available today. A feature request is drafted in the session scratchpad.
- **No provider on the gateway's side frees a runner from the gateway key.**
  Codex and Grok need a browser sign-in saved per machine; `VERCEL_OIDC_TOKEN`
  is issued by a Vercel runtime, not a GitHub one.

## Do we need actions/toolkit?

Not yet. Everything we use it for has a shell equivalent already on the runner:
`$GITHUB_OUTPUT` for `core.setOutput`, `::error::`/`::warning::` for
`setFailed`/`warning`, `gh api` for Octokit, `actions/cache` as a step.

The moment to switch is real API work shell makes awkward: review comments
anchored to diff lines, pagination with retries, partial failure across several
calls. That is the line `shaftoe/pi-coding-agent-action` crossed, and it now
ships a `dist/index.js` measured in hundreds of kilobytes. If it does become a
JS action, do it wholesale — a composite that shells out to `node` is the worst
of both.

## Docs and prior art

`docs/guide.md` is the long-form user doc, the README's other 20%; keep it
true when a behaviour changes. `docs/agent-memory.md` is the survey behind the
memory feature, hosted stores against GitHub-native, with prices dated.
`docs/prior-art.md` is the distilled survey of a dozen coding-agent actions:
trigger, actor checks, auth, output, safety, and the recipes they document,
plus where this action deliberately differs. `refs/` holds clones of the three
that matter most, gitignored; `refs/README.md` says how to refresh them. Read
these before adding a feature, because most of what is here came out of them:

- **[shaftoe/pi-coding-agent-action](https://github.com/shaftoe/pi-coding-agent-action)**,
  the closest relative: `packages/pi-platform-github/` for reactions, the
  two-marker comment upsert, and the seven GitHub tools it hands the agent.
  Its README's project-trust caution is the best short note on why a PR's
  checkout is a PR's instructions.
- **[anthropics/claude-code-action](https://github.com/anthropics/claude-code-action)**:
  `docs/security.md` and `src/github/validation/` for the actor checks and the
  hidden-markup list; `docs/solutions.md` for workflow recipes.
- **[anomalyco/opencode](https://github.com/anomalyco/opencode)**:
  `packages/opencode/src/cli/cmd/github.handler.ts` for the tag-keyed binary
  cache and the App-plus-token-service model this action chose not to copy.

## Testing a change

There is no unit test worth writing for 300 lines of glue. Test it the way it
runs. The repo dogfoods itself: `.github/workflows/fx.yml` is `examples/fx.yml`
with `uses: ./`, so `/fx` on an issue here runs the checked-out action, and
`check.yml` fails if the two files drift. One caveat of `uses: ./` in write
mode: the action's scripts are the checkout, and the integrity check refuses
to open a PR when `action.yml` or `scripts/` changed during the run. A
`/fx pr` here that touches those fails on purpose; changes to the action's
own code come from a person or a stronger agent, not from fx on itself.

Locally:

```bash
export RUNNER_TEMP=$(mktemp -d)
export GITHUB_OUTPUT=$RUNNER_TEMP/out GITHUB_REPOSITORY=owner/repo GH_TOKEN=$(gh auth token)
export INPUT_PROMPT="Summarise this issue in one line." INPUT_ISSUE_NUMBER=1
bash scripts/build-prompt.sh && cat "$RUNNER_TEMP/fx-prompt.md"
```

For the built-in note, `GITHUB_EVENT_NAME=issues` with `INPUT_PROMPT` unset;
`check.yml` runs that cascade with a fake payload on every push.

`scripts/check-actor.sh` takes `ACTOR`, `EVENT_NAME`, `SENDER_TYPE`,
`ALLOWED_NON_WRITE_USERS`, `ALLOWED_BOTS` and a real `GITHUB_REPOSITORY`;
`octocat` on an `issue_comment` event should fail, `dependabot[bot]` should
fail until listed, and a `schedule` event should skip the write check.

`python3 -c 'from scripts.sanitize import sanitize'` for the sanitizer, with the
cases listed in its docstring. `scripts/memory.sh fetch` and `save` run against
the real `agent-memory` branch of `GITHUB_REPOSITORY`, so test them in a scratch
git directory and expect a commit on the branch. Then end to end: push a
branch, point a workflow at `uses: khalido/fx-agent-action@<branch>`, comment
on a throwaway issue.

Run `shellcheck scripts/*.sh` and `actionlint` before pushing. An fx audit of
the action itself is worth its ten cents after a large change: run `fx ask` in
this checkout with scratch-mode rules and a brief that asks for defects ranked
by severity, then check every finding against the code before fixing it. The
first one found six real defects in an afternoon's work.

## References

- [Creating a composite action](https://docs.github.com/en/actions/tutorials/create-actions/create-a-composite-action)
- [Metadata syntax](https://docs.github.com/en/actions/reference/metadata-syntax-for-github-actions) — the `action.yml` schema
- [Workflow commands](https://docs.github.com/en/actions/reference/workflow-commands-for-github-actions) — `::error::`, `$GITHUB_OUTPUT`, step summaries
- [Security hardening](https://docs.github.com/en/actions/security-for-github-actions/security-guidelines/security-hardening-for-github-actions) — untrusted input, `pull_request_target`, token scopes
- [claude-code-action security](https://github.com/anthropics/claude-code-action/blob/main/docs/security.md) and [solutions](https://github.com/anthropics/claude-code-action/blob/main/docs/solutions.md)
- [fx docs for agents](https://fx.sh/llms.txt), and the human pages: [`fx ask`](https://fx.sh/docs/using-fx/fx-ask), [permissions](https://fx.sh/docs/configure-fx/permissions), [configuration](https://fx.sh/docs/configure-fx/configuration), [sessions](https://fx.sh/docs/using-fx/sessions), [usage and costs](https://fx.sh/docs/using-fx/usage-and-costs)
- [claude-code-action on GitHub Actions](https://code.claude.com/docs/en/github-actions) — the "who can trigger runs" rules this action copies
- [Keep a Changelog 2.0.0](https://keepachangelog.com/en/2.0.0/) — the changelog format
- [AI Gateway budgets](https://vercel.com/docs/ai-gateway/observability-and-spend/budgets) — the per-key spend cap

## Releasing

`/release` — `.claude/skills/release/SKILL.md` has the whole thing. The short
version: **SemVer, not CalVer**, because the tag here is a compatibility
promise rather than a marker for a period. People write
`uses: khalido/fx-agent-action@v1`, so a bad `v1` breaks their workflow on the
next run with nothing to roll back to.

`CHANGELOG.md` is the canonical record and its rolled section *is* the release
notes, pasted as-is; there is no second draft. **Never move the `v1` or `v1.N`
tags by hand** — `.github/workflows/release-tag.yml` does it on
`release: published`, and a prerelease moves nothing, which is how to test one. Dependabot keeps the
`actions/*` this action and its workflows pin current
(`.github/dependabot.yml`); a bump there is a PATCH unless it changes an input.

`.github/workflows/check.yml` runs on every push: shellcheck, actionlint, the
dogfood-drift diff, the prompt cascade with a fake issue event, the skills'
frontmatter, and the sanitizer's cases. That is the whole test suite, aimed at
the bugs this repo actually ships: shell quoting and action metadata.
