# fx-agent-action — agent guide

A GitHub Action that runs [fx](https://fx.sh) on an issue or PR and posts one
comment. Read `README.md` for what it does; this file is how to work on it.

## Shape, and why

**A composite action, not a JavaScript one.** Every step is shell you can read
in the browser. There is no bundled `dist/` anyone has to trust, no build step
before a change ships, and `gh`, `jq` and `python3` are already on every runner.

| File | Does |
|---|---|
| `action.yml` | inputs, outputs, and the step sequence |
| `scripts/react.sh` | 👀 on the trigger comment, taken off at the end |
| `scripts/build-prompt.sh` | runtime block, instruction, then the thread — and it decides read vs write |
| `scripts/sanitize.py` | strips hidden markup out of the untrusted block |
| `scripts/run-fx.sh` | one `fx ask --json`, pull out the answer, scrub secrets, record the spend |
| `scripts/redact.py` | the secret scrubber, shared by the answer and the session |
| `scripts/session-html.py` | `fx session --json` → one readable HTML file |
| `scripts/post-comment.sh` | upsert one comment, found by a hidden marker |
| `scripts/open-pr.sh` | branch, commit, push, open the draft PR |

If a change wants a tenth file, ask whether it belongs in the prompt instead.

## The decisions, and why each one

**Two permission modes, and they are different mechanisms.** Read mode is
`auto` plus deny rules on `edit` and `shell` in `~/.fx/settings.json`; the rules
hide those tools, so the model never spends a step finding out and the run exits
0. Write mode is `full-access`, because the runner is a throwaway container and
**the real boundary is the workflow's `permissions:` block, not fx's review
layer** — which would only add latency and a billed model request per unresolved
call. Verified headless: no acknowledgement prompt. Never full-access in read
mode; it disables the checks the deny rules ride on, and a question has no
business running commands.

**Rules go in the global settings file, not a workspace profile.** The checkout
path changes between runs, so a workspace-scoped rule silently would not apply.

**The model is set in the config file, not `FX_MODEL`.** One owner for the
value. `models` is keyed by provider; the gateway's is `models.gateway`.

**No version pin for fx.** It ships weekly and pinning an agent ages badly. The
release tag is resolved only to key the cache, and a failed resolve falls back
to a *dated* key — `actions/cache` never overwrites an existing key, so a fixed
fallback would pin a stale binary forever.

**Cost comes from `fx usage --json`, not from `fx ask`.** `ask` reports tokens
and no price. `fx usage` keeps a local ledger with dollars in it, and the
runner's HOME is new every job, so the only spend in it is this run's.

**Secrets are scrubbed from anything published.** fx never prints the key, but
in write mode its shell tool is a child process and inherits the environment —
measured, an agent-run `test -n "$AI_GATEWAY_API_KEY"` reports PRESENT. GitHub
masks secrets in logs, not in API bodies or artifacts. Hence `redact.py`, on
both the answer and the session HTML. It is a backstop, not the control: the
control is a gateway key with its own budget, so a leak costs $20 and one
rotation.

**Hidden markup is stripped from the untrusted block only.** HTML comments,
zero-width characters, image alt text, hidden attributes. The list came from
`anthropics/claude-code-action`, `docs/security.md`.

**Post `final_output`, not `output`.** The finished answer, not the running
commentary. This is what makes the action model-agnostic.

**One comment, updated.** A marker on the first line, invisible when rendered.
GitHub keeps the edit history, so overwriting loses nothing. The comment step
runs under `always()`: a red X with no comment is the worst outcome for someone
who typed a command and walked away.

**Pull requests are drafts, and only carry what fx touched.** The tree is
snapshotted before the run so a previous step's build output cannot ride along,
and the draft state is the human-oversight step — the same reason
`claude-code-action` stops at a branch and makes a person click the button.

**`github_token` is an input defaulting to `github.token`.** Bring your own App
token for a named bot, and for CI to run on what it pushes. No hosted service,
ever — that is the line between this and the opencode model.

## Do we need actions/toolkit?

Not yet. Everything we use it for has a shell equivalent already on the runner:
`$GITHUB_OUTPUT` for `core.setOutput`, `::error::`/`::warning::` for
`setFailed`/`warning`, `gh api` for Octokit, `actions/cache@v4` as a step.

The moment to switch is real API work shell makes awkward: review comments
anchored to diff lines, pagination with retries, partial failure across several
calls. That is the line `shaftoe/pi-coding-agent-action` crossed, and it now
ships a `dist/index.js` measured in hundreds of kilobytes. If it does become a
JS action, do it wholesale — a composite that shells out to `node` is the worst
of both.

## refs/

`refs/` holds clones of the prior art, gitignored. `refs/README.md` says what is
worth reading in each and how to refresh them. Read those before adding a
feature: three of the things in this action came straight out of them.

## Testing a change

There is no unit test worth writing for 300 lines of glue. Test it the way it
runs:

```bash
export RUNNER_TEMP=$(mktemp -d) GITHUB_OUTPUT=$RUNNER_TEMP/out
export GITHUB_REPOSITORY=owner/repo GH_TOKEN=$(gh auth token)
export INPUT_PROMPT="Summarise this issue in one line." INPUT_ISSUE_NUMBER=1
bash scripts/build-prompt.sh && cat "$RUNNER_TEMP/fx-prompt.md"
```

`python3 -c 'from scripts.sanitize import sanitize'` for the sanitizer, with the
cases listed in its docstring. Then end to end: push a branch, point a workflow
at `uses: khalido/fx-agent-action@<branch>`, comment on a throwaway issue.

Run `shellcheck scripts/*.sh` and `actionlint` before pushing.

## References

- [Creating a composite action](https://docs.github.com/en/actions/tutorials/create-actions/create-a-composite-action)
- [Metadata syntax](https://docs.github.com/en/actions/reference/metadata-syntax-for-github-actions) — the `action.yml` schema
- [Workflow commands](https://docs.github.com/en/actions/reference/workflow-commands-for-github-actions) — `::error::`, `$GITHUB_OUTPUT`, step summaries
- [Security hardening](https://docs.github.com/en/actions/security-for-github-actions/security-guidelines/security-hardening-for-github-actions) — untrusted input, `pull_request_target`, token scopes
- [claude-code-action security](https://github.com/anthropics/claude-code-action/blob/main/docs/security.md) and [solutions](https://github.com/anthropics/claude-code-action/blob/main/docs/solutions.md)
- [fx docs](https://fx.sh/docs): [`fx ask`](https://fx.sh/docs/using-fx/fx-ask), [permissions](https://fx.sh/docs/configure-fx/permissions), [sessions](https://fx.sh/docs/using-fx/sessions), [skills](https://fx.sh/docs/capabilities/skills)
- [AI Gateway budgets](https://vercel.com/docs/ai-gateway/observability-and-spend/budgets) — the per-key spend cap

## Publishing

A tag is the version people use. Cut `v1.2.3`, then move the floating `v1` tag
to it, because `uses: khalido/fx-agent-action@v1` is what the README says.

```bash
git tag -a v1.0.0 -m "..." && git push origin v1.0.0
git tag -f v1 v1.0.0 && git push -f origin v1
```

Listing on the Marketplace is a checkbox on the release form and needs the
`branding` block in `action.yml`, which is already there.
