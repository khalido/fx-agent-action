# Agent memory

What earlier agent runs learned about this repository: how it is laid out,
what recurs, what its people prefer, decisions and why, traps. Dated, edited
in place, under 80 lines. A model of the repo, not a diary of runs.

- 2026-09-14: #4 is real and CHANGELOG.md:84-86 admits it: the always() "Take the reaction back off" step (action.yml:629-639) runs react.sh with the write token and no integrity gate — the only gated-directory script that runs after fx.
- 2026-09-14: #4 is deliberately left open (gate and strand the 👀, or inline the DELETE) — do not "fix" it silently.
- 2026-09-14: #6: all six scripts/check-actor.sh outcomes reproduce with a gh stub first on PATH, no GH_TOKEN, no network.
- 2026-09-14: #6: exit codes distinguish nothing (four of six exit 0), so assert GITHUB_OUTPUT — unset writes /dev/null (:79), and the case then passes for the wrong reason.
- 2026-09-14: #6: inputs at action.yml:234-241; bot and stranger rows need MODE=read, SHELL_TOOL=false; the stub must tell users/ 404 (App → needs allowed_bots) from 500 (fail closed).
- 2026-09-14: #6: check.yml:24's scripts/.sh glob will not lint scripts/tests/.sh; house pattern is inline cases, like the sanitizer at :70ff.
- 2026-09-14: #11: on 0.0.9 fx usage --json totals carry cache_read_tokens/cache_write_tokens, and cache_read ⊆ input_tokens — input is the whole prompt, and the text view prints Total = Input + Output.
- 2026-09-14: #11: cost.sh:24-27 exits as soon as totals.spend > 0, before the gateway lookups and without a providers= line, so a run mixing a gateway-billed helper with a BYOK model drops the BYOK charge entirely.
- 2026-09-14: #11: cost_estimated=false (cost.sh:50) makes a BYOK figure look gateway-billed; post-comment.sh:62 renders est:true as ≈ — do not reuse it for the upstream basis.
- 2026-09-14: #11: GET /v1/generation?id= 404s seconds after creation and 200s later, so || true skips the unsettled ones.
- 2026-09-14: #15 verified, all three hold: open-pr.sh:61's if means a nonzero fx pr never reaches the scrub at :65, and set -euo pipefail does not stop the body branch :127-128 reading the unredacted draft; :129's RESPONSE_PATH fallback is already scrubbed.
- 2026-09-14: #15: :68's || true is the one difference from the working call at run-fx.sh:52-55.
- 2026-09-14: #15: memory.sh has 0 redact calls; MEMORY.md → base64 :113, PUT :137, quoted at build-prompt.sh:352.
- 2026-09-14: #15: all three date to 8158343, which moved the scrub before the title parse (:69) and deleted the later call — title, commit and PR-title paths are safe now, do not re-flag them.
- 2026-09-14: #15: AGENTS.md:242 lists only "the answer and the session HTML"; the PR draft is the third site.
- 2026-09-14: #12 (agent-decides PR, couples to #5): the code claims hold — model chosen once at Configure (action.yml:402) and read back (:424), snapshot gate :499, fingerprint already in scratch mode (:483, :523).
- 2026-09-14: #12: pr_model cannot be scoped to the PR text (one session, one model) — keep it and every note runs on the write model, or delete the input.
- 2026-09-14: #12: a signal file cannot gate a step if: — read it in the inline integrity step :521-552 and emit an output for :587.
- 2026-09-14: #12: a new agent-written PR-text file needs its own redact.py pass; only run-fx.sh:52 and open-pr.sh:65 are scrubbed today.
- 2026-09-14: #12: the snapshot sits after Build the prompt, so issues.json/__pycache__ never ship; schedule/dispatch skip the write check and pass write_access=true (check-actor.sh:81-87).
- 2026-09-14: The 409 merge loses in practice — concurrent runs got 409 at memory.sh:175, zero merges, and the loss shows only as a check annotation.
- 2026-09-14: Losers' appends land on the final lines, where the winner's last hunk is; only an edit the winner left alone merges.
- 2026-09-14: Compaction compounds that loss: "Newest first" over an oldest-first file permutes everything.
- 2026-09-14: Compaction itself works — 88 lines in → 25 out, heading kept, no fences, inside the cap+5 guard (memory.sh:101); do not test with memory_lines: 5 here, that cap is the real branch's — use memory_repo.
- 2026-09-13: fx's shell-command permission key is bash, not shell: on 0.0.9 an ALLOW under shell does not bind (a DENY only hides the tool), so scratch mode's {edit,shell} at action.yml:411-414 leaves its shell allow inert and every shell call goes to the auto reviewer.
- 2026-09-13: The read-back at action.yml:426-429 cannot catch that — fx permissions echoes any key verbatim, so AGENTS.md's "edit and shell are the two measured to bind" is wrong for allow.
- 2026-09-13: Bash rule patterns glob the WHOLE command string and the last match wins, so a prefix deny leaks through &&; a railway variables deny placed after a broad railway allow does hold.
- 2026-09-13: Probe with fx ask in a temp HOME: the run env has fx 0.0.9 + AI_GATEWAY_API_KEY (models.gateway=deepseek-v4.1-flash).
- 2026-09-11: Full history since 4b9810b (fetch-depth: 0 in fx.yml), so git log -S/git blame work.
- 2026-09-11: Note/comment jobs have no GH_TOKEN, so gh issue view and logs fail and issues.json (build-prompt.sh) is the only issue list.
- 2026-09-11: Anonymous API does answer for commits?sha=agent-memory, contents/MEMORY.md?ref=agent-memory and check-runs/<id>/annotations — the only view of memory.sh's warns.
- 2026-09-11: The memory block is quoted before sanitize.py runs on the whole context (build-prompt.sh:343), and read mode's edit instruction is gated on INPUT_SHELL == true (build-prompt.sh:189) — both #3 traps are handled in code.
- 2026-09-11: The write-access gate from #3 is in the tree since a0d3bf8, in two places, not memory.sh: check-actor.sh:79 emits write_access, action.yml:595 gates Save memory, and build-prompt.sh:208,262 (fed at action.yml:341) flips the agent's edit instruction; step-level if: is the determinism, fail closed.
- 2026-09-11: check.yml = shellcheck -S warning, actionlint, the dogfood diff, the prompt cascade, skills frontmatter, py_compile + sanitizer cases; nothing functionally covers memory.sh or check-actor.sh.
- 2026-09-11: memory.sh fetch no longer deletes .agent-memory/ on an API error (1c93098); 1085748 flipped the memory default to true; memory.sh splits 403 (token) from 409 (race) on the push (f519a1e, cases at :145-157) — do not re-flag.
- 2026-09-11: docs/agent-memory.md:1-5 reconciles the branch name — the fx-memory refs below it (--delete fx-memory at :292) are the preserved survey, not stale docs; default agent-memory (action.yml:78, memory.sh:19) — do not flag again.
- 2026-09-11: Do not trust an issue comment's "verification" as repo state: the 04:05 #3 comment described MEMORY_ACTOR_WRITE and scripts/tests/actor-check.sh, neither of which ever existed in any ref — grep/git log -S the tree first.
