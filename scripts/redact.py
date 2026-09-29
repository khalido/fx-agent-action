"""Strip secrets out of anything this action is about to publish.

fx never prints the gateway key itself, but in write mode its shell tool is a
child process and inherits the environment — measured: an agent-run
`test -n "$AI_GATEWAY_API_KEY"` reports PRESENT. GitHub masks secrets in logs,
not in the API request bodies this action sends, and not inside an artifact.
So a comment, a pull request body and a session artifact are three ways out of
the runner that log masking does not cover.

Used by run-fx.sh (the answer), open-pr.sh (fx's whole PR draft, the moment it
is written — the title is parsed out of it into a commit message that is pushed
before the body is ever read), session-html.py (the transcript) and memory.sh
(MEMORY.md, which is pushed to a branch and quoted into every later prompt).
Not any other file fx writes: a determined agent could put a secret in one
and ship it in a pull request — which is one more reason the gateway key is
budgeted and the write path is gated on people who could already push.
"""

import os
import re

# Whatever is in the environment and looks like a credential, rather than a
# hand-kept list. A list goes stale in the direction that matters: it names
# things that are not set (so it reads as protection it is not providing) and
# misses the one the caller added last week.
SECRET_NAME = re.compile(r'(_KEY|_TOKEN|_SECRET|_PASSWORD)$')   # covers API_KEY, PRIVATE_KEY, ACCESS_KEY
# Long enough that a match is the secret and not a coincidence.
MIN_LENGTH = 16


def secrets() -> dict[str, str]:
    return {
        name: value
        for name, value in os.environ.items()
        if SECRET_NAME.search(name) and len(value) >= MIN_LENGTH
    }


def redact(text: str) -> tuple[str, list[str]]:
    """Return the text with any secret VALUE replaced, and what was found."""
    found = []
    for name, value in secrets().items():
        if value in text:
            text = text.replace(value, f'***{name} redacted***')
            found.append(name)
    return text, found


def redact_file(path: str) -> list[str]:
    with open(path, encoding='utf-8', errors='replace') as fh:
        text = fh.read()
    text, found = redact(text)
    if found:
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(text)
    return found


if __name__ == '__main__':
    # `python3 redact.py FILE WHAT`: scrub FILE in place and say what came out
    # of it, WHAT naming the file for the reader of the log. Exits nonzero only
    # if the scrub itself fails, which callers treat as "do not publish".
    import sys
    path, what = sys.argv[1], sys.argv[2]
    for name in redact_file(path):
        print(f'::warning::Removed {name} from {what}.', file=sys.stderr)
