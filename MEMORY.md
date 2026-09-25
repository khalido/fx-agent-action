# Agent memory

What earlier agent runs learned about this repository: how it is laid out,
what recurs, what its people prefer, decisions and why, traps. Dated, edited
in place, under 80 lines. A model of the repo, not a diary of runs.

- 2026-09-14: #4 is real and CHANGELOG.md:84-86 admits it: the always() "Take the reaction back off" step (action.yml:629-639) runs react.sh with the write token and no integrity gate — the only gated-directory script that runs after fx.
- 2026-09-14: #4 is deliberately left open (gate and strand the 👀, or inline the DELETE) — do not "fix" it silently.
- 2026-09-14: #6: all six scripts/check-actor.sh outcomes reproduce with a gh stub first on PATH, no GH_TOKEN, no network.
- 2026-09-14: #6: exit codes distinguish nothing (four of six exit 0), so assert GITHUB_OUTPUT — unset writes /dev/null (:79), and the case then passes for the wrong reason.
- 2026-09-14: #6: bot and stranger rows need MODE=read. The `shell` input is gone — one `mode` input since 4d3490f — so do not re-add SHELL_TOOL. The stub must tell users/ 404 (App → needs allowed_bots) from 500 (fail closed).
- 2026-09-14: #6: check.yml:24's scripts/.sh glob will not lint scripts/tests/.sh; house pattern is inline cases, like the sanitizer at :70ff.
- 2026-09-25: #11 confirmed on 0.0.11: `fx usage --json` .totals and every .models[].totals carry cache_read_tokens/cache_write_tokens, present even on zero-spend BYOK generations (this runner: 54,443 in / 32,128 read / 3,463 write; both are subsets of input_tokens). Nothing new to plumb: run-fx.sh:93,100-103 already reads .totals and :122-123 echoes in/out to GITHUB_OUTPUT. To show it in the footer, the two files are run-fx.sh (add two jq reads + two echo lines) and post-comment.sh:82,88 (def k + the footer string); action.yml:702-703 is the env passthrough. cost.sh reads the same object but prints no tokens.
- 2026-09-25: #11: cost.sh:27-30 still exits as soon as totals.spend > 0, before the gateway lookups and without a providers= line, so a run mixing a gateway-billed helper with a BYOK model drops the BYOK charge entirely. Unfixed on this commit.
- 2026-09-25: #11: cost.sh:53 sets cost_estimated=false on both the ledger and the gateway-lookup paths, so a BYOK figure looks gateway-billed; post-comment.sh:79 renders est:true as ≈ — do not reuse it for the upstream basis.
- 2026-09-25: #11 tokens vs dollars already cover different request sets: in/out come from steps.run (run-fx.sh reads fx usage before any compaction) while the dollars prefer steps.memory_save.outputs.cost (action.yml:698-700), which includes a later fx usage over a HOME that now holds fx pr and the compaction.
- 2026-09-14: #11: GET /v1/generation?id= 404s seconds after creation and 200s later, so || true skips the unsettled ones.
- 2026-09-15: #15 gaps 1-2 closed on main in #19: open-pr.sh:70-76 scrubs .agent-pr.md unconditionally, before the title parse at :80, with no `|| true`; no `fx pr` drafting call is left in scripts/. Do not re-flag.
- 2026-09-15: #15 gap 3 open, now the whole issue: memory.sh has 0 redact calls; $content is base64 at :113 and again at :167 after the 409 merge, PUT at :137.
- 2026-09-15: #15 fix shape: scrub $file right before each base64 — the merge path rewrites $file from before.md/theirs, so one pre-:113 scrub lets a line from `theirs` back through. ~6-10 lines, plus a guard so a python3 failure sets memory=unsaved and skips the push (memory.sh:8 promises to never fail the run).
- 2026-09-15: #15 docs to change with it: AGENTS.md:32 and :274-275 ("both the answer and the session HTML"), redact.py:10-15 ("Not what fx writes to a FILE"), CHANGELOG.md:153-158.
- 2026-09-15: #15: the AI_GATEWAY_API_KEY env sits on the `uses:` step (examples/fx.yml:94), so every composite step inherits it — a scrub inside memory.sh sees the gateway key, not just GH_TOKEN.
- 2026-09-14: #15: pre-fix branch content is not retroactively scrubbed; a key already on agent-memory stays in its history, so rotating beats rewriting.
- 2026-09-14: #12 (agent-decides PR, couples to #5): the code claims hold — model chosen once at Configure (action.yml:402) and read back (:424), snapshot gate :499, fingerprint already in scratch mode (:483, :523).
- 2026-09-14: #12: pr_model cannot be scoped to the PR text (one session, one model) — keep it and every note runs on the write model, or delete the input.
- 2026-09-14: #12: a signal file cannot gate a step if: — read it in the inline integrity step :521-552 and emit an output for :587.
- 2026-09-14: #12: a new agent-written PR-text file needs its own redact.py pass; only run-fx.sh:52 and open-pr.sh:65 are scrubbed today.
- 2026-09-15: #5 re-confirmed on main c0aac03: the event shortcut (check-actor.sh:80-86) still exits before the allowed_bots read-mode block (:93-99), so schedule/workflow_dispatch/push + a listed bot → exit 0, write_access=true (repro: dependabot[bot], ALLOWED_BOTS=dependabot, MODE=agent). Mode is not tied to write_access: `mode` defaults to agent (action.yml:55), no verb decides it since 4d3490f, so the old #5 comment's "a schedule is read mode" (true of b96e6a7:146-147 auto+no pr verb) is now false.
- 2026-09-14: #12: the snapshot sits after Build the prompt, so issues.json/__pycache__ never ship; schedule/dispatch skip the write check and pass write_access=true (check-actor.sh:81-87).
- 2026-09-14: The 409 merge loses in practice — concurrent runs got 409 at memory.sh:175, zero merges, and the loss shows only as a check annotation.
- 2026-09-14: Losers' appends land on the final lines, where the winner's last hunk is; only an edit the winner left alone merges.
- 2026-09-14: Compaction compounds that loss: "Newest first" over an oldest-first file permutes everything.
- 2026-09-14: Compaction itself works — 88 lines in → 25 out, heading kept, no fences, inside the cap+5 guard (memory.sh:101); do not test with memory_lines: 5 here, that cap is the real branch's — use memory_repo.
- 2026-09-13: fx's shell-command permission key is bash, not shell: on 0.0.9 an ALLOW under shell does not bind (a DENY only hides the tool), so agent/answer's {edit,shell} allow at action.yml:386-390 leaves its shell allow inert and every shell call goes to the auto reviewer.
- 2026-09-13: The read-back at action.yml:426-429 cannot catch that — fx permissions echoes any key verbatim, so AGENTS.md's "edit and shell are the two measured to bind" is wrong for allow.
- 2026-09-13: Bash rule patterns glob the WHOLE command string and the last match wins, so a prefix deny leaks through &&; a railway variables deny placed after a broad railway allow does hold.
- 2026-09-13: Probe with fx ask in a temp HOME: the run env has fx 0.0.9 + AI_GATEWAY_API_KEY (models.gateway=deepseek-v4.1-flash).
- 2026-09-11: Full history since 4b9810b (fetch-depth: 0 in fx.yml), so git log -S/git blame work.
- 2026-09-11: Note/comment jobs have no GH_TOKEN, so gh issue view and logs fail and issues.json (build-prompt.sh) is the only issue list.
- 2026-09-11: Anonymous API does answer for commits?sha=agent-memory, contents/MEMORY.md?ref=agent-memory and check-runs/<id>/annotations — the only view of memory.sh's warns.
- 2026-09-11: The memory block is quoted before sanitize.py runs on the whole context (build-prompt.sh:343), and the memory-edit instruction is gated on mode != read + MEMORY_WRITABLE (build-prompt.sh:254-255) — the INPUT_SHELL gate in this line's old text no longer exists; both #3 traps are handled in code.
- 2026-09-11: The write-access gate from #3 is in the tree since a0d3bf8, in two places, not memory.sh: check-actor.sh:79 emits write_access, action.yml:595 gates Save memory, and action.yml:329 feeds MEMORY_WRITABLE from write_access; step-level if: is the determinism, fail closed.
- 2026-09-15: #16: the fix taken is the base block, not the note. Read mode's paragraph (build-prompt.sh:192-196) now names the note's commands — a grep, git log, the tests — and says read the files instead and label the claim unverified. prompts/issue.md:12,29,49 is still ungated; khalido's last word on #16 was to gate it, so that half was decided against, not overlooked.
- 2026-09-15: #16: that sentence and the agent/answer/read rework exist only on `one-agent` (b690fae, 2026-09-15); origin/main (b96e6a7) still has read mode with no fallback sentence, so on main the contradiction is live.
- 2026-09-15: #16: check.yml builds read mode only from a comment event (:92) and the built-in note only in default mode (:46-58), so read + the note — the exact configuration — is untested; one more case there is the cheap guard.
- 2026-09-11: check.yml = shellcheck -S warning, actionlint, the dogfood diff, the prompt cascade, skills frontmatter, py_compile + sanitizer cases; nothing functionally covers memory.sh or check-actor.sh.
- 2026-09-11: memory.sh fetch no longer deletes .agent-memory/ on an API error (1c93098); 1085748 flipped the memory default to true; memory.sh splits 403 (token) from 409 (race) on the push (f519a1e, cases at :145-157) — do not re-flag.
- 2026-09-11: docs/agent-memory.md:1-5 reconciles the branch name — the fx-memory refs below it (--delete fx-memory at :292) are the preserved survey, not stale docs; default agent-memory (action.yml:78, memory.sh:19) — do not flag again.
- 2026-09-14: #17: the `issue_comment: types: [created]` bug lived in three copies — README.md:20, examples/build-it.yml:21, examples/minimal-no-action.yml:21 — and check.yml's dogfood diff normalizes only examples/fx.yml against .github/workflows/fx.yml, so those three are checked against nothing; README.md:20 shipped fixed on branch, the two examples still stale.
- 2026-09-14: #17: this runner has no GH_TOKEN, so the cascade's `test -s issues.json` assertion cannot be reproduced locally (build-prompt.sh:270 gates the fetch on one); CI's check job supplies github.token, so run the rest and say so.
- 2026-09-11: Do not trust an issue comment's "verification" as repo state: the 04:05 #3 comment described MEMORY_ACTOR_WRITE and scripts/tests/actor-check.sh, neither of which ever existed in any ref — grep/git log -S the tree first.
