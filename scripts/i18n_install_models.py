#!/usr/bin/env python3
"""Install the Argos models every enabled locale needs, both ways, and nothing else.

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

    # Both directions: en -> X translates, X -> en reads the translation back
    # for the round-trip gate (`quality.meaning_kept`).
    pairs = {("en", code) for code in wanted} | {(code, "en") for code in wanted}
    installed = {(pkg.from_code, pkg.to_code) for pkg in package.get_installed_packages()}
    missing = sorted(pairs - installed)

    if not missing:
        print(f"all {len(pairs)} models already installed")
        return 0

    package.update_package_index()
    available = {(pkg.from_code, pkg.to_code): pkg for pkg in package.get_available_packages()}
    unavailable = [pair for pair in missing if pair not in available]

    if unavailable:
        names = ", ".join(f"{source} -> {target}" for source, target in unavailable)
        print(f"no Argos package for {names}", file=sys.stderr)
        return 1

    for pair in missing:
        print(f"installing {pair[0]} -> {pair[1]}")
        package.install_from_path(available[pair].download())

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
