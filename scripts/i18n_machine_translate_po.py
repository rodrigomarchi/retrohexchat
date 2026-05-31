#!/usr/bin/env python3
"""Draft-translate Gettext PO catalogs with Argos Translate.

This script is intentionally optional: it uses the established PO/Gettext file
format and an offline translation engine, then leaves quality gates to the
Elixir validation scripts. Install dependencies in a temporary venv when needed:

    python -m pip install argostranslate polib
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import polib
from argostranslate import translate


LOCALE_TO_ARGOS = {
    "es": "es",
    "fr": "fr",
    "de": "de",
    "ja": "ja",
    "zh_Hans": "zh",
    "id": "id",
}

ONE_FORM_LOCALES = {"id", "ja", "zh_Hans", "ko", "vi", "zh_Hant"}
PROTECTED_PATTERNS = [
    re.compile(r"%\{[A-Za-z0-9_]+\}"),
    re.compile(r"https?://[^\s<>\"]+"),
    re.compile(r"`[^`]+`"),
    re.compile(r"</?[^>]+>"),
    re.compile(r"/[A-Za-z][A-Za-z0-9_-]*"),
    re.compile(r"#[A-Za-z0-9_-]+"),
]
WORD_RE = re.compile(r"[A-Za-z][A-Za-z']+")
BATCH_SEPARATOR = "ZXQI18NSEPZXQ"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--locales", required=True, help="Comma-separated locale codes")
    parser.add_argument(
        "--cache",
        default="/tmp/retro_hex_chat_i18n_translation_cache.json",
        help="Translation cache JSON path",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing non-source translations",
    )
    parser.add_argument("--batch-size", type=int, default=48)
    parser.add_argument("--batch-chars", type=int, default=8000)
    parser.add_argument("paths", nargs="*", help="Optional PO glob paths")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    locales = [locale.strip() for locale in args.locales.split(",") if locale.strip()]
    unsupported = [locale for locale in locales if locale not in LOCALE_TO_ARGOS]
    if unsupported:
        raise SystemExit(f"Unsupported Argos locales: {', '.join(unsupported)}")

    cache_path = Path(args.cache)
    cache = load_cache(cache_path)
    translators = {locale: translator_for(LOCALE_TO_ARGOS[locale]) for locale in locales}

    files = po_files(locales, args.paths)
    rewritten = 0
    translated_entries = 0

    for path in files:
        locale = locale_from_path(path)
        if locale not in translators:
            continue

        po = polib.pofile(str(path))
        changed = False
        sources = pending_sources(po, locale, args.overwrite)
        translate_texts(
            sources,
            locale,
            translators[locale],
            cache,
            args.batch_size,
            args.batch_chars,
        )

        for entry in po:
            if entry.obsolete or not entry.msgid:
                continue

            if entry.msgid_plural:
                changed_entry = translate_plural_entry(
                    entry, locale, translators[locale], cache, args.overwrite
                )
            else:
                changed_entry = translate_singular_entry(
                    entry, locale, translators[locale], cache, args.overwrite
                )

            if changed_entry:
                changed = True
                translated_entries += 1

            if "fuzzy" in entry.flags:
                entry.flags.remove("fuzzy")

        if changed:
            po.save(str(path))
            rewritten += 1
            print(f"{path}: translated")

        save_cache(cache_path, cache)

    save_cache(cache_path, cache)
    print(f"files={len(files)} rewritten={rewritten} translated_entries={translated_entries}")
    return 0


def po_files(locales: list[str], paths: list[str]) -> list[Path]:
    if paths:
        files: list[Path] = []
        for pattern in paths:
            files.extend(Path(".").glob(pattern))
        return sorted(files)

    files = []
    for locale in locales:
        files.extend(Path(".").glob(f"apps/*/priv/gettext/{locale}/LC_MESSAGES/*.po"))
    return sorted(files)


def locale_from_path(path: Path) -> str:
    parts = path.parts
    return parts[parts.index("gettext") + 1]


def translator_for(to_code: str):
    installed_languages = translate.get_installed_languages()
    from_language = next(language for language in installed_languages if language.code == "en")
    to_language = next(language for language in installed_languages if language.code == to_code)
    return from_language.get_translation(to_language)


def translate_singular_entry(entry, locale: str, translator, cache: dict, overwrite: bool) -> bool:
    if not should_translate(entry.msgstr, entry.msgid, overwrite):
        return False

    entry.msgstr = translate_text(entry.msgid, locale, translator, cache)
    return True


def translate_plural_entry(entry, locale: str, translator, cache: dict, overwrite: bool) -> bool:
    changed = False
    source_by_index = plural_sources(entry, locale)

    for index, source in source_by_index.items():
        current = entry.msgstr_plural.get(index, "")

        if should_translate(current, source, overwrite, fallback_sources={entry.msgid, entry.msgid_plural}):
            entry.msgstr_plural[index] = translate_text(source, locale, translator, cache)
            changed = True

    return changed


def pending_sources(po, locale: str, overwrite: bool) -> list[str]:
    sources: list[str] = []

    for entry in po:
        if entry.obsolete or not entry.msgid:
            continue

        if entry.msgid_plural:
            source_by_index = plural_sources(entry, locale)

            for index, source in source_by_index.items():
                current = entry.msgstr_plural.get(index, "")

                if should_translate(
                    current,
                    source,
                    overwrite,
                    fallback_sources={entry.msgid, entry.msgid_plural},
                ):
                    sources.append(source)
        elif should_translate(entry.msgstr, entry.msgid, overwrite):
            sources.append(entry.msgid)

    return list(dict.fromkeys(sources))


def plural_sources(entry, locale: str) -> dict[int, str]:
    if locale in ONE_FORM_LOCALES:
        return {0: entry.msgid_plural}

    return {
        index: entry.msgid if index == 0 else entry.msgid_plural
        for index in sorted(entry.msgstr_plural.keys())
    }


def should_translate(
    current: str,
    source: str,
    overwrite: bool,
    fallback_sources: set[str] | None = None,
) -> bool:
    if overwrite:
        return True

    fallback_sources = fallback_sources or {source}
    return current == "" or current in fallback_sources


def translate_text(text: str, locale: str, translator, cache: dict) -> str:
    cache_key = f"{locale}\u0000{text}"

    if cache_key in cache:
        return cache[cache_key]

    if not should_machine_translate(text):
        translated = text
    else:
        protected, replacements = protect(text)
        translated = translator.translate(protected)
        translated = restore(translated, replacements)

    cache[cache_key] = translated
    return translated


def translate_texts(
    texts: list[str],
    locale: str,
    translator,
    cache: dict,
    batch_size: int,
    batch_chars: int,
) -> None:
    missing = [text for text in texts if f"{locale}\u0000{text}" not in cache]

    if not missing:
        return

    machine_texts = []

    for text in missing:
        if should_machine_translate(text):
            machine_texts.append(text)
        else:
            cache[f"{locale}\u0000{text}"] = text

    for batch in chunks(machine_texts, max(batch_size, 1), max(batch_chars, 500)):
        protected_batch = []
        replacements_batch = []

        for text in batch:
            protected, replacements = protect(text)
            protected_batch.append(protected)
            replacements_batch.append(replacements)

        translated_batch = translator.translate(f"\n{BATCH_SEPARATOR}\n".join(protected_batch))
        parts = translated_batch.split(BATCH_SEPARATOR)

        if len(parts) != len(batch):
            parts = [translator.translate(text) for text in protected_batch]

        for source, translated, replacements in zip(batch, parts, replacements_batch):
            translated = restore(translated.strip(), replacements)
            cache[f"{locale}\u0000{source}"] = translated


def chunks(values: list[str], size: int, max_chars: int):
    batch = []
    chars = 0

    for value in values:
        value_size = len(value)

        if batch and (len(batch) >= size or chars + value_size > max_chars):
            yield batch
            batch = []
            chars = 0

        batch.append(value)
        chars += value_size

    if batch:
        yield batch


def should_machine_translate(text: str) -> bool:
    if not WORD_RE.search(text):
        return False

    stripped = text.strip()
    if stripped.startswith("/") and "\n" not in stripped:
        return False

    return True


def protect(text: str) -> tuple[str, dict[str, str]]:
    replacements: dict[str, str] = {}
    protected = text
    counter = 0

    for pattern in PROTECTED_PATTERNS:
        def replace(match: re.Match[str]) -> str:
            nonlocal counter
            token = f"XPH{counter}X"
            replacements[token] = match.group(0)
            counter += 1
            return token

        protected = pattern.sub(replace, protected)

    return protected, replacements


def restore(text: str, replacements: dict[str, str]) -> str:
    restored = text

    for token, value in replacements.items():
        restored = re.sub(re.escape(token), value, restored, flags=re.IGNORECASE)

    return restored


def load_cache(path: Path) -> dict:
    if not path.exists():
        return {}

    return json.loads(path.read_text(encoding="utf-8"))


def save_cache(path: Path, cache: dict) -> None:
    path.write_text(json.dumps(cache, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
