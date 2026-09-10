# Changelog

What changed in each version, newest first. The format is
[Keep a Changelog](https://keepachangelog.com/en/2.0.0/); the versions are
[SemVer](https://semver.org), because `uses: khalido/fx-agent-action@v1` is a
compatibility promise — see `.claude/skills/release/SKILL.md` for what counts
as a break.

## [Unreleased]

### Added

- Run fx on a GitHub issue or PR and post the answer as one comment, found and
  edited in place by a hidden marker rather than stacked under every run.
- The trigger is `/fx` by default, matched as a whole word anywhere in the
  comment rather than as a prefix; the request is what follows it, and quoted
  lines do not count. A slash phrase rather than a mention because `@fx` is a
  real person on GitHub. The `trigger` input takes any phrase, or several at
  once, comma-separated.
- Two checks on who asked, before anything else, and the run fails if either
  says no: write access to the repository on issue and PR events, and a human
  actor on every event. `allowed_non_write_users` and `allowed_bots` are the
  exceptions. The same two checks `claude-code-action` runs.
- `/fx pr <what to build>` gets the edit and shell tools and opens a
  **draft** pull request from whatever the agent left in the working tree. `pr`
  is the only word that does this: `do`, `build` and `fix` can each start a
  question, and a word that can begin a question cannot also switch writing
  on.
- 👀 on the trigger comment, or on the issue itself when a new or edited issue
  is the trigger, taken off when the answer lands.
- The footer reads fx · model · tokens · cost · time · run, cost in cents.
  A comment that is rewritten keeps a hidden ledger of its runs and stacks
  the earlier ones under the newest with a total, so five edits show five
  costs and their sum. The script does the adding; the model is never asked.
- The whole session as one self-contained HTML file on the run page — every
  tool call, its arguments and its result — kept for a week.
- `examples/fx.yml`, the one file to copy into a repo: a note on every issue
  opened or edited, refreshed in place, plus `/fx` questions and `/fx pr` on
  issues and PRs. This repo runs the same file on itself, and CI fails if the
  two copies drift.
- `shell: true`: the shell in read mode too, for `git log`, `git blame` and
  the tests, with edits denied and nothing committed. Refused together with
  `allowed_non_write_users`, and with an allowed bot on an issue or PR event,
  because a shell can read the key and the bot's text is the instruction.
- A cancelled run, one superseded by a newer comment mid-edit, no longer
  pushes its half-finished edits or posts a "failed" comment. A failed run
  still does both, on purpose.
- `prompt_file` falls back to `prompt` when the file is absent, with a
  notice, so one workflow file serves many repos and a repo overrides the
  prompt by adding a file rather than editing YAML.
- `effort` input, for models that take a reasoning effort. `pr_model`, so a
  write run can use a stronger model than a question does: one rule, decided
  by the workflow, never by the model.
- The settings written for fx now include `max_agent_steps`,
  `max_tool_result_bytes` and `context`, so a checked-out `.fx.json` cannot
  change them, and the mode, model and rules are read back before the run:
  a settings file fx cannot parse is dropped whole and silently, and this
  catches that instead of running on defaults.
- The fx version comes from the same `latest.txt` the installer reads, and is
  passed to the installer, so the cache key and the binary always agree.
- The cost in the footer and on the `cost` output includes the `fx pr` draft,
  which was a second billed request read too late before. Footer tokens come
  from the same ledger as the dollars, so both cover helper models and web
  search.
- The session artifact shows why a tool call was held or denied, and when a
  result was truncated.
- `comment_key`, so two fx jobs on one thread keep separate comments: the
  issue note is not overwritten by a `/fx` answer, or the other way round.
- Five more examples: issue notes, PR review, triage from the repo's real
  labels, `/fx pr` alone, and a weekly dependency bump that runs your own
  checks and writes one PR instead of eight.
- `prompt_file`, so the agent's instructions live in your repo, not in YAML.
- Secrets are scrubbed from the answer, the commit and the session artifact.
  fx never prints the gateway key, but in write mode its shell tool inherits
  the environment, and GitHub masks secrets in logs — not in API bodies.
- Hidden markup is stripped out of the untrusted GitHub text before the model
  sees it: HTML comments, zero-width characters, image alt text, hidden
  attributes.
- Cost in the footer, from `fx usage`, which reports dollars where `fx ask`
  reports only tokens.
- `docs/prior-art.md`: what the other coding-agent actions do on trigger,
  actor checks, auth, output and safety, the recipes they document, and where
  this one differs on purpose.

### Fixed

Before the first release, so nobody hit these — but they are the bugs this
repo's own review found, and the reasons are worth keeping.

- A pull request now carries what fx touched and nothing else, measured as the
  difference between two git tree objects. Diffing `git status` text dropped an
  edit to a file that was already dirty, and missed everything created inside a
  pre-existing untracked directory.
- A path with a space or an accent no longer kills the run after the agent has
  done the work: git C-quotes those, and the quoted form failed as a pathspec.
- The pull-request step survives a failed run, so edits made before the cost
  tripwire fired are not thrown away with the runner.
- The attribute stripper only runs inside HTML tags. It was rewriting
  `const title = "My Post";` out of the diffs it handed a PR review.
- Reference-style image alt text (`![…][ref]`) is neutralised like the inline
  kind.
- The session artifact survives a session with an empty history.
- Redaction reads the environment rather than a hand-kept list of names, which
  had grown three entries that were never set.
- The fx release tag is resolved through `gh api` with the job's token rather
  than anonymous `api.github.com`, whose 60-an-hour limit is shared with every
  job on the runner.
- `FX_AUTO_UPGRADE=0` for the job, so the binary restored from cache does not
  download and replace itself mid-run.
- The session artifact shows provider-side web searches: the query, the
  domain filter and the date window the model sent to Exa, and what came
  back. They were invisible before, having no `tool_results` entry.
- The push in `open-pr.sh` uses `GITHUB_SERVER_URL` instead of a hard-coded
  `github.com`, so it works on GitHub Enterprise Server.

[Unreleased]: https://github.com/khalido/fx-agent-action/commits/main
