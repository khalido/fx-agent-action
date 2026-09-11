# Changelog

What changed, newest first, in the format of
[Keep a Changelog](https://keepachangelog.com/en/2.0.0/). Versions are
[SemVer](https://semver.org): `uses: khalido/fx-agent-action@v1` is a
compatibility promise. `.claude/skills/release/SKILL.md` says what counts as a
break and how a release is cut.

## [Unreleased]

### Added

- One comment per job, found by a hidden marker and edited in place, with a
  footer: fx, model, tokens, cost in cents, seconds, run link, and earlier
  runs stacked with a total when a comment is rewritten.
- `/fx` as the trigger, a whole word anywhere in a comment, quoted lines
  skipped; `trigger` takes several phrases. `/fx pr …` is the only phrase
  that turns writing on and ends in a draft pull request carrying exactly
  what fx changed.
- Two checks before anything runs, and a no fails the run: write access on
  issue and PR events, a human actor on every event. `allowed_non_write_users`
  and `allowed_bots` are the exceptions, read mode only.
- A built-in note prompt, `prompts/issue.md`, used on every issue opened or
  edited by someone with write access; `.github/fx/issue.md` in a repo
  replaces it. Repo facts go in `AGENTS.md`, which the base block says may
  add to or adjust the task.
- Three modes: read; scratch (`shell: true`), read plus a shell and edits
  that are thrown away; write (`pr`), full access in the runner.
- Memory, on by default: one `MEMORY.md` on an `agent-memory` branch,
  fetched before the run, edited by the agent with its ordinary tools, pushed
  back after, three-way merged on a concurrent write, compacted by one extra
  model call when over `memory_lines`. `memory_repo` gives an org one memory.
- Skills: the action ships `skills/compare-models` and copies it, with a
  repo's `.github/fx/skills/`, into fx's skill directory on the runner.
- The session as one HTML file on the run, kept a week, including web
  searches with the exact date window and domain filter sent.
- Inputs `model`, `pr_model`, `effort`, `max_steps`, `max_cost`,
  `comment_key`, `prompt`, `prompt_file`, `include_thread`, `include_diff`,
  `github_token`, `working_directory`, `session_artifact`, `skills`.
- 👀 on the trigger comment or issue while the run is going.
- `examples/fx.yml`, the one file to copy, run by this repo on itself; five
  more examples; `docs/guide.md` for the rest; `docs/prior-art.md` and
  `docs/agent-memory.md` as the surveys behind the choices.

### Changed

- Default model is `deepseek/deepseek-v4.1-flash` for every task, replacing
  `zai/glm-5.3-flash` (2026-09-10). Same input price, a fifth more on output,
  better work.
- The examples check out with `fetch-depth: 0`, so `git log` and `git blame`
  have history.
- `examples/fx.yml` sets concurrency per job; at workflow level `github.job`
  is empty and a comment during a note cancelled the note.

### Security

- fx's process never holds a GitHub token. Before a run that can write to
  disk, the action fingerprints its own `action.yml` and `scripts/`; a
  mismatch afterwards stops the steps that hold a token.
- Hidden markup is stripped from the thread, the diff and `issues.json`
  titles before the model sees them. Secrets are scrubbed from the answer,
  the commit and the session artifact.
- Settings fx cannot parse, or rules that did not register, fail the run
  before it spends anything.

### Fixed

Before the first release, from this repo's own reviews and from fx auditing
the action: the PR carries only what fx touched, measured as a tree diff;
paths with spaces survive; the cost includes the `fx pr` draft; a PR diff
the token cannot read is a warning, not an empty diff; the memory file never
lands in a PR at any depth; a repo skill can shadow a shipped one.

[Unreleased]: https://github.com/khalido/fx-agent-action/commits/main
