"""Translating and reviewing catalogs with Claude.

This sits beside Argos, not instead of it: Argos is free, offline and the
default for filling new strings; Claude reads a sentence the way a person does,
and is the engine that can review what is already in a catalog. Each caller
chooses (`--engine`, `make i18n.claude.review`).

The module holds prompts, the shape of a review and its checks, and no I/O and
no SDK: requests are plain dicts, so the whole flow runs in tests without a key.
A reviewed string goes through the same guards as anything an engine writes,
and the glossary stays the authority on labels.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field

from . import glossary, names, numerals
from .pipeline import wrong_words
from .protection import protect, restore, should_machine_translate
from .quality import is_usable_translation, keep_lowercase_start
from .terms import TERMS, _forms, brazilian_forms, italian_accents

MODEL = "claude-sonnet-5-5"
MAX_TOKENS = 16000
EFFORT = "medium"
CHUNK_ITEMS = 30
CHUNK_CHARS = 6000

# Dollars per million tokens, on the Batches API's half price.
BATCH_INPUT_PRICE = 1.00
BATCH_OUTPUT_PRICE = 5.00

LANGUAGES = {
    "pt_BR": "Brazilian Portuguese (você; registro, apelido, Central do canal)",
    "pt_PT": "European Portuguese (pre-1990 forms are wrong; registo, alcunha, tu or impersonal)",
    "es": "Spanish (neutral international, tú)",
    "fr": "French (vous)",
    "de": "German (du)",
    "it": "Italian (tu)",
    "nl": "Dutch (je)",
    "pl": "Polish (ty)",
    "ru": "Russian (вы)",
    "id": "Indonesian (Anda)",
    "ja": "Japanese (polite です・ます, natural UI wording)",
    "zh_hans": "Simplified Chinese (你)",
    "zh_hant": "Traditional Chinese, Taiwan usage (你)",
}

PRODUCT = """RetroHexChat is a free, Windows-98-looking web chat in the spirit of mIRC: \
channels, operators, modes, NickServ and ChanServ, bots, private messages, P2P calls, \
retro browser games and virtual spaces, on one desktop of windows."""

KEEP = """Keep exactly: every placeholder such as %{count}, HTML tags and attributes, \
/commands and their arguments, mode letters such as +i, IRC service names, file names, \
key names, and the product and game names unless a form is given below. Keep the \
source's line breaks, its leading and trailing spaces, and whether it ends in a full stop. \
Every string in an item's keep_verbatim must appear in the result byte for byte. A chat "room" is a chat room and a "channel" is a chat channel; a "flood" is message or \
join spam, never water."""


def language(locale_code: str) -> str:
    return LANGUAGES[locale_code]


def review_system(locale_code: str) -> str:
    return f"""You are the senior localizer of this product. {PRODUCT}

You review its {language(locale_code)} interface and help, most of it machine translated. \
Every item has the English source, where it appears, and the current translation.

Change an item only if the current text is wrong, unnatural, unidiomatic for a native \
speaker of a chat application, or says something other than the source. A correct text \
stays as it is, even if you would have phrased it differently: do not polish. Short \
labels are interface labels (menus, buttons, window titles), so "Account" is the user's \
account, "Legal" a link to legal pages, "Loading..." a progress state.

{KEEP}

Plural items have several forms, one per plural slot of the language, in slot order.

Return only the items you changed, each with its id and all of its forms."""


def translate_system(locale_code: str) -> str:
    return f"""You translate the interface and help of this product into \
{language(locale_code)}. {PRODUCT}

Tokens such as XPH0X are protected fragments: keep each one, exactly once. The token \
XSEGX separates strings: keep every separator and translate each string on its own, in \
order. {KEEP}

Answer with the translation only."""


@dataclass
class Item:
    """One distinct string of a locale, wherever its catalogs repeat it."""

    msgid: str
    msgctxt: str | None
    plural: str
    forms: list[str]
    where: str = ""
    domain: str = ""

    @property
    def key(self) -> str:
        return glossary.key(self.msgid, self.msgctxt) + ("\x00" + self.plural if self.plural else "")


@dataclass
class Verdict:
    accepted: dict[str, list[str]] = field(default_factory=dict)
    rejected: list[dict] = field(default_factory=list)


def reviewable(msgid: str, msgctxt: str | None, locale_code: str) -> bool:
    """Whether a review may touch this string: the glossary owns its labels."""
    if glossary.key(msgid, msgctxt) in glossary.for_locale(locale_code):
        return False

    return should_machine_translate(msgid)


def chunks(items: list[Item], size: int = CHUNK_ITEMS, max_chars: int = CHUNK_CHARS) -> list[list[Item]]:
    """Groups in catalog order, so neighbouring strings give each other context."""
    groups: list[list[Item]] = []
    group: list[Item] = []
    chars = 0

    for item in items:
        length = len(item.msgid) + sum(len(form) for form in item.forms)

        if group and (len(group) >= size or chars + length > max_chars):
            groups.append(group)
            group, chars = [], 0

        group.append(item)
        chars += length

    if group:
        groups.append(group)

    return groups


def vocabulary(items: list[Item], locale_code: str) -> dict:
    """The words these items must use: only what they mention, to keep requests small."""
    text = "\n".join(item.msgid + "\n" + item.plural for item in items)
    lowered = text.lower()
    labels = {
        glossary.source_of(term): value
        for term, value in glossary.for_locale(locale_code).items()
        if len(glossary.source_of(term)) > 2 and glossary.source_of(term).lower() in lowered
    }
    masked = protect(text)[0]
    required = sorted(
        {
            "/".join(accepted)
            for pattern, forms in TERMS
            if (accepted := _forms(forms, locale_code)) and pattern.search(masked)
        }
    )
    return {"labels": labels, "required_words": required}


REVIEW_SCHEMA = {
    "type": "object",
    "properties": {
        "changes": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "id": {"type": "integer"},
                    "forms": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["id", "forms"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["changes"],
    "additionalProperties": False,
}


def verbatim(item: Item) -> list[str]:
    """What the guards will demand back, whole: one fragment can hold another's sentinel."""
    replacements = protect(item.msgid + "\n" + item.plural)[1]
    return sorted({restore(value, replacements) for value in replacements.values()})


def review_request(items: list[Item], locale_code: str) -> dict:
    payload = [
        {
            "id": index,
            "en": item.msgid,
            **({"en_plural": item.plural} if item.plural else {}),
            "where": f"{item.domain} {item.where}".strip(),
            "current": item.forms,
            **({"keep_verbatim": kept} if (kept := verbatim(item)) else {}),
        }
        for index, item in enumerate(items)
    ]
    vocabulary_note = json.dumps(vocabulary(items, locale_code), ensure_ascii=False)
    content = (
        f"Terminology to use where it applies: {vocabulary_note}\n\n"
        f"Items:\n{json.dumps(payload, ensure_ascii=False)}"
    )
    return {
        "model": MODEL,
        "max_tokens": MAX_TOKENS,
        "thinking": {"type": "between_tools"},
        "output_config": {
            "effort": EFFORT,
            "format": {"type": "json_schema", "schema": REVIEW_SCHEMA},
        },
        "system": review_system(locale_code),
        "messages": [{"role": "user", "content": content}],
    }


def parse_changes(text: str) -> dict[int, list[str]]:
    return {change["id"]: change["forms"] for change in json.loads(text)["changes"]}


def finish(form: str, locale_code: str) -> str:
    """What every engine's output gets before a check reads it."""
    form = names.localize(form, locale_code)

    if locale_code == "it":
        return italian_accents(form)

    return brazilian_forms(form) if locale_code == "pt_BR" else form


def judge(item: Item, forms: list[str], locale_code: str, one_form: bool, nplurals: int) -> tuple[list[str], str | None]:
    """The forms ready to write, and why they are refused if they are."""
    if len(forms) != len(item.forms):
        return [], f"{len(forms)} forms for {len(item.forms)} slots"

    finished = []

    for slot, form in enumerate(forms):
        source = item.plural if item.plural and (one_form or slot > 0) else item.msgid
        replacements = protect(source)[1]
        form = keep_lowercase_start(source, finish(form, locale_code), locale_code)

        if form == source:
            return [], f"the English source: {form[:80]}"

        if not is_usable_translation(source, form, replacements):
            return [], f"unusable: {form[:80]}"

        if wrong_words(source, form, locale_code):
            return [], f"wrong words: {form[:80]}"

        finished.append(form)

    if item.plural and numerals.plural_defects(finished, item.msgid, nplurals) - numerals.plural_defects(
        item.forms, item.msgid, nplurals
    ):
        return [], "a plural defect the current forms do not have"

    return finished, None


def cost(usage: dict) -> float:
    """Dollars for this usage on the Batches API."""
    return (
        usage.get("input_tokens", 0) * BATCH_INPUT_PRICE + usage.get("output_tokens", 0) * BATCH_OUTPUT_PRICE
    ) / 1_000_000
