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

from .protection import FEED_RE, protect, restore

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
    # A room of the chat; the Game Room is its own term below, and a word for
    # it ("Spielzimmer", "游戏室") need not also be the chat's room.
    r"(?<!\bgame )\brooms?\b": {
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
    # A feed is a source of news, never fodder: the engine gave "Alimentar",
    # "pasza" and "кормить" (to feed an animal), and "种子" (a seed). The word
    # travels masked (`protection.FEED_RE`) and comes back as "feed" until
    # `names.localize` writes it in the language's form, so both are accepted.
    # A camera or video feed is a picture, and needs no news word.
    r"(?<!camera )(?<!video )\bfeeds?\b": {
        "pt": ("feed", "fonte"),
        "es": ("feed", "fuente"),
        "fr": ("flux", "feed"),
        "de": ("feed",),
        "it": ("feed", "flusso", "fonte"),
        "nl": ("feed",),
        "pl": ("feed", "kanał rss", "kanału rss", "źródł"),
        "ru": ("лент", "фид", "feed"),
        "id": ("feed", "umpan"),
        "ja": ("フィード", "feed"),
        "zh_hans": ("订阅", "源", "feed"),
        "zh_hant": ("訂閱", "源", "feed"),
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
    # A letter of the alphabet, not of the post: "start with a letter" came
    # back as "carta", "Brief" and "手紙".
    r"\b(?:with|by) an? letter\b|\b(?:upper|lower)case letters?\b": {
        "pt": ("letra",),
        "es": ("letra",),
        "fr": ("lettre",),
        "de": ("buchstab",),
        "it": ("letter",),
        "nl": ("letter",),
        "pl": ("liter",),
        "ru": ("букв",),
        "id": ("huruf",),
        "ja": ("文字",),
        "zh_hans": ("字母",),
        "zh_hant": ("字母",),
    },
    # Blanks between characters, not places: German gave "Keine Plätze".
    r"\bno spaces\b": {
        "de": ("leerzeich",),
        "pl": ("spacj",),
        "ru": ("пробел",),
        "ja": ("スペース", "空白"),
    },
    # Signing in to an account that exists: German gave "Registrieren", which
    # is creating one.
    r"\bsign(?:s|ed|ing)? in\b": {
        # The separable verbs split around "zu" / "te" in an infinitive:
        # "sich zuerst anzumelden", "om je eerst aan te melden".
        "de": ("anmeld", "anzumeld", "einlogg"),
        "nl": ("aanmeld", "aan te meld", "inlog"),
        "pl": ("zaloguj", "logow"),
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
    # The Office is a room behind a door: never a post ("ofício"), a cabinet
    # minister's ("gabinete") or a function.
    r"\boffices?\b": {
        "pt": ("escritório",),
        "es": ("oficina",),
        "fr": ("bureau",),
        "de": ("büro",),
        "it": ("ufficio", "uffici"),
        "nl": ("kantoor",),
        "pl": ("biur",),
        "ru": ("офис",),
        # Japanese says the room either way; never as a post (役職).
        "ja": ("オフィス", "事務所"),
        "zh_hans": ("办公室",),
        "zh_hant": ("辦公室",),
    },
    # The Game Room is a room to play in: never a single match ("partida"), a
    # sports hall or a casino.
    r"\bgame rooms?\b": {
        "pt": ("sala de jogos",),
        "es": ("sala de juego",),
        "fr": ("salle de jeu", "salle des jeux"),
        "de": ("spielzimmer", "spieleraum", "spielraum"),
        "it": ("sala giochi", "sala dei giochi", "stanza di gioco", "stanza dei giochi"),
        "nl": ("speelkamer", "spelkamer", "spelletjeskamer", "spelruimte", "speelruimte"),
        "pl": ("gier",),
        "ru": ("игров",),
        "id": ("ruang permainan", "ruang game"),
        "ja": ("ゲームルーム", "ゲーム部屋", "ゲーム室", "遊戯室"),
        "zh_hans": ("游戏房间", "游戏室"),
        "zh_hant": ("遊戲房間", "遊戲室"),
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
    # A match is a game played, never a correspondence or a coincidence:
    # "Watching a match" came back as "Observando uma correspondência", "Ver
    # una coincidencia" and "Eine Übereinstimmung beobachten". Only the noun
    # after a determiner is held to it; "passwords do not match", "the
    # matching line", a search's "the active match" and its "each match" are
    # the other word.
    r"\b(?:a|the|this|that|their|your|every|another|no|private|live|whole|full|short|fast)"
    r"\s+(?:(?:new|next|first|last|single|open)\s+)?match(?:es)?\b|\bmatch(?:es)?\s+(?:link|room|over|finished|format)\b": {
        "pt": ("partida", "jogo"),
        "es": ("partida", "partido", "juego"),
        "fr": ("partie", "match"),
        "de": ("spiel", "match", "partie"),
        "it": ("partit", "match"),
        "nl": ("wedstrijd", "potje", "partij", "match", "spel"),
        "pl": ("mecz", "rozgrywk", "partii", "partia", "gry", "grę", "grze"),
        "ru": ("матч", "игр", "парти"),
        "id": ("pertandingan", "permainan", "laga"),
        "ja": ("試合", "対戦", "マッチ"),
        "zh_hans": ("比赛", "对局", "对战"),
        "zh_hant": ("比賽", "對局", "對戰"),
    },
    # A player of a game, never a media player: French gave "un lecteur" in
    # "Right-click a player". Media, video and audio players, and a game's
    # single-player mode, are the other words.
    r"(?<!media )(?<!video )(?<!audio )(?<!native )(?<!single-)(?<!multi-)\bplayers?\b": {
        "pt": ("jogador",),
        "es": ("jugador",),
        "fr": ("joueur",),
        "de": ("spieler",),
        "it": ("giocator",),
        "nl": ("speler",),
        "pl": ("gracz",),
        "ru": ("игрок",),
        "id": ("pemain",),
        "ja": ("プレイヤー", "プレーヤー", "選手"),
        "zh_hans": ("玩家", "选手"),
        "zh_hant": ("玩家", "選手"),
    },
    # Playing a game, never playing back a recording: Japanese gave "再生"
    # ("ゲームを再生します") for "play games". Only a "play" whose sentence is
    # about a game, a match or the computer is held to it; a voice message is
    # still played back.
    r"\bplay(?:s|ed|ing)?\b(?=[^.]*\b(?:games?|match(?:es)?|computer)\b)": {
        "ja": ("遊", "プレイ", "対戦"),
        "zh_hans": ("玩", "对战"),
        "zh_hant": ("玩", "對戰"),
    },
    # The Arcade is the window's name. Spanish made it an arch ("Arcada") and
    # Chinese an archway ("拱门"), German dropped it from "Arcade flow diagram".
    r"\bArcade\b": {
        "pt": ("arcade",),
        "es": ("arcade",),
        "fr": ("arcade",),
        "de": ("arcade",),
        "it": ("arcade",),
        "nl": ("arcade",),
        "pl": ("arcade",),
        "ru": ("аркад",),
        "id": ("arcade",),
        "ja": ("アーケード",),
        "zh_hans": ("街机",),
        "zh_hant": ("街機",),
    },
    # A shooter is a game: Portuguese gave "atiradores", the people shooting.
    r"\bshooters?\b": {
        "pt": ("tiro", "shooter"),
        "es": ("disparo", "tiro", "shooter"),
        "fr": ("tir", "shooter"),
        "de": ("shooter",),
        "it": ("sparatutto", "shooter"),
    },
    # Looking a game over, never a critic's review: Spanish gave "reseña",
    # Russian "обзор".
    r"\breview details\b": {
        "es": ("revis",),
        "ru": ("просмотр", "изуч", "ознаком"),
    },
    # Advice, not the ends of things: Spanish gave "las puntas".
    r"\btips\b": {
        "es": ("consejo",),
    },
    # Measured on the Spaces page: "opens in a new browser tab" came back in
    # Portuguese as "numa nova página do navegador", a page rather than a tab.
    r"\bnew (?:browser )?tab\b": {
        "pt": ("aba", "separador", "guia"),
        "es": ("pestaña",),
        "fr": ("onglet",),
        "de": ("tab", "registerkarte"),
    },
    # The Space a channel opens onto: the product's word, never outer space.
    # Japanese gave "宇宙の場所を見る" and Russian "на острове Космоса" for
    # "the places of a Space". The space bar is a key, and keeps its own word.
    r"\b(?:a|the|its|each|every|this|of|own)\s+spaces?\b(?!\s*(?:bar|key))|\bspaces\b(?!\s*(?:bar|key))": {
        "ru": ("пространств",),
        "ja": ("スペース",),
        "zh_hans": ("空间",),
        "zh_hant": ("空間",),
    },
    # An account on the server, never a bank account: Russian gave "Это все,
    # что нужно для счета" — the bill.
    r"\baccounts?\b": {
        "ru": ("аккаунт", "учётн", "учетн"),
        "ja": ("アカウント",),
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
    A feed travels masked too, but it is vocabulary, so it is put back.
    """
    masked, replacements = protect(source)
    masked = restore(masked, {k: v for k, v in replacements.items() if FEED_RE.fullmatch(v)})
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
        # Measured on the Office's help: "O escritório vem mobilado" (Brazil
        # furnishes with "mobiliado") and the European enclitic of "todos
        # podem adicionar-lhe".
        "mobilado",
        "mobilada",
        "adicionar-lhe",
        # And "A carregar o escritório...", "leva-te de volta": the European
        # progressive and enclitic.
        "a carregar",
        "leva-te",
        # Measured on the game channels' help: "e pára com", the stopping verb
        # with the accent Brazil dropped in the 2009 agreement.
        "pára",
        # Measured on the Arcade's help: the European enclitics of "permits
        # you" and "opens it", Portugal's verb for sharing, its window
        # manager, and the subjunctive of reviewing ("Reveja") where Brazil
        # writes "Revise".
        "permite-lhe",
        "abre-o",
        "abre-a",
        "partilhar",
        "partilha",
        "partilham",
        "gestor de janelas",
        "reveja",
        # And on the Start menu's help: "pede-lhe para iniciar sessão quando
        # o seu não está registado".
        "pede-lhe",
        "registado",
        "registada",
        # Measured on the Spaces page: "Um escritório com secretárias" — the
        # European word for a desk, which in Brazil is a secretary.
        "secretária",
        "secretárias",
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


# The engine writes Italian's "è" as "e'", the way a keyboard without accents
# does: "L'ufficio e' pieno". The accent is spelling, not style, so it is put
# back on the way out of the engine rather than the translation being thrown
# away.
_ITALIAN_IS = re.compile(r"\b([Ee])'(?=[\s.,;:!?)]|$)")


def italian_accents(translated: str) -> str:
    """`translated` with "e'" (and "E'") written as "è" (and "È")."""
    return _ITALIAN_IS.sub(lambda m: "è" if m.group(1) == "e" else "È", translated)

