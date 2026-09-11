<!-- Survey by an Opus subagent, 2026-09-11, using KO's `ko` CLI for the
web research. Reference for whoever works on the memory feature; the decision
is tracked in the "Add agent memory" issue. Prices are as of the date above.
The branch shipped as `agent-memory`, not the `fx-memory` used below, so other
agents can share it. -->

# Memory for fx-agent-action — survey

Researched 2026-09-11; prices fetched from vendor pages that day. Scale assumed
throughout: **300 runs/month, one read (~1-2 KB) and one write (2-3 lines,
~300 bytes / ~80 tokens) per run.** That is tiny. Every hosted service below is
free at this volume. Price is not the question. The question is how many new
things you agree to run.

## 1. Hosted agent-memory services

| | Stores | Server-side consolidation | Scoping | API / MCP | Free tier | First paid | Own LLM key? | Shell to integrate |
|---|---|---|---|---|---|---|---|---|
| **Mem0** (platform) | Extracted facts; optional graph | **Yes — "Dream"**, but **Pro-only, $249/mo** | `user_id`/`agent_id`/`app_id`/`run_id` + projects | REST `POST /v3/memories/add/`, `POST /v3/memories/search/`, `Authorization: Token`; hosted MCP `https://mcp.mem0.ai/mcp` | 10,000 adds + **1,000 retrievals**/mo, 1 project | $19/mo | No | ~8 lines, 2 curls |
| **Mem0 OSS** | Same | Dream is in the OSS repo | Same | Python/TS lib only | Free, self-host | — | **Yes** | Not shell-shaped: needs Python + a vector store |
| **Zep** (cloud) | Temporal knowledge graph (Graphiti) | Supersession inside the graph; no named compaction pass | `graph_id`/`group_id`/`user_id`, projects | REST `POST /api/v2/graph`, `POST /api/v2/graph/search`; MCP is **OAuth-only**, seat-metered | 10,000 credits/mo (1 credit per 350-byte episode), 2 projects | **$125/mo** | No (cloud); Graphiti OSS needs `OPENAI_API_KEY` | ~8 lines, 2 curls |
| **Honcho** | Reasoning-derived conclusions about "peers", not raw notes | **Yes — "Dreaming", background, free** | Workspace → peers → sessions | REST + SDKs; docs are SDK-first | **$100 credits at signup**, then $2/M tokens *ingested*; retrieval and dreaming free | pay-as-you-go, no subscription | No | ~10 lines; REST shapes under-documented |
| **Supermemory** | Documents + a derived memory graph/profile | Profile synthesis; no named nightly pass | `containerTag`, **hierarchical** (`org:acme:repo:x`) | REST `POST /v3/documents`, `POST /v4/search`; MCP `https://api.supermemory.ai/mcp` | $5 credits/mo | $19/mo | No | ~8 lines, 2 curls |
| **Letta** | Stateful agents with self-editable memory blocks | Agent edits its own blocks | Agents, orgs | REST + SDK | Free tier is app/BYOK, **not** the API plan | **$20/mo** + $0.10/active agent/mo | BYOK possible | Wrong shape — you'd rent an agent, not a store |
| **cognee** | Knowledge graph over ingested sources | Graph build; bi-temporal conflict resolution is enterprise-only | Workspaces, $5 each | REST + MCP, OSS | 1M tokens, 1 workspace | Not rendered on their page | Self-host: yes | Heavier; wants to index a corpus, not hold 80 lines |
| **Cloudflare Agent Memory** | Extracted memories in named profiles | Yes — extraction, supersession, synthesis on Workers AI | Profile name + `sessionId` | Worker binding, plus REST "for agents outside Workers" | **Private beta, no public pricing** | — | No | Unavailable today |

What the table doesn't say:

- **Consolidation is the paid feature everywhere it exists.** Mem0 gates Dream
  behind a 13× jump ($19 → $249). Honcho is the exception: dreaming free,
  ingestion $2/M tokens, so 300 runs cost ~**$0.05/month** against $100 of
  signup credit — but it stores conclusions *about people*, not a running log.
- **`infer: false`.** Mem0's add endpoint takes it and "stores each message
  verbatim without running the extraction LLM" — an append-only log with search,
  no extractor rewriting your delta into third-person facts.
- **These are all user-memory products.** `agent_id: "repo:khalido/fx-agent-action"`
  is a namespace hack. It works; you pay in concepts, not dollars.
- **MCP is the wrong door.** fx supports it (`fx mcp add --transport http`, with
  `bearer_token_env` for a headless token; Zep's OAuth-only MCP wouldn't work on
  a runner). But an MCP tool is something the *model chooses* to call: extra
  steps, extra billed tokens, and a run might write nothing. Two `curl`s around
  `fx ask` always run and cost nothing. Use REST.
- **Risk.** All under-two-year-old startups repricing frequently (Honcho
  repriced its whole model Jan 2026). Honcho's core is AGPL. Data residency
  US-default and mostly unstated.

## 2. PostHog AI observability

**Not a memory store. Observability, tracing and evals.** From their own page:
traces arrive as `$ai_generation`, `$ai_trace`, `$ai_span`, `$ai_metric`,
`$ai_feedback` through the capture API; you read them back with HogQL via the
query API. There is no write-a-memory / read-my-memories primitive, no
namespaced document store, nothing that consolidates.

It has a real but different role: **a place to log runs.** One `$ai_trace` per
fx run — repo, actor, mode, tokens, cost from `fx usage --json`, whether a PR
opened — would give cost-per-repo and failure rates across every repo using the
action, which today has nowhere to go. Separate, smaller feature; keep it
separate. A personal API key is one more bearer token on the runner and one
more thing `redact.py` must cover.

## 3. DIY on Cloudflare

**$0/month at your scale, on the free plan.** 300 runs = 600 Worker requests
against 100,000/day free. KV free is 1,000 writes and 100,000 reads per day.
D1 free is 100,000 rows written/day. Nightly compaction on Workers AI
(`@cf/meta/llama-3.1-8b-instruct-fp8-fast`, $0.045/M input tokens) over an
80-line file is ~3,000 tokens ≈ 13 neurons against 10,000 free neurons/day.

Two endpoints:

```
GET  /m/{scope}   -> text/plain: compacted memory + recent deltas
POST /m/{scope}   -> append one delta (bearer token, body is the text)
```

KV-backed: `memory:{scope}` for the compacted block, `delta:{scope}:{ts}` per
append. D1 only if you want to query across repos. Realistically 60-100 lines
of TypeScript, a `wrangler.toml`, and `crons = ["0 3 * * *"]`.

The compaction prompt does three things and no more: **merge** duplicates,
**supersede** contradicted facts (keep the new, drop the old, never both),
**drop** anything true for exactly one run. Hard-cap the output ("at most 60
lines, newest first") and forbid invention — every output line must trace to an
input line. Easy to write, hard to get right; a bad compactor silently deletes
the one line that mattered.

**Cloudflare's own primitives don't help yet.** Agent Memory (Apr 2026) is the
right-shaped product — profiles, ingest/remember/recall, profiles shared across
a team, and they run it on their internal code reviewer where "the most useful
thing it learned to do was stay quiet" — but it is private beta with no public
pricing. The Agents SDK gives each agent a Durable Object with SQLite: a better
store than KV if you need queries, worse if you need two endpoints.

**The objection:** a Worker, a KV namespace, a cron, a deploy pipeline, a bearer
token and a compaction prompt. Six new things you own, none of which are the
action. Against that, it's the only cross-repo option that is free forever.

## 4. GitHub-native

More solved than expected: **GitHub ships it themselves.**
[`github/gh-aw`](https://github.com/github/gh-aw), their agentic-workflows
compiler, has three memory backends — `cache-memory` (actions/cache, 7-day
retention), `repo-memory` (an orphan git branch, unlimited), and
`comment-memory` (state in a managed issue comment).
[Their docs](https://github.github.com/gh-aw/reference/repo-memory/):
"Branches auto-create as orphans by default", default branch `memory/default`,
"merge conflict resolution (your changes win)", `max-patch-size` default 10KB.

**Mechanics that decide it.**

- **Token.** `GITHUB_TOKEN`'s "permissions are limited to the repository that
  contains your workflow". Needs `contents: write`. On `issue_comment` — your
  actual trigger — the token is full even when the comment is on a fork's PR.
  On `pull_request` **from a fork**, write is downgraded to read and the write
  **fails**; must be non-fatal.
- **No loops.** "events triggered by the `GITHUB_TOKEN` will not create a new
  workflow run". A memory push fires nothing.
- **Concurrency, solved in one call.** `PUT /repos/{o}/{r}/contents/{path}`
  takes the file's *blob* `sha` and documents **409 Conflict** — real
  compare-and-swap. Read `gh api repos/$R/contents/MEMORY.md?ref=fx-memory`,
  PUT with the sha, retry the 409 up to 3×. No git, no second worktree, no
  token-in-URL push, and it never touches the PR-head checkout. `git push`
  gives a non-fast-forward rejection, no CAS, and is refused outright by
  signed-commit rulesets.
- **Orphan branch, not `main`.** `.github/fx/MEMORY.md` on the default branch
  puts a commit in `git log main` every run, forever, and branch protection
  rejects the push. An orphan `fx-memory` branch has separate history, no
  rulesets, and is invisible to `git log main`.
- **The pinned-issue variant is worse for one specific reason.** Creating a
  comment notifies every watcher; **editing a body does not**. Per-run comments
  are per-run spam and people will turn the action off. Body-edit-only works,
  costs `issues: write`, is browser-editable by a human with no clone, and caps
  at **65,536 characters** (~400 runs at 150 chars each), which is at least a
  forcing function for compaction.
- **Org scope needs an App.** `GITHUB_TOKEN` cross-repo returns 404, not 403.
  The answer is an org-owned GitHub App with `Contents: write`, `APP_ID` and key
  as org secrets, minted per job with `actions/create-github-app-token`, writing
  to the org `.github` repo. Free, ~10 minutes. **Your `github_token` input
  already accepts an App token, so org scope is a docs change, not code.**

Prior art beyond gh-aw:
[`inference-gateway/.github`](https://github.com/inference-gateway/.github/commit/2e449b344a80fbe5eeef7069e64b59e78d734833)
persists Claude Code memory to a private `.memory` repo on a `claude` branch,
cloned to `~/.claude/memory` deliberately outside the workspace "so it never
leaks into the target repo's PR", synced under `always()`. Also
[OpenHands #2037](https://github.com/OpenHands/software-agent-sdk/issues/2037)
(the same read-at-start / append-at-end `MEMORY.md` shape) and
[Copilot Memory](https://docs.github.com/copilot/concepts/agents/copilot-memory),
public preview Jan 2026, repo-scoped and opt-in.

**Against 1 and 3:** $0, no new vendor, no new secret, no new deploy target,
diffable and revertable in the tool the work already lives in. It gives up
cross-repo scope (until you add the App) and server-side consolidation — but
you'd write the compaction prompt for Cloudflare too.

## 5. What the literature actually says

**The growth problem is measured. The rot problem is not.**

- [arXiv 2608.11095](https://arxiv.org/abs/2608.11095), "Why Does CLAUDE.md Keep
  Growing?" (11 Aug 2026), 247,694 instruction lifetimes across 1,867 repos:
  "agentic prompts grow without bound, more than tripling over their lifetime
  (+226%), gaining +4.9 net instructions every commit; further, the older an
  instruction gets, the less likely it is to be deleted." Deletion is expensive
  because the *rationale* is gone. Preprint; the growth measurement is solid.
- [arXiv 2605.10039](https://arxiv.org/abs/2605.10039) (11 May 2026), 1,650
  Claude Code sessions, manipulating file size (25/100/250/500 lines), rule
  position, and **deliberate self-contradiction**: "None of the four structural
  variables or three two-way interactions produces a detectable contrast after
  multiple-testing correction… affirmative-null Bayes factors (BF10 between 0.05
  and 0.10)." **This is the most important finding for you and it cuts against
  the memory-rot story** at the file sizes anyone actually writes. TypeScript
  only, one target rule, preprint.
- [Chroma, Context Rot](https://research.trychroma.com/context-rot) (Jul 2025)
  is well-run — "LLMs do not maintain consistent performance across input
  lengths" — but it is about **prompt length**, not stale memory files. Every
  "context rot in your CLAUDE.md" post extrapolates from it.

**Delta + consolidation is the consensus pattern, backed by product not proof.**
[OpenAI, "Dreaming"](https://openai.com/index/chatgpt-memory-dreaming/)
(4 Jun 2026) — "a background process that allows ChatGPT to learn from many
conversations and synthesize ChatGPT's memory state" — frames the problem as
staleness and publishes no numbers.
[Mem0 Dream](https://docs.mem0.ai/platform/features/dream): "It synthesizes
higher-order patterns, supersedes outdated facts, and merges duplicates" — the
three verbs your compaction prompt needs.

**Line caps are vendor hygiene, not evidence.**
[Claude Code memory docs](https://code.claude.com/docs/en/memory): "target under
200 lines per CLAUDE.md file. Longer files consume more context and reduce
adherence" — plus one genuinely *enforced* number: "The first 200 lines of
`MEMORY.md`, or the first 25KB, whichever comes first, are loaded at the start
of every conversation." [Cursor](https://cursor.com/docs/context/rules): "Keep
rules under 500 lines." Neither has an experiment behind it, and the one
experiment that exists found nothing at 500 lines. **Gemini's ~80-line cap is a
reasonable choice, not a measured threshold — don't present it as one.**

**What the three shipping agents do.** Claude Code: human-written `CLAUDE.md`
plus an **auto memory it writes itself, on by default**, machine-local under
`~/.claude/projects/<project>/memory/`. Codex: static `AGENTS.md` plus a **local
memories store, off by default**, updated "in the background" — the closest
thing to shipping consolidation. Cursor: rules only; Memories was removed in
2.1. **None of the three commits agent-written memory to the repo.** All three
keep the shared, checked-in layer human-edited. That is a signal.

## Three directions, ranked

### 1. Orphan branch `fx-memory`, read and written through the contents API — *the default*

**What it is.** One `MEMORY.md` on an orphan branch. Read at run start with
`gh api repos/$R/contents/MEMORY.md?ref=fx-memory`; append the delta at run end
with a `PUT` carrying the blob sha, retrying a 409 up to three times. No git, no
second checkout, no new secret, no new vendor. The same choice GitHub made in
gh-aw.

**What the action adds.** Inputs `memory` (default false) and `memory_branch`
(default `fx-memory`). One `scripts/memory.sh` with `read` and `append` verbs,
called before `build-prompt.sh` and after `run-fx.sh` — the second under
`always()`, non-fatal. `build-prompt.sh` gains a memory block *inside* the
untrusted framing. One prompt line at the end of the runtime block: *"After
answering, write 2-3 lines of what you did and what you learned that a future
run would want. Facts, not narrative. If MEMORY.md is over 80 lines, rewrite it
whole: merge duplicates, drop anything true for one run only, newest first."*
Compaction rides the run you already paid for — no cron, no second model call.

**Cost.** $0, plus a handful of output tokens per run.

**What goes wrong.** (a) **Prompt-injection laundering** — the one genuinely new
security surface. A stranger's issue comment steers what fx writes into memory,
and it persists into every future run *including write-mode ones*; the per-run
sanitizer doesn't help across runs. Mitigate: only write memory from runs that
passed `check-actor.sh`, and frame the memory block as untrusted. (b) Fork
`pull_request` events get a read-only token — the write 403s, warn and continue.
(c) Signed-commit rulesets: the contents API produces Verified commits, `git
push` doesn't. (d) Bland deltas — 80 lines of "reviewed the PR".

**What would make you pick it.** You already believe the action should be shell
you can read in a browser. This adds ~40 lines and zero new nouns.

### 2. Honcho or Supermemory over REST — *only for scope an App token can't reach*

**What it is.** Two curls to a hosted store, namespaced per repo. Honcho for
free server-side dreaming ($2/M tokens, ~$0.05/mo here, $100 signup credit).
Supermemory for clean hierarchical scope out of the box (`containerTag:
org:syntechfibres:repo:fx-agent-action`). Mem0 with `infer: false` for a literal
verbatim log — but its consolidation is $249/mo, so you'd write the compaction
prompt anyway.

**What the action adds.** A `memory_api_url` / `memory_api_key` input pair, the
same two calls in the same two places, the key added to `redact.py`.

**Cost.** ~$0.05-0.15/month at 300 runs, on any of the three.

**What goes wrong.** A new vendor in a run's critical path, a new secret on the
runner, a startup that repriced eight months ago, and your repo's institutional
memory somewhere you don't control. All of direction 1's injection risk, plus
exfiltration: in write mode fx's shell inherits the environment and can read the
memory key.

**What would make you pick it.** Memory has to span *across* GitHub orgs, or
across GitHub and something else, and direction 1's App token doesn't reach.

### 3. Cloudflare Worker + KV + cron — *a product, not a feature*

**What it is.** Section 3: two endpoints, ~80 lines of TypeScript, nightly
Workers AI compaction.

**Cost.** $0/month, and still $0 at 100× this scale.

**What goes wrong.** You run a Worker, a KV namespace, a cron, a deploy pipeline
and a compaction model, none of which are the action. When compaction eats a
line it shouldn't, you debug it in a second repo.

**What would make you pick it.** Cross-org memory *and* a refusal to take a
vendor, or memory shared between fx and non-GitHub agents. Fine design; three
new things to run for a feature whose whole value is 80 lines of text.

### The call

**Direction 1 for repo scope.** Default off. Org scope is earned by the *same*
mechanism — point `memory_branch` at the org's `.github` repo and pass a GitHub
App token through the `github_token` input you already have. Zero new vendors at
either scope. Reach for a hosted store only when memory has to leave GitHub.

**Be blunt about the feature itself:** the only controlled experiment on this
found no adherence effect from memory-file size or even self-contradiction, and
none of Claude Code, Codex or Cursor commits agent-written memory to a repo.
The upside here is real but modest and unmeasured — an agent that stops
re-asking answered questions. Ship it off by default, cap it hard, and make it
trivially deletable (`git push origin --delete fx-memory`).

## Claims I could not verify

- Any published measurement that stale or contradictory *memory-file* entries
  degrade coding-agent behaviour. The one controlled test looked and found
  nothing; everything else is blog assertion.
- cognee's paid tier prices — their pricing page renders the feature lists but
  not the numbers.
- Cloudflare Agent Memory pricing and GA date: private beta, nothing published.
- Honcho's REST endpoints in enough detail to write the two curls with
  confidence. SDK-first docs; the ~10-line estimate is a guess.
- Mem0 Dream's gating thresholds (24h / 5 sessions / 20 memories) — OSS release
  notes, not hosted docs. Cursor's removal of Memories in an official
  changelog — forum threads only.
- Whether Codex's background memory pass does real merge/supersede or only
  extraction. The docs say "updates memories in the background" and stop.
- gh-aw's `createCommitOnBranch` GPG-signing behaviour — reported by a source I
  did not read directly.
