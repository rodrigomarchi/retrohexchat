#!/usr/bin/env python3
"""Read and write browser-side i18n catalogs split by locale."""

from __future__ import annotations

import json
import subprocess
import tempfile
from collections import OrderedDict
from pathlib import Path


CATALOG_BARREL = Path("apps/retro_hex_chat_web/assets/js/lib/i18n_catalog.js")
CATALOG_DIR = Path("apps/retro_hex_chat_web/assets/js/lib/i18n_catalogs")

LOCALE_EXPORTS = OrderedDict(
    [
        ("ar", "AR"),
        ("bn", "BN"),
        ("de", "DE"),
        ("es", "ES"),
        ("fr", "FR"),
        ("hi", "HI"),
        ("id", "ID"),
        ("it", "IT"),
        ("ja", "JA"),
        ("ko", "KO"),
        ("nl", "NL"),
        ("pl", "PL"),
        ("pt_BR", "PT_BR"),
        ("pt_PT", "PT_PT"),
        ("ru", "RU"),
        ("tr", "TR"),
        ("ur", "UR"),
        ("vi", "VI"),
        ("zh_Hans", "ZH_HANS"),
        ("zh_Hant", "ZH_HANT"),
    ]
)


def read_catalogs(
    catalog_dir: Path = CATALOG_DIR,
    legacy_catalog: Path = CATALOG_BARREL,
) -> dict[str, dict[str, str]]:
    catalogs = read_split_catalogs(catalog_dir)

    if catalogs:
        return catalogs

    if legacy_catalog.exists():
        return read_legacy_catalog(legacy_catalog)

    return {}


def read_split_catalogs(catalog_dir: Path = CATALOG_DIR) -> dict[str, dict[str, str]]:
    catalogs = {}

    for locale, export_name in LOCALE_EXPORTS.items():
        path = locale_catalog_path(locale, catalog_dir)

        if not path.exists():
            continue

        exported = import_js_exports(path.read_text(encoding="utf-8"))

        if export_name in exported:
            catalogs[export_name] = exported[export_name]

    return catalogs


def read_legacy_catalog(catalog: Path = CATALOG_BARREL) -> dict[str, dict[str, str]]:
    exported = import_js_exports(catalog.read_text(encoding="utf-8"))
    allowed = set(LOCALE_EXPORTS.values())
    return {export_name: messages for export_name, messages in exported.items() if export_name in allowed}


def write_catalogs(
    catalogs: dict[str, dict[str, str]],
    catalog_dir: Path = CATALOG_DIR,
    barrel: Path = CATALOG_BARREL,
    locales: list[str] | tuple[str, ...] | None = None,
) -> None:
    catalog_dir.mkdir(parents=True, exist_ok=True)
    locales_to_write = set(locales) if locales is not None else None

    for locale, export_name in LOCALE_EXPORTS.items():
        if locales_to_write is not None and locale not in locales_to_write:
            continue

        if export_name not in catalogs:
            continue

        path = locale_catalog_path(locale, catalog_dir)
        body = json.dumps(catalogs[export_name], ensure_ascii=False, indent=2, sort_keys=True)
        path.write_text(f"export const {export_name} = {body};\n", encoding="utf-8")

    write_barrel(barrel, catalog_dir)


def write_barrel(barrel: Path = CATALOG_BARREL, catalog_dir: Path = CATALOG_DIR) -> None:
    barrel_exports = []

    for locale, export_name in LOCALE_EXPORTS.items():
        if locale_catalog_path(locale, catalog_dir).exists():
            barrel_exports.append(f'export {{ {export_name} }} from "./i18n_catalogs/{locale}.js";')

    barrel.write_text("\n".join(barrel_exports) + "\n", encoding="utf-8")


def locale_catalog_path(locale: str, catalog_dir: Path = CATALOG_DIR) -> Path:
    return catalog_dir / f"{locale}.js"


def import_js_exports(module_text: str) -> dict:
    script = (
        "import(process.argv[1]).then((m) => "
        "console.log(JSON.stringify(m))).catch((error) => { "
        "console.error(error); process.exit(1); })"
    )

    with tempfile.NamedTemporaryFile("w", suffix=".mjs", encoding="utf-8") as module:
        module.write(module_text)
        module.flush()

        result = subprocess.run(
            ["node", "--input-type=module", "-e", script, Path(module.name).resolve().as_uri()],
            check=True,
            text=True,
            capture_output=True,
        )

    return json.loads(result.stdout)
