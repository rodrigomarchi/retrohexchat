"""The supported locale set, derived from the Elixir registry.

`config/i18n_locales.exs` is the single source of truth. Every other list in
the tree (Makefile, JS loaders, checker defaults) is generated from it or
validated against it, so adding or dropping a language stays a one-file edit.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_PATH = REPO_ROOT / "config" / "i18n_locales.exs"

_ENTRY_RE = re.compile(r"%\{(.*?)\n  \}", re.S)
_FIELD_RE = re.compile(r"(\w+):\s*(?:\"([^\"]*)\"|:(\w+)|(\d+))")

# Locales whose Gettext plural rules collapse to a single form: the singular
# slot is filled from msgid_plural rather than msgid.
ONE_FORM_LOCALES = frozenset({"id", "ja", "zh_hans", "zh_hant"})

# Argos Translate language codes, keyed by our locale code. Regional variants
# share one model; script variants are post-processed (see postprocess).
LOCALE_TO_ARGOS = {
    "en": "en",
    "es": "es",
    "fr": "fr",
    "de": "de",
    "it": "it",
    "ja": "ja",
    "nl": "nl",
    "pl": "pl",
    "pt_BR": "pt",
    "pt_PT": "pt",
    "ru": "ru",
    "zh_hans": "zh",
    "zh_hant": "zh",
    "id": "id",
}


@dataclass(frozen=True)
class Locale:
    code: str
    label: str
    direction: str
    wave: int
    status: str

    @property
    def enabled(self) -> bool:
        return self.status == "enabled"

    @property
    def export_name(self) -> str:
        """Identifier used for the browser catalog export (pt_BR -> PT_BR)."""
        return self.code.upper()

    @property
    def one_form(self) -> bool:
        return self.code in ONE_FORM_LOCALES


@lru_cache(maxsize=None)
def _parse(registry_text: str) -> tuple[Locale, ...]:
    locales = []

    for block in _ENTRY_RE.findall(registry_text):
        fields = {}

        for name, string, atom, number in _FIELD_RE.findall(block):
            fields[name] = string or atom or number

        if "code" not in fields:
            continue

        locales.append(
            Locale(
                code=fields["code"],
                label=fields.get("label", fields["code"]),
                direction=fields.get("direction", "ltr"),
                wave=int(fields.get("wave", 0)),
                status=fields.get("status", "enabled"),
            )
        )

    return tuple(locales)


def all_locales(registry_path: Path | None = None) -> tuple[Locale, ...]:
    path = registry_path or REGISTRY_PATH
    return _parse(path.read_text(encoding="utf-8"))


def enabled_locales(registry_path: Path | None = None) -> tuple[Locale, ...]:
    return tuple(locale for locale in all_locales(registry_path) if locale.enabled)


def translatable_locales(registry_path: Path | None = None) -> tuple[Locale, ...]:
    """Enabled locales that need catalogs, i.e. everything but the source."""
    return tuple(locale for locale in enabled_locales(registry_path) if locale.code != "en")


def codes(registry_path: Path | None = None) -> tuple[str, ...]:
    return tuple(locale.code for locale in translatable_locales(registry_path))


def locale_exports(registry_path: Path | None = None) -> dict[str, str]:
    """Browser catalog exports, ordered as the registry lists them."""
    return {locale.code: locale.export_name for locale in translatable_locales(registry_path)}


def argos_code(locale_code: str) -> str:
    try:
        return LOCALE_TO_ARGOS[locale_code]
    except KeyError:
        raise SystemExit(f"No Argos model mapped for locale {locale_code!r}") from None
