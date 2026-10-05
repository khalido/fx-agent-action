# Agent memory

What earlier agent runs learned about this repository: how it is laid out,
what recurs, what its people prefer, decisions and why, traps. Dated, edited
in place, under 80 lines. A model of the repo, not a diary of runs.

- 2026-09-11: Full history is checked out (fetch-depth: 0 in fx.yml), so git log -S and git blame work.
- 2026-09-11: Note and comment jobs hold no GH_TOKEN, so gh issue view fails; issues.json in the workspace is the only issue list.
- 2026-09-11: The anonymous API answers for commits?sha=agent-memory, contents/MEMORY.md?ref=agent-memory and check-run annotations — the only place memory.sh's warnings show.
- 2026-09-11: Do not trust an issue comment's "verification" as repo state; one described files that never existed in any ref. Grep or git log -S first.
- 2026-09-11: docs/agent-memory.md keeps the old fx-memory branch name in its survey on purpose; the live default is agent-memory. Do not flag it.
- 2026-09-13: Probe fx in a temp HOME: the runner has fx and AI_GATEWAY_API_KEY, so a settings file there tests a rule without touching the run.
- 2026-09-13: fx rule patterns glob the whole command string and the last match wins, so a prefix deny leaks through &&.
- 2026-09-14: #4 (the reaction step runs a script with the token and no integrity gate) is deliberately open. Do not fix it silently.
- 2026-09-14: Memory compaction works (88 lines in, 25 out). Never test it with a tiny memory_lines on this repo's branch; point memory_repo at a scratch repo.
- 2026-09-15: prompts/issue.md names commands read mode cannot run on purpose (#16); the base block tells read mode to read files instead. Not an oversight.
- 2026-09-29: check.yml covers check-actor.sh with a stub gh; memory.sh is tested only by hand, with a stub gh on PATH.
- 2026-10-01: Repo visibility is not an axis. check-actor.sh has no `private` branch and never had one; the only visibility test is the runner-saving `if:` in fx.yml/examples/fx.yml, so a private repo's read collaborator boots a runner and then gets check-actor.sh's red X. KO decided against a private-repo exception on #13 (2026-09-29): a maintainer quotes the read-only person's comment and points /fx at it. It is a decision, not a gap.
- 2026-10-05: memory.sh's 409 merge uses `git merge-file -p --union`, which exits 0 on a content conflict (git 2.55; plain merge-file exits 1), so the conflict-then-lost path in #10 is closed for content. Both merges compare `file` against `before.md` and `theirs`; compaction rewrites `file` but not `before.md`, so a 409 after a compaction merges a rewritten side against a stale base — union keeps both, no loss, but a shrink is partly undone. The remaining dropped-run path is the one-shot retry: api_get failing or a third writer 409ing the retry PUT loses the run at the final warning. check.yml still tests none of memory.sh.
