"""The strings the browser asks to translate, read from the JS that asks.

`js/lib/i18n.js` translates two ways: `t("message", params)` and the tagged
template `` jt`text ${value}` ``, whose msgid numbers each value in order
(`text %{0}`). A call whose message is a variable or a built string names no
msgid and is skipped: what it passes must already be in the catalog.

Pure: no catalog access and no engine, so the checker can run on stdlib in CI.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

# `t(` or `jt(` as a whole identifier, then one string literal and then the
# end of the argument (`)` or `,`). A literal followed by `+` is a built string.
_T_CALL = re.compile(
    r"""(?<![\w$.])j?t\(\s*("(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')\s*[,)]"""
)
_JT_TEMPLATE = re.compile(r"(?<![\w$.])jt`((?:[^`\\]|\\.)*)`", re.S)
_INTERPOLATION = re.compile(r"\$\{(?:[^{}]|\{[^{}]*\})*\}")


def _unquote(literal: str) -> str:
    # JavaScript's escapes are JSON's plus \' ; a single-quoted literal may
    # also hold a bare double quote, which JSON needs escaped.
    body = literal[1:-1].replace("\\'", "'")
    if literal[0] == "'":
        body = re.sub(r'(?<!\\)"', '\\"', body)
    return json.loads(f'"{body}"')


def _template_msgid(body: str) -> str:
    counter = iter(range(10_000))
    msgid = _INTERPOLATION.sub(lambda _m: f"%{{{next(counter)}}}", body)
    # A template decodes the same escapes a string literal does (\u2014 is a
    # dash at run time); its own \` and \$ are a backtick and a dollar.
    msgid = msgid.replace("\\`", "`").replace("\\$", "$").replace("\n", "\\n")
    return json.loads('"' + re.sub(r'(?<!\\)"', '\\"', msgid) + '"')


def extract(source: str) -> set[str]:
    """Every msgid one JS source asks `t` or `jt` for."""
    found = {_unquote(m.group(1)) for m in _T_CALL.finditer(source)}
    found |= {_template_msgid(m.group(1)) for m in _JT_TEMPLATE.finditer(source)}
    return found


def scan(js_dir: Path, skip: tuple[str, ...] = ("i18n_catalogs",)) -> dict[str, str]:
    """Every msgid under `js_dir`, with the first file that asks for it."""
    messages: dict[str, str] = {}

    for path in sorted(js_dir.rglob("*.js")):
        if any(part in path.parts for part in skip):
            continue

        for msgid in extract(path.read_text(encoding="utf-8")):
            messages.setdefault(msgid, str(path))

    return messages


def missing(messages, catalogs: dict[str, dict[str, str]]) -> dict[str, list[str]]:
    """For each catalog that lacks some of `messages`, the ones it lacks."""
    result: dict[str, list[str]] = {}

    for export_name, catalog in catalogs.items():
        absent = sorted(message for message in messages if message not in catalog)
        if absent:
            result[export_name] = absent

    return result
