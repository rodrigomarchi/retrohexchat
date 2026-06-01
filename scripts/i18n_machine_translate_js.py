#!/usr/bin/env python3
"""Draft-translate the small browser-side i18n catalog with Argos Translate."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from i18n_js_catalogs import (
    CATALOG_BARREL,
    CATALOG_DIR,
    LOCALE_EXPORTS,
    read_catalogs,
    write_catalogs,
)
from i18n_machine_translate_po import LOCALE_TO_ARGOS, load_cache, save_cache, translate_text, translator_for


CONST_NAMES = dict(LOCALE_EXPORTS)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--locales", required=True)
    parser.add_argument(
        "--cache",
        default="/tmp/retro_hex_chat_i18n_translation_cache.json",
        help="Translation cache JSON path",
    )
    parser.add_argument(
        "--catalog",
        default=str(CATALOG_BARREL),
        help="Legacy catalog/barrel path",
    )
    parser.add_argument(
        "--catalog-dir",
        default=str(CATALOG_DIR),
        help="Directory containing one browser catalog file per locale",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    catalog = Path(args.catalog)
    catalog_dir = Path(args.catalog_dir)
    locales = [locale.strip() for locale in args.locales.split(",") if locale.strip()]
    unsupported = [locale for locale in locales if locale not in LOCALE_TO_ARGOS]
    if unsupported:
        raise SystemExit(f"Unsupported Argos locales: {', '.join(unsupported)}")

    catalogs = read_catalogs(catalog_dir, catalog)
    pt_br = catalogs.get("PT_BR", {})
    messages = list(pt_br.keys())
    cache_path = Path(args.cache)
    cache = load_cache(cache_path)

    for locale in locales:
        translator = translator_for(LOCALE_TO_ARGOS[locale])
        catalogs[CONST_NAMES[locale]] = {
            message: translate_text(message, locale, translator, cache) for message in messages
        }

    save_cache(cache_path, cache)
    write_catalogs(catalogs, catalog_dir, catalog)
    print(f"{catalog_dir}: locales={','.join(catalogs.keys())} messages={len(messages)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
