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

from i18n import catalogs, locales  # noqa: E402
from i18n.pipeline import DEFAULT_BATCH_CHARS, DEFAULT_BATCH_SIZE, Pipeline  # noqa: E402
from i18n.protection import has_sentinel_residue  # noqa: E402
from i18n.translator import TraditionalChinesePostprocessor, build  # noqa: E402

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
                path, locale, pipeline, cache, args.overwrite, args.repair_fallbacks
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

    return Pipeline(
        translator,
        postprocess=postprocess,
        batch_size=args.batch_size,
        batch_chars=args.batch_chars,
    )


def resolve_paths(paths: list[str], code: str) -> list[Path]:
    if not paths:
        return catalogs.po_files(code)

    found: list[Path] = []

    for pattern in paths:
        found.extend(Path(".").glob(pattern))

    return sorted(path for path in found if catalogs.locale_of(path) == code)


def translate_file(
    path: Path, locale, pipeline: Pipeline, cache: dict, overwrite: bool, fallbacks: bool
) -> int:
    po = catalogs.load_po(path)
    pending = collect_pending(po, locale, cache, overwrite, fallbacks)

    if pending:
        for source, translated in pipeline.translate_many(pending).items():
            cache[cache_key(locale.code, source)] = translated

    changed = 0

    for entry in catalogs.translatable_entries(po):
        if entry.msgid_plural:
            for index, source in catalogs.plural_sources(entry, locale.one_form).items():
                if not needs_translation(
                    entry.msgstr_plural.get(index, ""), source, entry, overwrite, fallbacks
                ):
                    continue

                entry.msgstr_plural[index] = lookup(cache, locale.code, source)
                changed += 1
                clear_fuzzy(entry)
        elif needs_translation(entry.msgstr, entry.msgid, entry, overwrite, fallbacks):
            entry.msgstr = lookup(cache, locale.code, entry.msgid)
            changed += 1
            clear_fuzzy(entry)

    if changed:
        po.save(str(path))

    return changed


def collect_pending(po, locale, cache: dict, overwrite: bool, fallbacks: bool) -> list[str]:
    pending: list[str] = []

    for entry in catalogs.translatable_entries(po):
        if entry.msgid_plural:
            for index, source in catalogs.plural_sources(entry, locale.one_form).items():
                if needs_translation(
                    entry.msgstr_plural.get(index, ""), source, entry, overwrite, fallbacks
                ):
                    pending.append(source)
        elif needs_translation(entry.msgstr, entry.msgid, entry, overwrite, fallbacks):
            pending.append(entry.msgid)

    missing = [
        source
        for source in pending
        if overwrite or not cached_usable(cache, locale.code, source)
    ]
    return list(dict.fromkeys(missing))


def needs_translation(current: str, source: str, entry, overwrite: bool, fallbacks: bool) -> bool:
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
    if overwrite or is_fuzzy(entry) or current == "":
        return True

    return fallbacks and current in {source, entry.msgid, entry.msgid_plural}


def cache_key(code: str, source: str) -> str:
    return f"{code}\0{source}"


def cached_usable(cache: dict, code: str, source: str) -> bool:
    value = cache.get(cache_key(code, source))
    return value is not None and not has_sentinel_residue(value)


def lookup(cache: dict, code: str, source: str) -> str:
    return cache.get(cache_key(code, source), source)


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
