#!/usr/bin/env python3
"""Draft-translate Gettext PO catalogs with Argos Translate.

Thin CLI over the `i18n` package: this file resolves arguments and touches
files, everything else lives in importable, testable modules. Install the
engine in a temporary venv when needed:

    python -m pip install argostranslate polib opencc-python-reimplemented
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from i18n import catalogs, glossary, locales, numerals  # noqa: E402
from i18n.pipeline import DEFAULT_BATCH_CHARS, DEFAULT_BATCH_SIZE, Pipeline  # noqa: E402
from i18n.protection import has_sentinel_residue  # noqa: E402
from i18n.translator import TraditionalChinesePostprocessor, build, build_back  # noqa: E402

DEFAULT_CACHE = "/tmp/retro_hex_chat_i18n_translation_cache.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--locales",
        default=",".join(locales.codes()),
        help="Comma-separated locale codes (default: every enabled locale)",
    )
    parser.add_argument("--cache", default=DEFAULT_CACHE, help="Translation cache JSON path")
    parser.add_argument(
        "--overwrite", action="store_true", help="Overwrite existing non-source translations"
    )
    parser.add_argument(
        "--repair-fallbacks",
        action="store_true",
        help=(
            "Also retranslate entries whose msgstr is still the English source. "
            "Off by default: those are pre-existing debt, and sweeping them into "
            "an unrelated run buries the change under thousands of edits."
        ),
    )
    parser.add_argument(
        "--repair-plurals",
        action="store_true",
        help=(
            "Retranslate plural entries whose forms are mechanically wrong (count "
            "moved after the noun, three-form slots collapsed), and keep a result "
            "only if it fixes a defect. See i18n.numerals.plural_defects."
        ),
    )
    parser.add_argument(
        "--msgid",
        action="append",
        default=[],
        help=(
            "Retranslate this msgid even though it is already translated (repeatable). "
            "How a known-bad entry is fixed through the tool instead of by hand."
        ),
    )
    parser.add_argument("--batch-size", type=int, default=DEFAULT_BATCH_SIZE)
    parser.add_argument("--batch-chars", type=int, default=DEFAULT_BATCH_CHARS)
    parser.add_argument("paths", nargs="*", help="Optional PO glob paths")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    selected = [code.strip() for code in args.locales.split(",") if code.strip()]
    known = {locale.code: locale for locale in locales.enabled_locales()}
    unknown = [code for code in selected if code not in known]

    if unknown:
        raise SystemExit(f"Not an enabled locale: {', '.join(unknown)}")

    cache_path = Path(args.cache)
    cache = load_cache(cache_path)
    rewritten = 0
    total_entries = 0

    for code in selected:
        locale = known[code]
        pipeline = build_pipeline(code, args)

        for path in resolve_paths(args.paths, code):
            entries = translate_file(
                path,
                locale,
                pipeline,
                cache,
                args.overwrite,
                args.repair_fallbacks,
                frozenset(args.msgid),
                args.repair_plurals,
            )
            total_entries += entries

            if entries:
                rewritten += 1
                print(f"{path}: {entries} entries")

        save_cache(cache_path, cache)
        report(code, pipeline)

    save_cache(cache_path, cache)
    print(f"rewritten={rewritten} translated_entries={total_entries}")
    return 0


def build_pipeline(code: str, args: argparse.Namespace) -> Pipeline:
    translator = build(code, locales.argos_code(code))
    postprocess = None

    if code == "zh_hant":
        postprocess = TraditionalChinesePostprocessor(translator).convert

    answers = {word: glossary.for_locale(code)[word] for word in ("Yes", "No")} if code != "en" else {}

    return Pipeline(
        translator,
        postprocess=postprocess,
        batch_size=args.batch_size,
        batch_chars=args.batch_chars,
        locale_code=code,
        back_translator=build_back(code, locales.argos_code(code)),
        answers=answers,
        full_stop="。" if code in ("ja", "zh_hans", "zh_hant") else ".",
    )


def resolve_paths(paths: list[str], code: str) -> list[Path]:
    if not paths:
        return catalogs.po_files(code)

    found: list[Path] = []

    for pattern in paths:
        found.extend(Path(".").glob(pattern))

    return sorted(path for path in found if catalogs.locale_of(path) == code)


def translate_file(
    path: Path,
    locale,
    pipeline: Pipeline,
    cache: dict,
    overwrite: bool,
    fallbacks: bool,
    forced: frozenset = frozenset(),
    repair_plurals: bool = False,
) -> int:
    po = catalogs.load_po(path)

    if locale.code == "en":
        return fill_source_locale(po, Path(path))

    pending = collect_pending(po, locale, cache, overwrite, fallbacks, forced, repair_plurals)

    if pending:
        for source, translated in pipeline.translate_many(pending).items():
            cache[cache_key(locale.code, source)] = translated

    changed = 0

    for entry in catalogs.translatable_entries(po):
        # A repair run repairs and does nothing else: an unrelated empty entry
        # in a domain mid-merge is not this run's to fill.
        if repair_plurals:
            if needs_plural_repair(entry, locale):
                changed += repair_plural(entry, locale, cache)

            continue

        if entry.msgid_plural:
            for index, source in catalogs.plural_sources(entry, locale.one_form).items():
                if not needs_translation(
                    entry.msgstr_plural.get(index, ""), source, entry, overwrite, fallbacks, forced
                ):
                    continue

                entry.msgstr_plural[index] = plural_lookup(cache, locale, index, source)
                changed += 1
                clear_fuzzy(entry)
        elif needs_translation(entry.msgstr, entry.msgid, entry, overwrite, fallbacks, forced):
            entry.msgstr = lookup(cache, locale.code, entry.msgid)
            changed += 1
            clear_fuzzy(entry)

    if changed:
        catalogs.save_po(po, Path(path))

    return changed


def fill_source_locale(po, path: Path) -> int:
    """Sets every `en` entry to its own source, byte for byte.

    The source locale is its msgids, nothing else. A msgstr that differs is a
    guess the merge copied from another entry ("%{count} commands" arrived as
    "%{count} games"), and the pipeline is no way to copy a string: it trims
    the spaces a fragment is joined by.
    """
    changed = 0

    for entry in catalogs.translatable_entries(po):
        if entry.msgid_plural:
            wanted = {
                index: entry.msgid if index == 0 else entry.msgid_plural
                for index in (sorted(entry.msgstr_plural) or [0, 1])
            }

            if entry.msgstr_plural != wanted:
                entry.msgstr_plural = wanted
                changed += 1
        elif entry.msgstr != entry.msgid:
            entry.msgstr = entry.msgid
            changed += 1

        if "fuzzy" in entry.flags:
            clear_fuzzy(entry)
            changed += 1

    if changed:
        catalogs.save_po(po, path)

    return changed


def collect_pending(
    po,
    locale,
    cache: dict,
    overwrite: bool,
    fallbacks: bool,
    forced: frozenset = frozenset(),
    repair_plurals: bool = False,
) -> list[str]:
    pending: list[str] = []
    # A forced plural is sent as its numeral and plural strings, not its msgid,
    # so the strings it sends are forced too.
    forced_sources: set[str] = set()

    for entry in catalogs.translatable_entries(po):
        before = len(pending)

        if repair_plurals:
            if needs_plural_repair(entry, locale):
                for index, source in catalogs.plural_sources(entry, locale.one_form).items():
                    numeral = plural_numeral(locale, index, source)
                    pending.extend([numeral[0], source] if numeral else [source])

            continue

        if entry.msgid_plural:
            for index, source in catalogs.plural_sources(entry, locale.one_form).items():
                if needs_translation(
                    entry.msgstr_plural.get(index, ""), source, entry, overwrite, fallbacks, forced
                ):
                    numeral = plural_numeral(locale, index, source)

                    if numeral:
                        pending.append(numeral[0])

                    # The masked source too: it is what the slot falls back to
                    # when the number does not come back exactly once.
                    pending.append(source)
        elif needs_translation(entry.msgstr, entry.msgid, entry, overwrite, fallbacks, forced):
            pending.append(entry.msgid)

        if entry.msgid in forced:
            forced_sources.update(pending[before:])

    missing = [
        source
        for source in pending
        if must_translate(cache, locale.code, source, overwrite, forced | forced_sources)
    ]
    return list(dict.fromkeys(missing))


def must_translate(
    cache: dict, code: str, source: str, overwrite: bool, forced: frozenset = frozenset()
) -> bool:
    """Whether a pending source goes to the engine rather than to the cache.

    A forced msgid always goes: `--msgid` exists to replace a known-bad entry,
    and answering it from the cache hands back the very value being replaced.
    """
    return overwrite or source in forced or not cached_usable(cache, code, source)


def needs_translation(
    current: str,
    source: str,
    entry,
    overwrite: bool,
    fallbacks: bool,
    forced: frozenset = frozenset(),
) -> bool:
    """Whether this entry is one of the ones this run is meant to touch.

    An entry that is empty or fuzzy is new: the merge just created it and
    nothing has ever translated it. An entry whose msgstr still reads as the
    English source is *old* debt — it may have been left that way on purpose,
    because a bad translation is worse than English.

    Those two are separate jobs, and conflating them is what made every run
    rewrite thousands of unrelated entries: translating 96 new strings dragged
    16.000 English fallbacks along, and each one had to be reverted by hand
    afterwards to keep the diff honest. Repairing fallbacks is now opt-in.
    """
    if overwrite or is_fuzzy(entry) or current == "" or entry.msgid in forced:
        return True

    return fallbacks and current in {source, entry.msgid, entry.msgid_plural}


def cache_key(code: str, source: str) -> str:
    return f"{code}\0{source}"


def cached_usable(cache: dict, code: str, source: str) -> bool:
    """A cached value that is a translation, not a recorded failure.

    A source the engine could not translate is cached as itself; reusing that
    is how a string skipped once stays English in every later run, even after
    the reason it was skipped is gone.
    """
    value = cache.get(cache_key(code, source))
    return value is not None and value != source and not has_sentinel_residue(value)


def lookup(cache: dict, code: str, source: str) -> str:
    return cache.get(cache_key(code, source), source)


def plural_numeral(locale, index: int, source: str) -> tuple[str, int] | None:
    """The slot's source written with an example count, when it has `%{count}`.

    See `i18n.numerals`: a masked placeholder gives the model no number to
    agree with, so each plural form is translated as the sentence it renders.
    """
    if not locale.plural_forms:
        return None

    number = numerals.sample_number(locale.plural_forms, index)
    numeral = numerals.as_numeral(source, number)
    return (numeral, number) if numeral else None


def plural_forms_of(entry) -> list[str]:
    return [entry.msgstr_plural.get(index, "") for index in sorted(entry.msgstr_plural)]


def needs_plural_repair(entry, locale) -> bool:
    if not entry.msgid_plural or not numerals.repairable(entry.msgid) or not locale.plural_forms:
        return False

    nplurals, _rule = numerals.parse_plural_forms(locale.plural_forms)
    return bool(numerals.plural_defects(plural_forms_of(entry), entry.msgid, nplurals))


def repair_plural(entry, locale, cache: dict) -> int:
    """Replace a defective plural entry's forms, if the retranslation is better."""
    nplurals, _rule = numerals.parse_plural_forms(locale.plural_forms)
    old = plural_forms_of(entry)
    new = [
        plural_lookup(cache, locale, index, source)
        for index, source in catalogs.plural_sources(entry, locale.one_form).items()
    ]

    if not numerals.repair_wins(old, new, entry.msgid, nplurals, entry.msgid_plural):
        return 0

    for index, form in enumerate(new):
        entry.msgstr_plural[index] = form

    clear_fuzzy(entry)
    return len(new)


def plural_lookup(cache: dict, locale, index: int, source: str) -> str:
    numeral = plural_numeral(locale, index, source)

    if numeral:
        text, number = numeral
        translated = cache.get(cache_key(locale.code, text))
        # The pipeline keeps the source when a model fails it, and "5 hours"
        # restores as cleanly as a translation would. In any locale but
        # English that is a miss, not a result.
        if translated == text and locale.code != "en":
            translated = None

        restored = numerals.from_numeral(translated, number) if translated else None

        if restored:
            return restored

    return lookup(cache, locale.code, source)


def is_fuzzy(entry) -> bool:
    return "fuzzy" in entry.flags


def clear_fuzzy(entry) -> None:
    if "fuzzy" in entry.flags:
        entry.flags.remove("fuzzy")


def report(code: str, pipeline: Pipeline) -> None:
    stats = pipeline.stats
    print(
        f"{code}: translated={stats.translated} skipped={stats.skipped} "
        f"rejected={stats.rejected} retried={stats.retried} fell_back={stats.fell_back}"
    )

    if stats.fell_back:
        print(f"  {stats.fell_back} strings kept the English source; review them:")

        for source in stats.reasons[:10]:
            print(f"    - {source[:90]}")


def load_cache(path: Path) -> dict:
    if not path.exists():
        return {}

    return json.loads(path.read_text(encoding="utf-8"))


def save_cache(path: Path, cache: dict) -> None:
    path.write_text(
        json.dumps(cache, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8"
    )


if __name__ == "__main__":
    sys.exit(main())
