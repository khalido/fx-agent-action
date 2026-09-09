# fx agent action

Run the [fx](https://fx.sh) coding agent on a GitHub issue or pull request.
Read-only by default. It posts one comment and updates that same comment on
every re-run.

```yaml
- uses: khalido/fx-agent-action@v1
  env:
    AI_GATEWAY_API_KEY: ${{ secrets.AI_GATEWAY_API_KEY }}
  with:
    prompt_file: .github/fx/review.md
```

## Why this exists

fx is a single static binary with an AI Gateway built in, web search via Exa,
and skills it reads from `.claude/skills/`. What it does not have is the GitHub
half: reading the thread, posting an answer, not spamming the issue. That is
all this action is.

Two things make it small. `fx ask --json` separates the finished answer from
everything the model said on the way there, so there is no "stop narrating"
rule to write and any model works. And fx's own permission rules deny the edit
and shell tools by configuration, so in read mode the model never sees them,
never spends a step discovering it cannot write, and still exits clean.

## Setup

1. An [AI Gateway](https://vercel.com/docs/ai-gateway) key as a repository
   secret named `AI_GATEWAY_API_KEY`. Give it a spend cap; the agent runs on
   whatever anyone can put in an issue.
2. A workflow. Start from [`examples/`](examples/).

## Inputs

| Input | Default | What |
|---|---|---|
| `prompt` | — | What to ask. Empty means the triggering comment is the prompt. |
| `prompt_file` | — | A file in the repo holding the instructions instead. |
| `model` | `zai/glm-5.3-flash` | Any AI Gateway model id. |
| `mode` | `read` | `read` denies edit and shell. `write` allows them. |
| `max_steps` | `30` | Cap on the tool loop. |
| `post` | `comment` | `comment` posts on the issue, `none` leaves it on the output. |
| `issue_number` | the triggering one | Which issue to read and answer on. |
| `include_thread` | `true` | Give the agent the comments, not just the body. |
| `include_diff` | `true` | On a PR, give it the diff. |
| `max_cost` | `1` | Fail the step over this many dollars, when fx reports a cost. |
| `github_token` | `github.token` | Pass an App token for a bot with its own name. |
| `fx_version` | latest | Pin the fx release. |
| `working_directory` | `.` | The directory fx treats as its workspace. |

## Outputs

`response` (the answer as markdown), `cost`, `steps`, `comment_url`.

## Give the bot its own name

By default comments post as `github-actions[bot]`. For a bot with its own name
and avatar, create a GitHub App, install it on the repo, and hand this action
its token:

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

There is no hosted service and nothing to sign up for. The App is yours,
optional, and the only thing it changes is the name on the comment and the
ability for anything the bot opens to trigger other workflows, which the
default token deliberately cannot do.

## What it will not do

It will not run your code, edit files, or open a pull request unless you set
`mode: write`, which no comment-triggered workflow should. It has no hidden
network access beyond fx's own web search. It does not talk to any service the
action author runs, because there isn't one.

## Safety

The issue body and every comment reach the model. Treat them as untrusted:
they are appended below a fence that says so, after your instructions, and in
`read` mode the worst a crafted issue can achieve is a rude comment.

Gate the trigger on who is asking. Every example does:

```yaml
if: contains(fromJSON('["OWNER","MEMBER","COLLABORATOR"]'), github.event.comment.author_association)
```

## Licence

MIT.
