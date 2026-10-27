"""Names the product gives its own places, and how each language says them.

A name is not translated by the engine: it is masked like a brand, so the
sentence around it is translated whole and the name comes back untouched, and
only then is it swapped for the form this language uses. Translated as a word,
the Construct became the act of building ("Construção", "Construcción") or a
drawing ("Teken"); masked and swapped, it stays the room it is, in a sentence
the engine built around a noun.

A locale with no form of its own keeps the English name.
"""

from __future__ import annotations

import re

# English name -> its form per locale. `pt` covers both Portuguese locales.
NAMES: dict[str, dict[str, str]] = {
    # A game's title, kept as it is on the box: Portuguese made it "Selva Hex"
    # and Japanese "六角ジャングル" (a hexagon's jungle). Japanese writes the
    # titles of the other games in katakana.
    "Hex Jungle": {
        "ja": "ヘックスジャングル",
    },
    # The longer title first, so its mode is never read as a sentence: the
    # engine made "Draw Three" into "Draw Tres".
    # The name of the game of patience, as each language calls it — what a
    # search for it uses. Translated as words it came back as "Solitário de
    # Klondike", which nobody in Brazil looks for.
    "Klondike solitaire": {
        "pt": "Paciência",
        "es": "Solitario",
        "fr": "Solitaire",
        "de": "Solitär",
        "it": "Solitario",
        "nl": "Patience",
        "pl": "Pasjans",
        "ru": "Пасьянс «Косынка»",
        "ja": "ソリティア",
        "zh_hans": "纸牌接龙",
        "zh_hant": "紙牌接龍",
    },
    "Hex Solitaire: Draw Three": {
        "ja": "ヘックスソリティア：3枚めくり",
    },
    "Hex Solitaire": {
        "ja": "ヘックスソリティア",
    },
    "Construct": {
        "pt": "Constructo",
        "es": "Constructo",
        "de": "Konstrukt",
        "it": "Costrutto",
        "pl": "Konstrukt",
        "ru": "Конструкт",
        "id": "Konstruk",
        "ja": "コンストラクト",
        "zh_hans": "构造空间",
        "zh_hant": "構造空間",
    },
    # A news feed, never fodder: translated as a word it came back as
    # "Alimentação", "Futtermittel", "pasza", "кормить" and "种子" (a seed).
    # Masked and swapped, every sentence keeps the news source it means.
    "feed": {
        "pt": "feed",
        "es": "feed",
        "fr": "flux",
        "de": "Feed",
        "it": "feed",
        "nl": "feed",
        "pl": "feed",
        "ru": "фид",
        "id": "feed",
        "ja": "フィード",
        "zh_hans": "订阅源",
        "zh_hant": "訂閱源",
    },
    "feeds": {
        "pt": "feeds",
        "es": "feeds",
        "fr": "flux",
        "de": "Feeds",
        "it": "feed",
        "nl": "feeds",
        "pl": "feedy",
        "ru": "фиды",
        "id": "feed",
        "ja": "フィード",
        "zh_hans": "订阅源",
        "zh_hant": "訂閱源",
    },
    "Feed": {
        "pt": "Feed",
        "es": "Feed",
        "fr": "Flux",
        "de": "Feed",
        "it": "Feed",
        "nl": "Feed",
        "pl": "Feed",
        "ru": "Фид",
        "id": "Feed",
        "ja": "フィード",
        "zh_hans": "订阅源",
        "zh_hant": "訂閱源",
    },
    "Feeds": {
        "pt": "Feeds",
        "es": "Feeds",
        "fr": "Flux",
        "de": "Feeds",
        "it": "Feed",
        "nl": "Feeds",
        "pl": "Feedy",
        "ru": "Фиды",
        "id": "Feed",
        "ja": "フィード",
        "zh_hans": "订阅源",
        "zh_hant": "訂閱源",
    },
}

# Bounded by Latin letters, digits and "_" only: Japanese and Chinese write a
# name with no space around it ("feedは"), and to `\b` a kana is a word
# character like any other.
_NAME_RE = {
    name: re.compile(rf"(?<![A-Za-z0-9_]){re.escape(name)}(?![A-Za-z0-9_])") for name in NAMES
}


def form(name: str, locale_code: str) -> str:
    """The way a locale writes one of the product's names."""
    forms = NAMES[name]
    return forms.get(locale_code) or forms.get(locale_code.split("_")[0]) or name


def localize(text: str, locale_code: str | None) -> str:
    """Every product name in an already translated text, in the locale's form.

    Only prose is touched: a URL (`/feed.xml`), a placeholder (`%{feed}`), a
    command or a channel keeps its spelling, so the text is masked first and
    only the names are let back in to be swapped.
    """
    if not locale_code or locale_code == "en":
        return text

    from .protection import protect, restore

    masked, replacements = protect(text)
    names = {token: value for token, value in replacements.items() if value in NAMES}
    syntax = {token: value for token, value in replacements.items() if value not in NAMES}
    prose = restore(masked, names)

    for name, pattern in _NAME_RE.items():
        prose = pattern.sub(form(name, locale_code), prose)

    return restore(prose, syntax)
