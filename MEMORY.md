# Agent memory

What earlier agent runs learned about this repository: how it is laid out,
what recurs, what its people prefer, decisions and why, traps. Dated, edited
in place, under 80 lines. A model of the repo, not a diary of runs.

- 2026-09-11: The CI checkout is shallow: `git log` shows only the last few
  commits (HEAD 1085748, 4b9810b, 1c93098), nothing older. Use AGENTS.md,
  CHANGELOG.md and docs/ for history, not git.
- 2026-09-11: The note/comment jobs give the agent's shell no `GH_TOKEN`, so
  `gh issue view` fails. `issues.json` (fetched by build-prompt.sh) is the only
  issue list.
- 2026-09-11: Do not hand-run `scripts/memory.sh fetch` to smoke-test it: with
  no token the non-404 path does `rm -rf .agent-memory`, and the Save memory
  step then finds no file and records `unchanged`. Recreate the file if you do.
- 2026-09-11: `docs/agent-memory.md:1-5` already reconciles the branch name:
  it shipped as `agent-memory`, and the `fx-memory` references below (including
  `--delete fx-memory` at :292) are the preserved survey, not stale docs. Do not
  flag them as a bug again. Default is agent-memory (action.yml:78, memory.sh:19).
- 2026-09-11: read denies `edit`/`shell` by rule; `shell: true` flips both to
  allow (`tool_rule` at action.yml:407), which the memory edit instruction
  depends on. The comment at action.yml:347-358 now describes this correctly.
- 2026-09-11: The memory block is quoted before sanitize.py runs on the whole
  context (build-prompt.sh:343), and in read mode its edit instruction is gated
  on `INPUT_SHELL == true` (build-prompt.sh:189), so plain read mode is told it
  cannot edit. Both traps from the issue are handled in code.
- 2026-09-11: check.yml runs shellcheck -S warning, actionlint and the
  sanitizer cases; nothing covers scripts/memory.sh functionally, though
  shellcheck and `bash -n` on it pass.
- 2026-09-11: 1085748 flipped the `memory` default to `true` (action.yml:78),
  so every consumer writes to `agent-memory` unless it opts out. The
  `contents: write` notice (memory.sh:127) only covers the create-branch path;
  on an existing branch a read token's 403 PUT is merged as if it were a 409
  (:138-160) and mislabelled "another run changed MEMORY.md". Unconfirmed live.
