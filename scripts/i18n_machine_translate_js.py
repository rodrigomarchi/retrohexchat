#!/usr/bin/env python3
"""Draft-translate the small browser-side i18n catalog with Argos Translate."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from i18n_machine_translate_po import LOCALE_TO_ARGOS, load_cache, save_cache, translate_text, translator_for


CONST_NAMES = {
    "pt_BR": "PT_BR",
    "es": "ES",
    "fr": "FR",
    "de": "DE",
    "ja": "JA",
    "zh_Hans": "ZH_HANS",
    "id": "ID",
}


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
        default="apps/retro_hex_chat_web/assets/js/lib/i18n_catalog.js",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    catalog = Path(args.catalog)
    locales = [locale.strip() for locale in args.locales.split(",") if locale.strip()]
    unsupported = [locale for locale in locales if locale not in LOCALE_TO_ARGOS]
    if unsupported:
        raise SystemExit(f"Unsupported Argos locales: {', '.join(unsupported)}")

    pt_br = read_existing_pt_br(catalog)
    messages = list(pt_br.keys())
    cache_path = Path(args.cache)
    cache = load_cache(cache_path)
    translated = {"pt_BR": pt_br}

    for locale in locales:
        translator = translator_for(LOCALE_TO_ARGOS[locale])
        translated[locale] = {
            message: translate_text(message, locale, translator, cache) for message in messages
        }

    save_cache(cache_path, cache)
    write_catalog(catalog, translated)
    print(f"{catalog}: locales={','.join(translated.keys())} messages={len(messages)}")
    return 0


def read_existing_pt_br(catalog: Path) -> dict[str, str]:
    script = (
        "import(process.argv[1]).then((m) => "
        "console.log(JSON.stringify(m.PT_BR))).catch((error) => { "
        "console.error(error); process.exit(1); })"
    )

    with tempfile.NamedTemporaryFile("w", suffix=".mjs", encoding="utf-8") as module:
        module.write(catalog.read_text(encoding="utf-8"))
        module.flush()

        result = subprocess.run(
            ["node", "--input-type=module", "-e", script, Path(module.name).resolve().as_uri()],
            check=True,
            text=True,
            capture_output=True,
        )

    return json.loads(result.stdout)


def write_catalog(catalog: Path, translations: dict[str, dict[str, str]]) -> None:
    ordered_locales = ["de", "es", "fr", "id", "ja", "pt_BR", "zh_Hans"]
    chunks = []

    for locale in ordered_locales:
        if locale not in translations:
            continue

        const_name = CONST_NAMES[locale]
        body = json.dumps(translations[locale], ensure_ascii=False, indent=2, sort_keys=True)
        chunks.append(f"export const {const_name} = {body};\n")

    catalog.write_text("\n".join(chunks), encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
