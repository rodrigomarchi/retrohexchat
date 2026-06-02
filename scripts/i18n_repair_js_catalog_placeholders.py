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
    repaired_locales = []

    for export_name, catalog in catalogs.items():
        for source, translated in list(catalog.items()):
            if unsafe(source, translated):
                catalog[source] = source
                repaired += 1
                repaired_locales.append(export_name)

    if repaired:
        export_to_locale = {
            "AR": "ar",
            "BN": "bn",
            "DE": "de",
            "ES": "es",
            "FR": "fr",
            "HI": "hi",
            "ID": "id",
            "IT": "it",
            "JA": "ja",
            "KO": "ko",
            "NL": "nl",
            "PL": "pl",
            "PT_BR": "pt_BR",
            "PT_PT": "pt_PT",
            "RU": "ru",
            "TR": "tr",
            "UR": "ur",
            "VI": "vi",
            "ZH_HANS": "zh_hans",
            "ZH_HANT": "zh_hant",
        }
        write_catalogs(catalogs, locales=[export_to_locale[export] for export in set(repaired_locales)])

    print(f"catalogs={len(catalogs)} repaired_entries={repaired}")
    return 0


def unsafe(source: str, translated: str) -> bool:
    return placeholders(source) != placeholders(translated) or TOKEN_RE.search(translated) is not None


def placeholders(value: str) -> set[str]:
    return set(PLACEHOLDER_RE.findall(value or ""))


if __name__ == "__main__":
    raise SystemExit(main())
