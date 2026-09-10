# Prior art: coding agents that run on GitHub events

What the other actions do, what this one borrowed, and where it differs on purpose. Surveyed 2026-09-10 against the clones in `refs/` and the public docs; every claim has a file path or URL behind it, and anything that could not be pinned to one is marked **unverified**. Refresh the clones (`refs/README.md`) before trusting a line that matters.

## What was read, and how fresh

| Source | How | Freshness |
|---|---|---|
| `anthropics/claude-code-action` | local clone `refs/claude-code-action` | HEAD `5ccc3a3`, 2026-09-08 |
| `anomalyco/opencode` | local clone `refs/opencode` | HEAD `830d5eb`, 2026-09-09 (v1.18.30) |
| `shaftoe/pi-coding-agent-action` | local clone `refs/pi-coding-agent-action` | HEAD `1f0be23`, 2026-09-08 (v2.28.0) |
| code.claude.com/docs/en/github-actions | WebFetch | fetched 2026-09-10 |
| opencode.ai/docs/github | WebFetch (matches local `packages/web/src/content/docs/github.mdx`) | fetched 2026-09-10 |
| `google-github-actions/run-gemini-cli` | web (raw GitHub) | fetched 2026-09-10 |
| `openai/codex-action`, Codex Cloud | web | fetched 2026-09-10 |
| GitHub Copilot coding agent + code review | docs.github.com, github.blog changelogs | fetched 2026-09-10 |
| OpenHands, CodeRabbit, Cursor, Devin, Amazon Q, gh-aw, goose, Aider, Sweep | web | fetched 2026-09-10 |

Note: `refs/opencode/github/index.ts` is **dead code**. `github/action.yml` runs `opencode github run`, and the live implementation is `packages/opencode/src/cli/cmd/github.handler.ts` (1606 lines). The two disagree (the root `index.ts` supports only two events; the handler supports six). Read the handler.

---

## Comparison table

Six dimensions: trigger, actor checks, auth, output UX, safety, recipes.

| Action | Trigger | Actor checks | Auth | Output UX | Safety | Documented recipes |
|---|---|---|---|---|---|---|
| **claude-code-action** | `@claude` default; regex `(^\|\s)@claude([\s.,!?;:]\|$)` case-insens., in comment / review body / issue+PR **title and body** on open; also `assignee_trigger`, `label_trigger` (default `claude`); any `prompt` input fires unconditionally | **Inside the action.** Write/admin via collaborator API; non-`User` account rejected unless in `allowed_bots`; `allowed_non_write_users` bypass (only with own `github_token`); `workflow_run` checks upstream actor too; `schedule`/`dispatch` skip write check but **not** the bot check | GitHub: OIDC → `api.anthropic.com/api/github/github-app-token-exchange` for a Claude App token, else your `github_token`. Model: API key, OAuth (subscription), Bedrock/Vertex/Foundry OIDC, or Anthropic workload-identity federation | Sticky tracking comment with spinner GIF + progress checkboxes + job link + branch link; `use_sticky_comment`; buffered+classified inline review comments; step summary (`display_report`, off by default); "Fix this" links; branch link, **no PR** (human clicks prefilled PR page) | Sanitizer (HTML comments, invisible unicode, image alt, link titles, hidden attrs, entities, token redaction); tag mode allowlists tools and uses `--permission-mode acceptEdits`; base-branch restore of `.claude/`, `CLAUDE.md` etc. on PRs; bubblewrap PID isolation + env scrub when `allowed_non_write_users` set; `CLAUDE_CODE_SCRIPT_CAPS`; app token revoked in a post step | PR review (basic + tracked), path-filtered review, external-contributor review, review checklist, scheduled maintenance, issue triage, doc sync, security/OWASP review, CI-failure auto-fix, issue dedup, test-failure analysis, agent-approval-check |
| **opencode** | `/opencode` or `/oc`, `MENTIONS` input, case-insensitive **`includes()`** anywhere in body; bare mention alone → "Summarize this thread"; auto on `issues`, `pull_request`, `schedule`, `workflow_dispatch` (all need `prompt`, except `pull_request` which defaults to review) | **Inside the action**, write/admin via collaborator API, **but skipped entirely when `use_github_token: true`** and skipped for `schedule`/`workflow_dispatch`. Docs' own manual-setup workflow uses `use_github_token: true` with an `if:` of only `contains(body,'/oc')`: no actor gate at all | GitHub App `opencode-agent` + OIDC → `api.opencode.ai/exchange_github_app_token`; or `use_github_token: true` to skip. **Vendor runs a token service.** Model keys are yours | 👀 reaction added and removed; one comment created up front (`[Working...](run url)`) then updated live with tool-call progress; footer with run link and **public session share URL on opencode.ai** (default true for public repos) with a generated social-card image; opens a real PR from issues, pushes to branch on PRs, handles fork branches | Session created with `permission: [{permission:"question", action:"deny", pattern:"*"}]` so headless never blocks. Images from `user-attachments` downloaded and passed as files. **No prompt-injection sanitizer found** in the handler | Explain an issue, fix an issue (branch + PR), review PR and make changes, review specific code lines, scheduled task, PR auto-review, issue triage with account-age filter |
| **pi-coding-agent-action** | `/pi ` (trailing space) default; matching is in the **workflow `if:`** (`startsWith(github.event.comment.body,'/pi ')` or `github.event.review.body`); stripping inside is a plain `String.replace(trigger,'')`; `prompt` input for non-interactive; assignment triggers by workflow `if:` on `github.event.assignee.login` | **None inside the action.** README tells you to gate with `if: github.actor == '<my-user>'` and skip forks. Its own reusable workflow takes an `allowed_actor` input | Plain `github_token` input (required). Gist scope PAT needed for `share_session`. Model provider + key as inputs, plus base_url override, Bedrock | 👀 reaction on the trigger comment, add and remove; `update_comment: true` upserts by marker `<!-- pi-coding-agent-comment -->`, with a second marker for review-comment replies; session HTML and JSONL exports as outputs; `share_session` uploads HTML to a secret Gist and returns a pi.dev viewer link (or self-hosted Opengist); rich outputs incl. `cost`, `input_tokens`, `duration_seconds` | `sanitizeContent` strips HTML comments, invisible unicode, control chars (keeps `\n\r\t`); `loaded_tools` allowlist with fail-fast on unknown names; diff caps (`diff_max_lines`, `diff_max_bytes`, `diff_ignore_patterns`); ignores `.github/workflows/pi.yml`. **Caution in README: project trust always on**, so any `AGENTS.md`/`.pi/` in the checkout steers the agent | Issue assistance, PR assistance, automated code review, recurring tasks (weekly dep audit, daily doc sync), on-demand PR review via `workflow_dispatch` + `pr_number`, assignment triggers, chaining sessions via outputs |
| **run-gemini-cli** | `@gemini-cli` then a sub-command: `/review`, `/triage`, `/approve`, or bare mention → general invoke. All `startsWith`. A **dispatch workflow** routes to reusable `workflow_call` workflows. Auto on `pull_request.opened` (non-fork) → review; `issues.opened/reopened` → triage. No label or assignee trigger | **In the workflow `if:`**: `github.event.sender.type == 'User'` + `contains(fromJSON('["OWNER","MEMBER","COLLABORATOR"]'), author_association)`. Fork PRs excluded from auto-review by `head.repo.fork == false`. Scheduled triage is a separate workflow with no actor check | GitHub: `GITHUB_TOKEN` or a custom App via `actions/create-github-app-token` (recommended in README). Google: exactly one of `gemini_api_key`, `google_api_key`+Vertex, or GCP Workload Identity Federation (OIDC, `id-token: write`). No hosted vendor service | Immediate ack comment ("I've received your request... track my progress in the logs"), failure comment on unrecognised command; `GITHUB_STEP_SUMMARY` block with prompt/response/error; optional `upload_artifacts`; review comments posted inline via the GitHub MCP server; `/approve` path creates branch + PR. No reactions, no sticky comment | `docs/trust-guidance.md` splits trusted vs untrusted data; `settings.tools.core: []` disables built-ins and uses an explicit MCP `includeTools` allowlist per workflow; triage analysis step runs with `GITHUB_TOKEN: ''` and a **separate** job applies labels after re-validating them against the real label list; `maxSessionTurns: 25`; `timeout-minutes: 7`; concurrency per issue with `cancel-in-progress: true`; prompt forbids `$(...)` command substitution | `gemini-dispatch`, `pr-review`, `issue-triage` (+ `gemini-scheduled-triage`), `gemini-assistant` (`gemini-invoke`, `gemini-plan-execute`) |
| **openai/codex-action** | None built in. You write the `on:` block; the action does not parse mentions | **Inside the action**: write access required by default; `allow-users` (names or `*`), `allow-bots`, `allow-bot-users` | `OPENAI_API_KEY` / `AZURE_OPENAI_API_KEY` input, optional `responses-api-endpoint`. No OIDC. No hosted service | Single `final-message` output. Posts nothing itself; the README example pipes it into a comment step | `safety-strategy`: `drop-sudo` (default), `unprivileged-user`, `read-only`, `unsafe`; separate `permission-profile`/`sandbox`. `docs/security.md` names prompt injection via PR bodies/commit messages, warns read-only sandbox + retained sudo leaks the API key via procfs, says run the action last in the job, pass untrusted values via `env:` not interpolation | Build-your-own PR review; `examples/test-sandbox-protections.yml`, `examples/unprivileged-user.yml` |
| **Codex Cloud (hosted)** | `@codex review`, `@codex security review`, `@codex fix the CI failures` as PR comments; admin-enabled automatic review on PR open | Configuring it needs push/admin; per-comment gating not documented (**unverified**) | Hosted OpenAI service, ChatGPT account sign-in, runs in OpenAI's cloud | Comments as `chatgpt-codex-connector`; 👀 while working, 👍 on approve; inline comments tagged `[P0]`/`[P1]` only | Deliberately scoped to P0/P1 to limit noise; `AGENTS.md` "Code Review Rules" customise focus | Automatic PR review, security review, fix-CI task, parallel attempts, delegate from Slack/Linear/GitLab |
| **Copilot coding agent (hosted)** | Assign an issue to Copilot; `@copilot` in a PR comment; Copilot Chat; scheduled automations; assign a security-campaign alert | Paid plan + admin enablement; repos can opt out; branch rulesets may need Copilot as a bypass actor. Admin-gated, not per-user write-checked | Fully hosted by GitHub; no key or OIDC visible to you | Ephemeral Actions-powered env, draft branch/PR, visible session logs, can post a plan first. Code review posts High/Medium/Low comments, `Comment`-type review by default; since 2026-09-01 can be authorised to **approve** PRs | Default-on network firewall with a recommended allowlist; **firewall covers only the agent's Bash tool**, not MCP servers or `copilot-setup-steps.yml`; blocked requests surface in the PR body/comment. Hard 59-minute session cap. One premium request per session since 2025-07-10. No explicit prompt-injection stance found (**unverified**) | Bug fixes, feature implementation, test coverage, docs, tech debt, logging, merge-conflict resolution, security-alert remediation |
| **Amazon Q Developer (hosted app)** | Label `Amazon Q development agent` on an issue, or comment `/q dev`; on PRs `/q <instruction>`; `/q review`, which also runs automatically on new/reopened PRs | GitHub App install; per-user gating not documented (**unverified**) | GitHub App tied to an AWS account registration for quota | Comments on the issue with a link, then opens a PR; iteration posts further comments and commit links | Monthly cap on feature-development runs unless registered to an AWS account | Feature development, code review, security fixes, Java/legacy transformation |
| **OpenHands resolver** | Apply the label **`fix-me`** (or `fix-me-experimental`) to an issue | Whatever the workflow's `if:` says (**unverified** beyond the shipped workflow) | PAT with contents/issues/PRs/workflows read-write + an LLM API key | "Either a pull request or a message that it wasn't able to fix the issue" | Not documented in what was reachable (**unverified**; `docs.all-hands.dev` now redirects and the canonical page 404'd) | Auto-fix a labelled issue |
| **CodeRabbit (hosted)** | `@coderabbitai <command>` PR comments: `review`, `full review`, `pause`, `resume`, `ignore`, `resolve`, `approve`, `generate docstrings`/`unit tests`/`sequence diagram`, `autofix`, `fix-ci`, `rate limit`, `configuration`, `help` | **Unverified** | GitHub App | Inline PR comments, thread resolution, approvals | **Unverified**; `review` vs `full review` both consume one PR review from the allowance | Incremental review, full review, docstrings, unit tests, sequence diagrams, autofix, CI fix |
| **Cursor Bugbot / cursor-agent** | Bugbot: automatic on PR push; manual re-trigger with `cursor review` or `bugbot run`. `cursor-agent` CLI: no built-in trigger, wire your own | GitHub App level (**unverified** per-user) | Bugbot: GitHub App. CLI: `CURSOR_API_KEY` secret | Inline comments with fix suggestions, a "Cursor Bugbot" status check, "Fix in Cursor"/"Fix in Web" links | Autofix capped at **max 3 attempts per PR** to stop loops; docs recommend "restricted autonomy": agent edits files only, git/PR steps stay deterministic | Security (eval/exec), license compliance, deprecated APIs, style |
| **Devin Review** | `/devin review` on a PR (case-insensitive); auto on open/push/ready-for-review; swap `github.com`→`devinreview.com`; `npx devin-review <pr-url>` | Org members of the installing org; Devin acts with org-level permissions regardless of who invoked | GitHub App (write) or PAT (read-only) | Findings categorised Bugs/Flags/Security with CWE tags | Per-PR auto-review caps and ACU spend limits (enterprise); docs recommend branch protection; cannot create repos | PR review, autofix of other bots' review comments via an allowlist |
| **gh-aw (githubnext/github)** | Markdown + YAML frontmatter compiled by `gh aw compile` into a hardened `.lock.yml`; triggers are whatever the frontmatter declares | Whatever the compiled workflow declares | Multi-engine: Copilot (default), Claude, Codex, Gemini, each with its own key | Safe outputs are applied by **separate jobs** after the agent job | "Minimal permissions and no write access by default"; tools restricted to explicitly configured MCP; cost via `gh aw logs`. Self-described "research prototype" | Sample workflows in `githubnext/agentics` |
| **goose action (community, alpha)** | Label `goose` on an issue → PR; `@goose-ai` on a PR; `@goose-ai rollback` | Not documented (**unverified**) | `OPENAI_API_KEY`/`ANTHROPIC_API_KEY` + `GH_TOKEN` | Opens a PR; rollback command | "Always review goose changes"; not GitHub-certified | Issue → PR, PR assistance, rollback |
| **Aider** | No official action. `mirrajabi/aider-github-action` (59 stars, last push 2026-02-16, unofficial) runs Aider in a container and pushes a branch | Whatever your workflow says | API key via `api_key_env_name`/`api_key_env_value` | Pushes to a branch | None documented | "Issue to PR" via `mirrajabi/aider-github-workflows` |
| **Sweep** | Legacy: issue titled `Sweep:`, or the `Sweep` label, or a `Sweep:` comment prefix | n/a | n/a | n/a | n/a | Effectively unsupported: repo description is now "AI coding assistant for JetBrains", last push 2025-09-18 |

---

## Per-action notes

### anthropics/claude-code-action

- The trigger regex is **not** `startsWith`. `src/github/validation/trigger.ts` builds `` new RegExp(`(^|\\s)${escapeRegExp(phrase)}([\\s.,!?;:]|$)`, "i") `` and tests it against comment body, review body, and issue/PR **title and body** on `opened`. So `@claude` mid-sentence fires, and `@claude-bot` does not (the FAQ says exactly this: `docs/faq.md:209`).
- **A `prompt` input short-circuits every trigger check**: `trigger.ts` line 1 of `checkContainsTrigger` returns `true` unconditionally when `prompt` is set. That is what makes "agent mode" work on `schedule`, and it is why the actor checks (which still run) carry the whole security load in automation workflows.
- Two modes, auto-detected in `src/modes/detector.ts`: **tag** (mention/assignee/label, creates a tracking comment, tool allowlist) and **agent** (a `prompt` was given, no tracking comment). `track_progress: true` forces tag mode on `pull_request`/`issues` events and validates the event/action combination, throwing on unsupported ones.
- Tag mode's allowlist **deliberately omits Edit/MultiEdit/Write** and instead sets `--permission-mode acceptEdits`, with a comment explaining why: listing them "would grant blanket write access to the whole runner" whereas `acceptEdits` auto-allows edits inside `$GITHUB_WORKSPACE` and denies writes outside it (`src/modes/tag/index.ts`). This is the same problem fx solves with global deny rules, solved the other way round.
- **It never opens a PR.** `docs/security.md` "Pull Request Creation": Claude commits to a branch and posts a link to the prefilled PR-creation page, "ensuring human oversight". `docs/capabilities-and-limitations.md` adds that it cannot submit a formal review or approve a PR.
- Branch behaviour is event-dependent: issue → new branch; open PR → push to the existing PR branch; closed PR → new branch (`docs/capabilities-and-limitations.md`, `src/github/operations/branch.ts`). `branch_name_template` supports `{{prefix}} {{entityType}} {{entityNumber}} {{timestamp}} {{sha}} {{label}} {{description}}`; `validateBranchName` enforces ~10 git ref rules before use.
- On pull requests it **restores Claude config from the base branch**: `.claude/`, `.mcp.json`, `.claude.json`, `.gitmodules`, `.ripgreprc`, `CLAUDE.md`, `CLAUDE.local.md`, `.husky/`, keeping the PR versions under `.claude-pr/` for reference. The docs then spell out the residual hole: everything else (`package.json`, lockfiles, `bunfig.toml`, `.npmrc`, Makefile) is still PR-controlled, so a base-branch hook calling `bun run format` resolves through PR-supplied files (`docs/security.md`).
- `allowed_non_write_users` is a genuinely interesting escape hatch, and the mitigations around it are the interesting part: `apt-get install bubblewrap socat`, `sysctl kernel.apparmor_restrict_unprivileged_userns=0`, a pinned copy of `bun` for post-steps, re-prepending `/usr/bin` and clearing `LD_PRELOAD`/`BASH_ENV`/`DYLD_*` in `$GITHUB_ENV` afterwards (`action.yml`). Plus `CLAUDE_CODE_SCRIPT_CAPS: '{"edit-issue-labels.sh":2}'` to cap how many times a write-capable helper script can be called.
- Auth is a two-sided OIDC story. GitHub side: `core.getIDToken("claude-code-github-action")` → POST `https://api.anthropic.com/api/github/github-app-token-exchange`, with `additional_permissions` merged over defaults `{contents: write, pull_requests: write, issues: write}` (`src/github/token.ts`). A `workflow_not_found_on_default_branch` error is treated as a **skip, not a failure**, so adding the workflow in a PR does not go red. The token is revoked in an `always()` post step.
- Model side, five options: `anthropic_api_key`, `claude_code_oauth_token` (subscription), Bedrock, Vertex, Foundry, plus **workload identity federation** (`anthropic_federation_rule_id` + `anthropic_organization_id`) which exchanges the GitHub OIDC token for Claude API access and stores no static key at all.
- Inline review comments are **buffered and classified** by default (`classify_inline_comments: true`): comments without `confirmed: true` are held until the session ends, then a classifier decides real-review vs test/probe, "to prevent subagent test comments from reaching PRs" (`docs/solutions.md`).
- `use_sticky_comment` only applies on `pull_request` events, and the lookup is loose: it matches on the Claude App bot id `209825114`, **or** any Bot login containing "claude", **or** an exact body match (`src/github/operations/comments/create-initial.ts`). No hidden marker.
- The sticky comment is a spinner GIF hosted on `user-attachments` plus "Claude Code is working…" and a job-run link; progress checkboxes are written by the model into that same comment via the `mcp__github_comment__update_claude_comment` tool.
- `include_comments_by_actor` / `exclude_comments_by_actor` filter which actors' comments even reach the model, with a `*[bot]` wildcard. GraphQL returns bot logins without the `[bot]` suffix, so `resolveActorName` re-adds it before matching (`src/github/utils/actor-filter.ts`). Small detail, easy bug.
- `display_report` (step summary) and `show_full_output` are both **off by default** and carry explicit warnings that they publish model-authored content and tool results into publicly visible logs. `show_full_output` turns on automatically under `ACTIONS_STEP_DEBUG`.
- `agent-approval-check/` is the sleeper feature: a separate sub-action that requires **N human approvals on any PR containing agent-authored commits**, counted by committer email / bot login / bot APPROVED review, verified per-approver against the collaborators API, posted as a commit status you mark required. Runs from `pull_request_target` + `issue_comment` specifically so a PR cannot edit the check to approve itself. README says "This is the same gate Anthropic runs internally on every agent-authored PR."
- `settings` accepts either inline JSON or a path, and supports `model`, `env`, `permissions.allow`/`deny`, and `hooks`. `enableAllProjectMcpServers` is always forced to `true` by the action.
- The action also ships `plugins` / `plugin_marketplaces` inputs, and the docs recommend invoking a **skill** as the prompt (`prompt: "/code-review:code-review --comment owner/repo/pull/123"`), with the caveat that you must still name the MCP tool in `claude_args --allowedTools` because the action only starts that MCP server when it is listed.

### opencode (anomalyco/opencode)

- Mention matching is `bodyLower.includes(m)` over a comma-separated `MENTIONS` list (default `/opencode,/oc`), so `/oc` matches inside any word, including `/opencode`. Bare mention with nothing else becomes `"Summarize this thread"`; on a review comment it becomes a targeted "review these lines" prompt built from `path`, `line` and `diff_hunk` (`packages/opencode/src/cli/cmd/github.handler.ts`).
- **The write-access check is skipped when `use_github_token: true`** (`assertPermissions`: "skipped (using github token)"), and the manual-setup workflow in both `github/README.md` and `docs/github.mdx` uses exactly that, with an `if:` of only `contains(github.event.comment.body,'/oc')`. On a public repo with those docs followed literally, any commenter can run the agent. This is a real difference from fx-agent-action, which runs the write check inside the action regardless of token.
- `assertPermissions` and `addReaction` are both skipped for `schedule` and `workflow_dispatch` (`REPO_EVENTS`), which is correct for schedule and arguable for dispatch.
- Session permission is set once at creation: `permission: [{permission: "question", action: "deny", pattern: "*"}]`. Same idea as fx's deny rules, but it denies the *asking*, not the tools, so the agent still has edit and shell.
- **Sessions are shared publicly by default on public repos.** `share` defaults on unless the repo is private; the footer embeds a `social-cards.sst.dev` image with the session title base64'd into the URL, linking to `opencode.ai/s/<id>`. Worth naming explicitly when comparing: fx keeps the session as a 7-day artifact on the run page.
- Branch names: `opencode/issue<N>-<timestamp>` for issues, `opencode/{schedule,dispatch}-<6 hex>-<timestamp>` for repo events.
- On repo events it checks whether the agent switched branches itself and, if so, skips its own push/PR ("Agent managed its own branch"). Nice defensive touch for an agent that has git.
- `branchIsDirty(originalHead, expectedBranch)` and `hasNewCommits(base, head)` are the equivalent of fx's before/after tree objects, done with HEAD comparison rather than tree hashes.
- Images in comments are downloaded from `user-attachments` with the app token and passed to the model as files, with the markdown replaced by `@filename`. fx does not do this.
- No sanitizer. I grepped the handler and found no HTML-comment or zero-width stripping.
- OIDC: `core.getIDToken("opencode-github-action")` → `POST {oidc_base_url}/exchange_github_app_token`, default `https://api.opencode.ai`. Configurable base URL for self-hosted App installs, which is a nicer escape hatch than claude-code-action's hardcoded endpoint.
- `opencode github install` scaffolds the App install, workflow file, and secrets from the CLI.

### shaftoe/pi-coding-agent-action

- **No actor check anywhere in the action.** The README's "Securing your workflows" warning is the whole story, and its own reusable workflow exposes an `allowed_actor` input compared with `github.actor`, which is a single username, not a role. fx-agent-action checks inside the action, so it is stricter than this.
- The trigger default is `'/pi '` **with a trailing space**, and the workflow uses `startsWith(github.event.comment.body, '/pi ')` or `startsWith(github.event.review.body, '/pi ')`. Inside, stripping is `body.replace(getTrigger(deps), '')`: a plain string replace of the first occurrence anywhere, not an anchored strip.
- `pull_request_review` is supported as a trigger surface (the body lives on `payload.review`, not `payload.comment`), which fx does not handle. Worth copying: someone typing the trigger into a review summary is a natural gesture.
- Comment upsert uses **two** hidden markers, `<!-- pi-coding-agent-comment -->` for issue/PR comments and `<!-- pi-coding-agent-review-comment -->` for review-comment replies, and migrates comments that predate the second marker onto the correct one. fx uses a single marker; if it ever replies inside a review thread it will hit the same namespace problem.
- Reaction handling detects a review comment by `comment.pull_request_review_id !== undefined` and calls a different endpoint. This is the detail fx already borrowed (`scripts/react.sh`), and the credit in `action.yml` is accurate.
- `sanitizeContent` is narrower than claude-code-action's: HTML comments, `​-‏`, ` - `, `⁠-⁯`, `﻿`, and ASCII control chars minus `\n\r\t`. No image alt text, no hidden attributes, no HTML entities.
- The **project-trust caution** is the most interesting doc in the repo: because CI has no interactive user, the action always sets `projectTrusted: true`, so any `AGENTS.md`, `.pi/` config, or project extension in the checkout steers the agent. On a fork PR checkout that is a direct injection path. fx has the same exposure through whatever fx loads from the workspace and does not document it.
- Session sharing: exports self-contained HTML, uploads to a **secret Gist**, returns a `pi.dev/session/#<gistId>` viewer link. Also supports self-hosted Opengist. Needs a PAT with gist scope because `GITHUB_TOKEN` cannot create gists. fx's artifact approach avoids the extra token entirely; pi's gives you a link you can paste.
- Outputs are the richest of the three: `response`, `success`, `input_tokens`, `output_tokens`, `cost`, `duration_seconds`, `session_html_path`, `session_jsonl_path`, `share_url`, `gist_url`, `gist_id`.
- `loaded_tools` accepts an exact list and **fails early on an unknown tool name** rather than silently ignoring it. Small, good.
- It ships seven GitHub tools to the agent, including `create_pull_request_review` (a real GitHub review with inline comments anchored to diff lines, `COMMENT`/`APPROVE`/`REQUEST_CHANGES`), `get_ci_status` and `get_workflow_run_logs`. Both `create_pull_request` and `update_pull_request` support a `dry_run` mode.
- Cross-forge: `platform: forgejo|codeberg|gitea` and a `server_url` override, because self-hosted runners advertise an internally-reachable `GITHUB_SERVER_URL`. Not relevant to fx today but a cheap input if anyone asks.
- It hard-excludes `.github/workflows/pi.yml` from what the agent sees, and warns that `GITHUB_TOKEN` can never write under `.github/workflows/` even with `contents: write`.
- AGENTS.md-level detail: the action is bundled to a single `dist/index.js` via esbuild. This is the "line it crossed" that `fx-agent-action/AGENTS.md` refers to, and that framing is accurate.

### google-github-actions/run-gemini-cli

- The **dispatch pattern** is the structural idea worth stealing. One `gemini-dispatch.yml` listens on five event types, does the actor gate and the `startsWith` routing in a `github-script` step, then calls `gemini-review.yml` / `gemini-triage.yml` / `gemini-invoke.yml` / `gemini-plan-execute.yml` as reusable `workflow_call` workflows with `secrets: inherit`. One gate, many behaviours, each with its own tool allowlist and timeout.
- Sub-commands are `@gemini-cli /review`, `@gemini-cli /triage`, `@gemini-cli /approve`, and a bare `@gemini-cli <freeform>`. Unrecognised input falls through to a comment saying it could not process the request, rather than silence.
- The **triage split** is the best security idea in the survey: the analysis step runs with `GITHUB_TOKEN: ''` ("Do NOT pass any auth tokens here since this runs on untrusted inputs"), and a separate `label` job with a token applies the result **after re-validating the chosen labels against the real label list**, with the comment "we do this just in case someone was able to prompt inject malicious labels". `fx-agent-action/examples/triage.yml` has both halves: the workflow applies, the agent only picks, and the action's run step sets no `GH_TOKEN`.
- Tool policy is deny-by-default per workflow: `settings.tools.core: []` wipes the built-ins, then an MCP `includeTools` allowlist names exactly what the workflow needs (review gets three tools).
- Every workflow sets `timeout-minutes: 7` and a per-issue concurrency group with `cancel-in-progress: true`.
- The prompt itself carries a command-injection rule: "you MUST NOT use command substitution with `$(...)`, `<(...)`, or `>(...)`".
- No reactions and no sticky comment. It posts an ack comment up front and separate comments after, so a chatty PR accumulates them.
- Three mutually exclusive Google auth paths, validated in `action.yml` with a `GITHUB_STEP_SUMMARY` warning when zero or more than one is set. Good pattern for fx if it ever grows a second provider.
- **Gemini Code Assist is a different product**: a hosted GitHub App installed via Google Cloud, triggered with `/gemini` (not `/gemini-cli`), no workflow YAML in your repo. Do not conflate the two when citing "the Gemini one".

### openai/codex-action

- The cleanest separation of concerns in the survey: it is a **runner, not a bot**. No trigger parsing, no comment posting, one `final-message` output. Everything GitHub-shaped is your workflow's job.
- It still does the actor check inside the action, which is the right split: the thing that spends money enforces who may spend it, while the thing that formats comments stays in YAML.
- `safety-strategy` is orthogonal to the sandbox and the docs insist on it: "Permission profiles constrain commands that Codex runs; they do not replace the action's `safety-strategy`." Default `drop-sudo` revokes sudo before invoking the agent.
- `docs/security.md` has the sharpest single warning I found: a read-only sandbox **plus retained sudo** lets the agent read `OPENAI_API_KEY` out of procfs. fx's answer to the same class of problem is different and arguably weaker (deny the shell in read mode; redact on the way out in write mode), but the threat is identical and the fx README does not name procfs.
- Also recommends running the agent step **last in the job**, because it can spawn lingering processes or tamper with git hooks that later steps would run.

### GitHub Copilot coding agent

- The assignment model is the one thing nothing else here has: you assign an issue to a bot user and a draft PR appears. Cheap to imitate at the workflow level (`issues: [assigned]` + `if: github.event.assignee.login == '<bot>'`), which is exactly what pi documents.
- The firewall gap is worth knowing: it "only covers processes the agent starts via its Bash tool", not MCP servers and not `copilot-setup-steps.yml`.
- One premium request per session regardless of task size, and a hard 59-minute cap. Compare fx's `max_cost` tripwire plus the gateway budget: fx's model is more honest about the real cost, Copilot's is more predictable for the buyer.
- `copilot-setup-steps.yml` must have a job literally named `copilot-setup-steps` or it is ignored.

### The rest, briefly

- **gh-aw** is the most interesting architecture: agent workflows authored in Markdown, compiled to a locked-down `.lock.yml`, minimal permissions by default, and **safe outputs applied by separate jobs after the agent job finishes**. That last one generalises run-gemini-cli's triage split into a pattern. Self-described research prototype.
- **Cursor Bugbot** caps autofix at 3 attempts per PR, and its docs recommend "restricted autonomy": let the agent edit files, keep git and PR-comment steps deterministic. That is precisely fx's read-mode-plus-workflow-applies shape, described from the other direction.
- **CodeRabbit** has by far the richest command vocabulary (`review`, `full review`, `pause`, `resume`, `ignore`, `resolve`, `approve`, `generate docstrings`, `generate unit tests`, `generate sequence diagram`, `autofix`, `fix-ci`, `rate limit`, `configuration`, `help`). Useful as evidence for the *opposite* of fx's "no vocabulary to learn" stance: it is what fx is deliberately not.
- **OpenHands** uses a label (`fix-me`) rather than a comment, which is the lowest-friction trigger of all for an issue backlog and needs no phrase parsing.
- **Aider** has no official action. **Sweep** has pivoted to a JetBrains plugin. Both are honest "no" answers if anyone asks.

---

## Use cases catalogue

One line each, grouped, with who documents it.

### Review
- Review every PR on open and push. claude-code-action (`solutions.md` "Automatic PR Code Review"), opencode (`docs/github.mdx` PR example), pi (`update_comment` example), run-gemini-cli (`pr-review`), Cursor Bugbot, Copilot code review, Codex Cloud, CodeRabbit, Devin Review. **fx has this** (`examples/pr-review.yml`).
- Review only when specific paths change. claude-code-action ("Review Only Specific File Paths", `examples/pr-review-filtered-paths.yml`).
- Stricter review for first-time or external contributors. claude-code-action ("Review PRs from External Contributors", `author_association == 'FIRST_TIME_CONTRIBUTOR'`; `examples/pr-review-filtered-authors.yml`).
- Review against a fixed team checklist. claude-code-action ("Custom PR Review Checklist").
- Security-focused / OWASP review. claude-code-action ("Security-Focused PR Reviews"), Codex Cloud (`@codex security review`), Cursor Bugbot, Devin (CWE tags).
- Review a single hunk from an inline comment on the Files tab. opencode (passes path, line, diff_hunk), pi (`create_pull_request_review` with anchored comments).
- On-demand review of an arbitrary PR from the Actions tab. pi (`workflow_dispatch` + `pr_number`).
- Post a real GitHub Review (not a comment) with inline anchors. pi only, of the self-hosted three.
- Require N human approvals on any agent-authored PR. claude-code-action `agent-approval-check/`.

### Issues
- Triage and label a new issue. claude-code-action ("Issue Auto-Triage and Labeling", `examples/issue-triage.yml`), run-gemini-cli (`issue-triage` + `gemini-scheduled-triage`), opencode (triage with an account-age filter), Amazon Q. **fx has this** (`examples/triage.yml`).
- Detect duplicate issues. claude-code-action (`examples/issue-deduplication.yml`).
- Answer a question about the codebase on an issue thread. claude-code-action (`@claude What does this function do`), opencode (`/opencode explain this issue`), pi. **fx has this** (`examples/issue-notes.yml`).
- Implement from an issue and open a PR. opencode (`/opencode fix this`), Copilot (assign the issue), Amazon Q (`/q dev` or label), OpenHands (`fix-me` label), goose (`goose` label), Aider community action. **fx has this** (`examples/build-it.yml`, `/fx pr`).
- Trigger on assignment to a bot user. Copilot (native), pi ("Assignment Triggers"), claude-code-action (`assignee_trigger`).
- Trigger on a label. claude-code-action (`label_trigger`, default `claude`), OpenHands (`fix-me`), Amazon Q, goose, legacy Sweep.

### Scheduled and maintenance
- Weekly repository maintenance report as an issue. claude-code-action ("Scheduled Repository Maintenance").
- Dependency audit / bump with tests, as one PR. pi ("weekly dependency audit"). **fx has this** (`examples/weekly-deps.yml`).
- Daily documentation sync. pi ("daily documentation sync").
- Docs updated in the same PR when API files change. claude-code-action ("Documentation Sync on API Changes").
- Daily digest of yesterday's commits and open issues to the run log. claude-code-action (code.claude.com "Run on a schedule").
- Scheduled TODO sweep that opens an issue. opencode (schedule example).

### CI and repair
- Explain and fix a failing CI run. claude-code-action (`examples/ci-failure-auto-fix.yml`, `additional_permissions: actions: read`), Codex Cloud (`@codex fix the CI failures`), CodeRabbit (`fix-ci`).
- Analyse a failing test. claude-code-action (`examples/test-failure-analysis.yml`).
- Read workflow-run logs as a tool. pi (`get_workflow_run_logs`, `get_ci_status`), claude-code-action (`mcp__github_ci__*`).
- Resolve merge conflicts. Copilot coding agent.
- Fix review comments left by *other* bots. Devin (opt-in allowlist).

### Generation
- Generate docstrings, unit tests, or a sequence diagram on request. CodeRabbit.
- Add test coverage. Copilot coding agent.
- Java/legacy code transformation. Amazon Q.

### Manual and ad hoc
- Manual code analysis from the Actions tab. claude-code-action (`examples/manual-code-analysis.yml`), opencode (`workflow_dispatch` + `prompt`), pi.
- Plan first, then execute on approval. run-gemini-cli (`/approve` → `gemini-plan-execute.yml`), Copilot (posts a plan before code).

---

## Gaps and recommendations for fx-agent-action

Ranked by value. Each says what the others do and whether fx should copy it.

### 1. Actor checks: now inside the action

`scripts/check-actor.sh` runs first and fails the run if either check says no: write or admin via `repos/{repo}/collaborators/{actor}/permission` on issue and PR events, and not-a-bot on every event, with `allowed_non_write_users` and `allowed_bots` as the exceptions. That is the claude-code-action and codex-action shape. It matters because `author_association`, which the workflow `if:` still uses as a cheap filter, is **not** a permission check: `COLLABORATOR` is anyone with a repo invitation, `MEMBER` is any org member regardless of repo access, and it cannot be applied to `issues`-only events where there is no comment.

Still different from claude-code-action: no `workflow_run` upstream-actor check, and the `allowed_non_write_users` escape hatch has no sandboxing behind it (claude-code-action installs bubblewrap and scrubs the environment when it is set). fx's answer is that the exception is only sane in read mode with a fixed prompt, and the input description says so.

### 2. Trigger: now a mention, matched anywhere

`/fx` by default, whole word, any case, `(^|\s)phrase(?=[\s.,!?;:]|$)`, the same regex shape as claude-code-action's. The request is what follows the mention. `pull_request_review` bodies are read as well as comments (`.comment.body // .review.body`), which pi also does and claude-code-action does in `trigger.ts`.

Still missing, all pure workflow recipes rather than action changes: a **label trigger** (`issues: [labeled]` + `if: github.event.label.name == 'fx'` + `prompt_file`), which OpenHands, Amazon Q, goose and claude-code-action offer and is the lowest-friction trigger for a backlog; and an **assignee trigger** (Copilot natively, pi and claude-code-action by option). Both belong in `examples/`.

### 3. Adopt the triage token split

`examples/triage.yml` has the shape run-gemini-cli documents: the model picks from a list, a separate step with a token applies. The token split is already real in this action, by construction rather than by declaration: the "Run fx" step in `action.yml` sets no `GH_TOKEN`, and every example checks out with `persist-credentials: false`, so the model run holds no GitHub credential in either mode. run-gemini-cli adds one thing worth copying: it **re-validates the model's labels against the real label list** before calling the API ("just in case someone was able to prompt inject malicious labels"). The fx example now does the same against `labels.txt` rather than relying on `gh issue edit` rejecting an unknown name.

### 4. Nothing caps concurrent spend or wall time inside the action

- `max_steps: 30` and `max_cost: 1` (after the fact) are the only brakes; the README is honest that the gateway budget is the real one.
- run-gemini-cli sets `timeout-minutes: 7` on every workflow. fx's examples use 10 to 30. Fine.
- `examples/triage.yml` fires on `issues: [opened]`, so an import or a spam wave starts one paid run per issue. A per-issue `concurrency:` group collapses re-runs of the same issue but not a wave of different ones; the gateway budget is what stops that. Both it and `weekly-deps.yml` now carry a group like the other three.
- `max_cost` fails the step after the fact, and `open-pr.sh` runs under `always()`, so a run that blew the cap still opens its draft PR. Right call for not losing work; the input description now says so.

### 5. Prompt-injection surface not covered by `sanitize.py`

`sanitize.py` covers the untrusted block. Three exposures the other actions name and fx does not:

- **Repo-supplied agent instructions.** pi's README has a `[!CAUTION]` block saying project trust is always on in CI, so `AGENTS.md` and `.pi/` in the checkout steer the agent. fx presumably loads `AGENTS.md` from the workspace too. On a fork-PR checkout that is an injection channel with no sanitizer in front of it. `examples/pr-review.yml` already skips forks, which mostly covers it, but the README should say why in one line.
- **PR head vs base for config.** claude-code-action restores `.claude/`, `CLAUDE.md` etc. from the base branch on PRs and documents the residual hole (lockfiles, `bunfig.toml`, hooks still come from the head). fx does not need the full mechanism, but "on a PR, the agent's instructions come from the PR's own checkout" is a sentence the README owes the reader.
- **Secrets via procfs.** codex-action's `docs/security.md` warns that a read-only sandbox with sudo retained lets the agent read the API key from procfs. fx's read mode denies the shell entirely, which is a stronger answer, and `AGENTS.md` already documents that write mode's shell inherits the key. Worth a cross-reference; it makes fx's read-mode design look deliberate rather than lucky.

### 6. Output UX gaps, in order of value

- **Inline review comments.** fx posts one top-level comment. pi ships `create_pull_request_review` with diff-anchored comments; claude-code-action has an MCP server for it (with buffering and classification); run-gemini-cli uses the GitHub MCP server. For a PR-review action this is the single biggest UX difference, and `AGENTS.md` already names it as the line at which fx would need `actions/toolkit`. That assessment holds: `gh api` can post a review with `comments[]`, but anchoring to diff lines correctly is where shell stops being pleasant.
- **The comment is posted only at the end.** opencode and claude-code-action both create a comment immediately and edit it as the run progresses; fx uses the 👀 reaction instead. For a 30-step run the reaction is arguably better (no noise, no half-written answers) and the run link is one click away. Keep it, but note that a reaction is invisible in email notifications while a comment is not.
- **Structured outputs.** claude-code-action exposes `structured_output` via `--json-schema`, so a workflow can branch on typed fields instead of parsing prose. `examples/triage.yml` currently parses a comma-separated line out of `response`. If fx can get JSON out of `fx ask`, one `response_json` output would make every "agent decides, workflow acts" recipe cleaner. Check what `fx ask --json` already gives before building anything.
- **Session sharing as a link.** pi uploads the session HTML to a secret Gist and returns a `pi.dev` viewer URL; opencode shares to `opencode.ai`. fx's 7-day artifact needs a GitHub login and a download. The artifact is the better default (no third party, no extra token); a `session_url` you can paste into Slack is the thing it cannot do.

### 7. Recipes worth adding to `examples/`

In rough order of likely use: **CI-failure explainer** (`workflow_run` on a failed CI workflow, `mode: read`, feed it the job log); **path-filtered doc sync** (`paths:` filter + `mode: write`); **manual `workflow_dispatch` analysis** with a free-text `prompt` input; **issue dedup** on `issues: [opened]`; **label trigger** (`issues: [labeled]`, `if: label.name == 'fx'`). All five are pure YAML, no action changes. The README currently points at claude-code-action's `solutions.md` for these, which is fine but sends people away.

### 8. Small, cheap

- `branch_prefix` exists but there is no branch-name template. claude-code-action offers `{{prefix}}/{{entityType}}-{{entityNumber}}-{{timestamp}}/{{label}}/{{description}}`; pi offers `{number}/{timestamp}/{title}`. fx's fixed shape is probably right for a small tool; a `{title}` slug is the one variable people actually ask for.
- `base_branch` has no input. claude-code-action has one. Anyone on a `develop`-based flow needs it.
- No `version` input for fx, by design and documented. pi bundles a fixed SDK version and ships a dependency table; opencode resolves latest the same way fx does. fx's reasoning in `AGENTS.md` is sound, but the failure mode (an fx release changes `--json` output and every user's action breaks at once with no rollback) is real and nothing in the repo mitigates it. The README now says that pinning the action tag does **not** pin the agent.
- Commit signing: claude-code-action offers both API-based signing (`use_commit_signing`) and SSH signing (`ssh_signing_key` + `bot_id`/`bot_name`). fx has neither. Only matters for repos that require verified commits, but that is a hard blocker when it applies, and the API path is a small change (commit via `gh api` instead of `git commit`).

### Where fx-agent-action is arguably better

Say these out loud in the README; they are real differentiators and three of them are things the big actions got wrong.

- **No hosted service, and no ability to mint tokens into your repo.** opencode requires either their GitHub App plus a token-exchange service at `api.opencode.ai`, or `use_github_token: true` (which silently disables its write-access check). claude-code-action defaults to exchanging your OIDC token at `api.anthropic.com` for a Claude App token. fx's `github_token` input defaulting to `github.token` is the honest shape, and the README's "I don't want the ability to mint tokens into your repo" is a stronger claim than either.
- **Read mode actually hides the tools.** claude-code-action's tag mode relies on `--permission-mode acceptEdits` plus an allowlist and still hands the model edit tools inside the workspace. opencode denies the *question* prompt, not the tools. fx denies `edit` and `shell` outright so the model never sees them, and the reasoning in `action.yml` (no wasted step, run still exits 0, no shell means no reading the runner's env) is better than anything in the other two.
- **One verb, and the reasoning behind narrowing it from five.** CodeRabbit has ~14 commands, run-gemini-cli has 4, opencode has an implicit "the whole comment is the instruction". The `AGENTS.md` note that "do we already have a retry helper?" used to hand a full-access shell to a question is the most useful design lesson in this whole survey, and nobody else documents having made that mistake.
- **Composite, no `dist/`.** pi ships a bundled `dist/index.js`; claude-code-action runs `bun install --production` at action time and executes TypeScript from `src/`; opencode downloads a binary. fx's "every step is shell you can read in the browser" is a genuine trust property, and `AGENTS.md`'s stated line for when to abandon it (diff-anchored review comments, pagination with retries) is exactly right.
- **`minimal-no-action.yml`.** No other action in this survey ships a working example of *not using it*, and pi's "Goal" section makes the same argument in prose without giving you the file. This is the single most persuasive thing in the repo.
- **A per-key budget as the real control.** claude-code-action's cost advice is "set `--max-turns` and workflow timeouts"; Copilot bills a flat premium request; nobody else names a hard dollar ceiling enforced by the provider. fx's `vercel ai-gateway api-keys create --limit 10` plus "`max_cost` only notices afterwards" is more honest and more effective.
- **Draft PRs.** claude-code-action deliberately stops at a branch link. fx opens a draft, which is the same human-oversight step with one less click, and it keeps the work attached to something reviewable. Defensible either way; fx's choice is fine and the README's framing of it as "the same reason" is accurate.

---

## Corrections to this repo's docs

Checked every claim in `README.md`'s prior-art section, `AGENTS.md`, and `refs/README.md` against the clones. The imprecise ones below were fixed on 2026-09-10; kept here so the reasoning survives.

**Accurate, no change needed:**
- `README.md`: pi taught the comment marker, the author gate and the 👀 spinner. Confirmed: `packages/pi-platform-github/src/{comments,reactions}.ts`, README "Securing your workflows".
- `README.md`: opencode caches the binary by release tag and uses `/oc`. Confirmed: `github/action.yml` cache step keyed on the resolved tag, `MENTIONS` default `/opencode,/oc`.
- `README.md`: "They publish an App and run a token service; this doesn't." Confirmed: `github.com/apps/opencode-agent`, `api.opencode.ai/exchange_github_app_token`.
- `README.md`: claude-code-action's hidden-markup list and stopping at a draft rather than merge-ready. The sanitizer list is confirmed (`src/github/utils/sanitizer.ts`, `docs/security.md`).
- `AGENTS.md`: "That is the line `shaftoe/pi-coding-agent-action` crossed, and it now ships a `dist/index.js` measured in hundreds of kilobytes." Confirmed: `runs: using: node24, main: dist/index.js`, esbuild bundle.
- `refs/README.md`: opencode's `github/action.yml` is "a thin composite that installs the binary and runs `opencode github run`, so the GitHub logic lives in the agent". Confirmed and, if anything, understated: the logic is 1606 lines in `packages/opencode/src/cli/cmd/github.handler.ts`.

**Imprecise, worth fixing:**

1. `README.md` "Inspiration", on claude-code-action: **"stopping at a draft rather than a merge-ready PR"**. It does not stop at a draft. It stops at a **branch plus a link to the prefilled PR-creation page**, and a human clicks the button (`docs/security.md`, "Pull Request Creation"; `docs/capabilities-and-limitations.md`, "Prepare Pull Requests"). fx's draft PR is one step *further* than claude-code-action goes, not the same step. The `AGENTS.md` phrasing has the same problem: "the same reason `claude-code-action` stops at a branch and makes a person click the button" is accurate about the mechanism but then calls fx's draft "the same"; they are adjacent, not identical.

2. `refs/README.md` clone commands are stale: it says `gh repo clone anomalyco/opencode` and `anthropics/claude-code-action`, which is right, but the pi clone line is missing entirely (all three are cloned in `refs/`). Also worth adding: for opencode, read `packages/opencode/src/cli/cmd/github.handler.ts`, **not** `github/index.ts`, which is dead code that disagrees with the shipped behaviour.

3. `refs/README.md` says of pi: "`packages/pi-platform-github/` is the part worth reading, reactions, comment upsert, author gating." There is **no author gating in the action**. Gating is entirely in the caller's workflow `if:`. Change to "reactions, comment upsert, sanitizer, and the seven GitHub tools it hands the agent".

4. `refs/README.md` says claude-code-action's `docs/security.md` covers "why it stops at a branch instead of opening a PR". Correct, and it is the one place the distinction in (1) is stated plainly, so the fix for (1) is already sitting in a file the repo links to.

5. `AGENTS.md` "refs/" section said "three of the things in this action came straight out of them" (now "most of what is in this action"). Confirmed as at least three (👀 lifecycle and review-comment endpoint from pi, tag-keyed binary cache from opencode, hidden-markup list from claude-code-action). No change needed; noting it verified.

**Unverified, flagged rather than corrected:** `refs/README.md` describes `actions/toolkit` and `actions/checkout` as reference reading; neither is cloned in `refs/`, so nothing in this pass checked those two rows.
