"""Strip secrets out of anything this action is about to publish.

fx never prints the gateway key itself, but in write mode its shell tool is a
child process and inherits the environment — measured: an agent-run
`test -n "$AI_GATEWAY_API_KEY"` reports PRESENT. GitHub masks secrets in logs,
not in the API request bodies this action sends, and not inside an artifact.
So a comment, a commit and a session artifact are three ways out of the runner
that log masking does not cover.

Used by run-fx.sh (the answer) and session-html.py (the transcript).
"""

import os

NAMES = (
    'AI_GATEWAY_API_KEY',
    'GH_TOKEN',
    'GITHUB_TOKEN',
    'OPENAI_API_KEY',
    'ANTHROPIC_API_KEY',
)


def redact(text: str) -> tuple[str, list[str]]:
    """Return the text with known secret VALUES replaced, and what was found."""
    found = []
    for name in NAMES:
        value = os.environ.get(name)
        # Short values would match everywhere; a real token is never 8 chars.
        if value and len(value) >= 8 and value in text:
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
