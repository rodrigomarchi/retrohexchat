#!/usr/bin/env python3
"""Translate the messages the browser asks for and its catalogs lack.

Only what is missing: a message already in a locale's catalog is never sent
to the engine again, so a run for three new strings changes three entries per
locale. `--retry-english` also sends what a catalog holds in English, after a
source rewrite or a pipeline fix that may now let it through. Each goes through the same `Pipeline` the server catalogs use (masks,
the chat's terms, read-back, negation, glued words), and a message the
glossary owns takes the glossary's word whatever the engine said. A message
the pipeline will not ship stays English, and `i18n_js_catalog_check.py`
keeps naming it until a source rewrite lets it through.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from i18n import catalogs, glossary, js_messages, locales  # noqa: E402
from i18n.locales import REPO_ROOT  # noqa: E402

JS_DIR = REPO_ROOT / "apps/retro_hex_chat_web/assets/js"
PRETTIER = REPO_ROOT / "apps/retro_hex_chat_web/assets/node_modules/.bin/prettier"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--locales", required=True)
    parser.add_argument(
        "--retry-english",
        action="store_true",
        help="also send messages a catalog holds in English (and the glossary does not)",
    )
    return parser.parse_args()


def build_pipeline(code: str):
    # The engines and the read-back models live in the translation venv only.
    from i18n.pipeline import Pipeline
    from i18n.terms import brazilian_forms, italian_accents
    from i18n.translator import TraditionalChinesePostprocessor, build, build_back

    translator = build(code, locales.argos_code(code))
    postprocess = None

    if code == "zh_hant":
        postprocess = TraditionalChinesePostprocessor(translator).convert
    elif code == "it":
        postprocess = italian_accents
    elif code == "pt_BR":
        postprocess = brazilian_forms

    return Pipeline(
        translator,
        postprocess=postprocess,
        locale_code=code,
        back_translator=build_back(code, locales.argos_code(code)),
        answers={word: glossary.for_locale(code)[word] for word in ("Yes", "No")},
        full_stop="。" if code in ("ja", "zh_hans", "zh_hant") else ".",
    )


def main() -> int:
    args = parse_args()
    codes = [code.strip() for code in args.locales.split(",") if code.strip()]
    exports = locales.locale_exports()
    messages = js_messages.scan(JS_DIR)
    current = catalogs.read_js_catalogs()
    written = []

    for code in codes:
        export_name = exports[code]
        catalog = dict(current.get(export_name, {}))
        curated = glossary.for_locale(code)
        absent = sorted(
            message
            for message in messages
            if message not in catalog
            or (args.retry_english and catalog[message] == message and message not in curated)
        )

        if not absent:
            continue

        translated = build_pipeline(code).translate_many(absent)

        for message in absent:
            catalog[message] = curated.get(message, translated[message])

        current[export_name] = catalog
        written.append(code)
        kept = sum(1 for message in absent if catalog[message] == message)
        print(f"{code}: {len(absent)} filled, {kept} kept in English")

    if written:
        catalogs.write_js_catalogs(current, locales=written)
        subprocess.run([str(PRETTIER), "--write", str(catalogs.JS_CATALOG_DIR)], check=True)

    return 0


if __name__ == "__main__":
    sys.exit(main())
