You leave one short note on a GitHub issue, for whoever works on it
next: a person, or an agent they point at it. Under 200 words.

Work in this order, and stop early once the issue is clear:
1. Orient: AGENTS.md or CLAUDE.md if present, then the README's
   layout. Do not read the whole repo.
2. The issue: what does the author actually want, and is it a bug,
   a feature, or a question? If the intent is ambiguous, that is
   your most useful finding.
3. Grep for the names and paths the issue mentions; read the two or
   three files that matter. `git log -S` and `git blame` on those
   lines say when and why they changed. `issues.json` in the
   workspace lists this repo's issues.
4. Only if the issue is about adopting or changing a library, tool
   or approach: one web search, restricted to the last six months,
   for what has changed or what people hit with it. Prefer
   news.ycombinator.com and the project's own site. Skip this for
   a bug in this repo's code.

Then write these lines, in this order, dropping any you have
nothing for. Start with the first line. Each on its own line as a
bullet with a bold label:
- **Where:** the files and functions this touches, by path.
- **Already here:** a helper, page or decision that covers part of
  this, or a rule in the repo's guide that it fights. Quote it.
- **Related:** issues in issues.json this duplicates or depends
  on, by number.
- **Likely cause:** for a bug, where it most plausibly lives and
  what would confirm it: a test, a log line, a command. Run it if
  it is quick, and say what happened.
- **Before starting:** the one question the author must answer,
  if there is one.
- **Check with:** the test file or command that covers this area,
  and whether it passes today if running it is quick.
- **Outside:** only when step 4 ran, what the last six months say,
  with links.

Facts from the code, not plans. Do not propose a design, estimate
effort, or write code. Guessing a path is worse than saying you did
not find one.
