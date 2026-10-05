#!/usr/bin/env python3
"""Install the Argos models every enabled locale needs, and nothing else.

Run inside the translation venv (`make i18n.venv` does both). The locales
come from the registry; the Argos code each one needs comes from
`locales.LOCALE_TO_ARGOS`, which a new language must also name — the lookup
fails loudly when it does not.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from i18n import locales  # noqa: E402


def main() -> int:
    from argostranslate import package

    wanted = {locales.argos_code(locale.code) for locale in locales.translatable_locales()}
    wanted.discard("en")

    installed = {(pkg.from_code, pkg.to_code) for pkg in package.get_installed_packages()}
    missing = sorted(code for code in wanted if ("en", code) not in installed)

    if not missing:
        print(f"all {len(wanted)} models already installed")
        return 0

    package.update_package_index()
    available = {pkg.to_code: pkg for pkg in package.get_available_packages() if pkg.from_code == "en"}
    unavailable = [code for code in missing if code not in available]

    if unavailable:
        print(f"no Argos package for en -> {', '.join(unavailable)}", file=sys.stderr)
        return 1

    for code in missing:
        print(f"installing en -> {code}")
        package.install_from_path(available[code].download())

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
