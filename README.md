# fx agent action

Comment `/fx` on a GitHub issue and get a useful reply. Say `/fx pr` and get a
pull request instead.

```yaml
- uses: khalido/fx-agent-action@v1
  env:
    AI_GATEWAY_API_KEY: ${{ secrets.AI_GATEWAY_API_KEY }}
```

Runs [fx](https://fx.sh) inside your own Actions runner. Read-only unless you
ask for a PR. One comment, edited in place, not a new one every run.

## Two things it does

**`/fx why is the sync running twice?`** — it reads the repo and the thread, and
replies. It cannot edit a file or run a command: fx's own permission rules deny
those tools, so the model never sees them.

**`/fx pr add a retry to the Tracmor client`** — same, plus the edit and shell
tools. Whatever it changed becomes a branch and a PR, linked from the comment.
`do`, `build`, `implement` and `fix` work too.

Nothing else. No slash-command vocabulary to learn, no dashboard.

## Setup

Two things: an [AI Gateway](https://vercel.com/docs/ai-gateway) key as a repo
secret called `AI_GATEWAY_API_KEY`, and a workflow. Copy
[`examples/issue-notes.yml`](examples/issue-notes.yml).

Give the key a spend cap. Anyone who can comment can spend it.

You don't need an Exa key. Web search is on, and the gateway bills it.

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
| `max_cost` | `1` | Fail over this many dollars. |
| `github_token` | the workflow's | Pass an App token for a named bot. |
| `fx_version` | latest | Pin it. |

Outputs: `response`, `cost`, `steps`, `comment_url`, `pr_url`.

## Do you need this?

Probably not, for one repo. This is the whole integration without it:

```yaml
- run: curl -fsSL https://fx.sh/setup.sh | bash
- run: |
    fx ask --json "$PROMPT" | jq -r .final_output | gh issue comment "$N" --body-file -
```

[`examples/minimal-no-action.yml`](examples/minimal-no-action.yml) is that,
finished. Start there. The action adds the four things you'd otherwise paste
into every repo: one comment instead of a pile, a cached binary instead of a
download per run, read-only that actually holds, and the thread and diff handed
to the model.

## A bot with its own name

Comments post as `github-actions[bot]`. For your own name and avatar, make a
GitHub App, install it on the repo, pass its token:

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

There is no app to install from me and no service in the middle. The App is
yours. I don't want the ability to mint tokens into your repo.

## Before you turn it on

The issue body and every comment go to the model. Gate the trigger on who's
asking — every example does:

```yaml
if: contains(fromJSON('["OWNER","MEMBER","COLLABORATOR"]'), github.event.comment.author_association)
```

That matters more once `/fx pr` is live: it writes code, so the people who can
trigger it should be the people who can already push.

## Inspiration

- [fx](https://fx.sh) — the agent. Vercel Labs, Apache-2.0, one static binary.
- [shaftoe/pi-coding-agent-action](https://github.com/shaftoe/pi-coding-agent-action)
  — the comment-marker trick, and the author gate, came from reading it.
- [opencode](https://opencode.ai/docs/github/) — caching the binary by release
  tag, and the `/oc` shape. They publish an App and run a token service; this
  doesn't.

MIT.
