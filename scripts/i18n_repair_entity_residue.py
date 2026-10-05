#!/usr/bin/env python3
"""Turn an HTML entity's letters back into the character they stand for.

The translation engine HTML-escapes a source before translating it and never
unescapes the result, so a `&`, `’`, `“` or `—` in the msgid comes back as the
entity's own letters — usually with a space wedged in. The catalogues shipped
"Paso 1 & mdash; Clone" and "& #x1F4BB; Gentileza de código" that way, and
`& mdash;` alone accounted for 91 of them.

The repair needs no translation engine, because the damage is mechanical: the
entity names the character it replaced. Two rules, matching the guard in
`i18n.quality.has_entity_residue`:

  spaced     `& mdash;` is never markup, whatever the msgid holds — always damage
  unspaced   `&amp;` is damage only when the msgid carries no entity of its own,
             because landing and help msgids do legitimately contain one

Dry run by default. Needs polib, so it runs under the throwaway venv described
in `docs/reference/i18n-catalogs.md`, not the Makefile's `python3`.
"""

from __future__ import annotations

import argparse
import html
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from i18n import catalogs, locales  # noqa: E402
from i18n.quality import has_entity_residue  # noqa: E402

ENTITY = re.compile(
    r"&\s*(?:[a-zA-Z][a-zA-Z0-9]{1,10}|#\s*[0-9]{1,6}|#\s*[xX]\s*[0-9a-fA-F]{1,6})\s*;"
)


def repair(source: str, translated: str) -> str:
    """Replace the damaged entities in `translated` with their characters.

    Three refusals, each one a way this could make a string worse rather than
    better:

    When the source carries an entity of its own, an unspaced entity in the
    translation is the markup the writer meant, and only a spaced one is residue.

    When the entity decodes to a character the source does not contain, the
    engine did not merely escape — it substituted. "Point & click" came back as
    "Punto &gt; haga clic", and unescaping that writes a confident `>` where an
    `&` belonged. Those entries are garbage for a reason this pass cannot fix,
    so they are left for the guard to keep reporting.

    When nothing decodes the entity at all, it is left alone rather than
    mangled further.
    """
    source_has_entity = bool(ENTITY.search(source))

    def replacement(match: re.Match[str]) -> str:
        token = match.group(0)
        spaced = bool(re.search(r"\s", token))

        if source_has_entity and not spaced:
            return token

        collapsed = re.sub(r"\s+", "", token)
        decoded = html.unescape(collapsed)

        if decoded == collapsed:
            return token

        # Whitespace for whitespace cannot invert a meaning, and asking whether
        # the source contains it is the wrong question: every French entry here
        # is `&#160;` before a colon, which is correct French typography the
        # engine added on purpose and only mis-escaped on the way out.
        if decoded.isspace():
            return decoded

        if decoded not in source:
            return token

        return decoded

    return collapse_nbsp_runs(ENTITY.sub(replacement, translated))


def needs_repair(source: str, translated: str) -> bool:
    """Either the entity is still there, or the space it left behind is."""
    return has_entity_residue(source, translated) or collapse_nbsp_runs(
        translated
    ) != translated


def collapse_nbsp_runs(text: str) -> str:
    """Drop the plain space an escaped no-break space was written next to.

    "Licence & #160;:" carried a real space *before* the entity, so decoding
    alone leaves a plain space followed by a no-break space, where French
    typography wants the no-break space alone. Idempotent, so a second run
    over an already-decoded catalogue fixes it rather than compounding it.
    """
    return re.sub(r"[ \t]*\u00a0[ \t]*", "\u00a0", text)


def repair_locale(code: str, write: bool) -> tuple[int, int]:
    entries_fixed = 0
    files_touched = 0

    for path in catalogs.po_files(code):
        po = catalogs.load_po(path)
        dirty = False

        for entry in catalogs.translatable_entries(po):
            if entry.msgid_plural:
                for index, current in sorted(entry.msgstr_plural.items()):
                    source = entry.msgid if index == 0 else entry.msgid_plural

                    if not needs_repair(source, current):
                        continue

                    fixed = repair(source, current)

                    if fixed != current:
                        entry.msgstr_plural[index] = fixed
                        entries_fixed += 1
                        dirty = True
                continue

            current = entry.msgstr

            if not needs_repair(entry.msgid, current):
                continue

            fixed = repair(entry.msgid, current)

            if fixed != current:
                entry.msgstr = fixed
                entries_fixed += 1
                dirty = True

        if dirty:
            files_touched += 1

            if write:
                catalogs.save_po(po, Path(path))

    return entries_fixed, files_touched


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--locales", default=",".join(locales.codes()))
    parser.add_argument("--write", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    selected = [code.strip() for code in args.locales.split(",") if code.strip()]
    total_entries = 0
    total_files = 0

    for code in selected:
        entries, files = repair_locale(code, args.write)

        if entries:
            print(f"{code}: {entries} entries in {files} files")

        total_entries += entries
        total_files += files

    verb = "repaired" if args.write else "would repair"
    print(f"\n{verb} {total_entries} entries across {total_files} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
