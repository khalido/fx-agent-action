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

## What [SemVer](https://semver.org) actually requires

The five rules that bite here, in its words and ours:

- **A released version is immutable.** "Once a versioned package has been
  released, the contents of that version MUST NOT be modified. Any
  modifications MUST be released as a new version." So never retag a published
  release — cut `vX.Y.Z+1`. The one carve-out: a tag whose release is still a
  *draft* has been consumed by nobody and may still move, because nothing
  points at it yet.
- **1.0.0 defines the public API.** For this action that is: the input names
  and their defaults, the output names, the trigger grammar (`/fx`, and `pr`
  as the only write verb), the events it acts on, and the `permissions:` a
  workflow must grant. Changing any of those is MAJOR. Everything else —
  prompts, models, comment wording — is behaviour, judged by the table above.
- **Reset the lower numbers.** MINOR resets PATCH to 0, MAJOR resets both.
  `v1.2.3` → a new feature is `v1.3.0`, not `v1.3.3`.
- **Pre-releases sort below the release.** `1.0.0-rc.1` < `1.0.0`, so an rc is
  how to put a release in front of people without moving `v1`. GitHub's
  `--prerelease` flag matches: `release-tag.yml` moves nothing for one.
- **Deprecate in a MINOR, remove in the next MAJOR.** Renaming an input means
  shipping both names for at least one minor, with the old one warning, rather
  than breaking a workflow that passes the old name.

**0.y.z was the other option and this repo did not take it.** "Major version
zero is for initial development. Anything MAY change at any time." That is the
honest signal for something still moving weekly — and it is why the examples
can keep pinning `@main` while `v1` exists for anyone who wants the promise.
If a release would be easier to explain as 0.x, that is a sign the API is not
settled and the tag is writing a cheque.

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

### 1b. What changed in fx

The action installs fx's latest release on every run, so a new fx version
reaches every consumer whether or not this repo releases. Before tagging,
check that the action is checked against the current one:

```bash
gh release list --repo vercel-labs/fx --limit 5
grep -m1 '^## fx facts checked against' AGENTS.md
```

If fx is ahead of that heading, read the release notes for each version
since (`gh release view <tag> --repo vercel-labs/fx`) and recheck what the
action depends on: `fx ask` flags, the session schema `session-html.py`
reads, the ledger fields `cost.sh` reads, the rule keys and the read-back.
Update the AGENTS.md facts and say "Checked against fx X" in the changelog
section. A change there is part of this release, not the next one.

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
the changelog names exists in `action.yml`. Check it the other way too — an
input in `action.yml` that no document mentions is the failure people hit, and
a phantom input is only embarrassing:

```bash
python3 - <<'EOF'
import re
a = open('action.yml').read()
inputs = set(re.findall(r'^  ([a-z_]+):', a.split('inputs:')[1].split('\noutputs:')[0], re.M))
docs = set(re.findall(r'`([a-z_]+)`', open('CHANGELOG.md').read() + open('README.md').read()))
print("undocumented:", sorted(inputs - docs) or "none")
EOF
``` Bring the `actions/*` pins in
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

**The examples stay on `@main`, deliberately, until KO says the action is
baked.** v1.0.0 exists so anyone who wants the compatibility promise can pin
`@v1`, but the file people copy still points at the branch this repo develops
on, and so do KO's own repos — a fix reaches them the same day instead of
waiting for a release. That is the 0.y.z argument above, spent on the pins
rather than on the version number.

When that changes, flip them all in one commit: `grep -rln
"fx-agent-action@main" README.md docs examples .github` finds the eight —
README, all five `examples/*.yml`, `docs/guide.md`, and the normalising `sed`
in `.github/workflows/check.yml`, which turns the pin into `uses: ./` for the
dogfood-drift diff and fails the build if it is left behind.

Then tell the consumers. Repos already running `@main` take every push to main
on their next issue, which is the whole reason the tag exists; each one has a
Claude session that owns it, and there is a memory note listing them. Ask
before switching someone else's pin for them.

Do the release itself in the browser, from the `action.yml` banner: the Marketplace listing is
a checkbox on the release form and has no CLI. The `name` in `action.yml`
(`fx agent`) is what has to be unique there.
