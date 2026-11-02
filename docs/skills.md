# Skills: what ships, and what might

The skills this action copies into `~/.fx/skills/` on every run, and candidates that are not built yet. A candidate gets built when runs show the agent getting that task wrong in the same way more than once. Being able to imagine the task is not enough.

## The bar

- **Rare, and done the same way each time.** Something every run needs goes in the base block in `scripts/build-prompt.sh` instead.
- **Works in any repo.** Every consuming repo gets it. A repo-specific procedure goes in that repo's `.github/fx/skills/`.
- **Needs no GitHub token.** The agent holds none. Anything that needs the API is a step in the action that writes a file for the agent to read, like `issues.json` for the note.
- **Earns its description.** Each skill's `description` goes into every request, about 40 tokens. Since fx 0.0.16 the body is sent only with the turn that invokes it.

## Shipped

### `open-pr`

How a change ships: a clean tree, the repo's own checks, then `.agent-pr.md`. Whether to ship is judgement, so it stays in the base block. The skill holds the mechanics.

### `compare-models`

Checking a gateway model: catalog, what people hit, and fit with this repo.

## Candidates

### `review-pr`

**What:** review the PR diff that `build-prompt.sh` already puts in the prompt (`include_diff`). Check each finding against the code. Rank them: breaks in production, then correctness, then something the repo already has. Skip what earlier reviews already said.

**Why:** `examples/pr-review.yml` has this as an inline prompt, so typing `/fx review this` on a PR gets none of it.

**Catch:** on a `/fx` comment, `examples/fx.yml` checks out the default branch, not the PR. The diff is right, but any file the agent opens is the version before the change. The skill has to say so, or the workflow has to check out the PR head on PR comments, which would be a change to the example, not a skill.

**Build when:** `/fx` review requests on PRs come back shallow, or from the wrong diff.

### `fix-bug`

**What:** reproduce first, as a failing test where the repo has tests, then fix, then show that test passing. If it can't be reproduced, say so and quote the exact command run.

**Why:** "Fix this" on a bug report is probably the most common change request. Fixing without a repro is the usual way agents get it wrong.

**Build when:** PRs from `/fx fix this` fix the wrong thing, or come with no evidence the bug was there.

### `add-tests`

**What:** find the test setup from the repo's config, copy the style of the tests next to the code, cover the cases the issue names, and run them. Say what's still uncovered.

**Why:** agents invent test layouts. Matching what's already there is a fixed procedure.

**Build when:** test PRs come back in a framework or layout the repo doesn't use.

### `update-deps`

**What:** the `examples/weekly-deps.yml` procedure, generalised to npm, uv, cargo and go. Take minors and patches, read the release notes for anything more than a patch, run the checks, and revert any single package that breaks. List the majors that are available, with what each would break.

**Why:** it's rare and procedural, and today it lives only in one example workflow's prompt.

**Build when:** someone types `/fx update the deps` and gets an answer that skips the checks.

### `ci-failure` (needs an action step first)

**What:** explain why a PR's checks are red, and fix it when the fix is small.

**Why:** people would likely ask this often, but the agent can't read the logs. A step with the token would fetch the failed checks' logs on PR events (`gh run view --log-failed`) into a file, the way `issues.json` is fetched. The skill reads that file.

**Build when:** this is the next feature after the ones above. It's the only candidate that needs action code.

## Considered and dropped

- **Duplicate or related issues:** the built-in note already searches `issues.json`.
- **"How does X work":** a plain answer covers it. There's no procedure to fix.
- **Release notes:** every repo does them differently. This repo has its own `release` skill.
- **Labelling and triage:** needs the API, and `examples/triage.yml` does it as a workflow step.
