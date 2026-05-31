#!/usr/bin/env python3
"""Replace unsafe browser catalog entries that lost interpolation placeholders."""

from __future__ import annotations

import json
import re
import subprocess
import tempfile
from pathlib import Path


CATALOG = Path("apps/retro_hex_chat_web/assets/js/lib/i18n_catalog.js")
PLACEHOLDER_RE = re.compile(r"%\{[A-Za-z0-9_]+\}")
TOKEN_RE = re.compile(r"XPH\d+X", re.IGNORECASE)
ORDERED_EXPORTS = [
    ("DE", "DE"),
    ("ES", "ES"),
    ("FR", "FR"),
    ("ID", "ID"),
    ("JA", "JA"),
    ("PT_BR", "PT_BR"),
    ("ZH_HANS", "ZH_HANS"),
]


def main() -> int:
    catalogs = read_catalogs()
    repaired = 0

    for catalog in catalogs.values():
        for source, translated in list(catalog.items()):
            if unsafe(source, translated):
                catalog[source] = source
                repaired += 1

    write_catalogs(catalogs)
    print(f"catalogs={len(catalogs)} repaired_entries={repaired}")
    return 0


def read_catalogs() -> dict[str, dict[str, str]]:
    script = (
        "import(process.argv[1]).then((m) => "
        "console.log(JSON.stringify(m))).catch((error) => { "
        "console.error(error); process.exit(1); })"
    )

    with tempfile.NamedTemporaryFile("w", suffix=".mjs", encoding="utf-8") as module:
        module.write(CATALOG.read_text(encoding="utf-8"))
        module.flush()

        result = subprocess.run(
            ["node", "--input-type=module", "-e", script, Path(module.name).resolve().as_uri()],
            check=True,
            text=True,
            capture_output=True,
        )

    return json.loads(result.stdout)


def unsafe(source: str, translated: str) -> bool:
    return placeholders(source) != placeholders(translated) or TOKEN_RE.search(translated) is not None


def placeholders(value: str) -> set[str]:
    return set(PLACEHOLDER_RE.findall(value or ""))


def write_catalogs(catalogs: dict[str, dict[str, str]]) -> None:
    chunks = []

    for export_name, key in ORDERED_EXPORTS:
        if key not in catalogs:
            continue

        body = json.dumps(catalogs[key], ensure_ascii=False, indent=2, sort_keys=True)
        chunks.append(f"export const {export_name} = {body};\n")

    CATALOG.write_text("\n".join(chunks), encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
