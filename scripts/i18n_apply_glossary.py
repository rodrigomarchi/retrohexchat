#!/usr/bin/env python3
"""Apply the curated UI label glossary to the Gettext catalogs.

Only exact msgid matches are touched, and only where the catalog disagrees with
the glossary. Run from the repo root:

    python3 scripts/i18n_apply_glossary.py --write
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from i18n import catalogs, glossary, locales  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--locales", default=",".join(locales.codes()))
    parser.add_argument("--write", action="store_true", help="Apply changes (default: dry run)")
    parser.add_argument("--show", type=int, default=6, help="Examples to print per locale")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    selected = [code.strip() for code in args.locales.split(",") if code.strip()]
    known = {locale.code for locale in locales.translatable_locales()}
    total = 0

    for code in selected:
        if code not in known:
            raise SystemExit(f"Not an enabled locale: {code}")

        total += apply_locale(code, args)

    print(f"{'changed' if args.write else 'would change'}={total}")
    return 0


def apply_locale(code: str, args: argparse.Namespace) -> int:
    curated = glossary.for_locale(code)
    changed = 0
    examples: list[tuple[str, str, str]] = []

    for path in catalogs.po_files(code):
        po = catalogs.load_po(path)
        touched = False

        for entry in catalogs.translatable_entries(po):
            wanted = curated.get(entry.msgid.strip())

            if wanted is None:
                continue

            # Plural entries carry a different source per slot; the glossary
            # only speaks for singular labels.
            if entry.msgid_plural:
                continue

            if entry.msgstr == wanted:
                continue

            if len(examples) < args.show:
                examples.append((entry.msgid, entry.msgstr, wanted))

            entry.msgstr = wanted
            entry.flags = [flag for flag in entry.flags if flag != "fuzzy"]
            touched = True
            changed += 1

        if touched and args.write:
            po.save(str(path))

    if changed:
        print(f"{code}: {changed} changed")

        for source, before, after in examples:
            print(f"    {source!r}: {before!r} -> {after!r}")

    return changed


if __name__ == "__main__":
    sys.exit(main())
