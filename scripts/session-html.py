"""Render an fx session as one self-contained HTML file.

`fx session <id> --json` carries the whole run: what was asked, every tool call
with its arguments, every result, and the answer. That is the file you want
when a note comes out wrong, and reading it should not mean re-running anything.

No CSS framework, no JavaScript, no network: an artifact should still open in
five years. Tool results are long, so each one is a collapsed <details>.
"""

import html
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from redact import redact  # noqa: E402

CSS = """
:root { color-scheme: light dark; }
body { font: 15px/1.6 ui-sans-serif, system-ui, sans-serif; max-width: 52rem;
       margin: 2rem auto; padding: 0 1rem; }
h1 { font-size: 1.3rem; margin-bottom: .2rem; }
.meta { color: #6b7280; font-size: .85rem; margin-bottom: 2rem; }
.turn { border-left: 3px solid #d1d5db; padding-left: 1rem; margin: 2rem 0; }
.who { font-weight: 600; font-size: .8rem; text-transform: uppercase;
       letter-spacing: .04em; color: #6b7280; }
pre { background: #f6f7f9; padding: .7rem; border-radius: 6px; overflow-x: auto;
      font-size: .82rem; white-space: pre-wrap; word-break: break-word; }
details { margin: .4rem 0; }
summary { cursor: pointer; font-size: .85rem; color: #374151; }
.tool { font-family: ui-monospace, monospace; font-size: .85rem; }
.fail { color: #b91c1c; }
@media (prefers-color-scheme: dark) {
  body { background: #0f1115; color: #e5e7eb; }
  pre { background: #1a1d23; }
  summary { color: #9ca3af; }
  .turn { border-color: #374151; }
}
"""


def esc(value) -> str:
    text, _ = redact('' if value is None else str(value))
    return html.escape(text)


def block(label, body, open_by_default=False):
    if not body:
        return ''
    state = ' open' if open_by_default else ''
    return f'<details{state}><summary>{esc(label)}</summary><pre>{esc(body)}</pre></details>'


def render(session, meta):
    out = ['<!doctype html><meta charset="utf-8">',
           f'<title>fx session {esc(session.get("id", ""))}</title>',
           f'<style>{CSS}</style>',
           '<h1>fx session</h1>',
           f'<p class="meta">{esc(meta)}</p>']

    for turn in session.get('history') or []:
        asked = (turn.get('user') or {}).get('text')
        if asked:
            out.append(f'<div class="turn"><div class="who">Asked</div><pre>{esc(asked)}</pre></div>')

        for step in (turn.get('execution') or {}).get('tool_steps') or []:
            if step.get('assistant'):
                out.append(f'<div class="turn"><div class="who">Said</div><pre>{esc(step["assistant"])}</pre></div>')
            results = {r.get('tool_call_id'): r
                       for r in step.get('tool_results') or []
                       if isinstance(r, dict)}
            for call in step.get('tool_calls') or []:
                if not isinstance(call, dict):
                    continue
                result = results.get(call.get('id')) or {}
                # Web search on the gateway is a provider-native tool: Exa runs
                # it server-side, fx records the call with its arguments (query,
                # include_domains, start_published_date) and the raw result on
                # the call itself, and there is no tool_results entry.
                if result.get('provider_native') or call.get('provider_result') is not None:
                    status = 'provider'
                    body = call.get('provider_result')
                else:
                    status = result.get('status', '?')
                    body = result.get('output') or result.get('preview')
                css = ' class="fail"' if status not in ('success', 'provider') else ''
                out.append('<div class="turn"><div class="who">Tool</div>')
                out.append(f'<p class="tool"><b>{esc(call.get("name"))}</b> '
                           f'<span{css}>{esc(status)}</span></p>')
                out.append(block('arguments', call.get('arguments_json')))
                # Why a call was held or denied, and whether what you see is
                # all there was: the two facts that explain a wrong answer.
                out.append(block('permission', result.get('permission_feedback')))
                if result.get('truncated'):
                    out.append(f'<p class="tool">truncated: {esc(result.get("stored_output_bytes"))} '
                               f'of {esc(result.get("output_bytes"))} bytes kept</p>')
                out.append(block('result', body))
                out.append('</div>')

        if turn.get('assistant'):
            out.append(f'<div class="turn"><div class="who">Answered</div><pre>{esc(turn["assistant"])}</pre></div>')

    return '\n'.join(out)


def main():
    session_id, dest = sys.argv[1], sys.argv[2]
    raw = subprocess.run(['fx', 'session', session_id, '--json'],
                         capture_output=True, text=True)
    if raw.returncode != 0 or not raw.stdout.strip():
        print(f'::warning::Could not export session {session_id}: '
              f'{raw.stderr.strip()[:200]}', file=sys.stderr)
        return 0
    meta = os.environ.get('SESSION_META', '')
    with open(dest, 'w', encoding='utf-8') as fh:
        fh.write(render(json.loads(raw.stdout), meta))
    print(f'Wrote {dest}', file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main())
