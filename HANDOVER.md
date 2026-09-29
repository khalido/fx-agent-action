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

Nothing in this repo. One loose end outside it: **`khalido/rd` migrated its
workflow to 1.1.0's inputs in `fb5a852` but never pushed it** (its main is
ahead of origin), so origin still passes `shell: true` and every `/fx` there
fails on the first step. Noted in rd's `BOARD.md`; it needs a push from an rd
session. KO's repos ride `@main` on purpose; `jaldi` and `sfl-parts` pin
`@v1`.

## Not in flight, but parked and worth knowing

`#7` carries a designed experiment that nobody has run: whether the agent
declines to write a value it is told not to author, with three instruction
layers in its way, and which layer does the work. `khalido/koevguide` is set up
as the test bed and has offered to run it. It needs KO's say-so and his spend.
The method note there matters more than the result: a rule stated in two layers
cannot tell you which layer carried the run, so a probe needs a rule with
exactly one source and a failure the mechanical checks do not intercept.
