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
}

_NAME_RE = {name: re.compile(rf"\b{re.escape(name)}\b") for name in NAMES}


def form(name: str, locale_code: str) -> str:
    """The way a locale writes one of the product's names."""
    forms = NAMES[name]
    return forms.get(locale_code) or forms.get(locale_code.split("_")[0]) or name


def localize(text: str, locale_code: str | None) -> str:
    """Every product name in an already translated text, in the locale's form."""
    if not locale_code or locale_code == "en":
        return text

    for name, pattern in _NAME_RE.items():
        text = pattern.sub(form(name, locale_code), text)

    return text
