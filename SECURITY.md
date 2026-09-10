# Security

This action reads untrusted text (issue bodies, comments, diffs) and, in write
mode, runs an agent with a token that can push a branch. If you find a way to
make it do something its README says it cannot, report it privately through
[GitHub's advisory form](https://github.com/khalido/fx-agent-action/security/advisories/new)
rather than an issue. Say which version, and include the comment or payload
that triggers it if you can.

What is in scope: the actor checks, the read-mode tool denial, the hidden-markup
stripping, the secret scrubbing, and anything that lets a run write outside a
draft PR. Also in scope: text in an issue or comment that gets a run with the
shell to run a command, because that shell can read the gateway key. The
controls there are who may trigger a run and the budget on the key; a way past
the first is a report. Not in scope: injection that only changes what the agent
*says* in a comment, which the README treats as expected, and anything in fx
itself (report that to [vercel-labs/fx](https://github.com/vercel-labs/fx/security)).

Fixes ship as a PATCH release and move the `v1` tag, so a workflow pinned to
`@v1` picks them up on its next run.
