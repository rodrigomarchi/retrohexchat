#!/usr/bin/env python3
"""Fail while a message the browser asks to translate is missing from a catalog.

Reads every `t("...")` and `` jt`...` `` under assets/js (`i18n.js_messages`)
and the per-locale browser catalogs, and names each message a locale lacks.
A missing message shows English in that language, with nothing to say so;
`make i18n.js.translate` fills them.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from i18n import catalogs, js_messages  # noqa: E402
from i18n.locales import REPO_ROOT  # noqa: E402

JS_DIR = REPO_ROOT / "apps/retro_hex_chat_web/assets/js"


def main() -> int:
    messages = js_messages.scan(JS_DIR)
    missing = js_messages.missing(messages, catalogs.read_js_catalogs())

    for export_name, absent in sorted(missing.items()):
        print(f"{export_name}: {len(absent)} missing")
        for message in absent[:5]:
            print(f"  {message!r} ({Path(messages[message]).relative_to(REPO_ROOT)})")

    print(f"messages={len(messages)} locales_missing={len(missing)}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
