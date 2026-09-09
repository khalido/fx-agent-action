# fx agent action

Comment `/fx` on a GitHub issue and get a useful reply. Say `/fx pr` and get a
pull request instead.

```yaml
- uses: khalido/fx-agent-action@v1
  env:
    AI_GATEWAY_API_KEY: ${{ secrets.AI_GATEWAY_API_KEY }}
```

Runs [fx](https://fx.sh) in your own Actions runner. Read-only unless you ask
for a PR. One comment, edited in place, not a new one every run.

## Two things it does

**`/fx why is the sync running twice?`** — it reads the repo and the thread, and
replies. It cannot edit a file or run a command: fx's permission rules deny
those tools, so the model never sees them.

**`/fx pr add a retry to the Tracmor client`** — same, plus the edit and shell
tools. What it changed becomes a branch and a **draft** pull request, linked
from the comment.

`pr` is the only word that turns writing on, and that is deliberate. `do`,
`build` and `fix` were in that list until they weren't: "/fx do we already have
a retry helper?" is a question, and it was handing a full-access shell to one.

Nothing else. No slash-command vocabulary to learn, no dashboard.

## Setup

Two things: an [AI Gateway](https://vercel.com/docs/ai-gateway) key as a repo
secret called `AI_GATEWAY_API_KEY`, and a workflow. Copy one from
[`examples/`](examples/).

**Give the key its own budget.** The gateway enforces it and returns a 402;
this action's `max_cost` only notices afterwards.

```bash
vercel ai-gateway api-keys create --name github-actions \
  --budget 20 --refresh-period monthly --expiration 1y --alert-thresholds 75,100
```

One key across all your repos is fine and easier to rotate — GitHub has no
account-wide Actions secret, so it is `gh secret set` per repo, or an org
secret if the repos live in an org. Use a dedicated key, not the one you code
with: anyone who can comment can spend it.

No Exa key needed. Web search is on by default and the gateway bills it as
[a model](https://vercel.com/ai-gateway/models/exa-search) on the same key.

## Inputs

Every one is optional.

| Input | Default | |
|---|---|---|
| `prompt` | the comment | What to ask. |
| `prompt_file` | — | A file in your repo holding the instructions instead, so you edit the agent without touching YAML. |
| `model` | `zai/glm-5.3-flash` | Any gateway model id. |
| `mode` | `auto` | `auto` lets the comment decide. `read` and `write` force it. |
| `trigger` | `/fx` | |
| `max_steps` | `30` | |
| `post` | `comment` | `none` leaves the answer on the `response` output instead. |
| `session_artifact` | `true` | The whole run as one HTML file on the run page. |
| `max_cost` | `1` | Fail over this many dollars, after the fact. |
| `github_token` | the workflow's | Pass an App token for a named bot. |

Outputs: `response`, `cost`, `steps`, `session_id`, `comment_url`, `pr_url`.

## What to point it at

The five in [`examples/`](examples/) are working workflows, not sketches:

- **[issue-notes](examples/issue-notes.yml)** — a second opinion on every new issue, from something that has read the code.
- **[pr-review](examples/pr-review.yml)** — review on open and on push.
- **[triage](examples/triage.yml)** — labels from the ones your repo already has. The agent picks from a list, the workflow applies it.
- **[build-it](examples/build-it.yml)** — `/fx pr …` opens a draft PR.
- **[weekly-deps](examples/weekly-deps.yml)** — bump, test, and one PR a week with a note. What dependabot should have been.

More ideas, all portable to this action:
[claude-code-action's solutions doc](https://github.com/anthropics/claude-code-action/blob/main/docs/solutions.md)
— path-filtered doc sync, security-focused review, scheduled maintenance.

## When it goes wrong

Every run uploads the session as one HTML file — every tool call, its arguments
and its result — kept on the run page for a week. Read that before guessing.
Turn it off with `session_artifact: false`.

## Do you need this?

Probably not, for one repo. This is the whole integration without it:

```yaml
- run: curl -fsSL https://fx.sh/setup.sh | bash
- run: |
    fx ask --json "$PROMPT" | jq -r .final_output | gh issue comment "$N" --body-file -
```

[`examples/minimal-no-action.yml`](examples/minimal-no-action.yml) is that,
finished. Start there. The action adds what you'd otherwise paste into every
repo: one comment instead of a pile, a cached binary, read-only that holds, the
thread and diff handed to the model, hidden markup stripped out of them, and
the session to read when it goes wrong.

## A bot with its own name

Comments post as `github-actions[bot]`. For your own name and avatar, make a
GitHub App, install it, pass its token:

```yaml
- uses: actions/create-github-app-token@v2
  id: app
  with:
    app-id: ${{ secrets.FX_APP_ID }}
    private-key: ${{ secrets.FX_APP_PRIVATE_KEY }}
- uses: khalido/fx-agent-action@v1
  with:
    github_token: ${{ steps.app.outputs.token }}
```

Worth doing for `/fx pr`: GitHub runs no workflows on commits made with the
default `GITHUB_TOKEN`, so a PR opened without an App token gets no CI.

There is no app to install from me and no service in the middle. The App is
yours. I don't want the ability to mint tokens into your repo.

## Before you turn it on

The issue body and every comment go to the model. Gate the trigger on who's
asking — every example does:

```yaml
if: contains(fromJSON('["OWNER","MEMBER","COLLABORATOR"]'), github.event.comment.author_association)
```

That gate is load-bearing, not tidiness. Hidden markup is stripped out of the
issue body and the thread, but the text of the comment that summons the agent
is its instruction — so whoever can type `/fx` is directing it.

It matters more for `/fx pr`, which writes code with a token that can push.
Keep it to people who could already push, and turn on branch protection: what
the agent may do to your repo is decided by the workflow's `permissions:`
block, not by anything in this action.

## Inspiration

- [fx](https://fx.sh) — the agent. Vercel Labs, Apache-2.0, one static binary.
- [shaftoe/pi-coding-agent-action](https://github.com/shaftoe/pi-coding-agent-action)
  — the comment marker, the author gate, the 👀 while it works.
- [opencode](https://opencode.ai/docs/github/) — caching the binary by release
  tag, and the `/oc` shape. They publish an App and run a token service; this
  doesn't.
- [anthropics/claude-code-action](https://github.com/anthropics/claude-code-action)
  — stripping hidden markup out of untrusted text, and stopping at a draft
  rather than a merge-ready PR.

MIT.
