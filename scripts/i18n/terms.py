"""The chat's own vocabulary, checked in every translation that uses it.

The engine translates a word, not a domain. Left to itself it rendered a
"voiced user" as a *sung* one in German ("gesungene Benutzer"), a chat "room"
as a bedroom in Spanish ("habitación") and as a theatre piece in French
("pièce") — each in a sentence that was otherwise right, so no check over the
whole sentence noticed.

So each term names the forms a translation must use for it. A translation of
a source that uses the term but carries none of its forms is rejected, and the
entry keeps the English source until it can be translated properly. This is a
vocabulary — a word per language — never a curated sentence.

Forms are matched case-insensitively as substrings, so a stem ("kanał") covers
its inflections ("kanału", "kanałem").
"""

from __future__ import annotations

import re

from .protection import protect

# English term pattern -> accepted forms per locale. `pt` covers both
# Portuguese locales; a locale with no entry is not checked for that term.
_TERMS: dict[str, dict[str, tuple[str, ...]]] = {
    r"\bvoic(?:e|ed)\b": {
        "pt": ("voz",),
        "es": ("voz",),
        "fr": ("voix",),
        "de": ("voice", "stimm", "sprach"),
        "it": ("voce", "voice"),
        "nl": ("voice", "stem", "spraak"),
        "pl": ("głos", "voice"),
        "ru": ("голос", "войс"),
        "id": ("suara", "voice"),
        "ja": ("ボイス", "発言", "音声"),
        "zh_hans": ("发言", "语音"),
        "zh_hant": ("發言", "語音"),
    },
    r"\brooms?\b": {
        "pt": ("sala",),
        "es": ("sala",),
        "fr": ("salon", "salle"),
        "de": ("raum", "räum"),
        "it": ("stanz", "sala", "sale", "chat room"),
        "nl": ("kamer", "ruimte", "room"),
        "pl": ("pokoj", "pokój", "pokoi", "czat", "chat room"),
        "ru": ("комнат", "чат"),
        "id": ("ruang", "chat room"),
        "ja": ("ルーム", "部屋"),
        "zh_hans": ("房间", "聊天室"),
        "zh_hant": ("房間", "聊天室"),
    },
    r"\bchannels?\b": {
        "pt": ("canal", "canais"),
        "es": ("canal",),
        "fr": ("canal", "canaux"),
        "de": ("kanal", "kanäl"),
        "it": ("canal",),
        "nl": ("kanaal", "kanalen"),
        "pl": ("kanał", "kanal"),
        "ru": ("канал",),
        "id": ("kanal", "saluran"),
        "ja": ("チャンネル", "チャネル"),
        "zh_hans": ("频道",),
        "zh_hant": ("頻道",),
    },
    r"\bnicknames?\b": {
        "pt": ("apelido", "alcunha", "nick"),
        "es": ("apodo", "nick"),
        "fr": ("pseudo", "surnom"),
        "de": ("spitzname", "nick"),
        "it": ("nickname", "soprannom", "nick"),
        "nl": ("bijnaam", "bijnamen", "nick"),
        "pl": ("pseudonim", "nick", "ksywk"),
        "ru": ("ник", "псевдоним", "прозвищ"),
        "id": ("nama panggilan", "nick"),
        "ja": ("ニックネーム", "ニック"),
        "zh_hans": ("昵称",),
        "zh_hant": ("暱稱",),
    },
    r"\boperators?\b": {
        "pt": ("operador",),
        "es": ("operador",),
        "fr": ("opérateur",),
        "de": ("operator",),
        "it": ("operator",),
        "nl": ("operator",),
        "pl": ("operator",),
        "ru": ("оператор",),
        "id": ("operator",),
        "ja": ("オペレーター", "オペレータ"),
        "zh_hans": ("管理员", "操作员"),
        "zh_hant": ("管理員", "操作員"),
    },
    # Letters, not money: "capital letters" came back as "letras de capital"
    # and as "資本の手紙" — capital as in finance.
    r"\bcapital letters?\b": {
        "pt": ("maiúscula",),
        "es": ("mayúscula",),
        "fr": ("majuscule",),
        "de": ("großbuchstabe", "großschreibung"),
        "it": ("maiuscol",),
        "nl": ("hoofdletter",),
        "pl": ("wielk", "duże litery"),
        "ru": ("заглавн", "прописн", "регистр"),
        "id": ("huruf besar", "huruf kapital"),
        "ja": ("大文字",),
        "zh_hans": ("大写",),
        "zh_hant": ("大寫",),
    },
}

TERMS: tuple[tuple[re.Pattern[str], dict[str, tuple[str, ...]]], ...] = tuple(
    (re.compile(pattern, re.IGNORECASE), forms) for pattern, forms in _TERMS.items()
)


def _forms(forms: dict[str, tuple[str, ...]], locale_code: str) -> tuple[str, ...]:
    return forms.get(locale_code) or forms.get(locale_code.split("_")[0], ())


def missing_terms(source: str, translated: str, locale_code: str) -> list[str]:
    """The terms `source` uses whose required forms `translated` lacks.

    The source is read masked, so a term inside a command or placeholder
    (`/nick`, `%{channel}`) is syntax, not vocabulary, and asks for nothing.
    """
    masked, _ = protect(source)
    text = translated.lower()
    missing = []

    for pattern, forms in TERMS:
        accepted = _forms(forms, locale_code)

        if accepted and pattern.search(masked) and not any(form in text for form in accepted):
            missing.append(pattern.pattern)

    return missing


# Words one variant of a language uses and the other does not. Argos has a
# single Portuguese model, and its output leans European: "Escolhe uma alcunha
# e entras", "A janela que conheces". Read in Brazil that is a foreign text,
# so a pt_BR translation carrying these forms is rejected like any other bad
# one. Second-person "tu" verbs are listed by form, not by ending: "-es" and
# "-as" also end plenty of Brazilian words.
_FOREIGN_FORMS: dict[str, tuple[str, ...]] = {
    "pt_BR": (
        "alcunha",
        "alcunhas",
        "utilizador",
        "utilizadores",
        "registar",
        "registe",
        "registo",
        "registos",
        "ecrã",
        "telemóvel",
        "tua",
        "teu",
        "tuas",
        "teus",
        "estás",
        "tens",
        "podes",
        "queres",
        "sabes",
        "conheces",
        "entras",
        "escreves",
    ),
}

FOREIGN_FORMS: dict[str, re.Pattern[str]] = {
    code: re.compile(r"\b(?:" + "|".join(map(re.escape, forms)) + r")\b", re.IGNORECASE)
    for code, forms in _FOREIGN_FORMS.items()
}


def foreign_forms(translated: str, locale_code: str) -> list[str]:
    """Words in `translated` that belong to another variant of its language."""
    pattern = FOREIGN_FORMS.get(locale_code)
    return pattern.findall(translated) if pattern else []
