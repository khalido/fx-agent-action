# fx-agent-action — agent guide

A GitHub Action that runs [fx](https://fx.sh) on an issue or PR and posts one
comment. Read `README.md` for what it does; this file is how to work on it.

## Shape, and why

**A composite action, not a JavaScript one.** Every step is shell you can read
in the browser. There is no bundled `dist/` anyone has to trust, no build step
before a change ships, and `gh`, `jq` and `curl` are already on every runner.

Three files hold everything:

| File | Does |
|---|---|
| `action.yml` | inputs, outputs, and the step sequence |
| `scripts/build-prompt.sh` | instruction first, GitHub context after, fenced as evidence |
| `scripts/run-fx.sh` | one `fx ask --json`, pull out the answer, enforce the cost tripwire |
| `scripts/post-comment.sh` | upsert one comment, found by a hidden marker |
| `scripts/open-pr.sh` | branch, commit, push, and open the PR after a write turn |

`fx pr` writes the PR title and body, and it reads the **uncommitted** working
tree — verified on 0.0.8, it runs `git diff` and changes nothing itself. So it
must run before the commit, which is why `open-pr.sh` calls it first and does
the git work afterwards. It has no `--json`, so its prose is parsed loosely with
a fallback to the agent's own answer.

Keep it that way. If a change wants a fourth script, ask whether it belongs in
the prompt instead.

## Do we need actions/toolkit?

Not yet, and the trade is worth stating. [`actions/toolkit`](https://github.com/actions/toolkit)
is the Node library set for JavaScript actions: `@actions/core` for inputs and
outputs, `@actions/github` for a ready Octokit, `@actions/cache`, `@actions/exec`.

Everything we use it for has a shell equivalent already on the runner:

| toolkit | what we do instead |
|---|---|
| `core.setOutput` | append to `$GITHUB_OUTPUT` |
| `core.setFailed` / `warning` | `::error::` / `::warning::` workflow commands |
| `core.addMask` | secrets passed as `env:` are masked by GitHub already |
| `@actions/github` Octokit | `gh api`, pre-installed and pre-authenticated |
| `@actions/cache` | `actions/cache@v4` as a step |
| `@actions/exec` | it is a shell script |

The moment to switch is real API work that shell makes awkward: review comments
anchored to specific diff lines, pagination with retries, or partial failure
handling across several calls. That is the line `shaftoe/pi-coding-agent-action`
crossed, and it now ships a bundled `dist/index.js` measured in hundreds of
kilobytes. Until we need that, a JS action costs a build, a committed bundle and
a dependency treadmill for no capability we use.

If it does become a JS action, do it wholesale rather than half: a composite
action that shells out to `node` is the worst of both.

## What we learned from the two prior arts

**[shaftoe/pi-coding-agent-action](https://github.com/shaftoe/pi-coding-agent-action)**
puts all the GitHub logic in the action. Worth copying: finding its own comment
by a hidden HTML marker and updating in place, gating on `author_association`,
and appending a footer with the run link and cost. Its trap, and the reason this
action posts `final_output`: it posts **every** text chunk the agent emits, so a
model that narrates between tool calls fills the comment with "let me look at…".

**[opencode](https://opencode.ai/docs/github/)**
([action.yml](https://github.com/anomalyco/opencode/blob/dev/github/action.yml))
puts the GitHub logic in the agent binary — the action is a thin composite that
installs opencode and runs `opencode github run`. Worth copying: caching the
binary with `actions/cache` keyed on the resolved release tag. Not available to
us, because fx is Vercel's Zig codebase, not ours; our GitHub logic has to live
in the action. Their GitHub App also does an OIDC token exchange against a
service they host, which is why we take a token as an input instead.

## The defaults, and why each one

- **Two permission modes, not one.** Read mode is `auto` plus deny rules on
  `edit` and `shell` in `~/.fx/settings.json`; the rules are what enforce it,
  and they hide those tools from the model, so it never spends a step finding
  out and the run exits 0. Write mode is `full-access`, because the runner is a
  throwaway container with a scoped token and fx's review layer would only add
  latency and a separate billed model request per unresolved call — verified
  headless, no acknowledgement prompt. **Never full-access in read mode**: it
  disables the checks the deny rules ride on. `FX_PERMISSION_MODE=ask` also
  blocks writes, but a rejected call aborts with exit 1, which is worse than a
  hidden tool.
- **Rules go in the global settings file, not a workspace profile.** The
  checkout path changes between runs, so a workspace-scoped rule would silently
  not apply.
- **The model is set in the config file, not `FX_MODEL`.** One owner for the
  value. `models` is keyed by provider; the gateway's is `models.gateway`.
- **No Exa key.** On the AI Gateway fx uses Exa for `web_search` by default,
  and Vercel bills it as [a model on the gateway](https://vercel.com/ai-gateway/models/exa-search)
  against the same `AI_GATEWAY_API_KEY`. Nothing else to provision.
- **Post `final_output`, not `output`.** The finished answer, not the running
  commentary. This is what makes the action model-agnostic.
- **One comment, updated.** A marker on the first line, invisible when rendered.
  GitHub keeps the edit history, so overwriting loses nothing.
- **Context after instructions, behind a fence that names it as evidence.** An
  issue body is untrusted input.
- **`github_token` is an input defaulting to `github.token`.** Bring your own
  App token for a named bot. No hosted service, ever — that is the line between
  this and the opencode model.
- **`max_steps: 30` and a cost tripwire.** fx has no mid-run spend cap, so the
  real bound is the job timeout at a cheap model's prices; the tripwire is an
  alarm after the fact.

## Testing a change

There is no unit test worth writing for 200 lines of glue. Test it the way it
runs:

```bash
# the scripts, against a real repo, with the runner's variables faked
export RUNNER_TEMP=$(mktemp -d) GITHUB_OUTPUT=$RUNNER_TEMP/out GITHUB_STEP_SUMMARY=$RUNNER_TEMP/sum
export GITHUB_REPOSITORY=owner/repo GITHUB_RUN_ID=1 GH_TOKEN=$(gh auth token)
export INPUT_PROMPT="Summarise this issue in one line." INPUT_ISSUE_NUMBER=1
bash scripts/build-prompt.sh && cat $RUNNER_TEMP/fx-prompt.md
```

Then end to end: push a branch, point a workflow at
`uses: khalido/fx-agent-action@<branch>`, and comment on a throwaway issue.

Run `shellcheck scripts/*.sh` before pushing. `actionlint` checks `action.yml`
and the examples.

## References

- [Creating a composite action](https://docs.github.com/en/actions/tutorials/create-actions/create-a-composite-action)
- [Metadata syntax for actions](https://docs.github.com/en/actions/reference/metadata-syntax-for-github-actions) — the `action.yml` schema
- [Workflow commands](https://docs.github.com/en/actions/reference/workflow-commands-for-github-actions) — `::error::`, `$GITHUB_OUTPUT`, step summaries
- [Security hardening for actions](https://docs.github.com/en/actions/security-for-github-actions/security-guidelines/security-hardening-for-github-actions) — untrusted input, `pull_request_target`, token scopes
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token) — the BYO bot identity
- [fx docs](https://fx.sh/docs): [`fx ask`](https://fx.sh/docs/using-fx/fx-ask), [permissions](https://fx.sh/docs/configure-fx/permissions), [configuration](https://fx.sh/docs/configure-fx/configuration), [tools](https://fx.sh/docs/capabilities/tools), [skills](https://fx.sh/docs/capabilities/skills), [project instructions](https://fx.sh/docs/configure-fx/project-instructions)
- [fx source](https://github.com/vercel-labs/fx) — Apache-2.0, Zig, released weekly

## Publishing

A tag is the version people use. Cut `v1.2.3`, then move the floating `v1` tag
to it, because `uses: khalido/fx-agent-action@v1` is what a README tells people
to write.

```bash
git tag -a v1.0.0 -m "..." && git push origin v1.0.0
git tag -f v1 v1.0.0 && git push -f origin v1
```

Listing it on the GitHub Marketplace is a checkbox on the release form and needs
the `branding` block in `action.yml`, which is already there.
