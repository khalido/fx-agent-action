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
