#!/usr/bin/env python3
"""Fail on English source fallbacks that are likely human-facing text."""

from __future__ import annotations

import argparse
import ast
import re
from dataclasses import dataclass
from pathlib import Path

from i18n_js_catalogs import (
    CATALOG_BARREL,
    CATALOG_DIR,
    LOCALE_EXPORTS,
    locale_catalog_path,
    read_catalogs,
)

DEFAULT_LOCALES = ("pt_BR", "es", "fr", "de", "ja", "zh_Hans", "id", "ar", "ru", "hi", "ko", "tr", "vi")
PLACEHOLDER_RE = re.compile(r"%\{[A-Za-z0-9_]+\}")
WORD_RE = re.compile(r"[A-Za-z]{2,}")

TECHNICAL_SOURCE_ALLOWLIST = [
    r"^\s*/%\{name\} → %\{expansion\}$",
    r"^\s*%\{channel\}%\{key\}$",
    r"^\s*%\{command_prefix\}%\{bot_name\} %\{trigger\} — %\{cmd_description_cmd_response\}%\{status\}$",
    r"^\s*%\{id\} \| %\{title\} \| %\{channel\} \| %\{url\}$",
    r"^\s*%\{id\} \| %\{type\} \| %\{channel\} \| %\{message\}$",
    r"^\s*%\{index\}: %\{command\}$",
    r"^\s*%\{name\} \(%\{pid\}\)$",
    r"^\s*%\{name\} \(%\{type\}, %\{interval\}s\) → %\{command\}$",
    r"^\s*%\{name\} \[%\{status\}\] — %\{description\}$",
    r"^\s*%\{nickname\} \[%\{status\}\]%\{note\}$",
    r"^\s*%\{nickname\} \[%\{type\}\] \(%\{expires\}\)$",
    r"^\s*%\{position\}: %\{status\} %\{trigger\} %\{channel\} → %\{command\}$",
    r"^\s*%\{prefix\}%\{trigger\} — %\{description\}$",
    r"^\s*\[%\{time\}\] %\{actor\} %\{action\}%\{target\}%\{details\}$",
    r"^\s*ETS: %\{ets\}$",
    r"^\s*Online: %\{online\}$",
    r"^\s*Total: %\{total\}$",
    r"^→ %\{target_type\}:%\{target_id\}$",
    r"^#%\{name\}$",
    r"^%\{field\}: %\{errors\}$",
    r"^%\{message\} \(%\{reason\}\)$",
    r"^%\{label\} — /p2p/%\{token\}$",
    r"^%\{nick\} \(%\{role\}\)$",
    r"^%\{syntax\} - %\{description\}$",
    r"^%\{prefix\} %\{title\} — %\{link\}$",
    r"^%\{rank\}\. %\{name\}: %\{points\}pts$",
    r"^%\{speed\} — %\{percent\}%$",
    r"^%\{duration\} — %\{quality\}$",
    r"^%\{browser\} — %\{os\}$",
    r"^%\{score\} P2$",
    r"^P1 %\{score\}$",
    r"^%\{game\} — %\{nickname\} vs %\{peer\}$",
    r"^— %\{p1\} × %\{p2\}%\{winner\}$",
    r"^- %\{note\}$",
    r"^%\{base\} = %\{sum\}$",
    r"^%\{base\} %\{sign\} %\{modifier\} = %\{total\}$",
    r"^\(%\{duration\}\)$",
    r"^1 %\{singular\}$",
    r"^\[%\{title\}\]$",
    r"^HTTP %\{status\}$",
    r"^UTC%\{sign\}%\{hours\}(?::%\{minutes\})?$",
    r"^q/%\{minutes\}min$",
    r"^daily@%\{time\}$",
    r"^%\{(?:hours|minutes|seconds)\}[hms](?: %\{(?:minutes|seconds)\}[hms]){0,2}$",
    r"^%\{0\}(?:h|m|  P2| R%\{1\}/3| — %\{1\} — %\{2\}|: %\{1\}pts)$",
    r"^%\{0\} %{1}m$",
    r"^%\{0\}h %\{1\}m %\{2\}s$",
    r"^%\{0\}m %\{1\}s$",
    r"^P[12]: %\{0\}(?:pts| pieces)?(?: \(%\{1\} ovt\))?$",
    r"^P[12] ?%\{0\}$",
    r"^R%\{0\}(?:  %\{1\}|/5)$",
    r"^OVT: %\{0\}$",
    r"^5:%\{seconds\}$",
    r"^%\{inet_ntoa_ip\}:%\{port\}/UDP$",
    r"^\(%\{inet_ntoa_c_ip\}:%\{c_port\}, %\{inet_ntoa_s_ip\}:%\{s_port\}, UDP\)$",
    r"^turn:%\{relay_ip\}:%\{listen_port\}\?transport=udp$",
    r"^\* %\{notice\}$",
    r"^\*\*\* %\{message\}$",
    r"^\*\*\* %\{key\} = '%\{value\}'$",
    r"^\*\*\* %\{server_name\} \*\*\*%\{desc_line\}$",
    r"^\*\*\* \[ChanServ\] %\{name\}$",
    r"^\*\*\* \[NickServ\] %\{nick\}$",
    r"^----- Whois: %\{target\} -----$",
    r"^----- Whowas: %\{nickname\} -----$",
    r"^\[NickServ\] %\{message\}$",
    r"^\[ChanServ\] %\{message\}$",
    r"^\[BotService\] %\{message\}$",
    r"^\[BotService\] Bot '%\{name\}' %\{action\}\.$",
    r"^\[Wallops\] %\{sender\}: %\{content\}$",
    r"^\[Auto-Whois\] %\{nickname\}:$",
    r"^BEAM uptime: %\{uptime_days\}d %\{remaining_hours\}h$",
    r"^Version %\{version\}$",
    r"^WebRTC: %\{state\}$",
    r"^Bio: %\{bio\}$",
    r"^Error: %\{message\}$",
    r"^Color %\{index\}: %\{name\}$",
    r"^Arcade — %\{nickname\}$",
    r"^%\{count\} URLs?$",
    r"^%\{count\} items?$",
    r"^%\{count\} minutes?$",
]

ALLOWLIST = [re.compile(pattern) for pattern in TECHNICAL_SOURCE_ALLOWLIST]


@dataclass(frozen=True)
class Finding:
    surface: str
    path: str
    locale: str
    msgid: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--locales",
        default=",".join(DEFAULT_LOCALES),
        help="Comma-separated locale codes to check",
    )
    parser.add_argument("--fail-on-findings", action="store_true")
    parser.add_argument("paths", nargs="*", help="Optional PO glob paths")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    locales = tuple(locale.strip() for locale in args.locales.split(",") if locale.strip())
    findings = po_findings(locales, args.paths) + js_findings(locales)

    for finding in findings:
        print(
            f"{finding.surface}: locale={finding.locale} path={finding.path} "
            f"msgid={finding.msgid!r}"
        )

    print(f"findings={len(findings)}")

    if args.fail_on_findings and findings:
        return 1

    return 0


def po_findings(locales: tuple[str, ...], paths: list[str]) -> list[Finding]:
    findings: list[Finding] = []

    for path in po_files(locales, paths):
        locale = locale_from_path(path)

        if locale not in locales or locale == "en":
            continue

        for entry in parse_po(path):
            if entry.get("obsolete") or not entry.get("msgid"):
                continue

            if entry.get("msgid_plural"):
                findings.extend(plural_findings(path, locale, entry))
            elif source_fallback(entry["msgid"], entry.get("msgstr", "")):
                findings.append(Finding("po", str(path), locale, entry["msgid"]))

    return findings


def po_files(locales: tuple[str, ...], paths: list[str]) -> list[Path]:
    if paths:
        files: list[Path] = []
        for pattern in paths:
            files.extend(Path(".").glob(pattern))
        return sorted(files)

    files = []
    for locale in locales:
        files.extend(Path(".").glob(f"apps/*/priv/gettext/{locale}/LC_MESSAGES/*.po"))
    return sorted(files)


def parse_po(path: Path) -> list[dict]:
    blocks = re.split(r"\n{2,}", path.read_text(encoding="utf-8"))
    return [parse_po_block(block) for block in blocks if "msgid " in block]


def parse_po_block(block: str) -> dict:
    entry: dict = {"msgstr_plural": {}}
    current: tuple[str, int | None] | None = None

    if re.search(r"^#~", block, re.MULTILINE):
        entry["obsolete"] = True

    for line in block.splitlines():
        parsed = field_line(line)

        if parsed is not None:
            field, index, value = parsed
            current = (field, index)
            set_value(entry, field, index, value)
            continue

        value = continuation_line(line)

        if value is not None and current is not None:
            append_value(entry, current[0], current[1], value)

    return entry


def field_line(line: str) -> tuple[str, int | None, str] | None:
    match = re.match(r'^(msgid_plural|msgid|msgstr)(?:\[(\d+)\])? "(.*)"$', line)

    if match is None:
        return None

    field, index, value = match.groups()
    return field, int(index) if index is not None else None, unquote(value)


def continuation_line(line: str) -> str | None:
    match = re.match(r'^"(.*)"$', line)
    return unquote(match.group(1)) if match else None


def set_value(entry: dict, field: str, index: int | None, value: str) -> None:
    if field == "msgstr" and index is not None:
        entry["msgstr_plural"][index] = value
    else:
        entry[field] = value


def append_value(entry: dict, field: str, index: int | None, value: str) -> None:
    if field == "msgstr" and index is not None:
        entry["msgstr_plural"][index] = entry["msgstr_plural"].get(index, "") + value
    else:
        entry[field] = entry.get(field, "") + value


def unquote(value: str) -> str:
    return ast.literal_eval(f'"{value}"')


def plural_findings(path: Path, locale: str, entry: dict) -> list[Finding]:
    findings: list[Finding] = []
    plural_forms = entry["msgstr_plural"]

    for index, msgstr in plural_forms.items():
        source = entry["msgid_plural"] if len(plural_forms) == 1 or index > 0 else entry["msgid"]

        if source_fallback(source, msgstr):
            findings.append(Finding("po", str(path), locale, source))

    return findings


def js_findings(locales: tuple[str, ...]) -> list[Finding]:
    catalogs = read_catalogs()
    if not catalogs:
        return []

    findings: list[Finding] = []

    for locale in locales:
        export_name = LOCALE_EXPORTS.get(locale)

        if export_name not in catalogs:
            continue

        path = locale_catalog_path(locale, CATALOG_DIR)
        path_label = str(path if path.exists() else CATALOG_BARREL)

        for source, translated in catalogs[export_name].items():
            if source_fallback(source, translated):
                findings.append(Finding("js", path_label, locale, source))

    return findings


def locale_from_path(path: Path) -> str:
    parts = path.parts
    return parts[parts.index("gettext") + 1]


def source_fallback(source: str, translated: str) -> bool:
    if translated != source:
        return False

    if not likely_translatable(source):
        return False

    return not allowlisted(source)


def likely_translatable(source: str) -> bool:
    return PLACEHOLDER_RE.search(source) is not None and WORD_RE.search(source) is not None


def allowlisted(source: str) -> bool:
    value = source.strip()
    return any(pattern.match(value) for pattern in ALLOWLIST)


if __name__ == "__main__":
    raise SystemExit(main())
