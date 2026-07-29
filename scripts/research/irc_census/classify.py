#!/usr/bin/env python3
"""Language and subject classification for harvested IRC channels.

Deliberately transparent heuristics — every verdict carries the evidence that
produced it, so a wrong bucket is auditable rather than mysterious.

Language, in order of confidence:
  1. writing system of the topic (Cyrillic, CJK, Hangul, Greek, ...)
  2. diacritic fingerprints (ã/õ -> pt, ñ/¿ -> es, ß -> de, ł/ż -> pl, ...)
  3. stopword scoring over the topic text
  4. country/language tokens in the channel name
  5. the network's own prior (an all-Spanish network is Spanish by default)
  6. undetermined
"""
import re
import unicodedata

# --------------------------------------------------------------------------
# writing systems
# --------------------------------------------------------------------------
SCRIPT_RANGES = [
    ("ru", r"[Ѐ-ӿ]"),          # Cyrillic (ru/uk/bg/sr — merged)
    ("el", r"[Ͱ-Ͽ]"),          # Greek
    ("he", r"[֐-׿]"),          # Hebrew
    ("ar", r"[؀-ۿ]"),          # Arabic
    ("th", r"[฀-๿]"),          # Thai
    ("hi", r"[ऀ-ॿ]"),          # Devanagari
    ("ko", r"[가-힯]"),          # Hangul
    ("ja", r"[぀-ヿ]"),          # Kana (Han alone is ambiguous)
    ("zh", r"[一-鿿]"),          # Han
]

DIACRITIC_HINTS = [
    ("pt", r"[ãõ]|ç[ãaeo]|ção\b"),
    ("es", r"[ñ¿¡]|ción\b"),
    ("de", r"ß|[äöü](?=[a-z])"),
    ("pl", r"[ąćęłńśźż]"),
    ("tr", r"[şğıİ]"),
    ("cs", r"[řůěščž]"),
    ("hu", r"[őű]"),
    ("ro", r"[șțăî]"),
    ("da", r"[æø]"),
    ("sv", r"[åäö]{1}"),
    ("fr", r"[àèùçîôê]|œ"),
]

STOPWORDS = {
    "en": "the and for you with this are our welcome please here help channel "
          "questions about before ask read more info all new who what",
    "pt": "que não para com você uma aqui canal bem-vindo obrigado mais está "
          "são todos sobre nós isso quem também",
    "es": "que para con una aquí canal bienvenido bienvenidos gracias más está "
          "todos por del las los sala hola sobre",
    "fr": "que pas pour avec une ici salon bienvenue merci plus est les des "
          "vous nous sur tout aussi",
    "de": "und der die das nicht für mit eine hier willkommen danke ist wir "
          "auf oder aber alle über kanal",
    "it": "che non per con una qui canale benvenuto benvenuti grazie più sono "
          "del gli della anche tutti",
    "nl": "het een niet voor met hier welkom bedankt zijn wij ook van naar "
          "maar alle over kanaal",
    "pl": "nie dla jest tutaj witamy dziękuję oraz przez wszystkich kanał się "
          "który tylko jak można",
    "ru": "для это все как что канал добро пожаловать привет тут или",
    "tr": "bir için değil burada hoşgeldiniz teşekkür kanal herkese ile daha",
    "fi": "että tämä ovat täällä tervetuloa kiitos kanava mutta myös",
    "sv": "och för inte här välkommen tack kanal men också alla",
    "id": "yang tidak untuk dengan disini selamat datang terima kasih saluran semua",
    "ms": "yang tidak untuk dengan sini selamat datang terima kasih saluran semua "
          "adalah kepada dalam boleh sila jangan",
    "no": "ikke her velkommen takk kanal men også alle som",
}
STOPWORDS = {k: set(v.split()) for k, v in STOPWORDS.items()}

# Tokens in a channel name that name a language or a place.
NAME_LANG_TOKENS = {
    "pt": "brasil brazil br portugal pt portugues português lusofonia rio sp "
          "saopaulo lisboa porto",
    "es": "espanol español espana españa spain es hispano mexico argentina chile "
          "colombia peru venezuela madrid barcelona latino castellano",
    "fr": "france francais français fr quebec belgique paris francophone",
    "de": "deutsch deutschland german de berlin wien schweiz oesterreich österreich",
    "it": "italia italiano italy it roma milano",
    "nl": "nederland nederlands dutch nl vlaanderen belgie amsterdam",
    "pl": "polska polski poland pl warszawa",
    "ru": "russia russian ru moscow moskva rus",
    "ja": "japan japanese nihon jp tokyo",
    "zh": "china chinese cn taiwan hongkong",
    "ko": "korea korean kr seoul",
    "tr": "turkiye türkiye turkey turkish tr istanbul",
    "sv": "sverige svenska sweden se stockholm",
    "fi": "suomi finland fi helsinki",
    "no": "norge norsk norway no oslo",
    "da": "danmark dansk denmark dk",
    "el": "greece greek hellas gr athens",
    "cs": "cesko czech cz praha",
    "hu": "magyar hungary hu budapest",
    "ro": "romania romanian ro bucuresti",
    "id": "indonesia indo id jakarta bandung surabaya",
    "ms": "malaysia malaysian melayu kampung johor melaka kelantan kedah pahang "
          "selangor perak terengganu perlis sabah sarawak penang pulaupinang "
          "kualalumpur kl putrajaya negerisembilan mamak",
    "ar": "arab arabic egypt saudi",
    "he": "israel hebrew il",
    "en": "usa uk london america canada australia ireland scotland",
}
NAME_LANG_TOKENS = {k: set(v.split()) for k, v in NAME_LANG_TOKENS.items()}

# --------------------------------------------------------------------------
# subjects — (label, name-tokens, topic-keywords)
# Ordered: earlier categories win ties, so put the specific before the generic.
# --------------------------------------------------------------------------
SUBJECTS = [
    ("filesharing/xdcc",
     "xdcc warez packs fserve mp3 movies iso ebooks ebook releases dvd bookz "
     "0day mp3s scene appz gamez torrents mvgroup",
     "xdcc fserve trigger packs @find warez torrent release scene ebook "
     "audiobook 0day dcc send"),
    ("anime/manga",
     "anime manga fansub subs weeb otaku nyaa horriblesubs erai",
     "anime manga fansub subbed raws episode ova doujin vtuber"),
    ("adult/dating",
     "sex porn nsfw adult dating singles flirt cam hot nude erotic bdsm gay "
     "lesbian swingers milf",
     "adult nsfw 18+ nudes camgirl porn explicit hookup"),
    ("linux/foss",
     "linux debian ubuntu arch archlinux gentoo fedora nixos slackware bsd "
     "freebsd openbsd netbsd kernel gnu foss libre suse alpine void manjaro "
     "systemd wayland xorg gnome kde xfce",
     "linux distro kernel package repo upstream maintainer apt pacman rpm "
     "free software gnu wayland xorg"),
    ("programming/dev",
     "python ruby rust golang go javascript js typescript node php java kotlin "
     "swift haskell lisp scheme clojure elixir erlang perl lua zig ocaml "
     "webdev frontend backend devops docker kubernetes git vim emacs neovim "
     "programming coding dev code compiler regex sql postgres mysql sqlite "
     "django rails react vue laravel spring dotnet csharp cpp c++",
     "programming language compiler library framework api sdk repository "
     "pull request stackoverflow paste your code documentation"),
    ("ai/ml",
     "llm gpt llama ollama stablediffusion diffusion "
     "machinelearning deeplearning localllama",
     # Deliberately narrow: "model", "training" and above all "network" are
     # ordinary English and were dragging in half of IRC.
     "llm inference fine-tune transformer embeddings huggingface ollama "
     "stable-diffusion pytorch"),
    ("security/hacking",
     "security infosec hacking hack ctf pentest exploit malware reverse "
     "reversing forensics opsec privacy tor i2p vpn crypto cryptography "
     "hardening netsec appsec",
     "ctf exploit vulnerability cve pentest malware reverse engineering "
     "opsec threat anonymity"),
    ("crypto/finance",
     "bitcoin btc ethereum eth monero xmr crypto cryptocurrency trading forex "
     "stocks finance defi nft mining",
     "bitcoin blockchain wallet exchange trading price satoshi altcoin"),
    ("gaming",
     "game games gaming quake doom counterstrike cs csgo dota lol minecraft "
     "wow runescape osrs tf2 valorant overwatch fortnite steam speedrun "
     "roguelike nethack chess poker emulator emulation rom retroarch "
     "nintendo playstation xbox gamedev",
     "server ip clan match tournament ladder scrim speedrun mod pack "
     "gameplay respawn"),
    ("retro/vintage computing",
     "retro amiga c64 commodore atari msx zx spectrum dos vintage bbs 8bit "
     "16bit sega pixelart demoscene dial-up modem",
     "amiga commodore retro vintage demoscene bbs floppy 8-bit cassette"),
    ("science/education",
     "math maths physics chemistry biology astronomy science space electronics "
     "engineering university study homework academia statistics",
     "physics theorem equation experiment research paper arxiv university "
     "lecture homework"),
    ("music/art/media",
     "music metal rock punk jazz hiphop rap electronic techno guitar piano "
     "radio dj art design photography film movies cinema books writing "
     "podcast",
     "music album band radio stream playlist artist song film movie novel"),
    ("politics/news",
     "politics political news war ukraine israel palestine election worldnews "
     "economics debate",
     "politics election war news debate government protest"),
    ("network staff/services",
     # Only names that can mean nothing else. "welcome", "lobby", "status" and
     # "network" are what every social channel calls itself.
     "help helpdesk support services opers oper staff admin abuse ops chanserv "
     "nickserv operhelp ircd ircops",
     # Topic evidence must be unmistakable: "Respect Operators & Users" is
     # boilerplate on thousands of ordinary social channels.
     "nickserv chanserv operhelp k-line g-line ircop netadmin"),
    ("hardware/sysadmin",
     "hardware sysadmin server servers hosting vps networking cisco proxmox "
     "homelab raspberry pi arduino electronics 3dprinting selfhosted nas dns",
     "sysadmin hosting vps server uptime dns router firewall homelab "
     "self-hosted rack"),
    ("regional/national",
     " ".join(sorted(set().union(*NAME_LANG_TOKENS.values()))),
     ""),
    ("social/chat",
     "chat chats chatting lounge chill talk friends random offtopic social "
     "cafe bar pub hangout general main lobby teen teens kids party fun "
     "friendly community",
     "chat hang out friendly welcome everyone say hi be nice no spam "
     "conversation off-topic"),
]


# mIRC formatting: colour (\x03 with optional fg[,bg]), bold, italic, underline,
# reverse, monospace and reset. Topics on social networks are dense with these,
# and left in place they poison both classifiers — a colour code's stray digits
# and letters read as words.
MIRC_CODES = re.compile(r"\x03(?:\d{1,2}(?:,\d{1,2})?)?|[\x02\x0f\x11\x16\x1d\x1e\x1f\x01]")
# Some ircds prefix the channel's modes into the LIST topic field: "[+nrt] real topic".
MODE_PREFIX = re.compile(r"^\[\+[A-Za-z]*(?:\s[^\]]*)?\]\s*")


def clean_topic(topic):
    """The topic as a human reads it: no colour codes, no mode prefix."""
    if not topic:
        return ""
    topic = MIRC_CODES.sub("", topic)
    topic = MODE_PREFIX.sub("", topic)
    return " ".join(topic.split())


def _tokens(name):
    # Strip the channel prefix (#, ##, &, !, +) before tokenising, or every token
    # arrives as "#linux" and matches no keyword at all.
    name = name.lower().lstrip("#&!+")
    return set(t for t in re.split(r"[^a-z0-9\+#]+", name) if t)


def _words(text):
    text = unicodedata.normalize("NFC", clean_topic(text).lower())
    return set(re.findall(r"[\wÀ-ÿа-яё\-']+", text, re.UNICODE))


# Channels that exist to be counted, not inhabited. HybridIRC runs spam traps
# advertising five-figure membership; taken at face value they make it the second
# largest network on IRC. Detected, excluded from totals, and reported separately.
SYNTHETIC_TOPIC = re.compile(r"fake channel|confus\w* spambot|spam ?trap|honeypot", re.I)
SYNTHETIC_NAME = re.compile(r"^#+spam[A-Za-z0-9]{10,}$")


def is_synthetic(channel, topic):
    return bool(SYNTHETIC_TOPIC.search(topic or "")) or bool(SYNTHETIC_NAME.match(channel or ""))


def classify_language(channel, topic, prior=None):
    """Return (lang, evidence)."""
    topic = clean_topic(topic)
    if topic:
        for lang, pattern in SCRIPT_RANGES:
            hits = len(re.findall(pattern, topic))
            if hits >= 3:
                return lang, "script:%s(%d)" % (lang, hits)
        low = topic.lower()
        for lang, pattern in DIACRITIC_HINTS:
            if re.search(pattern, low):
                return lang, "diacritic:%s" % lang
        words = _words(topic)
        if len(words) >= 4:
            scores = {l: len(words & sw) for l, sw in STOPWORDS.items()}
            best = max(scores, key=scores.get)
            runner = sorted(scores.values())[-2]
            if scores[best] >= 2 and scores[best] > runner:
                return best, "stopwords:%s(%d)" % (best, scores[best])

    toks = _tokens(channel)
    for lang, names in NAME_LANG_TOKENS.items():
        if toks & names:
            return lang, "name:%s" % ",".join(sorted(toks & names))[:24]

    if prior:
        return prior, "network-prior"
    return "und", "none"


def classify_subject(channel, topic):
    """Return (subject, evidence). Name matches count double."""
    toks = _tokens(channel)
    words = _words(topic) if topic else set()
    best, best_score, best_ev = "unclassified", 0, ""
    for label, name_kw, topic_kw in SUBJECTS:
        nk, tk = set(name_kw.split()), set(topic_kw.split())
        n_hit, t_hit = toks & nk, words & tk
        score = 2 * len(n_hit) + len(t_hit)
        if score > best_score:
            best, best_score = label, score
            best_ev = ",".join(sorted(n_hit | t_hit))[:40]
    return (best, best_ev) if best_score else ("unclassified", "")


def enrich(row, prior=None):
    raw_topic = row.get("topic", "")
    topic = clean_topic(raw_topic)
    lang, lang_ev = classify_language(row["channel"], raw_topic, prior)
    subj, subj_ev = classify_subject(row["channel"], raw_topic)
    row = dict(row)
    row.update(topic=topic, raw_topic=raw_topic,
               lang=lang, lang_evidence=lang_ev,
               subject=subj, subject_evidence=subj_ev,
               has_topic=bool(topic),
               synthetic=is_synthetic(row["channel"], topic))
    return row
