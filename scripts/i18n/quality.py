"""Deciding whether a machine translation is fit to ship.

The guards here encode failure modes observed in real catalogs. They are pure
functions over strings so they can be exercised without a translation engine,
and they are shared by the translation pipeline (which rejects bad output at
write time) and the CI gate (which rejects it at review time).
"""

from __future__ import annotations

import re
from collections import defaultdict

from .protection import SENTINEL_RE, has_sentinel_residue, protect

# A token repeated this many times in a row is an NMT decoding loop, e.g.
# "permanently" -> "Sürekli kalıcı kalıcı kalıcı kalıcı kalıcı".
DEGENERATE_RUN = 4
# A long run of one character, e.g. a backslash explosion.
DEGENERATE_CHAR_RUN = re.compile(r"(\S)\1{7,}")
# One translation serving at least this many distinct sources means the model
# collapsed unrelated strings onto a single output.
COLLAPSE_THRESHOLD = 5


def is_degenerate(text: str) -> bool:
    """True when the output shows a decoding loop."""
    tokens = text.split()
    run = 1

    for index in range(1, len(tokens)):
        if tokens[index] == tokens[index - 1] and len(tokens[index]) > 1:
            run += 1

            if run >= DEGENERATE_RUN:
                return True
        else:
            run = 1

    return bool(DEGENERATE_CHAR_RUN.search(text))


# Full stops only. "!" and "?" are expressive choices a translator may make,
# and an ellipsis is a UI convention meaning "opens a dialog".
TRAILING_STOP = (".", "。", "．")
# Two scripts in one short label is normal — a brand, a unit, "IRC チャンネル".
# Three is not: it means the bytes were corrupted rather than translated.
MOJIBAKE_SCRIPT_LIMIT = 3


def has_trailing_stop(source: str, translated: str) -> bool:
    """True when a label gained sentence punctuation the source lacks.

    Buttons and menu items are not sentences: "Sim." and "いいえ。" are wrong
    where the source says "Yes" and "No".

    Applied only to the curated glossary, never to short strings in general —
    those are mostly game hints and chat phrases ("Got it", "Robert Downey Jr")
    where a full stop is correct, and gating on them buries the real findings.
    """
    if source.strip().endswith(TRAILING_STOP):
        return False

    stripped = translated.strip()

    if not stripped.endswith(TRAILING_STOP):
        return False

    # "Settings..." opens a dialog; that is a convention, not a sentence.
    if stripped.endswith(("...", "…", "。。。")):
        return False

    # Several languages write ordinals with a trailing dot ("lat 80.").
    return not (len(stripped) >= 2 and stripped[-2].isdigit())


def _script_of(char: str) -> str | None:
    import unicodedata

    try:
        name = unicodedata.name(char)
    except ValueError:
        return None

    for block in ("LATIN", "GREEK", "CYRILLIC", "ARABIC", "HANGUL"):
        if name.startswith(block):
            return block

    if name.startswith(("CJK", "HIRAGANA", "KATAKANA")):
        return "CJK"

    return None


def looks_like_mojibake(text: str) -> bool:
    """True when one short string mixes too many writing systems.

    "Next" came back from the Chinese model as "ưμ㼯A" — a Vietnamese vowel, a
    Greek mu, a rare CJK ideograph and a Latin letter. That is corrupted bytes,
    and no per-string translation check would call it wrong.
    """
    if len(text) > 24:
        return False

    scripts = {script for script in map(_script_of, text) if script}

    return len(scripts) >= MOJIBAKE_SCRIPT_LIMIT


def introduced_degeneration(source: str, translated: str) -> bool:
    """True when the repetition is the model's doing, not the source's.

    Some sources repeat on purpose (a scroll-area demo string), and echoing
    that faithfully is correct.
    """
    return is_degenerate(translated) and not is_degenerate(source)


def is_usable_translation(source: str, translated: str, replacements: dict[str, str]) -> bool:
    """Reject output we would rather not ship at all.

    A translation that lost a placeholder, kept a raw sentinel, looped, or came
    back empty is worse than leaving the English source in place: the source
    stays readable and the fallback check flags it for a human.
    """
    if not translated.strip():
        return False

    if has_sentinel_residue(translated):
        return False

    if introduced_degeneration(source, translated):
        return False

    return all(value in translated for value in replacements.values())


def batch_is_contaminated(parts: list[str], sources: list[str]) -> bool:
    """Detect a model treating a joined batch as a single document.

    Chaining unrelated UI strings makes some models emit a running heading in
    front of the segments. It shows up as one extra leading line that several
    parts share and their sources do not. The first segment usually escapes it
    (the model only starts the heading after the first separator), so a
    majority rule is used rather than requiring every part to carry it.
    """
    if len(parts) < 3 or len(parts) != len(sources):
        return False

    spurious: dict[str, int] = defaultdict(int)

    for part, source in zip(parts, sources):
        # A single-line result has no extra heading: the line is the answer.
        if "\n" not in part:
            continue

        head = part.split("\n", 1)[0].strip()

        if not head:
            continue

        # A first line mirroring the source's own first line is legitimate.
        if head == source.split("\n", 1)[0].strip():
            continue

        spurious[head] += 1

    return any(count >= 2 for count in spurious.values())


def find_shared_headings(
    entries: list[tuple[str, str]], threshold: int = COLLAPSE_THRESHOLD
) -> dict[str, set[str]]:
    """Leading lines many translations share but their sources do not.

    This is `batch_is_contaminated` applied to a whole catalog: it catches a
    heading the model injected during batching that was then written to disk,
    which no per-string check can see.
    """
    headings: dict[str, set[str]] = defaultdict(set)

    for source, translated in entries:
        if "\n" not in translated:
            continue

        head = translated.split("\n", 1)[0].strip()

        if not head or head == source.split("\n", 1)[0].strip():
            continue

        headings[head].add(source.strip())

    return {head: sources for head, sources in headings.items() if len(sources) >= threshold}


# A heading short enough that it can only be a label the model prefixed, never
# a sentence the source asked for.
HEADING_CHARS = 12


def invented_break(source: str, translated: str) -> str | None:
    """Repair a translation that broke a single-line source into two.

    `find_shared_headings` needs a heading to recur across the catalog before
    it will call it injected, which is right for a bulk contamination and
    blind to a single one: Argos prefixed exactly one diagrams entry with
    シリーズ ("series") and the rule could not see it.

    A UI string's newlines are its own. A source with none that comes back
    with one is always the model's invention, whatever the rest of the catalog
    does, so this judges the pair alone. A short leading line is a heading and
    is dropped; anything else is a sentence the model split, and is rejoined.

    Returns the repaired value, or None when there is nothing wrong.
    """
    if not source or not translated:
        return None

    if "\n" in source or "\n" not in translated:
        return None

    lines = [line.strip() for line in translated.split("\n")]
    lines = [line for line in lines if line]

    if not lines:
        return None

    if len(lines) > 1 and len(lines[0]) <= HEADING_CHARS:
        return " ".join(lines[1:])

    return " ".join(lines)


# The negations whose loss changes what the reader does. A bare "no" is left
# out on purpose: "No topic set" translates to a dozen shapes that carry the
# sense without a marker, and flagging them all would bury the ones that matter.
#
# Both apostrophes, and the contraction list is exhaustive on purpose. The first
# version of this pattern listed only can't and won't and matched only the ASCII
# apostrophe, while the repository writes the typographic one in prose — so the
# home page's own headline, "Your community isn’t yours.", was invisible to the
# guard and reached ten locales saying the opposite.
# "Nothing but" is not a negation: "may want nothing but the words" means
# "only the words", and a translation saying "only" said it right.
NEGATED_SOURCE = re.compile(
    r"\b(cannot|never|nothing(?!\s+but\b)|nobody|neither|nor"
    r"|do not|does not|did not|will not|is not|are not|was not|were not"
    r"|has not|have not|had not|would not|should not|could not|must not"
    r"|(?:can|won|shan|ain|isn|aren|wasn|weren|don|doesn|didn"
    r"|hasn|haven|hadn|wouldn|shouldn|couldn|mustn|needn)['’]t)\b",
    re.IGNORECASE,
)

# A translation that carries a literal HTML entity. The engine HTML-escapes the
# source before translating and never unescapes the result, so a `&`, `’` or `“`
# in the msgid comes back as the entity's own letters — and when the escaped
# character sat inside a negative contraction, the negation left with it. Every
# damaged entry measured in the catalogues contained one of those three
# characters; none without.
#
# A space inside an entity is the categorical case: `& mdash;` is never markup,
# whatever the msgid holds. An unspaced entity is only damage when the msgid has
# none of its own, because landing and help msgids do legitimately carry `&amp;`.
_SPACED_ENTITY = re.compile(
    r"&\s+(?:[a-zA-Z][a-zA-Z0-9]{1,10}|#\s*[0-9]{1,6}|#\s*[xX]\s*[0-9a-fA-F]{1,6})\s*;"
)
_ANY_ENTITY = re.compile(
    r"&\s*(?:[a-zA-Z][a-zA-Z0-9]{1,10}|#\s*[0-9]{1,6}|#\s*[xX]\s*[0-9a-fA-F]{1,6})\s*;"
)

# What a negation looks like in each catalogue. Substrings, not words: German
# compounds ("niemals", "niemand") and Japanese inflections ("ません", "ない")
# are the same marker wearing different endings.
#
# Prefix negations belong here too, and their absence is what made this table
# cry wolf. "not read" is a correct `ungelesen` in German and
# `непрочитанному` in Russian; "could not be found" is a correct `introuvable`
# in French; "Nothing is selected" is a correct `未選択` in Japanese. A table
# that misses those reports healthy entries, and a guard that cries wolf gets
# a baseline instead of a fix — which is how "THIS CANNOT BE UNDONE" stayed in
# German as "Das ist alles" behind 54 accepted hashes.
#
# The bias is deliberate: a marker that is slightly too generous misses a real
# inversion, while one that is too strict buries every real inversion in noise.
NEGATION_MARKERS = {
    "pt_BR": r"não|nem\b|nunca|ninguém|nada|nenhum|jamais|imposs|\bin[a-z]{5,}|\bsem\b",
    "pt_PT": r"não|nem\b|nunca|ninguém|nada|nenhum|jamais|imposs|\bin[a-z]{5,}|\bsem\b",
    "es": r"\bno\b|\bni\b|nunca|nadie|nada|ning|jamás|imposib|\bin[a-z]{5,}|\bsin\b|\bsolo\b",
    "fr": r"\bne\b|\bn['’]|\bpas\b|jamais|personne|\brien\b|aucun|\bni\b|imposs"
    r"|\bin(?:trouvable|disponible|connu|actif|existant)|\bsans\b",
    "de": r"nicht|kein|\bnie|niemand|nichts|weder|nein|unmöglich"
    r"|\bun(?:gelesen|bekannt|gültig|tätig|sichtbar)|\berst\b|\bohne\b",
    "it": r"\bnon\b|\bné\b|mai\b|nessun|niente|nulla|imposs|\bin[a-z]{5,}|\bsenza\b"
    r"|\bsolo\b|\bsoltanto\b",
    "nl": r"niet|geen|nooit|niemand|niets|nergens|noch|onmogelijk"
    r"|\bon(?:gelezen|bekend|zichtbaar|geldig)|\bzonder\b|alleen",
    "pl": r"\bnie|żad|nigdy|nikt|\bnic\b|ani\b|brak|\bbez\b|tylko|jedynie",
    # "не" also prefixes a negated adjective — непрочитанный, недоступный —
    # so the right boundary has to go.
    "ru": r"\bне|\bни|нет|никог|никт|ничего|нечего|некому|никак|нельзя|невозмож|\bбез\b",
    # 無 negates, but 無料 is "free of charge": "install for free" passed as
    # "nothing to install".
    "ja": r"ない|なく|なかっ|ませ|なし|せず|れず|ずに|不|無(?!料)|非|未|できま|決して|だけ",
    "zh_hans": r"不|没|无|未|别|非|勿|仅|只",
    "zh_hant": r"不|沒|無|未|別|非|勿|僅|只",
    "id": r"tidak|bukan|jangan|belum|\btak\b|mustahil|tanpa|hanya|gagal",
}

_MARKER_RE = {code: re.compile(pat, re.IGNORECASE) for code, pat in NEGATION_MARKERS.items()}


def lost_negation(source: str, translated: str, locale_code: str) -> bool:
    """A source that says "cannot" and a translation that says nothing of the kind.

    This is the failure that matters most and that every other guard passes:
    the output is a well-formed sentence, so collapse, degeneration and
    residue all see a healthy entry. Measured in the shipped catalogues:
    "THIS CANNOT BE UNDONE" reached German as "DIESER KANNES" and, elsewhere,
    as "Das ist alles" — on the line that precedes destroying the server.

    A locale with no marker table is not judged rather than judged wrongly.
    """
    marker = _MARKER_RE.get(locale_code)

    if marker is None or not source or not translated.strip():
        return False

    # An entry left in English has lost nothing: its negation is still there.
    if translated.strip() == source.strip():
        return False

    return bool(NEGATED_SOURCE.search(source)) and not marker.search(translated)


def has_entity_residue(source: str, translated: str) -> bool:
    """A translation printing an HTML entity's letters at the reader.

    The same escaping asymmetry that eats negations leaves its other half in
    plain sight: "Step 1 — Clone" reached Spanish as "Paso 1 & mdash; Clone",
    and "💻 Contribute code" as "& #x1F4BB; Gentileza de código". Measured in
    the shipped catalogues, `& mdash;` alone accounted for 91 occurrences.

    Two rules, because only one of them is categorical. A space inside an
    entity is never markup, so it is damage whatever the source holds. An
    unspaced entity is damage only when the source carries none of its own —
    the landing and help msgids do legitimately contain `&amp;`.
    """
    if not translated.strip():
        return False

    if _SPACED_ENTITY.search(translated):
        return True

    return bool(_ANY_ENTITY.search(translated)) and not _ANY_ENTITY.search(source)


def find_collapses(
    entries: list[tuple[str, str]], threshold: int = COLLAPSE_THRESHOLD
) -> dict[str, set[str]]:
    """Group sources that share one translation.

    `entries` is a list of (source, translated) pairs. The result maps each
    over-reused translation to the distinct sources that produced it.
    """
    by_translation: dict[str, set[str]] = defaultdict(set)

    for source, translated in entries:
        stripped = translated.strip()

        if stripped:
            by_translation[stripped].add(source.strip())

    return {
        translated: sources
        for translated, sources in by_translation.items()
        if len(sources) >= threshold
    }


# The round-trip gate. Read back into English, a translation that kept its
# meaning shares most of the source's content words; one that turned "Do I
# need an account?" into "Do I need a bill?" or "+ voiced users, who can speak"
# into "I asked the user to speak properly" does not. Measured over the guide
# pages, the garbage read back a third of its content words or fewer, while a
# correct paraphrase ("set the topic" -> "defined the subject") can fall to
# two in five; a single wrong word in a long sentence stays well above, which
# is what `terms.missing_terms` is for.
MEANING_THRESHOLD = 0.4
# Below this many content words a short label reads back too loosely to judge
# ("Games you can play here" -> "Playable Games"), so it is not judged.
MEANING_MIN_WORDS = 4

_CONTENT_WORD = re.compile(r"[A-Za-z]{3,}")
_STOPWORDS = frozenset(
    "the and are for its this that with from you your can not but has have had was were "
    "will would there their they them what when who how which into onto than then also "
    "any all one each every here does did".split()
)


def content_words(text: str) -> set[str]:
    """Content words, reduced to a five-letter stem so "voiced" meets "voice"."""
    words = _CONTENT_WORD.findall(SENTINEL_RE.sub(" ", text))
    return {word.lower()[:5] for word in words if word.lower() not in _STOPWORDS}


def meaning_kept(source: str, read_back: str) -> bool:
    """True when the translation, read back into English, still says the source.

    Both sides are compared masked, so commands and placeholders — which the
    translation keeps verbatim anyway — neither help nor hurt the score.
    """
    wanted = content_words(protect(source)[0])

    if len(wanted) < MEANING_MIN_WORDS:
        return True

    found = content_words(protect(read_back)[0])
    return len(wanted & found) / len(wanted) >= MEANING_THRESHOLD
