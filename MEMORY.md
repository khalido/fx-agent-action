# Agent memory

What earlier agent runs learned about this repository: how it is laid out,
what recurs, what its people prefer, decisions and why, traps. Dated, edited
in place, under 80 lines. A model of the repo, not a diary of runs.

- 2026-09-11: Full history since 4b9810b (`fetch-depth: 0` in fx.yml), so
  `git log -S` and `git blame` work; an earlier run read "shallow" off `git log -3`.
- 2026-09-11: Note/comment jobs have no `GH_TOKEN`: `gh issue view` and logs
  fail, `issues.json` (build-prompt.sh) is the only issue list. Anonymous API does
  answer for `commits?sha=agent-memory`, `contents/MEMORY.md?ref=agent-memory` and
  `check-runs/<id>/annotations` — the last is the only view of memory.sh's warns.
- 2026-09-14: The 409 merge loses in practice: six of seven 09-14 runs started
  inside 90s, #6 wrote a8fcd54 and #5/#7/#9 each got 409 at memory.sh:175 — three
  attempts, zero merges, the loss visible only as a check annotation. Losers'
  appends land on the final lines where the winner's last hunk is; only an edit the
  winner left alone merges. Compaction compounds: "Newest first" over an
  oldest-first file permutes everything.
- 2026-09-14: Compaction's model call works, measured 88 lines in → 25 out, heading
  kept, no fences, inside the cap+5 guard (memory.sh:101). Do not test it with
  `memory_lines: 5` here — that cap is the real branch's; use `memory_repo`.
- 2026-09-11: `memory.sh fetch` no longer deletes `.agent-memory/` on an API error (1c93098); safe by hand.
- 2026-09-11: `docs/agent-memory.md:1-5` reconciles the branch name — the
  `fx-memory` refs below it (incl. `--delete fx-memory` at :292) are the preserved
  survey, not stale docs. Do not flag again. Default `agent-memory`
  (action.yml:78, memory.sh:19).
- 2026-09-13: fx's shell-command permission key is `bash`, not `shell`. On 0.0.9 an
  ALLOW under `shell` does not bind (a DENY only hides the tool); action.yml:411-414
  writes {edit,shell}, so scratch mode's shell allow is inert and every shell call
  falls to the auto reviewer. Read-back at :426-429 can't catch it — `fx permissions`
  echoes any key verbatim. AGENTS.md "edit and shell are the two measured to bind"
  is wrong for allow.
- 2026-09-13: Bash rule patterns glob the WHOLE command string and the last match
  wins, so a prefix deny leaks through `&&`; a `*railway variables*` deny placed
  after a broad `*railway*` allow does hold. Probe with fx ask in a temp HOME: the
  run env has fx 0.0.9 + AI_GATEWAY_API_KEY (models.gateway=deepseek-v4.1-flash).
- 2026-09-11: The memory block is quoted before sanitize.py runs on the whole
  context (build-prompt.sh:343), and read mode's edit instruction is gated on
  `INPUT_SHELL == true` (build-prompt.sh:189). Both #3 traps are handled in code.
- 2026-09-11: check.yml = shellcheck -S warning, actionlint, the dogfood diff, the
  prompt cascade, skills frontmatter, py_compile + sanitizer cases. Nothing
  functionally covers memory.sh or check-actor.sh.
- 2026-09-11: 1085748 flipped `memory` default to true. memory.sh splits a 403
  (token) from a 409 (race) on the push since f519a1e; memory.sh:145-157 cases
  403|404 vs 409 vs other. Do not re-flag.
- 2026-09-11: The write-access gate from #3 is in the tree since a0d3bf8, in two
  places, not memory.sh: check-actor.sh:79 emits `write_access`, action.yml:595
  gates Save memory, build-prompt.sh:208,262 (fed at action.yml:341) flips the
  agent's edit instruction. Step-level `if:` is the determinism; fail closed.
- 2026-09-11: Do not trust an issue comment's "verification" as repo state. The
  04:05 #3 comment described `MEMORY_ACTOR_WRITE` and `scripts/tests/actor-check.sh`;
  neither ever existed in any ref. 4b69005 reverts action.yml + scripts/ from HEAD
  in read-mode runs. `grep`/`git log -S` the tree first.
- 2026-09-14: #6: all six check-actor.sh outcomes reproduce with a `gh` stub first
  on PATH, no GH_TOKEN, no network. Exit code distinguishes nothing (four of six
  exit 0), so assert GITHUB_OUTPUT; unset GITHUB_OUTPUT writes /dev/null (:79) and
  the case passes for the wrong reason. Inputs (action.yml:234-241): ACTOR,
  EVENT_NAME, SENDER_TYPE, GITHUB_REPOSITORY, GITHUB_OUTPUT=<file>, MODE, ALLOWED_BOTS,
  ALLOWED_NON_WRITE_USERS (the bot and stranger rows need MODE=read, SHELL_TOOL=false).
  Stub must tell `users/*` 404 (an App → Bot → needs allowed_bots) from 500 (fail
  closed). check.yml:24's `scripts/*.sh` glob won't lint scripts/tests/*.sh; the
  sanitizer keeps its cases inline in check.yml:70ff, the house pattern.
- 2026-09-14: #4 is real and CHANGELOG:84-86 admits it: the `always()` "Take the
  reaction back off" step (action.yml:629-639) runs react.sh with the write token
  and no integrity gate — the only gated-directory script that runs after fx. The
  repo left the choice open (gate and strand the 👀, or inline the DELETE). Do not
  "fix" it silently.
- 2026-09-14: #11 cost/footer: on 0.0.9 `fx usage --json` totals carry
  `cache_read_tokens`/`cache_write_tokens` (verified: input 202168, read 166656,
  write 11613) and `cache_read ⊆ input_tokens` — input is the whole prompt
  (37599 in / 36992 cached, the 607 left is the new turn; fx's text view prints
  Total = Input + Output with Cache on its own line). cost.sh:24-27 exits as soon as
  `totals.spend > 0`, before the gateway lookups and without a `providers=` line, so
  a run mixing a gateway-billed helper with a BYOK model drops the BYOK charge
  entirely (this runner: 9 luna calls = the whole $0.0074, deepseek upstream
  0.0021 unclaimed). `cost_estimated=false` on cost.sh:50 makes the
  BYOK figure indistinguishable from a gateway-billed one; post-comment.sh:62 renders
  `est:true` as `≈` = list-price estimate, so do not reuse it for the upstream basis.
  `GET /v1/generation?id=` 404s for generations created seconds earlier and 200s once
  settled — cost.sh's `|| true` silently skips the unsettled ones.
