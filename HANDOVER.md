# Handover

Work in flight, for the next agent or person who picks this repo up cold.
`AGENTS.md` is how to work on the action and does not go stale. This file is
what is half-done right now, and it goes stale the moment someone finishes
something.

## If you were pointed at this file, you own it

Read it, do the work, and **before you finish, leave it true**:

- **Delete what you finished.** Not a "Done" section, not a dated line — take
  it out. `git log` is the record and it is better than anything you would
  write here. This file is a model of what is outstanding, not a diary of what
  happened. (Same doctrine as the agent memory: edit in place, delete stale,
  earn its place.)
- **Add what the next one needs**, and only that: what you learned that is not
  in the code, what you tried that did not work, what you were about to do.
- **Correct what you found to be wrong.** Everything below is a claim by
  whoever wrote it, not a fact. If the code disagrees, the code wins — fix the
  line, do not work around it.
- **If nothing is in flight**, say so in one line and delete the rest. An empty
  handover is a good outcome. A stale one is worse than none, because the next
  agent will believe it.

---

## In flight

Nothing half-built. Small follow-ups from the fx 0.0.16 pass (2026-11-02,
#27–#29), none started:

- **`/fx` on a PR reads the pre-change files.** `examples/fx.yml` checks out
  the default branch on `issue_comment`, so the agent gets the PR diff in the
  prompt (`include_diff`) but every file it opens is the old version. Fix in
  the example (check out the PR head on PR comments) and in this repo's
  `fx.yml`, which `check.yml` keeps identical.
- **`skills/compare-models/SKILL.md` still calls list-price tokens the spend
  "at most".** Since 0.0.16 they include cache reads and `cost.sh` prices the
  serving host; the skill should say the same. Listed in `docs/skills.md`.
- **Answers to questions average about 280 words** against the base block's
  250 cap, before and after #29. Watch it; not worth a prompt change yet.
- **`provider_order: wafer, baseten`** came from 6 local runs per host on two
  questions. The gateway's stats for wafer look thin (p50 equals p95), so if
  footers start showing slow wafer runs or `via baseten` often, recheck.

One loose end outside this repo: **`khalido/rd` migrated its workflow to
1.1.0's inputs in `fb5a852` but never pushed it** (its main is ahead of
origin), so origin still passes `shell: true` and every `/fx` there fails on
the first step. Noted in rd's `BOARD.md`; it needs a push from an rd session.
KO's repos ride `@main` on purpose; `jaldi` and `sfl-parts` pin `@v1`.

## Not in flight, but parked and worth knowing

`#7` carries a designed experiment that nobody has run: whether the agent
declines to write a value it is told not to author, with three instruction
layers in its way, and which layer does the work. `khalido/koevguide` is set up
as the test bed and has offered to run it. It needs KO's say-so and his spend.
The method note there matters more than the result: a rule stated in two layers
cannot tell you which layer carried the run, so a probe needs a rule with
exactly one source and a failure the mechanical checks do not intercept.
