"""Strip secrets out of anything this action is about to publish.

fx never prints the gateway key itself, but in write mode its shell tool is a
child process and inherits the environment — measured: an agent-run
`test -n "$AI_GATEWAY_API_KEY"` reports PRESENT. GitHub masks secrets in logs,
not in the API request bodies this action sends, and not inside an artifact.
So a comment, a pull request body and a session artifact are three ways out of
the runner that log masking does not cover.

Used by run-fx.sh (the answer), open-pr.sh (fx's drafted PR body) and
session-html.py (the transcript). Not the commit itself: what fx writes to a
FILE is not scanned, and a determined agent could put a secret there — which is
one more reason the gateway key is budgeted and the write path is gated on
people who could already push.
"""

import os
import re

# Whatever is in the environment and looks like a credential, rather than a
# hand-kept list. A list goes stale in the direction that matters: it names
# things that are not set (so it reads as protection it is not providing) and
# misses the one the caller added last week.
SECRET_NAME = re.compile(r'(API_KEY|_TOKEN|_SECRET|_PASSWORD)$')
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
