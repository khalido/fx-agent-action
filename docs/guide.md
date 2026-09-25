# fx agent action, the long version

The [README](../README.md) is the 80%. This is the rest, in one file, for a
person or an agent setting the action up in a repo. Raw copy for an agent:
`https://raw.githubusercontent.com/khalido/fx-agent-action/main/docs/guide.md`.
Working on the action itself is a different job; that is [`AGENTS.md`](../AGENTS.md).

## What a run does

1. **Checks who asked.** Write access on issue and PR events, a human actor on
   every event. A no fails the run before anything else happens.
2. **Reacts** with 👀 on the comment, or on the issue when an issue opening or
   edit is the trigger. Taken off at the end.
3. **Installs fx**, the latest release, cached by version.
4. **Builds the prompt**: the base block, the instruction, then the thread as
   evidence with hidden markup stripped.
5. **Configures fx** from one settings file, then reads the settings back and
   fails if fx did not take them.
6. **Runs fx once.** One `fx ask`, the answer scrubbed of anything that looks
   like a secret.
7. **Opens a draft PR** when the agent asked for one and the tree changed,
   from the difference between the tree before and after.
8. **Posts one comment per question**, or edits the one it posted before —
   the note refreshes as the issue is edited, and each `/fx` question keeps
   its own reply, so follow-ups read as pairs. With a footer:
   fx, model, tokens, cost in cents, seconds, a link to the run.
9. **Uploads the session** as one HTML file, kept a week.

## Three modes

| | agent (default) | answer | read |
|---|---|---|---|
| read files, search the web | yes | yes | yes |
| run commands, edit files | yes | yes, thrown away | no |
| commit, push, PR | draft PR, when it decides to ship | no | no |
| fx permission rules | edit and shell allowed | edit and shell allowed | edit and shell denied |
| a stranger or bot may trigger it | no | no | yes, with `allowed_non_write_users` or `allowed_bots` |
| needs | `contents: write`, `pull-requests: write` | `contents: read` | `contents: read` |

Two capabilities come apart here — a shell, and a pull request — and three of
the four combinations are worth having. Each mode is one step down from the
last.

**Agent** is one agent with a shell and edits, every run. It reads the
thread, tries things in the checkout, runs the tests, and decides what the
run should produce: an answer, or, when it was asked to change something and
can do it well in one run, the change as a draft pull request through its
`open-pr` skill. The skill has it write `.agent-pr.md` (title, then body)
and the action does the branch, the push and the PR; no file, or an
unchanged tree, and nothing opens. When the change is bigger than a run or
needs a decision, the base block tells it to leave a pointed note for a
stronger agent or a person instead. Nothing else it does to the checkout is
kept. There are two off switches for pull requests and they work at
different levels. `mode: answer` is the polite one: the agent is never told
to ship, so it does not spend the run building something that gets thrown
away. `contents: read` is the hard one: the agent may try, the push fails,
the edits are discarded and the comment carries a line saying the job could
not push. Use `mode: answer` to say what you want and `contents: read` to
make it true; a repo that never wants a PR should set both.

**Answer** is the same agent with the pull request taken away. It has the
shell and the edits, so it runs your tests, writes a repro and tries the fix
before it answers, and the checkout is scratch paper every time: nothing is
committed, pushed or opened, and the prompt tells it so rather than telling
it to ship. Pick this when pull requests from the agent are off for good —
`main` deploys on push, or the repo has no branch protection to fall back
on — and you still want answers that were checked rather than guessed.

**Read** is for a fixed prompt on a job that strangers or bots may trigger.
The edit and shell tools are hidden from the model by rule, so it never
spends a step finding out, and a model with no shell cannot read the
runner's environment. It can open nothing. It is the only mode
`allowed_non_write_users` and `allowed_bots` combine with, and the base
block warns the model that instructions below it may name commands it cannot
run, so a note says a claim is unverified instead of implying it checked.

Check out with `fetch-depth: 0`, as the examples do. The default shallow
clone leaves `git log` and `git blame` with one commit, and "this used to
work, what changed?" is the question history answers. A full clone of an
ordinary repo costs a second or two; set a depth only on a very large one.

What the shell changes is exposure: fx needs the gateway key in its own
environment to call the model, and fx's shell tool is fx's child process, so
anything with a shell can reach that key. There is no way to have one without
the other. That is the whole reason `read` exists, and why neither `agent`
nor `answer` combines with `allowed_non_write_users` or with bots on issue
events. The real boundary
around what the agent can do to the repository is the workflow's
`permissions:` block, not fx's review layer, which is why the rules are
allow rules and not `auto`'s billed review call per action.

## The prompt, layer by layer

1. **The base block**, written by the action for every run. Where it is, that
   nothing is interactive, which tools it has in this mode, the voice, that
   only the final answer is posted, and the judgement: answer a question;
   make, test and ship a change when it fits one run; otherwise leave a note
   for a stronger agent or a person. It also says the repo's `AGENTS.md` may
   add to or adjust the task.
2. **The instruction.** In order of precedence: `prompt_file` if that file
   exists in the checkout; `prompt` inline in the workflow; on an `issues`
   event, the built-in note, [`prompts/issue.md`](../prompts/issue.md);
   otherwise the comment that triggered the run, minus the trigger phrase.
3. **The thread**, fenced and labelled as evidence: title, body, comments, and
   on a PR the diff, truncated at 200 KB. Reading the diff needs
   `pull-requests: read` on the job; without it the run warns and tells the
   agent the diff was unavailable rather than handing it an empty one.

Underneath, fx loads the repo's own `AGENTS.md` or `CLAUDE.md` the way it does
on a laptop, and discovers skills in `skills/`, `.claude/skills/`,
`.agents/skills/`, `.opencode/skills/`, `.codex/skills/` and `.claw/skills/`.
A skill's description sits in the catalog on every run; its instructions load
only when invoked. On a PR event all of this is the PR branch's copy.

The action adds skills of its own. Its `skills/` folder, and the repo's
`.github/fx/skills/` if there is one, are copied into `~/.fx/skills/` on the
runner before fx starts, so they exist for this agent in this run and for
nothing else, not your laptop's fx, not Claude Code. `skills: false` turns the
copy off. Shipped today: `open-pr`, the procedure for shipping a change
(clean tree, checks run, `.agent-pr.md` written), and `compare-models`, for
"is this model on the gateway, what does it cost, what do people hit, does it
fit this repo, switch or test it". A skill here improves for every repo on
the next run, like the note.

**To add to what the agent does in your repo**, write it in `AGENTS.md`. A
`## In CI` section keeps bot instructions apart from laptop ones. **To change
the note entirely**, add `.github/fx/issue.md`; on issue events the action
uses it instead of the built-in note, with no input to set, so the same job
still answers `/fx` comments from the comment. The built-in note says "no
pull request from a note"; a replacement that does not say so lets an issue
opening end in a draft PR when the agent judges the ask fits one run, which
may be what you want. **For another kind of job**, `prompt` inline or a
`prompt_file` of your own; the base block and the thread come free.

## Memory

Memory is on by default. The agent gets one file that survives between runs:
`MEMORY.md` on an orphan branch, `agent-memory` by default. Before the run the
action fetches it into the workspace at `.agent-memory/MEMORY.md` and quotes
it in the prompt. The base block tells the agent what it is: a model of how
this repository and its people work, not a diary. Correct or delete stale
lines rather than adding on top, bump a date when a run confirms a line, add
a line only when a future run needs it, stay under the cap. The agent edits
the file with its ordinary tools and knows nothing else about the mechanism.

After the run, if the file changed and the run's actor has write access to
the repo, the action pushes it back through the contents API with the blob
sha it fetched. A run allowed through `allowed_non_write_users` or
`allowed_bots` reads the memory and cannot change it; that is decided by the
actor check, not by the prompt. A 409 means another run wrote
first; the action merges three ways and retries once, else warns. If the
file is over `memory_lines` the action first makes one extra model call, on
the same model, to compact it. Everything is non-fatal: a failed push loses
this run's memory and nothing else. The path is excluded from pull requests.

What it needs: `contents: write` on the job, because the push uses the
workflow token; fx itself never holds it. Read mode sees the memory and
cannot change it. `memory_repo` pointing at the org's `.github` repo, with an
App token through `github_token`, gives one memory across an org.

The memory is quoted inside the untrusted framing, because earlier runs wrote
it from threads a stranger may have shaped. Read it on the branch in the
browser, edit it by hand, or `git push origin --delete agent-memory` to
forget everything.

## Who can trigger a run

Two checks inside the action, before anything else, and a no fails the run
rather than skipping it, so a misconfigured workflow is visible:

- **Write access**, on `issues`, `issue_comment`, `pull_request`,
  `pull_request_target`, `pull_request_review` and
  `pull_request_review_comment` events, via the collaborators permission
  endpoint, which the default token can call. Scheduled and manual runs skip
  this check. `allowed_non_write_users` lists exceptions, or `*` for anyone,
  and only combines with `mode: read`.
- **Not a bot**, on every event: a `[bot]` login, a `Bot` sender type, or a
  login that is not a user account. `allowed_bots` lists exceptions, with or
  without the `[bot]` suffix, or `*`, and on issue and PR events the same
  read-only restriction applies. This is what stops two bots looping.

Keep the `if:` on the job as well. `author_association` in it saves booting a
runner for a stranger's `/fx`, but `MEMBER` means org member, not write
access, so it is a filter and not the check.

## Pull requests

The agent opens one when it was asked for a change and judges the change
ready: it writes `.agent-pr.md` at the repo root, title on the first line and
the body after, and the action does the rest. The tree was snapshotted before
fx ran, so the PR carries exactly the files that differ, committed on a
branch named from `branch_prefix` and the issue number, pushed with the
workflow token, opened as a **draft**. The body is what the agent wrote:
what changed, what it left alone, which checks ran. A person reviews and
marks it ready; nothing merges on its own. No `.agent-pr.md`, or a tree that
did not change, and nothing is opened: prose alone cannot open a pull
request, and neither can a run in read mode.

Two GitHub facts shape this:

- **The repo setting.** Settings → Actions → General → "Allow GitHub Actions
  to create and approve pull requests" is off by default, and at org level
  too. Without it the push succeeds and the PR creation fails.
- **No CI on the default token.** GitHub runs no workflows on a PR opened with
  `GITHUB_TOKEN`. To get checks on fx's drafts, pass an App token, below.

Files under `.github/workflows/` are skipped with a note in the PR body: the
default token cannot push them.

### A bot with its own name

Comments post as `github-actions[bot]`. For your own name and for CI on the
PRs it opens, make a GitHub App, install it on the repo, pass its token:

```yaml
- uses: actions/create-github-app-token@v3
  id: app
  with:
    app-id: ${{ secrets.FX_APP_ID }}
    private-key: ${{ secrets.FX_APP_PRIVATE_KEY }}
- uses: khalido/fx-agent-action@main
  with:
    github_token: ${{ steps.app.outputs.token }}
```

The App needs Contents, Pull requests and Issues read and write, plus
Workflows read and write if the agent should be able to change workflow files.
The App is yours. I don't want the ability to mint tokens into your repo.

## Cost

Everything bills to your [AI Gateway](https://vercel.com/ai-gateway) key,
web search included. Give the key its own budget when you create it; the
gateway enforces that, and `max_cost` only notices after the fact.

```bash
vercel ai-gateway api-keys create --name github-actions --limit 10 --refresh-period monthly
```

The footer on every comment has the model, tokens in and out, the cost in
cents and the seconds, from fx's own ledger. That ledger is per machine and
the numbers assume a fresh HOME every job, which GitHub-hosted runners give
you. On a self-hosted runner with a persistent HOME the figures and
`max_cost` become cumulative; give each job its own HOME there. A comment that gets rewritten
stacks its earlier runs underneath and a total. The script does the adding.

If you add your own provider key to the gateway (BYOK), the gateway bills
nothing for those calls, so your gateway budget no longer caps that model's
spend; the provider's own account does. fx's ledger then records zero, so
the action asks the gateway for its record of each generation in the run and
sums the provider's real charge instead, peak pricing included, and the
footer names the provider that served the run (`via deepseek`). Only if
those lookups fail does it fall back to a list-price estimate from the
tokens, marked `≈`.

Speed varies with who serves the model. The gateway routes a request for
`deepseek/deepseek-v4.1-flash` to any of a dozen or more providers at
different prices and speeds. `provider_order: deepseek, fireworks` tries
those first, then the pool; the slugs are on the gateway's models page. A
repo's `.fx.json` cannot change this, because the action always writes it.
BYOK also pins: add your own DeepSeek API key to the gateway and it uses that
provider first. DeepSeek's own endpoint has peak pricing, double between 01:00
and 04:00 and 06:00 and 10:00 UTC on weekdays.

Model choice is one input. `deepseek/deepseek-v4.1-flash` is the default; a
note runs a few cents, a question about the same, and a change that ends in
a pull request more, since it runs the tests too. `effort` passes a reasoning
effort to models that take one. `max_steps` caps the tool loop and is set in
the action's settings, so a repo's `.fx.json` cannot raise it.

## When it goes wrong

Read the session first. Every run uploads `fx-session-<run id>` as one HTML
file: every tool call, its arguments and result, web searches with the exact
query, domain filter and date window sent, and why a call was held or
truncated. The comment footer links the run.

Things that fail on the first day:

- **No comment, red X, "Check who asked" failed.** The actor lacked write
  access or was a bot. The job's `if:` should have skipped it; check
  `author_association` and the bot condition there.
- **`prompt_file not found`** with no fallback. The path is relative to the
  checkout; the built-in note only fills in on `issues` events.
- **`fx failed before doing anything`** with `HTTP 401` or `402`. The
  gateway key is wrong, or its budget is spent.
- **`fx did not finish within 10 minutes`**. fx waits for a model endpoint it
  cannot reach rather than giving up, so an outage ends here. Rerun later, or
  raise `timeout_minutes` if the job was genuinely long.
- **`model_not_found`** from the gateway. The model id left the catalog, which
  preview ids do. Check <https://ai-gateway.vercel.sh/v1/models>.
- **PR push fine, PR creation 403.** The repo or org setting above.
- **`fx did not take the settings written for it`.** fx changed its settings
  shape. Open an issue here with the run link.

## Before you turn it on

- **The thread goes to the model**, as evidence, with hidden markup stripped:
  HTML comments, zero-width characters, image alt text, hidden attributes. The
  comment that summons the agent is its instruction. That is why the
  write-access check exists.
- **The workflow's `permissions:` block decides what the agent can do**, not
  this action. `contents: write` can push to your default branch, and
  [branch protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
  is what makes "at most a draft PR" true whatever the agent does. The action
  closes the routes it knows about on its own: fx's process never holds a
  GitHub token, the checkout has no credentials, the push goes to a branch,
  and a run that finds fx has edited the action's own scripts stops before
  the step that pushes or posts. A private repo on the free plan cannot have
  branch protection — GitHub answers 403 to both the branch-protection and
  the ruleset APIs on that plan — so there you are trusting those guards and
  everyone with write access. The push does at least refuse to target your
  default branch, which is asserted rather than assumed. If that is not true of your repo, `contents: read`; the
  agent can then push nothing however it is asked.
- **Read mode can reach the web.** Search and fetch are on, so an injected
  thread that steers the agent could read a file and send it out in a URL.
  The write-access check is the control; only people who could already read
  the repo can start a run.
- **The agent reads your `AGENTS.md` and sees every skill in the repo**, as
  above, and on a PR that is the PR's copy. The pr-review example skips forks
  for this reason.
- **Anyone who can trigger a run can spend the key**, and a thread that talks
  the agent into a command has a shell that can read it. Secrets are scrubbed
  from everything posted; the budget is the control.
- **`@main` for now.** Every push here reaches every repo on `@main` at its
  next run, good and bad. That is the right trade while this is young and the
  people using it are in the same room. Once a release exists, `@v1` moves
  only when one is published, and is what to use in a repo you do not watch.
- **Pinning the action does not pin fx.** fx ships weekly and the action
  installs the latest, on purpose. The footer says which version ran.

Found a way past any of this? [SECURITY.md](../SECURITY.md) says where to
report it.

## Do you need the action at all?

For one repo, maybe not:

```yaml
- run: curl -fsSL https://fx.sh/setup.sh | bash
- run: fx ask --json "$PROMPT" | jq -r .final_output | gh issue comment "$N" --body-file -
```

[`examples/minimal-no-action.yml`](../examples/minimal-no-action.yml) is that,
finished. The action adds what you would otherwise paste into every repo: the
actor checks, one comment instead of a pile, a cached binary, the draft pull
request from what the agent changed, the thread and diff with hidden markup
stripped, the built-in note, and the session to read when it goes wrong.
