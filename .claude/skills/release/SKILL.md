---
name: release
description: Cut a SemVer release of fx-agent-action — decide the bump from what changed to the action's contract, roll Unreleased into a dated section, tag, publish, and let the workflow move the major tag. Human-in-the-loop.
---

# /release

Cut a release for **khalido/fx-agent-action**. Same shape as the everx release
skill, with one thing changed that changes everything else:

**The tag is an API contract here.** Everx uses CalVer because its tag marks a
period and nobody depends on it. This repo is a published action: people write
`uses: khalido/fx-agent-action@v1`, and a bad `v1` breaks their workflow on the
next run, silently, with nothing to roll back to but a comment. So SemVer, and
the bump is a judgement about compatibility, not about how much work went in.

## What the version means

Read the diff against the last tag and ask what a consumer would notice.

| | |
|---|---|
| **MAJOR** | An input removed or renamed. A default that changes what a run does. An output dropped. A permission the action now needs. A change to the trigger vocabulary. Anything where a workflow that worked yesterday behaves differently today. |
| **MINOR** | A new input whose default preserves today's behaviour. A new output. A new example. A better answer from the same call. |
| **PATCH** | A bug fixed, with no behaviour anyone could have relied on. |

Two traps, both from fixes already in this repo:

- **A default is part of the contract.** Dropping the `fx_version` input was a
  break even though it never worked, because a workflow passing it now fails
  on an unknown input.
- **A prompt change is a behaviour change.** The prompt decides what the
  comment says. A rewrite that makes answers shorter is MINOR at least; one
  that changes when the agent writes files is MAJOR.

## Steps

### 1. The range

```bash
git fetch --tags --quiet
git describe --tags --abbrev=0 2>/dev/null   # empty = first release, which is v1.0.0
git log <last-tag>..HEAD --format='%h %s%n%b%n---'
git diff --stat <last-tag>..HEAD
```

Read the full commit bodies — the *why* lives there. Never feed raw diffs.

### 2. Decide the bump, and say why in one line

Name the specific change that forces it. "MINOR: `session_artifact` is new and
defaults to the old behaviour" is an answer. "Lots of improvements" is not.

### 3. Roll CHANGELOG.md

`## [Unreleased]` becomes `## [X.Y.Z] - YYYY-MM-DD` with Keep-a-Changelog
categories (`Added` / `Changed` / `Fixed` / `Removed` / `Deprecated` /
`Security`). "Fixed" = it was wrong; "Changed" = it worked and now differs.
Leave a fresh empty `## [Unreleased]` and update the compare links at the
bottom.

Account for every commit: promote what a consumer would notice, roll the rest
into one line, drop nothing silently.

### 4. Verify the claims — a fresh subagent, not the one that wrote them

Same rule as everx, for the same reason: the editorial pass embellishes, and
can invert. Every concrete claim gets CONFIRMED / WRONG / IMPRECISE with
evidence. Check input names against `action.yml`, paths against the tree, and
that each "fixed" behaviour is what the code does **now** rather than what a
commit title said. Fix the changelog and the notes before the gate.

### 5. Show me — approval gate

The proposed version and the one-line reason, the changelog section, the
release notes, and what the verify pass flagged. **Stop.** Nothing publishes
without a yes: a release here changes what runs in other people's repos.

### 6. Tag and publish

```bash
git add CHANGELOG.md && git commit -m "docs: changelog for vX.Y.Z"
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin main --follow-tags
gh release create vX.Y.Z --repo khalido/fx-agent-action \
  --title "vX.Y.Z - <short theme>" --notes-file - --verify-tag <<'NOTES'
<the approved notes>
NOTES
```

**Never move `v1` by hand.** `.github/workflows/release-tag.yml` fires on
`release: published`, refuses a tag that is not `vN.N.N`, and force-moves the
major tag to it. A prerelease moves nothing — which is how to test a release
without pointing every consumer at it.

Check it: `git ls-remote --tags origin | grep -w v1` shows the new commit
within a minute.

### 7. First release only

Listing on the GitHub Marketplace is a checkbox on the release form and needs
the `branding` block in `action.yml` (already there). It cannot be done
retroactively from the CLI, so publish the first release in the browser.
