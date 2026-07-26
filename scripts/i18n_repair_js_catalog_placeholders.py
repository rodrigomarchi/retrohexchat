#!/usr/bin/env python3
"""Replace unsafe browser catalog entries that lost interpolation placeholders."""

from __future__ import annotations

import re

from i18n_js_catalogs import LOCALE_EXPORTS, read_catalogs, write_catalogs

PLACEHOLDER_RE = re.compile(r"%\{[A-Za-z0-9_]+\}")
TOKEN_RE = re.compile(r"XPH\d+X", re.IGNORECASE)


def main() -> int:
    catalogs = read_catalogs()
    repaired = 0
    repaired_locales = []

    for export_name, catalog in catalogs.items():
        for source, translated in list(catalog.items()):
            if unsafe(source, translated):
                catalog[source] = source
                repaired += 1
                repaired_locales.append(export_name)

    if repaired:
        export_to_locale = {export: locale for locale, export in LOCALE_EXPORTS.items()}
        write_catalogs(catalogs, locales=[export_to_locale[export] for export in set(repaired_locales)])

    print(f"catalogs={len(catalogs)} repaired_entries={repaired}")
    return 0


def unsafe(source: str, translated: str) -> bool:
    return placeholders(source) != placeholders(translated) or TOKEN_RE.search(translated) is not None


def placeholders(value: str) -> set[str]:
    return set(PLACEHOLDER_RE.findall(value or ""))


if __name__ == "__main__":
    raise SystemExit(main())
