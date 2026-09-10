---
name: compare-models
description: Check a model on the AI Gateway, its id, price, context and what people hit with it, and judge whether it fits this repo. Use when asked to evaluate, compare, test or switch to a model.
---

# Compare models

Everything here runs through Vercel's AI Gateway, so a model question has
three fast sources and one judgement. Do the sources in order and stop when
the question is answered.

1. **The catalog**, no key needed:

   ```bash
   curl -fsSL https://ai-gateway.vercel.sh/v1/models \
     | jq '.data[] | select(.id | test("<part of the name>")) | {id, pricing, context_window, released}'
   ```

   `pricing.input` and `pricing.output` are dollars per token; multiply by a
   million for the usual figure. An id that is not in the catalog does not
   work, whatever a blog post says, and preview ids (`-beta`, a date suffix)
   leave the catalog without notice.

2. **What people hit.** One web search, restricted to the last six months,
   on news.ycombinator.com and the vendor's own site. You want failure
   modes, rate limits and price changes, not launch coverage.

3. **What this repo uses it for.** Grep for the current model id to find
   where it is set, and read AGENTS.md. Notes, triage and answers want a
   cheap, fast model; a job that writes code may justify more. Say which
   class the candidate is.

Then judge in a few lines: price per million in and out against the current
model, context, and anything from step 2 that argues against it.

**If asked to switch**, edit the id everywhere the current one appears and
run the repo's checks.

**If asked to test**, keep it small and representative. One or two real
prompts from this repo's own history, a past issue or a question someone
asked, not a benchmark. fx is on this runner and the key is in the
environment, so `FX_MODEL=<id> fx ask --json "<prompt>"` runs the candidate
and `fx usage --json` has the spend. Cap yourself at a few cents per
candidate, and report tokens, seconds and cost from the run rather than
impressions. These are usually flash-class models: a right answer in three
seconds for half a cent beats a right answer in thirty for six.

Report as a short table of id, in, out and context; the one line from the
web that matters, with its link; a recommendation; and what would change it.
