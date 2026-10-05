"""Reading and writing the two catalog formats.

All filesystem access for catalogs lives here so the rest of the package stays
pure. Paths are parameters with repo defaults, which lets tests point at a
temporary tree instead of the real one.
"""

from __future__ import annotations

import json
import re
import subprocess
import tempfile
from pathlib import Path

from .locales import REPO_ROOT, locale_exports

PO_GLOB = "apps/*/priv/gettext/{locale}/LC_MESSAGES/*.po"
JS_CATALOG_DIR = REPO_ROOT / "apps/retro_hex_chat_web/assets/js/lib/i18n_catalogs"
JS_CATALOG_BARREL = REPO_ROOT / "apps/retro_hex_chat_web/assets/js/lib/i18n_catalog.js"


# ── Gettext PO ────────────────────────────────────────────────


def po_files(locale: str, root: Path | None = None) -> list[Path]:
    base = root or REPO_ROOT
    return sorted(base.glob(PO_GLOB.format(locale=locale)))


def locale_of(path: Path) -> str:
    parts = path.parts
    return parts[parts.index("gettext") + 1]


def load_po(path: Path):
    """Full read/write PO handle. Needs polib, so writers only."""
    import polib

    return polib.pofile(str(path))


_PO_FIELD_RE = re.compile(r'^(msgctxt|msgid_plural|msgid|msgstr(?:\[\d+\])?)\s+"(.*)"\s*$')
_PO_CONTINUATION_RE = re.compile(r'^"(.*)"\s*$')
_PO_ESCAPES = (
    ("\\\\", "\x00"),
    ('\\"', '"'),
    ("\\n", "\n"),
    ("\\t", "\t"),
    ("\\r", "\r"),
)


def unescape_po(text: str) -> str:
    for escaped, raw in _PO_ESCAPES:
        text = text.replace(escaped, raw)

    return text.replace("\x00", "\\")


def read_po_pairs(path: Path) -> list[tuple[str, str]]:
    """(source, translation) pairs from a PO file, without polib.

    Read-only and dependency-free so the CI gate runs anywhere. Obsolete
    entries and empty translations are skipped; plural forms are flattened
    against the source they render.
    """
    pairs: list[tuple[str, str]] = []
    fields: dict[str, list[str]] = {}
    current: str | None = None

    def flush() -> None:
        nonlocal fields, current

        if fields:
            pairs.extend(_pairs_from_fields(fields))

        fields = {}
        current = None

    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()

        if not stripped:
            flush()
            continue

        if stripped.startswith("#"):
            # "#~" marks an obsolete entry; drop whatever we had collected.
            if stripped.startswith("#~"):
                fields = {}
                current = None

            continue

        match = _PO_FIELD_RE.match(stripped)

        if match:
            current = match.group(1)
            fields.setdefault(current, []).append(unescape_po(match.group(2)))
            continue

        continuation = _PO_CONTINUATION_RE.match(stripped)

        if continuation and current:
            fields[current].append(unescape_po(continuation.group(1)))

    flush()
    return pairs


def _pairs_from_fields(fields: dict[str, list[str]]) -> list[tuple[str, str]]:
    msgid = "".join(fields.get("msgid", []))

    if not msgid:
        return []

    plural = "".join(fields.get("msgid_plural", []))
    found = []

    for name, parts in fields.items():
        if not name.startswith("msgstr"):
            continue

        value = "".join(parts)

        if not value:
            continue

        # msgstr[0] renders the singular, every other slot the plural.
        source = msgid if (not plural or name == "msgstr[0]" or name == "msgstr") else plural
        found.append((source, value))

    return found


def translatable_entries(po) -> list:
    """Entries worth translating: live, with a source string."""
    return [entry for entry in po if not entry.obsolete and entry.msgid]


def entry_pairs(po) -> list[tuple[str, str]]:
    """(source, translation) pairs, flattening plural forms.

    Slot 0 renders the singular, every other slot the plural. Kept in step with
    `read_po_pairs` so the polib and stdlib paths group identically.
    """
    pairs = []

    for entry in translatable_entries(po):
        if entry.msgid_plural:
            for index, value in entry.msgstr_plural.items():
                if value:
                    pairs.append((entry.msgid if index == 0 else entry.msgid_plural, value))
        elif entry.msgstr:
            pairs.append((entry.msgid, entry.msgstr))

    return pairs


def save_po(po, path: Path) -> int:
    """Write `po`'s translations back into `path`, rewriting only what changed.

    Never `po.save()`. polib re-wraps every long string at 78 columns while the
    catalogs are written by Gettext's own writer, which keeps a string on one
    line unless it holds a newline. One save to fill twenty entries rewrapped
    thousands of untouched msgstrs, and `mix gettext.merge` does not undo it:
    the merge restores msgids, never msgstrs. With `wrapwidth=0` polib instead
    rewrites the `#:` reference blocks.

    So the file text is the source of truth. Each entry block is matched to its
    polib entry by context and msgid, and a block is rewritten only when its
    msgstr, its flags or its previous-msgid lines differ — and then only those
    lines, in the writer's own style. Everything else stays byte for byte.

    Stdlib only: the entries are read by attribute, so tests drive it with
    plain objects and the CI gate needs no polib. Returns the number of blocks
    rewritten.
    """
    entries = {(entry.msgctxt or None, entry.msgid): entry for entry in po if not entry.obsolete}
    text = path.read_text(encoding="utf-8")
    trailing = text[len(text.rstrip("\n")) :]
    blocks = text.rstrip("\n").split("\n\n")
    rewritten = 0
    out = []

    for block in blocks:
        new_block = _rewrite_block(block, entries)

        if new_block != block:
            rewritten += 1

        out.append(new_block)

    if rewritten:
        path.write_text("\n\n".join(out) + trailing, encoding="utf-8")

    return rewritten


def _rewrite_block(block: str, entries: dict) -> str:
    lines = block.split("\n")

    if any(line.startswith("#~") for line in lines):
        return block

    fields = _block_fields(lines)
    msgid = "".join(fields.get("msgid", ([], 0))[0])

    if not msgid:
        return block

    msgctxt = fields.get("msgctxt")
    key = ("".join(msgctxt[0]) if msgctxt else None, msgid)
    entry = entries.get(key)

    if entry is None:
        return block

    current_strs = {
        name: "".join(parts) for name, (parts, _start) in fields.items() if name.startswith("msgstr")
    }

    if getattr(entry, "msgid_plural", None):
        new_strs = {f"msgstr[{index}]": value for index, value in sorted(entry.msgstr_plural.items())}
    else:
        new_strs = {"msgstr": entry.msgstr}

    flag_lines = [line for line in lines if line.startswith("#,")]
    current_flags = [
        flag.strip() for line in flag_lines for flag in line[2:].split(",") if flag.strip()
    ]
    new_flags = list(entry.flags)
    drop_previous = getattr(entry, "previous_msgid", None) is None and any(
        line.startswith("#|") for line in lines
    )

    if new_strs == current_strs and new_flags == current_flags and not drop_previous:
        return block

    first_msgstr = min(start for name, (_parts, start) in fields.items() if name.startswith("msgstr"))
    head = []

    for line in lines[:first_msgstr]:
        if line.startswith("#,"):
            continue

        if line.startswith("#|") and drop_previous:
            continue

        head.append(line)

    if new_flags:
        # Flags sit after the translator, extracted and reference comments,
        # and before previous-msgid lines and the fields themselves.
        at = next(
            (i for i, line in enumerate(head) if not line.startswith(("# ", "#.", "#:")) and line != "#"),
            len(head),
        )
        head.insert(at, "#, " + ", ".join(new_flags))

    body = []

    for name, value in new_strs.items():
        body.extend(_field_lines(name, value))

    return "\n".join(head + body)


def _block_fields(lines: list[str]) -> dict[str, tuple[list[str], int]]:
    """Field name -> (unescaped parts, index of its first line)."""
    fields: dict[str, tuple[list[str], int]] = {}
    current: str | None = None

    for index, line in enumerate(lines):
        stripped = line.strip()

        if stripped.startswith("#"):
            continue

        match = _PO_FIELD_RE.match(stripped)

        if match:
            current = match.group(1)
            fields[current] = ([unescape_po(match.group(2))], index)
            continue

        continuation = _PO_CONTINUATION_RE.match(stripped)

        if continuation and current:
            fields[current][0].append(unescape_po(continuation.group(1)))

    return fields


def escape_po(text: str) -> str:
    return (
        text.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\t", "\\t")
        .replace("\r", "\\r")
    )


def _field_lines(name: str, value: str) -> list[str]:
    """One field in Gettext's own style: one line unless it holds a newline."""
    if "\n" not in value:
        return [f'{name} "{escape_po(value)}"']

    return [f'{name} ""'] + [f'"{escape_po(part)}"' for part in value.splitlines(True)]


def plural_sources(entry, one_form: bool) -> dict[int, str]:
    """Which source string fills each plural slot."""
    if one_form:
        return {0: entry.msgid_plural}

    return {
        index: entry.msgid if index == 0 else entry.msgid_plural
        for index in sorted(entry.msgstr_plural.keys())
    }


# ── Browser catalogs ──────────────────────────────────────────


def js_catalog_path(locale: str, catalog_dir: Path | None = None) -> Path:
    return (catalog_dir or JS_CATALOG_DIR) / f"{locale}.js"


def read_js_catalogs(catalog_dir: Path | None = None) -> dict[str, dict[str, str]]:
    directory = catalog_dir or JS_CATALOG_DIR
    catalogs: dict[str, dict[str, str]] = {}

    for locale, export_name in locale_exports().items():
        path = js_catalog_path(locale, directory)

        if not path.exists():
            continue

        exported = import_js_exports(path.read_text(encoding="utf-8"))

        if export_name in exported:
            catalogs[export_name] = exported[export_name]

    return catalogs


def write_js_catalogs(
    catalogs: dict[str, dict[str, str]],
    catalog_dir: Path | None = None,
    barrel: Path | None = None,
    locales: list[str] | tuple[str, ...] | None = None,
) -> None:
    directory = catalog_dir or JS_CATALOG_DIR
    directory.mkdir(parents=True, exist_ok=True)
    selected = set(locales) if locales is not None else None

    for locale, export_name in locale_exports().items():
        if selected is not None and locale not in selected:
            continue

        if export_name not in catalogs:
            continue

        body = json.dumps(catalogs[export_name], ensure_ascii=False, indent=2, sort_keys=True)
        js_catalog_path(locale, directory).write_text(
            f"export const {export_name} = {body};\n", encoding="utf-8"
        )

    write_js_barrel(barrel or JS_CATALOG_BARREL, directory)


def write_js_barrel(barrel: Path | None = None, catalog_dir: Path | None = None) -> None:
    directory = catalog_dir or JS_CATALOG_DIR
    exports = [
        f'export {{ {export_name} }} from "./i18n_catalogs/{locale}.js";'
        for locale, export_name in locale_exports().items()
        if js_catalog_path(locale, directory).exists()
    ]
    (barrel or JS_CATALOG_BARREL).write_text("\n".join(exports) + "\n", encoding="utf-8")


def import_js_exports(module_text: str) -> dict:
    """Evaluate an ES module and return its exports as plain data."""
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
