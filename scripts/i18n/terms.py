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

from .protection import FEED_RE, SUIT_RE, protect, restore

# English term pattern -> accepted forms per locale. `pt` covers both
# Portuguese locales; a locale with no entry is not checked for that term.
_TERMS: dict[str, dict[str, tuple[str, ...]]] = {
    # A playing card, never a bank card or a business card: Spanish gave
    # "tarjeta" in every line of a card game's help, and Portuguese "cartão".
    # Only a card game's own phrasings are held to it: the interface has cards
    # of its own ("the card below", "a card with one open seat"), which stay
    # the interface's word.
    r"\b(?:face-down\s+cards?|playing\s+cards?|card\s+game|game\s+of\s+cards"
    r"|cards?\s+at\s+a\s+time|cards?\s+on\s+(?:a|its|the)\s+pile|cards?\s+on\s+top\s+of"
    r"|cards?\s+(?:back\s+)?from\s+(?:the\s+deck|a\s+pile)|(?:its|the)\s+next\s+card"
    r"|every\s+card\s+on)\b": {
        "pt": ("carta",),
        "es": ("carta", "naipe"),
        "fr": ("carte",),
        "de": ("karte",),
        "it": ("cart",),
        "nl": ("kaart",),
        "pl": ("kart",),
        "ru": ("карт",),
        "id": ("kartu",),
        "ja": ("カード", "札"),
        "zh_hans": ("牌",),
        "zh_hant": ("牌",),
    },
    # A tap of a finger on a screen: Chinese made it a kick ("踢打") and German
    # dropped what is tapped ("Tippen Sie auf zu spielen").
    r"\btap(?:s|ped)?\b": {
        "pt": ("toqu", "toca"),
        "es": ("toca", "toque", "pulsa"),
        "fr": ("touch", "appuy"),
        "de": ("tipp",),
        "it": ("tocc",),
        "nl": ("tik",),
        "pl": ("dotkn", "stukn"),
        "ru": ("нажм", "нажат", "косн", "тап"),
        "id": ("ketuk", "sentuh"),
        "ja": ("タップ",),
        "zh_hans": ("点按", "轻触", "点击", "轻点"),
        "zh_hant": ("點按", "輕觸", "點擊", "輕點"),
    },
    # Drawing a card from the deck, never drawing a picture: Portuguese gave
    # "Desenhar a sua próxima carta", Spanish "dibuja".
    r"\b(?:draws?\s+(?:its\s+next\s+card|one\s+card|three|from\s+the\s+deck)"
    r"|drawing\s+(?:one|three)\s+cards?)\b": {
        "pt": ("compr", "tir", "vir", "pux"),
        "es": ("roba", "rob", "saca", "tom"),
        "fr": ("pioch", "tir"),
        "de": ("zieh",),
        "it": ("pesc",),
        "nl": ("pak", "trek"),
        "pl": ("dobier", "bierz", "dobr"),
        "ru": ("бер", "тян", "взя"),
        "id": ("ambil",),
        "ja": ("引", "めく"),
        "zh_hans": ("抽", "翻"),
        "zh_hant": ("抽", "翻"),
    },
    # The back of the cards, never a part of them: Portuguese gave "outra
    # parte para as cartas".
    r"\bbacks?\s+(?:for|of)\s+the\s+cards\b": {
        "pt": ("verso", "parte de trás"),
        "es": ("dorso", "reverso", "parte trasera"),
        "fr": ("dos",),
        "de": ("rückseite",),
        "it": ("dorso", "retro"),
        "nl": ("achterkant",),
        "pl": ("rewers", "tył"),
        "ru": ("рубашк",),
        "id": ("belakang", "punggung"),
        "ja": ("裏",),
        "zh_hans": ("背面",),
        "zh_hant": ("背面",),
    },
    # A pile of cards, never a post: German gave "auf ihren Pfahl".
    r"\b(?:on\s+its\s+pile|(?:another|a|the)\s+pile|the\s+four\s+piles|piles\s+at\s+the\s+top"
    r"|between\s+piles)\b": {
        "pt": ("pilha", "monte"),
        "es": ("pila", "montón", "monton"),
        "fr": ("pile", "tas"),
        "de": ("stapel",),
        "it": ("pil", "mazz", "mucchi"),
        "nl": ("stapel",),
        "pl": ("stos",),
        "ru": ("стопк", "куч"),
    },
    # A card lying face up, its face seen: German gave "verdeckt" (face down)
    # and Japanese "直面" (to confront).
    r"\bface\s+up\b": {
        "pt": ("para cima", "virad", "à vista", "visíve"),
        "es": ("boca arriba", "descubiert", "a la vista"),
        "fr": ("face visible", "visible", "retourn"),
        "de": ("aufgedeckt", "offen", "sichtbar"),
        "it": ("scopert", "a faccia in su", "visibil"),
        "ja": ("表向き", "表に"),
    },
    # The ace, the card: German gave "Spitze" (a peak).
    r"\bthe\s+ace\b": {
        "pt": ("ás",),
        "es": ("as",),
        "fr": ("as",),
        "de": ("ass",),
        "it": ("asso",),
        "nl": ("aas",),
        "pl": ("as",),
        "ru": ("туз",),
        "ja": ("エース",),
    },
    # A card's suit, never clothing: Portuguese gave "fato" and "terno",
    # Spanish "traje", German "Anzug". The word travels masked
    # (`protection.SUIT_RE`) and comes back as "suit" until `names.localize`
    # writes it, so "suit" is accepted where `names.py` has the language's form.
    r"(?<!HEV )\bsuits?\b": {
        "pt": ("naipe", "suit"),
        "es": ("palo", "suit"),
        "fr": ("couleur",),
        "de": ("farbe",),
        "it": ("seme", "semi", "suit"),
        "nl": ("kleur",),
        "pl": ("kolor",),
        "ru": ("маст",),
        "ja": ("スート", "マーク", "組", "suit"),
        "zh_hans": ("花色", "suit"),
        "zh_hant": ("花色", "suit"),
    },
    # Dealing cards, never a business deal: Portuguese gave "negocia" and
    # "acordo", German "behandelt" (treats).
    r"\b(?:deals?\s+(?:only|a\s+row|one\s+card)|deal\s+from\s+the\s+deck)\b": {
        "pt": ("distribu", "dá ", "dar ", "da uma"),
        "es": ("repart", "da "),
        "fr": ("distribu",),
        "de": ("austeil", "teilt", "gibt", "geben"),
        "it": ("distribu",),
    },
    # The suits by name: German gave "Spaten" (a shovel).
    # Spider's two decks of cards, never a ship's: Spanish gave "cubiertas".
    r"\btwo\s+decks\b": {
        "pt": ("baralho",),
        "es": ("mazo", "baraja"),
        "fr": ("jeu", "paquet"),
        "it": ("mazz",),
    },
    # Spider's two suits by name: German gave "Spaten" (a shovel) and
    # Portuguese "corações". They travel masked (`protection.SUIT_RE`) and
    # come back in English until `names.localize` writes them.
    r"\bspades\s+and\s+hearts\b": {
        "pt": ("espadas e copas", "spades and hearts"),
        "es": ("picas y corazones", "spades and hearts"),
        "fr": ("piques et cœurs", "spades and hearts"),
        "de": ("pik und herz", "spades and hearts"),
        "it": ("picche e cuori", "spades and hearts"),
        "ja": ("スペードとハート", "spades and hearts"),
    },
    # A mine under a square, never "my" ("minha") nor a mining pit: a game's
    # mines, as its help and its catalogue say them.
    r"\b(?:mines?\s+(?:you|touch|lie|hidden|hiding)|a\s+mine\b|no\s+mine\b|\d+\s+mines|hidden\s+mines|without\s+(?:a|one)\s+mine)\b": {
        "pt": ("mina",),
        "es": ("mina",),
        "fr": ("mine",),
        "de": ("mine",),
        "it": ("mine", "mina"),
        "nl": ("mijn",),
        "pl": ("min",),
        "ru": ("мин",),
        "ja": ("地雷",),
        "zh_hans": ("雷",),
        "zh_hant": ("雷",),
    },
    # A flag planted on a square: Portuguese and Spanish keep the flag, never
    # a country's banner word gone astray ("sinalizador").
    r"\b(?:plants?\s+a\s+flag|plant\s+flags|a\s+flag\s+keeps|as\s+many\s+flags)\b": {
        "pt": ("bandeir",),
        "es": ("bandera", "banderas"),
        "fr": ("drapeau",),
        "de": ("flagge", "fahne", "markierung"),
        "it": ("bandier",),
        "ja": ("旗", "フラグ"),
        "zh_hans": ("旗",),
        "zh_hant": ("旗",),
    },
    # A press held on the screen, never a printing press: Portuguese gave
    # "imprensa", Spanish "prensa".
    r"\blong\s+press\b": {
        "pt": ("toque longo", "pression", "segur", "manten"),
        "es": ("pulsación", "pulsa", "mantén", "mantener", "presión"),
        "fr": ("appui", "maint"),
        "de": ("lange", "gedrückt"),
        "it": ("prolungat", "tieni"),
        "ja": ("長押し",),
        "zh_hans": ("长按",),
        "zh_hant": ("長按",),
    },
    # FreeCell's cell holds one card: never a prison cell ("cela") nor a
    # living one in a sentence about a game.
    r"\bfree\s+cells?\b": {
        "pt": ("célula",),
        "es": ("celda", "casilla"),
        "fr": ("cellule", "case"),
        "de": ("zelle", "feld"),
        "it": ("cell", "casell"),
        "nl": ("cel", "vak"),
        "pl": ("komór", "pol"),
        "ru": ("ячейк",),
        "ja": ("セル",),
        "zh_hans": ("空当", "格"),
        "zh_hant": ("空當", "格"),
    },
    # The cards' pile one draws from, never a ship's deck: Spanish gave
    # "cubierta" and drew from it with a pencil ("dibuja").
    r"\b(?:the|a)\s+deck\b": {
        "pt": ("baralho", "monte"),
        "es": ("mazo", "baraja"),
        "fr": ("paquet", "pioche", "talon"),
        "de": ("stapel", "deck", "talon"),
        "it": ("mazzo",),
        "nl": ("stapel", "pak"),
        "pl": ("tali", "stos"),
        "ru": ("колод",),
        "id": ("tumpukan", "dek"),
        "ja": ("山札", "デッキ"),
        "zh_hans": ("牌堆", "牌组"),
        "zh_hant": ("牌堆", "牌組"),
    },
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
    # The host of a room or a match is the person who opened it: Portuguese
    # gave "a máquina pressiona Iniciar". The server's host — its processors,
    # the readings it reports — is the machine, and the other word; only the
    # host that presses, cancels, or that somebody is, is held to it.
    r"\bthe host(?:'s Start|\s+(?:presses|pressed|cancels|cancelled))\b|\b(?:as|is|are) (?:the )?host\b": {
        "pt": ("anfitri",),
        "es": ("anfitri",),
        "fr": ("hôte",),
        "de": ("gastgeber", "host"),
        "it": ("host", "ospit"),
        "nl": ("host", "gastheer", "gastvrouw"),
        "pl": ("gospodarz", "host"),
        "ru": ("хозя", "ведущ", "хост"),
        "id": ("tuan rumah", "host"),
        "ja": ("ホスト",),
        "zh_hans": ("房主", "主持"),
        "zh_hant": ("房主", "主持"),
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
    # A vine a player swings on, never a grapevine: Hex Jungle's help came
    # back as "videira" in Portuguese, "vid" in Spanish and "ぶどう" (grapes)
    # in Japanese.
    r"\bvines?\b": {
        "pt": ("cipó",),
        "es": ("liana", "bejuco"),
        "fr": ("liane",),
        "de": ("liane",),
        "it": ("liana", "liane"),
        "nl": ("liaan", "lianen"),
        "pl": ("lian",),
        "ru": ("лиан",),
        "ja": ("ツタ", "つた", "蔓"),
        "zh_hans": ("藤",),
        "zh_hant": ("藤",),
    },
    # Sand that swallows, never plain sand: Spanish gave "arena" for
    # "quicksand", Hex Jungle's deadly ground.
    r"\bquicksand\b": {
        "pt": ("movediç",),
        "es": ("movediz",),
    },
    # A treasure found in a game, never jewellery: Japanese gave "ジュエリー".
    r"\btreasures?\b": {
        "ja": ("宝",),
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
    masked = restore(
        masked,
        {k: v for k, v in replacements.items() if FEED_RE.fullmatch(v) or SUIT_RE.fullmatch(v)},
    )
    text = translated.lower()
    missing = []

    for pattern, forms in TERMS:
        accepted = _forms(forms, locale_code)

        if accepted and pattern.search(masked) and not any(form in text for form in accepted):
            missing.append(pattern.pattern)

    for pattern, forms in WRONG_SENSES:
        wrong = _forms(forms, locale_code)

        if wrong and pattern.search(masked) and any(form in text for form in wrong):
            missing.append(pattern.pattern)

    return missing


# Words that carry a term's other sense, rejected even beside the right one:
# Spanish wrote "Mover una tarjeta, o las cartas encima de ella", a bank card
# and a playing card in one sentence, so the card term alone passed it.
_WRONG_SENSES: dict[str, dict[str, tuple[str, ...]]] = {
    r"\b(?:face-down\s+cards?|playing\s+cards?|card\s+game|game\s+of\s+cards"
    r"|cards?\s+at\s+a\s+time|cards?\s+on\s+(?:a|its|the)\s+pile|cards?\s+on\s+top\s+of"
    r"|cards?\s+(?:back\s+)?from\s+(?:the\s+deck|a\s+pile)|(?:its|the)\s+next\s+card"
    r"|every\s+card\s+on|tap\s+a\s+card|a\s+card\s+goes|a\s+card\s+that\s+no\s+other\s+card"
    r"|no\s+card\s+can|holds\s+one\s+card|all\s+the\s+cards|any\s+card\s+goes"
    r"|cards?\s+move\s+together|move\s+a\s+card|cards\s+of\s+its\s+suit)\b": {
        "pt": ("cartão", "cartões"),
        "es": ("tarjeta",),
        "it": ("scheda", "schede"),
    },
    r"\bfree\s+cells?\b": {
        "pt": ("cela", "celas"),
        "ja": ("無料",),
    },
    r"\bface\s+up\b": {
        "de": ("verdeckt",),
    },
    r"\b(?:mines?\s+(?:you|touch|lie|hidden|hiding)|a\s+mine\b|no\s+mine\b|\d+\s+mines|hidden\s+mines|without\s+(?:a|one)\s+mine)\b": {
        "pt": ("minha", "minhas", "mineração", "minério"),
        "es": (" mi ",),
    },
    r"\blong\s+press\b": {
        "pt": ("imprensa",),
        "es": ("prensa",),
    },
    # A Sudoku's digit is a figure, never a finger.
    r"\b(?:a\s+digit|the\s+digits?|its\s+digit|that\s+digit|right\s+digit|wrong\s+digit|put\s+a\s+digit)\b": {
        "pt": ("dedo",),
        "es": ("dedo",),
        "fr": ("doigt",),
        "it": ("dito", "dita"),
        "de": ("finger",),
    },
    # A key of a keypad or a keyboard, never a door's key.
    r"\b(?:a\s+key\s+(?:of|goes|on)|its\s+key|the\s+keys?\s+of\s+the\s+keypad)\b": {
        "pt": ("chave",),
        "es": ("llave",),
        "fr": ("clé", "clef"),
        "de": ("schlüssel",),
        "it": ("chiave",),
    },
    # A Sudoku's notes are written down, never sung: German gave "Noten".
    r"\b(?:writes\s+notes|digits\s+and\s+notes|take\s+notes|as\s+a\s+note|the\s+notes\s+(?:in|start|on))\b": {
        "de": ("noten",),
        "zh_hans": ("音符",),
        "zh_hant": ("音符",),
    },
    # A Sudoku's grid, never a power grid: Chinese gave "电网".
    r"\b(?:the|every|each|new)\s+(?:9×9\s+)?grids?\b": {
        "zh_hans": ("电网",),
        "zh_hant": ("電網",),
    },
    # A hint a game gives, never an innuendo.
    r"\b(?:a\s+hint|hints?\s+(?:adds?|reveals?|stays)|the\s+hints|hint\s+\(adds)\b": {
        "pt": ("insinua",),
        "es": ("insinua",),
        "fr": ("allusion",),
        "de": ("andeutung", "anspielung"),
        "it": ("allusion",),
    },
    # A field's square, never a town square.
    r"\b(?:(?:a|the|every|each|first|other|chosen)\s+squares?|squares?\s+(?:you|of|around|without|with))\b": {
        "es": ("plaza",),
        "zh_hans": ("广场",),
        "zh_hant": ("廣場",),
    },
    r"(?<!HEV )\bsuits?\b": {
        "pt": ("fato", "terno"),
        "es": ("traje",),
        "de": ("anzug", "anzüg"),
    },
    r"\b(?:deals?\s+(?:only|a\s+row|one\s+card)|deal\s+from\s+the\s+deck)\b": {
        "pt": ("negoci", "acordo"),
        "de": ("behandelt",),
    },
}

WRONG_SENSES: tuple[tuple[re.Pattern[str], dict[str, tuple[str, ...]]], ...] = tuple(
    (re.compile(pattern, re.IGNORECASE), forms) for pattern, forms in _WRONG_SENSES.items()
)


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
        # Measured on the browser's call and Space strings: Portugal's camera
        # and file, the pre-1990 "reacção", "antevisão" for a preview, the
        # European progressive ("A ligar ao espaço", "A tentar recuperar",
        # "A juntar-se") and the "tu" preterite of joining.
        "câmara",
        "câmaras",
        "ficheiro",
        "ficheiros",
        "reacção",
        "reacções",
        "antevisão",
        "a ligar",
        "a tentar",
        "a juntar",
        "entraste",
        # "À espera da oferta dos media", "Falha na ligação de sinalização":
        # waiting, the media and a connection as Portugal writes them.
        "à espera",
        "dos media",
        "ligação",
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



# The one Portuguese model writes Portugal's Portuguese, and `foreign_forms`
# rightly refuses it for the Brazilian catalog. What has one Brazilian
# equivalent is rewritten on the way out of the engine instead, so the
# translation ships rather than staying English: the words, the "tu"
# possessive, and the progressive ("A carregar...", "está a ser"), which Brazil
# says with a gerund. "começou a falar" is Brazilian too, so only a sentence's
# opening "A <infinitive>" and "estar a <infinitive>" are touched. A word whose
# gender differs (Portugal's "o ecrã", Brazil's "a tela") is left to the
# variant check: swapping it would break the agreement of the words around it.
_BRAZILIAN_WORDS = {
    "câmara": "câmera",
    "câmaras": "câmeras",
    "ficheiro": "arquivo",
    "ficheiros": "arquivos",
    "reacção": "reação",
    "reacções": "reações",
    "antevisão": "pré-visualização",
    "seleccionado": "selecionado",
    "seleccionada": "selecionada",
    "desactivado": "desativado",
    "desactivar": "desativar",
    "activar": "ativar",
    "grelha": "grade",
    "grelhas": "grades",
    "correcto": "correto",
    "correcta": "correta",
    "correctos": "corretos",
    "correctas": "corretas",
    "cinzento": "cinza",
    "cinzenta": "cinza",
    "terminares": "terminar",
    "desactivada": "desativada",
    "activado": "ativado",
    "activada": "ativada",
    "à espera da": "aguardando a",
    "à espera do": "aguardando o",
    "à espera de": "aguardando",
    "os media": "a mídia",
    "dos media": "da mídia",
    "a tua": "a sua",
    "as tuas": "as suas",
    "o teu": "o seu",
    "os teus": "os seus",
}
_BRAZILIAN_WORD_RE = re.compile(
    r"\b(" + "|".join(map(re.escape, sorted(_BRAZILIAN_WORDS, key=len, reverse=True))) + r")\b",
    re.IGNORECASE,
)
_OPENING_PROGRESSIVE = re.compile(r"(^|[.!?…]\s+)A (\w+?)(ar|er|ir)\b(-se)?")
_ESTAR_PROGRESSIVE = re.compile(
    r"\b(est(?:á|ão|ou|amos|ava|avam))\s+a\s+(\w+?)(ar|er|ir)\b", re.IGNORECASE
)
_GERUND = {"ar": "ando", "er": "endo", "ir": "indo"}


def _keep_case(original: str, replacement: str) -> str:
    return replacement[0].upper() + replacement[1:] if original[0].isupper() else replacement


def brazilian_forms(translated: str) -> str:
    """`translated` with Portugal's words and progressive written as Brazil's."""
    text = _BRAZILIAN_WORD_RE.sub(
        lambda m: _keep_case(m.group(1), _BRAZILIAN_WORDS[m.group(1).lower()]), translated
    )
    text = _OPENING_PROGRESSIVE.sub(
        lambda m: m.group(1)
        + (m.group(2) + _GERUND[m.group(3)]).capitalize()
        + (m.group(4) or ""),
        text,
    )
    return _ESTAR_PROGRESSIVE.sub(
        lambda m: f"{m.group(1)} {m.group(2)}{_GERUND[m.group(3)]}", text
    )
