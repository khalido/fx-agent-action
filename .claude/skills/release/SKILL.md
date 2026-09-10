---
name: release
description: Cut a release of fx-agent-action — pick the SemVer bump from what a consumer would notice, roll Unreleased into a dated changelog section, tag, publish. The workflow moves v1 and v1.N. Human-in-the-loop; nothing publishes without a yes.
---

# /release

People write `uses: khalido/fx-agent-action@v1` and get every `v1.x` as it
ships, without touching their workflow. So the tag is a promise, and the bump
is a judgement about compatibility, not about how much work went in.

| | |
|---|---|
| **MAJOR** | A workflow that worked yesterday behaves differently today: an input removed or renamed, a default that changes what a run does, an output dropped, a permission the action now needs, a trigger that no longer fires or fires differently. |
| **MINOR** | Something new that leaves today's behaviour alone: an input with a preserving default, an output, an example, a better answer from the same call. |
| **PATCH** | A bug fixed, with no behaviour anyone could have relied on. A dependabot bump of an `actions/*` pin. |

Two traps from this repo's own history: **a default is part of the contract**
(dropping an input that never worked was still a break, because a workflow
passing it now fails on an unknown input), and **a prompt change is a behaviour
change** (shorter answers is MINOR; a change to when the agent writes files is
MAJOR).

## Steps

### 1. What changed

```bash
git fetch --tags --quiet
git describe --tags --abbrev=0 2>/dev/null     # empty = first release, v1.0.0
git log <last-tag>..HEAD --format='%h %s%n%b%n---'
```

Read the commit bodies, not the diffs. `CHANGELOG.md`'s `## [Unreleased]`
should already say all of this, because entries are written as changes land;
add what is missing, drop nothing silently.

### 2. Decide the bump, in one line

Name the change that forces it. "MINOR: `allowed_bots` is new and defaults to
rejecting bots, which is what the examples already did" is an answer. "Lots of
improvements" is not.

### 3. Roll the changelog

`## [Unreleased]` becomes `## [X.Y.Z] - YYYY-MM-DD`, categories per
[Keep a Changelog 2.0.0](https://keepachangelog.com/en/2.0.0/): `Added`,
`Changed`, `Fixed`, `Removed`, `Deprecated`, `Security`. "Fixed" means it was
wrong; "Changed" means it worked and now differs. Leave a fresh empty
`## [Unreleased]` and update the compare links at the bottom. The first
release is one `Added` section: nobody ran the code that the fixes fixed.

That section **is** the release notes. One text, no second draft to drift.

### 4. Check it

`shellcheck -S warning scripts/*.sh`, `actionlint`, and every input or output
the changelog names exists in `action.yml`. Bring the `actions/*` pins in
`examples/` and `action.yml` up to whatever Dependabot has moved
`.github/workflows/` to, so the file people copy is the one that is tested. For a **MAJOR**, also hand the
section to a fresh subagent to verify each claim against the code: editorial
passes embellish and can invert, and a major is the release people read.

### 5. Show me, and stop

The version, the one-line reason, the changelog section. Nothing publishes
without a yes; a release changes what runs in other people's repos.

### 6. Tag and publish

```bash
git add CHANGELOG.md && git commit -m "changelog for vX.Y.Z"
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin main --follow-tags
gh release create vX.Y.Z --repo khalido/fx-agent-action \
  --title "vX.Y.Z" --verify-tag --notes-file - <<'NOTES'
<the changelog section, without its heading>
NOTES
```

`.github/workflows/release-tag.yml` then moves `v1` and `v1.N` to it. **Never
move those by hand.** It refuses anything not shaped `vN.N.N`, and a
`--prerelease` moves nothing, which is how to test a release without pointing
every consumer at it. `git ls-remote --tags origin | grep -w v1` shows the new
commit within a minute.

### First release only

Do it in the browser, from the `action.yml` banner: the Marketplace listing is
a checkbox on the release form and has no CLI. The `name` in `action.yml`
(`fx agent`) is what has to be unique there.
