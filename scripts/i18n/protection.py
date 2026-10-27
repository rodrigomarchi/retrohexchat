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
# pages refer to them literally. The product's own place names (`names.py`)
# are masked the same way, and swapped for each language's form afterwards.
BRAND_RE = re.compile(
    r"\b(Retro Hex Chat|RetroHexChat|RetroHex|ChanServ|NickServ|MemoServ|OperServ|HostServ|Construct|"
    r"End of Time|Hex Solitaire: Draw Three|Hex Solitaire|Klondike solitaire|"
    r"Hex FreeCell|FreeCell solitaire|FreeCell|"
    r"Hex Spider: Two Suits|Hex Spider: Four Suits|Hex Spider|Spider solitaire|Spider|"
    r"Hex Mines: Intermediate|Hex Mines: Expert|Hex Mines|Minesweeper|"
    r"mIRC|IRC|CTCP|DCC|"
    r"LibreQuake|QuakeSpasm|WebRTC|LiveView|PostgreSQL|Elixir|Phoenix)\b"
)

# Dotted lowercase identifiers are audit-log action keys (channel.create,
# cs.drop), never prose.
DOTTED_KEY_RE = re.compile(r"\b[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\b")

# A channel or user mode as typed (+m, -v) and an alias variable ($1, $nick):
# syntax a reader copies, which a model reads as stray punctuation and drops.
MODE_RE = re.compile(r"(?<![\w+-])[+-][A-Za-z]\b")
ALIAS_VARIABLE_RE = re.compile(r"\$[A-Za-z0-9]+\b")

# The interface's own glyphs — the arrow of a menu path ("Start ▸ Navigate"),
# a status mark ("↻ Reconnecting:"). The Portuguese model reads them as noise
# and swaps them for a box ("Iniciar □ Navegar"), so they travel masked.
UI_GLYPH_RE = re.compile("[▸◂▾▴↻←→↑↓✓✕]")

# A key chord or a function key as pressed (Shift+Tab, Ctrl+Shift+F, F10): the
# reader looks for those labels on the keyboard. Unmasked, pt_BR rendered
# "Shift+Tab" as "Shift+ Aba" and the Japanese model split it apart.
KEY_CHORD_RE = re.compile(
    r"\b(?:Ctrl|Shift|Alt|Cmd|Meta)(?:\+(?:Ctrl|Shift|Alt|Cmd|Meta|F\d{1,2}|[A-Z][a-z]*|[A-Za-z0-9./\[\]]))+"
    r"|\bF(?:[1-9]|1[0-2])\b"
)

# A news feed is masked like a name and written in each language's form
# (`names.py`); a camera's or a video's feed is a picture and is left alone.
FEED_RE = re.compile(r"(?<![Cc]amera )(?<![Vv]ideo )\b[Ff]eeds?\b")

# A card's suit, and the two suits Spider deals together, are masked like names and
# written in each language's form (`names.py`): translated as words a suit was
# clothing ("fato", "traje", "Anzug"), spades a shovel ("Spaten") and hearts
# organs ("corações"). A suit of armour (Half-Life's HEV suit) is left alone,
# and a game's own mode ("Hex Spider: Two Suits") is masked whole before it.
# Hearts alone are left to the emoji they also name.
SUIT_RE = re.compile(r"(?<!HEV )\b(?:spades and hearts|suits?)\b")

# The prefix a service's reply carries ("[BotService] Feed added."): the reader
# sees which service is speaking by it. Masked whole, brackets included, or the
# engines drop it, translate it, or wrap it in markup they invent.
SERVICE_TAG_RE = re.compile(r"\[(?:BotService|ChanServ|NickServ|MemoServ|OperServ|HostServ)\]")

PROTECTED_PATTERNS = (
    SERVICE_TAG_RE,
    re.compile(r"https?://[^\s<>\"]+"),
    re.compile(r"`[^`]+`"),
    re.compile(r"</?[^>]+>"),
    BRAND_RE,
    DOTTED_KEY_RE,
    re.compile(r"/[A-Za-z][A-Za-z0-9_-]*"),
    re.compile(r"#[A-Za-z0-9_-]+"),
    re.compile(r"%\{[A-Za-z0-9_]+\}"),
    # After commands, channels and placeholders: `/feed`, `#feeds` and
    # `%{feed}` are syntax, and a mask inside a mask would not come back.
    FEED_RE,
    SUIT_RE,
    MODE_RE,
    ALIAS_VARIABLE_RE,
    UI_GLYPH_RE,
    KEY_CHORD_RE,
)

SENTINEL_TEMPLATE = "XPH{index}X"
# Matches the current sentinel, the retired markup-shaped one, and the shapes
# models mangled the latter into (`<ph0`, `</ph2>>`, `<ph0}`). Cached values
# carrying any of them are unusable and get retranslated.
SENTINEL_RE = re.compile(r"XPH\d+X|<\s*/?\s*ph\s*\d+", re.IGNORECASE)

BATCH_SEPARATOR = "XSEGX"

# Both apostrophes: the repository writes the typographic one in prose, so an
# ASCII-only class splits "don’t" into "don" and a stray "t".
WORD_RE = re.compile(r"[A-Za-z][A-Za-z'’]+")


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

    # A one-line string that opens with a command is a syntax line or an
    # example ("/join #channel [key]", "/bot set GreeterBot greeting Hi."),
    # whose words are what the reader types. Prose does not open with one.
    if stripped.startswith("/") and "\n" not in stripped:
        return False

    return True
