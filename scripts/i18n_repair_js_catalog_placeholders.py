#!/usr/bin/env python3
"""Replace unsafe browser catalog entries that lost interpolation placeholders."""

from __future__ import annotations

import re

from i18n_js_catalogs import read_catalogs, write_catalogs

PLACEHOLDER_RE = re.compile(r"%\{[A-Za-z0-9_]+\}")
TOKEN_RE = re.compile(r"XPH\d+X", re.IGNORECASE)


def main() -> int:
    catalogs = read_catalogs()
    repaired = 0

    for catalog in catalogs.values():
        for source, translated in list(catalog.items()):
            if unsafe(source, translated):
                catalog[source] = source
                repaired += 1

    if repaired:
        write_catalogs(catalogs)

    print(f"catalogs={len(catalogs)} repaired_entries={repaired}")
    return 0


def unsafe(source: str, translated: str) -> bool:
    return placeholders(source) != placeholders(translated) or TOKEN_RE.search(translated) is not None


def placeholders(value: str) -> set[str]:
    return set(PLACEHOLDER_RE.findall(value or ""))


if __name__ == "__main__":
    raise SystemExit(main())
