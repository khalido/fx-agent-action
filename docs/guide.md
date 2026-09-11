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
   evidence with hidden markup stripped. Decides read or write.
5. **Configures fx** from one settings file, then reads the settings back and
   fails if fx did not take them.
6. **Runs fx once.** One `fx ask`, the answer scrubbed of anything that looks
   like a secret.
7. **Opens a draft PR** in write mode, from the difference between the tree
   before and after.
8. **Posts one comment**, or edits the one it posted before, with a footer:
   fx, model, tokens, cost in cents, seconds, a link to the run.
9. **Uploads the session** as one HTML file, kept a week.

## Three modes

| | read | scratch (`shell: true`) | write (`/fx pr`) |
|---|---|---|---|
| read files, search the web | yes | yes | yes |
| run commands | no | yes | yes |
| edit files | no | yes, thrown away | yes |
| commit, push, PR | no | no | draft PR |
| fx permission mode | `auto`, edit and shell denied | `auto`, both allowed | `full-access` |
| needs | `contents: read` | `contents: read` | `contents: write`, `pull-requests: write` |

**Read** is what a `/fx` question gets by default. The edit and shell tools
are hidden from the model by rule, so it never spends a step finding out.

Check out with `fetch-depth: 0`, as the examples do. The default shallow
clone leaves `git log` and `git blame` with one commit, and "this used to
work, what changed?" is the question history answers. A full clone of an
ordinary repo costs a second or two; set a depth only on a very large one.

**Scratch** is read plus a shell and edits, nothing kept. The checkout is a
throwaway container, and an agent that can try a fix and run the tests gives
a better answer than one that guesses. The base block tells it to report what
it found, not what it changed. This is what `examples/fx.yml` uses for both
the note and questions. What scratch mode changes is exposure: a shell can
read the runner's environment, gateway key included, so it does not combine
with `allowed_non_write_users` or with bots on issue events.

**Write** is `/fx pr`. Full access inside the runner, because the real
boundary is the workflow's `permissions:` block, not fx's review layer. The
agent edits the working tree and stops; the action makes the branch, the
commit and the draft PR.

`mode: read` or `mode: write` on the job forces one; `auto`, the default,
lets the comment decide, and only the word `pr` right after the trigger turns
writing on.

## The prompt, layer by layer

1. **The base block**, written by the action for every run. Where it is, that
   nothing is interactive, which tools it has in this mode, that only the final
   answer is posted, the voice, and in write mode: edit the tree, do not
   commit. It also says the repo's `AGENTS.md` may add to or adjust the task.
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
copy off. Shipped today: `compare-models`, for "is this model on the gateway,
what does it cost, what do people hit, does it fit this repo, switch or test
it". A skill here improves for every repo on the next run, like the note.

**To add to what the agent does in your repo**, write it in `AGENTS.md`. A
`## In CI` section keeps bot instructions apart from laptop ones. **To change
the note entirely**, add `.github/fx/issue.md` and set
`prompt_file: .github/fx/issue.md` on the note job; the file replaces the
built-in note whole. **For another kind of job**, `prompt` inline or a
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

After the run, if the file changed, the action pushes it back through the
contents API with the blob sha it fetched. A 409 means another run wrote
first; the action merges three ways and retries once, else warns. If the
file is over `memory_lines` the action first makes one extra model call, on
the same model, to compact it. Everything is non-fatal: a failed push loses
this run's memory and nothing else. The path is excluded from pull requests.

What it needs: `contents: write` on the job, because the push uses the
workflow token; fx itself never holds it. And a mode that can edit, so
`shell: true` or a `pr` run; plain read mode sees the memory and cannot
change it. `memory_repo` pointing at the org's `.github` repo, with an App
token through `github_token`, gives one memory across an org.

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
  and only combines with `mode: read` and no shell.
- **Not a bot**, on every event: a `[bot]` login, a `Bot` sender type, or a
  login that is not a user account. `allowed_bots` lists exceptions, with or
  without the `[bot]` suffix, or `*`, and on issue and PR events the same
  read-only restriction applies. This is what stops two bots looping.

Keep the `if:` on the job as well. `author_association` in it saves booting a
runner for a stranger's `/fx`, but `MEMBER` means org member, not write
access, so it is a filter and not the check.

## Pull requests

`/fx pr <what to build>` runs in write mode. The action snapshots the tree
before fx runs, and afterwards the PR carries exactly the files that differ,
committed on a branch named from `branch_prefix` and the issue number, pushed
with the workflow token, opened as a **draft**. The body is what fx wrote
about its change. A person reviews and marks it ready; nothing merges on its
own.

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
Workflows read and write if `/fx pr` should be able to change workflow files.
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

Model choice is one input. `deepseek/deepseek-v4.1-flash` is the default; a
note runs a few cents, a question about the same. `pr_model` puts write runs
on something stronger without touching questions. `effort` passes a reasoning
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
  branch protection, so there you are trusting those guards and everyone
  with write access. If that is not true of your repo, do not wire `pr`:
  `mode: read` and `contents: read`.
- **Read mode can reach the web.** Search and fetch are on, so an injected
  thread that steers the agent could read a file and send it out in a URL.
  The write-access check is the control; only people who could already read
  the repo can start a run.
- **The agent reads your `AGENTS.md` and sees every skill in the repo**, as
  above, and on a PR that is the PR's copy. The pr-review example skips forks
  for this reason.
- **Anyone who can trigger a run can spend the key**, and in scratch or write
  mode a thread that talks the agent into a command has a shell that can read
  it. Secrets are scrubbed from everything posted; the budget is the control.
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
actor checks, one comment instead of a pile, a cached binary, read-only that
holds, the thread and diff with hidden markup stripped, the built-in note, and
the session to read when it goes wrong.
