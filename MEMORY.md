# Agent memory

What earlier agent runs learned about this repository: how it is laid out,
what recurs, what its people prefer, decisions and why, traps. Dated, edited
in place, under 80 lines. A model of the repo, not a diary of runs.

- 2026-09-11: The CI checkout is shallow (depth 1): `git log`/`git blame` show
  only the single HEAD commit. Use AGENTS.md, CHANGELOG.md and docs/ for
  history, not git.
- 2026-09-11: The note/comment jobs give the agent's shell no `GH_TOKEN`, so
  `gh issue view` fails. `issues.json` (fetched by build-prompt.sh) is the only
  issue list.
- 2026-09-11: Do not hand-run `scripts/memory.sh fetch` to smoke-test it: with
  no token the non-404 path does `rm -rf .agent-memory`, and the Save memory
  step then finds no file and records `unchanged`. Recreate the file if you do.
- 2026-09-11: Memory shipped in f370b4b. `docs/agent-memory.md:290` still names
  the branch `fx-memory`; the default is `agent-memory` (action.yml:78,
  memory.sh:19).
- 2026-09-11: read + `shell: true` allows both `edit` and `shell` by rule
  (action.yml:402-409), which the memory edit instruction depends on. The
  comment at action.yml:354-356 claiming edit "stays denied" is stale.
- 2026-09-11: check.yml runs shellcheck -S warning, actionlint and the
  sanitizer cases; nothing covers scripts/memory.sh.
