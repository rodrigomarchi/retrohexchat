"""Shielding the fragments a translator must not touch.

Placeholders, commands, brands and identifiers are swapped for sentinels
before translation and swapped back after. Sentinels are bare alphanumerics on
purpose: anything resembling markup (an earlier revision used `<ph0></ph0>`)
reads as a tag to an NMT model, which reorders, duplicates or slashes it until
it can no longer be matched, and the raw token ships to users.
"""

from __future__ import annotations

import re

# Brand and service names must survive byte-identical: the UI and the help
# pages refer to them literally.
BRAND_RE = re.compile(
    r"\b(RetroHexChat|RetroHex|ChanServ|NickServ|MemoServ|OperServ|HostServ|"
    r"LibreQuake|QuakeSpasm|WebRTC|LiveView|PostgreSQL|Elixir|Phoenix)\b"
)

# Dotted lowercase identifiers are audit-log action keys (channel.create,
# cs.drop), never prose.
DOTTED_KEY_RE = re.compile(r"\b[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\b")

PROTECTED_PATTERNS = (
    re.compile(r"https?://[^\s<>\"]+"),
    re.compile(r"`[^`]+`"),
    re.compile(r"</?[^>]+>"),
    BRAND_RE,
    DOTTED_KEY_RE,
    re.compile(r"/[A-Za-z][A-Za-z0-9_-]*"),
    re.compile(r"#[A-Za-z0-9_-]+"),
    re.compile(r"%\{[A-Za-z0-9_]+\}"),
)

SENTINEL_TEMPLATE = "XPH{index}X"
# Matches the current sentinel, the retired markup-shaped one, and the shapes
# models mangled the latter into (`<ph0`, `</ph2>>`, `<ph0}`). Cached values
# carrying any of them are unusable and get retranslated.
SENTINEL_RE = re.compile(r"XPH\d+X|<\s*/?\s*ph\s*\d+", re.IGNORECASE)

BATCH_SEPARATOR = "XSEGX"

WORD_RE = re.compile(r"[A-Za-z][A-Za-z']+")


def protect(text: str) -> tuple[str, dict[str, str]]:
    """Replace protected fragments with sentinels.

    Returns the masked text and a sentinel -> original fragment mapping.
    """
    replacements: dict[str, str] = {}
    protected = text
    counter = 0

    for pattern in PROTECTED_PATTERNS:

        def replace(match: re.Match[str]) -> str:
            nonlocal counter
            token = SENTINEL_TEMPLATE.format(index=counter)
            replacements[token] = match.group(0)
            counter += 1
            return token

        protected = pattern.sub(replace, protected)

    return protected, replacements


def restore(text: str, replacements: dict[str, str]) -> str:
    """Put the protected fragments back.

    Matching is deliberately loose: models re-case sentinels and pad them with
    spaces, and a fragment that comes back slightly mangled is still better
    than a raw sentinel reaching the UI.
    """
    restored = text

    for token, value in replacements.items():
        loose = re.escape(token).replace("PH", r"\s*PH\s*")
        restored = re.sub(loose, lambda _, value=value: value, restored, flags=re.IGNORECASE)

    return restored


def has_sentinel_residue(text: str) -> bool:
    return SENTINEL_RE.search(text) is not None


def should_machine_translate(text: str) -> bool:
    """Skip strings with no prose to translate.

    The check runs on the masked text: placeholder and command names are words
    too ("%{count}"), and judging the raw string sends pure-format strings to
    the model, which can only mangle them.
    """
    masked, _ = protect(text)

    if not WORD_RE.search(SENTINEL_RE.sub(" ", masked)):
        return False

    stripped = text.strip()

    if stripped.startswith("/") and "\n" not in stripped:
        return False

    return True
