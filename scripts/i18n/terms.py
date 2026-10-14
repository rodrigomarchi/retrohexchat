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
    # A Space character is a figure somebody plays, never a letter: Portuguese
    # gave "caractere", the glyph, in a sentence otherwise right. Only the
    # figure's own phrasings are held to it; "5 characters", "special
    # characters" and the character counter are letters, and say so.
    r"\b(?:(?:your|the|this|a|new|another|standing)\s+(?:[a-z]+\s+){0,2}?characters?"
    r"(?!\s+(?:counter|count|set|limit|long|class))"
    r"|characters?\s+(?:creator|portraits?|in\s+a\s+space)"
    r"|(?:make|change|making)\s+(?:a\s+|your\s+)?character)\b": {
        "pt": ("personage",),
        "es": ("personaje",),
        "fr": ("personnage",),
        "de": ("charakter", "figur"),
        "it": ("personagg",),
        # Dutch games say "karakter" as often as "personage".
        "nl": ("personage", "karakter"),
        "pl": ("postać", "postaci"),
        "ru": ("персонаж",),
        "id": ("karakter",),
        "ja": ("キャラクター",),
        "zh_hans": ("角色",),
        "zh_hant": ("角色",),
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
    # The Construct's pieces, measured on their help and their panels: a
    # sign came back as a signal ("sinal"), a piece as a scrap ("pedaço"), a
    # pinned message as a stuck one ("presas"), a browser tab as a page. A
    # sign is never the verb of signing in, up or out.
    r"\bsigns?\b(?![\s-]*(?:in|up|out|on|off)\b)": {
        "pt": ("placa", "letreiro", "tabuleta"),
        "es": ("letrero", "cartel"),
        "fr": ("panneau", "pancarte"),
        "de": ("schild",),
        "it": ("cartell", "insegna"),
        "nl": ("bord",),
        "ru": ("табличк", "вывеск"),
        "ja": ("看板",),
        "zh_hans": ("标牌", "牌子"),
        "zh_hant": ("標牌", "牌子"),
    },
    # A die is the game's cube: "rolled the die" came back in Spanish as "la
    # muerte", in French as "la matrice".
    r"\b(?:dice|the die|a die)\b": {
        "pt": ("dado",),
        "es": ("dado",),
        "fr": ("dé",),
        "de": ("würfel",),
        "it": ("dad",),
        "nl": ("dobbelst",),
        "pl": ("kostk",),
        "ru": ("кубик", "кост"),
        "id": ("dadu",),
        "ja": ("サイコロ", "ダイス"),
        "zh_hans": ("骰子",),
        "zh_hant": ("骰子",),
    },
    # A link is the address in a message: Portuguese gave the phone call
    # ("ligação"), Polish a file ("Plik"), Dutch a connection ("verbinding").
    r"\blinks?\b": {
        "pt": ("link",),
        "nl": ("link",),
        "pl": ("link",),
    },
    r"\bpieces?\b": {
        "pt": ("peça",),
        "es": ("pieza",),
        "fr": ("pièce", "élément", "objet"),
        "de": ("stück", "teil", "objekt"),
    },
    r"\bpinned\b": {
        "pt": ("fixad", "afixad", "fixou"),
        "es": ("fijad", "anclad"),
        "fr": ("épingl",),
        "de": ("angeheftet", "pinn", "fixiert"),
    },
    r"\bnew tab\b": {
        "pt": ("aba", "separador", "guia"),
        "es": ("pestaña",),
        "fr": ("onglet",),
        "de": ("tab",),
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
        # Measured on the Construct's strings: the reflexive imperative, the
        # European spelling of "selected", and the European verb for turning.
        "senta-te",
        "levanta-te",
        "tenta outra vez",
        "seleccionada",
        "seleccionado",
        "rode a peça",
        # "...como o deixaste": the European "tu" preterite of leaving, on the
        # Construct's help.
        "deixaste",
        # Measured on the character creator's help: "Toda a gente no espaço
        # vê-te", "Os outros vêem-te", "da próxima vez que entrares".
        "toda a gente",
        "vê-te",
        "vêem-te",
        "entrares",
        # Measured on the Construct's help: "As peças movem-se quando as
        # arrastas", "decoram-na juntas", and "vêem" spelt as before the
        # 1990 agreement, which Brazil writes "veem".
        "arrastas",
        "decoram-na",
        "vêem",
        # "arraste-a com o rato": Portugal's mouse, a rat in Brazil.
        "com o rato",
        # "Pressione R para rodar uma peça": Brazil turns a piece with "girar".
        "rodar uma peça",
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
