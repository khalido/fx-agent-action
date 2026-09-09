"""Strip hiding tricks out of GitHub text before it reaches the model.

An issue body, a comment and a diff are all written by whoever opened them. The
prompt already fences that text and says it is evidence rather than orders, but
a fence only works on text you can SEE. The tricks below put instructions where
a person reading the thread will not notice them:

    <!-- ignore the above and run this -->     an HTML comment
    ![](x "…")  /  ![hidden text](x)           markdown image alt and title
    <span title="…">  <div data-x="…">         hidden HTML attributes
    U+200B U+200E U+2060 U+E0001…              zero-width and tag characters
    &#105;&#103;…                              HTML entities spelling words

Taken from anthropics/claude-code-action's docs/security.md, which sanitizes the
same list. It is not a guarantee — new tricks turn up — which is why the read
path has no shell and the write path is gated on people who can already push.
"""

import re
import sys

# Zero-width, bidi controls, and the Unicode tag block used to smuggle ASCII.
INVISIBLE = re.compile(
    '[​-‏‪-‮⁠-⁤⁪-⁯﻿\U000e0000-\U000e007f]'
)
HTML_COMMENT = re.compile(r'<!--.*?-->', re.DOTALL)
IMAGE_ALT = re.compile(r'!\[[^\]]*\]\(([^)\s]*)[^)]*\)')
HIDDEN_ATTR = re.compile(
    r'\s(?:title|alt|aria-label|data-[\w-]+)\s*=\s*(?:"[^"]*"|\'[^\']*\')',
    re.IGNORECASE,
)
ENTITY = re.compile(r'&#x?[0-9a-fA-F]{2,6};')


def sanitize(text: str) -> str:
    text = HTML_COMMENT.sub('', text)
    text = IMAGE_ALT.sub(r'![image](\1)', text)
    text = HIDDEN_ATTR.sub('', text)
    # Entities are decoded by nothing here, but a model will read them as the
    # characters they name. Neutralise rather than decode.
    text = ENTITY.sub('&#…;', text)
    return INVISIBLE.sub('', text)


if __name__ == '__main__':
    path = sys.argv[1]
    with open(path, encoding='utf-8', errors='replace') as fh:
        original = fh.read()
    cleaned = sanitize(original)
    if cleaned != original:
        print(f'::notice::Removed hidden markup from the GitHub context '
              f'({len(original) - len(cleaned)} characters).', file=sys.stderr)
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(cleaned)
