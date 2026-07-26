#!/usr/bin/env python3
"""Repair catalog entries that fail the quality guards.

Two strategies, applied in order:

  strip     an injected heading is dropped, keeping the translation beneath it
            (cheap, deterministic, and the text under it is usually fine)
  retranslate  anything still failing is put back through the fixed pipeline

Run from the repo root. Requires the translation venv for --retranslate:

    python3 scripts/i18n_repair_catalogs.py --locales ja --write
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from i18n import catalogs, locales  # noqa: E402
from i18n.pipeline import Pipeline  # noqa: E402
from i18n.protection import has_sentinel_residue  # noqa: E402
from i18n.quality import (  # noqa: E402
    COLLAPSE_THRESHOLD,
    find_collapses,
    find_shared_headings,
    introduced_degeneration,
)
from i18n.translator import TraditionalChinesePostprocessor, build  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--locales", default=",".join(locales.codes()))
    parser.add_argument("--write", action="store_true", help="Apply changes (default: dry run)")
    parser.add_argument("--collapse-threshold", type=int, default=COLLAPSE_THRESHOLD)
    parser.add_argument(
        "--no-retranslate",
        action="store_true",
        help="Only strip injected headings; never call the translation engine",
    )
    return parser.parse_args()


def slots(entry):
    """Yield (getter, setter, source, current) for every translatable slot."""
    if entry.msgid_plural:
        for index in list(entry.msgstr_plural):
            yield (
                index,
                entry.msgstr_plural.get(index, ""),
                entry.msgid if index == 0 else entry.msgid_plural,
            )
    else:
        yield (None, entry.msgstr, entry.msgid)


def set_slot(entry, index, value: str) -> None:
    if index is None:
        entry.msgstr = value
    else:
        entry.msgstr_plural[index] = value


def main() -> int:
    args = parse_args()
    selected = [code.strip() for code in args.locales.split(",") if code.strip()]
    known = {locale.code: locale for locale in locales.translatable_locales()}

    for code in selected:
        if code not in known:
            raise SystemExit(f"Not an enabled locale: {code}")

        repair_locale(known[code], args)

    return 0


def repair_locale(locale, args: argparse.Namespace) -> None:
    files = {path: catalogs.load_po(path) for path in catalogs.po_files(locale.code)}
    stripped = strip_injected_headings(files, args.collapse_threshold)

    # Collapse is judged after stripping: an injected heading makes distinct
    # translations look distinct, and removing it can reveal that what sat
    # beneath was collapsed all along.
    broken = collect_broken(files, args.collapse_threshold)
    print(f"{locale.code}: stripped={stripped} still_broken={len(broken)}")

    if broken and not args.no_retranslate:
        retranslate(locale, broken)

    if args.write:
        for path, po in files.items():
            po.save(str(path))


def strip_injected_headings(files: dict, threshold: int) -> int:
    pairs = [pair for po in files.values() for pair in catalogs.entry_pairs(po)]
    headings = set(find_shared_headings(pairs, threshold))

    if not headings:
        return 0

    stripped = 0

    for po in files.values():
        for entry in catalogs.translatable_entries(po):
            for index, current, _source in slots(entry):
                if not current or "\n" not in current:
                    continue

                if current.split("\n", 1)[0].strip() not in headings:
                    continue

                remainder = current.split("\n", 1)[1].strip()

                if remainder:
                    set_slot(entry, index, remainder)
                    stripped += 1

    return stripped


def collect_broken(files: dict, threshold: int) -> list:
    pairs = [pair for po in files.values() for pair in catalogs.entry_pairs(po)]
    collapsed = set(find_collapses(pairs, threshold))
    broken = []

    for path, po in files.items():
        for entry in catalogs.translatable_entries(po):
            for index, current, source in slots(entry):
                if not current:
                    continue

                if (
                    has_sentinel_residue(current)
                    or introduced_degeneration(source, current)
                    or current.strip() in collapsed
                ):
                    broken.append((path, entry, index, source))

    return broken


def retranslate(locale, broken: list) -> None:
    translator = build(locale.code, locales.argos_code(locale.code))
    postprocess = (
        TraditionalChinesePostprocessor(translator).convert if locale.code == "zh_hant" else None
    )
    pipeline = Pipeline(translator, postprocess=postprocess)

    sources = list(dict.fromkeys(source for _path, _entry, _index, source in broken))
    fresh = pipeline.translate_many(sources)

    # A second pass of the same model reproduces the same collapse: these are
    # strings the language pair cannot handle (IRC syntax like "+nt", short
    # labels). Keeping the source beats shipping a confidently wrong word.
    still_collapsed = set(find_collapses(list(fresh.items())))
    kept_source = []

    for _path, entry, index, source in broken:
        value = fresh.get(source, source)

        if value.strip() in still_collapsed:
            value = source
            kept_source.append(source)

        set_slot(entry, index, value)

    stats = pipeline.stats
    print(
        f"  retranslated={stats.translated} retried={stats.retried} "
        f"fell_back={stats.fell_back} skipped={stats.skipped} "
        f"kept_source={len(kept_source)}"
    )

    if kept_source:
        print("    curate these by hand if they matter (scripts/i18n_apply_translation_overrides.py):")

        for source in sorted(set(kept_source))[:8]:
            print(f"      - {source[:60]!r}")


if __name__ == "__main__":
    sys.exit(main())
