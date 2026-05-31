#!/usr/bin/env python3
"""Replace unsafe translations that lost Gettext placeholders with source text."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import polib


PLACEHOLDER_RE = re.compile(r"%\{[A-Za-z0-9_]+\}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="*", help="Optional PO globs")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    files = po_files(args.paths)
    rewritten = 0
    repaired = 0

    for path in files:
        po = polib.pofile(str(path))
        changed = False

        for entry in po:
            if entry.obsolete or not entry.msgid:
                continue

            if entry.msgid_plural:
                changed_entry = repair_plural(entry)
            else:
                changed_entry = repair_singular(entry)

            changed = changed or changed_entry
            repaired += int(changed_entry)

        if changed:
            po.save(str(path))
            rewritten += 1

    print(f"files={len(files)} rewritten={rewritten} repaired_entries={repaired}")
    return 0


def po_files(paths: list[str]) -> list[Path]:
    if paths:
        files: list[Path] = []
        for pattern in paths:
            files.extend(Path(".").glob(pattern))
        return sorted(files)

    return sorted(Path(".").glob("apps/*/priv/gettext/*/LC_MESSAGES/*.po"))


def repair_singular(entry) -> bool:
    expected = placeholders(entry.msgid)

    if placeholders(entry.msgstr) == expected:
        return False

    entry.msgstr = entry.msgid
    return True


def repair_plural(entry) -> bool:
    changed = False
    plural_form_count = len(entry.msgstr_plural)

    for index in sorted(entry.msgstr_plural.keys()):
        source = entry.msgid_plural if plural_form_count == 1 or index > 0 else entry.msgid
        expected = placeholders(source)

        if placeholders(entry.msgstr_plural[index]) != expected:
            entry.msgstr_plural[index] = source
            changed = True

    return changed


def placeholders(value: str) -> set[str]:
    return set(PLACEHOLDER_RE.findall(value or ""))


if __name__ == "__main__":
    raise SystemExit(main())
