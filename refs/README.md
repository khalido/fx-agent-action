# refs

Actions we learn from. Everything here except this file is gitignored — clone
what you need, read it, delete it when it goes stale.

```bash
cd refs
gh repo clone shaftoe/pi-coding-agent-action
gh repo clone anomalyco/opencode -- --depth 1 --filter=blob:none
gh repo clone anthropics/claude-code-action -- --depth 1
```

Refresh with `git -C refs/<name> pull` before trusting anything you read here;
both move weekly.

| Repo | Why it's here |
|---|---|
| [shaftoe/pi-coding-agent-action](https://github.com/shaftoe/pi-coding-agent-action) | The closest prior art: a JS action that puts every piece of GitHub logic in the action itself. `packages/pi-platform-github/` is the part worth reading — reactions, comment upsert, author gating. |
| [anomalyco/opencode](https://github.com/anomalyco/opencode) | The opposite design: `github/action.yml` is a thin composite that installs the binary and runs `opencode github run`, so the GitHub logic lives in the agent. Also the reference for a GitHub App + OIDC token exchange. |
| [anthropics/claude-code-action](https://github.com/anthropics/claude-code-action) | The most developed of the three. `docs/security.md` is the one to read — actor write-access checks, the hidden-markup list we now strip, why it stops at a branch instead of opening a PR. `docs/solutions.md` is a catalogue of workflows worth stealing. |
| [actions/toolkit](https://github.com/actions/toolkit) | What you'd reach for if this ever becomes a JavaScript action. `AGENTS.md` says when that would be. |
| [actions/checkout](https://github.com/actions/checkout) | The canonical well-behaved action: input handling, `persist-credentials`, and how a widely-used action documents itself. |

Two upstreams that are not actions but decide how this one behaves:

| | |
|---|---|
| [vercel-labs/fx](https://github.com/vercel-labs/fx) | The agent. Apache-2.0, Zig, weekly releases. `fx --help` on a current binary beats the docs when they disagree. |
| [GitHub Actions docs](https://docs.github.com/en/actions) | Metadata syntax, workflow commands, security hardening — the three pages linked from `AGENTS.md`. |
