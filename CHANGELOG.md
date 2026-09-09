# Changelog

What changed in each version, newest first. The format is
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the versions are
[SemVer](https://semver.org), because `uses: khalido/fx-agent-action@v1` is a
compatibility promise — see `.claude/skills/release/SKILL.md` for what counts
as a break.

## [Unreleased]

### Added

- Run fx on a GitHub issue or PR and post the answer as one comment, found and
  edited in place by a hidden marker rather than stacked under every run.
- `/fx pr <what to build>` gets the edit and shell tools and opens a **draft**
  pull request from whatever the agent left in the working tree. `pr` is the
  only word that does this: `do`, `build` and `fix` can each start a question,
  and a word that can begin a question cannot also switch writing on.
- 👀 on the trigger comment while it works, taken off when the answer lands.
- The whole session as one self-contained HTML file on the run page — every
  tool call, its arguments and its result — kept for a week.
- Five working examples: issue notes, PR review, triage from the repo's real
  labels, `/fx pr`, and a weekly dependency bump that runs your own checks and
  writes one PR instead of eight.
- `prompt_file`, so the agent's instructions live in your repo, not in YAML.
- Secrets are scrubbed from the answer, the commit and the session artifact.
  fx never prints the gateway key, but in write mode its shell tool inherits
  the environment, and GitHub masks secrets in logs — not in API bodies.
- Hidden markup is stripped out of the untrusted GitHub text before the model
  sees it: HTML comments, zero-width characters, image alt text, hidden
  attributes.
- Cost in the footer, from `fx usage`, which reports dollars where `fx ask`
  reports only tokens.

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

[Unreleased]: https://github.com/khalido/fx-agent-action/commits/main
