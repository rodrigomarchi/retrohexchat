"""Catalog reading.

The stdlib PO reader exists so the CI gate needs no third-party packages; these
tests pin its behaviour against the format's awkward corners.
"""

from __future__ import annotations

import re
import tempfile
import unittest
from pathlib import Path

from i18n import catalogs

PO = '''# Comment line
msgid ""
msgstr ""
"Language: pt_BR\\n"

#: lib/app.ex:1
msgid "Simple"
msgstr "Simples"

#: lib/app.ex:2
msgid ""
"A source split "
"across lines"
msgstr ""
"Uma fonte quebrada "
"em linhas"

#: lib/app.ex:3
msgid "%{count} minute"
msgid_plural "%{count} minutes"
msgstr[0] "%{count} minuto"
msgstr[1] "%{count} minutos"

#: lib/app.ex:4
msgid "Untranslated"
msgstr ""

#: lib/app.ex:5
msgid "With \\"quotes\\" and \\\\ backslash"
msgstr "Com \\"aspas\\" e \\\\ barra"

#: lib/app.ex:6
msgid "Two\\nlines"
msgstr "Duas\\nlinhas"

#~ msgid "Obsolete"
#~ msgstr "Obsoleto"
'''


class ReadPoPairsTest(unittest.TestCase):
    def setUp(self):
        handle = tempfile.NamedTemporaryFile("w", suffix=".po", delete=False, encoding="utf-8")
        handle.write(PO)
        handle.close()
        self.path = Path(handle.name)
        self.pairs = dict(catalogs.read_po_pairs(self.path))

    def tearDown(self):
        self.path.unlink()

    def test_reads_a_simple_entry(self):
        self.assertEqual(self.pairs["Simple"], "Simples")

    def test_joins_multiline_fields(self):
        self.assertEqual(self.pairs["A source split across lines"], "Uma fonte quebrada em linhas")

    def test_pairs_plural_slots_with_their_own_source(self):
        self.assertEqual(self.pairs["%{count} minute"], "%{count} minuto")
        self.assertEqual(self.pairs["%{count} minutes"], "%{count} minutos")

    def test_skips_untranslated_entries(self):
        self.assertNotIn("Untranslated", self.pairs)

    def test_skips_the_header_entry(self):
        self.assertNotIn("", self.pairs)

    def test_skips_obsolete_entries(self):
        self.assertNotIn("Obsolete", self.pairs)

    def test_unescapes_quotes_and_backslashes(self):
        self.assertEqual(self.pairs[r'With "quotes" and \ backslash'], r'Com "aspas" e \ barra')

    def test_unescapes_newlines(self):
        self.assertEqual(self.pairs["Two\nlines"], "Duas\nlinhas")


LONG = (
    "Wenn Sie Benachrichtigungen einschalten, gibt Ihr Browser dem Server eine Adresse "
    "beim Push-Dienst seines Herstellers, und der Server sendet die Benachrichtigung dorthin."
)

WRITTEN = f'''msgid ""
msgstr ""
"Language: de\\n"

#: lib/app.ex:1
#, elixir-autogen, elixir-format
msgid "Untouched long line"
msgstr "{LONG}"

#: lib/app.ex:2
#, elixir-autogen, elixir-format, fuzzy
#| msgid "Old source"
msgid "New source"
msgstr "Alte Übersetzung"

#: lib/app.ex:3
#, elixir-autogen, elixir-format
msgid "Empty"
msgstr ""

#: lib/app.ex:4
#, elixir-autogen, elixir-format
msgid "%{{count}} minute"
msgid_plural "%{{count}} minutes"
msgstr[0] ""
msgstr[1] ""

#~ msgid "Gone"
#~ msgstr "Weg"
'''


def entry(msgid, msgstr="", flags=("elixir-autogen", "elixir-format"), **extra):
    """A stand-in for a polib entry: `save_po` reads attributes, nothing more."""
    from types import SimpleNamespace

    return SimpleNamespace(
        msgid=msgid,
        msgctxt=extra.get("msgctxt"),
        msgid_plural=extra.get("msgid_plural", ""),
        msgstr=msgstr,
        msgstr_plural=extra.get("msgstr_plural", {}),
        flags=list(flags),
        previous_msgid=extra.get("previous_msgid"),
        obsolete=False,
    )


class SavePoTest(unittest.TestCase):
    """`save_po` rewrites what a script changed and nothing else.

    polib's own save re-wrapped every long string in the catalog at 78
    columns; filling twenty entries produced a diff of thousands of lines that
    `mix gettext.merge` could not take back.
    """

    def setUp(self):
        handle = tempfile.NamedTemporaryFile("w", suffix=".po", delete=False, encoding="utf-8")
        handle.write(WRITTEN)
        handle.close()
        self.path = Path(handle.name)

    def tearDown(self):
        self.path.unlink()

    def unchanged(self):
        return [
            entry("Untouched long line", LONG),
            entry(
                "New source",
                "Alte Übersetzung",
                flags=("elixir-autogen", "elixir-format", "fuzzy"),
                previous_msgid="Old source",
            ),
            entry("Empty"),
            entry(
                "%{count} minute",
                msgid_plural="%{count} minutes",
                msgstr_plural={0: "", 1: ""},
            ),
        ]

    def save(self, entries):
        rewritten = catalogs.save_po(entries, self.path)
        return rewritten, self.path.read_text(encoding="utf-8")

    def test_nothing_changed_writes_nothing(self):
        rewritten, text = self.save(self.unchanged())

        self.assertEqual(rewritten, 0)
        self.assertEqual(text, WRITTEN)

    def test_a_filled_entry_is_one_line_and_the_rest_is_byte_identical(self):
        entries = self.unchanged()
        entries[2].msgstr = "Leer, aber jetzt mit einem Satz, der länger ist als achtundsiebzig Zeichen."

        rewritten, text = self.save(entries)

        self.assertEqual(rewritten, 1)
        self.assertIn(
            'msgstr "Leer, aber jetzt mit einem Satz, der länger ist als achtundsiebzig Zeichen."',
            text,
        )
        self.assertEqual(
            text.replace(
                'msgid "Empty"\nmsgstr "Leer, aber jetzt mit einem Satz, der länger ist als achtundsiebzig Zeichen."',
                'msgid "Empty"\nmsgstr ""',
            ),
            WRITTEN,
        )

    def test_clearing_fuzzy_drops_the_flag_and_the_previous_msgid(self):
        entries = self.unchanged()
        entries[1].msgstr = "Neue Übersetzung"
        entries[1].flags = ["elixir-autogen", "elixir-format"]
        entries[1].previous_msgid = None

        _rewritten, text = self.save(entries)

        self.assertIn(
            '#: lib/app.ex:2\n#, elixir-autogen, elixir-format\nmsgid "New source"\nmsgstr "Neue Übersetzung"\n',
            text,
        )
        self.assertNotIn("#| msgid", text)

    def test_a_value_with_newlines_splits_on_them_only(self):
        entries = self.unchanged()
        entries[2].msgstr = 'Erste "Zeile"\nZweite Zeile'

        _rewritten, text = self.save(entries)

        self.assertIn('msgstr ""\n"Erste \\"Zeile\\"\\n"\n"Zweite Zeile"\n', text)

    def test_plural_slots_are_written_in_order(self):
        entries = self.unchanged()
        entries[3].msgstr_plural = {1: "%{count} Minuten", 0: "%{count} Minute"}

        _rewritten, text = self.save(entries)

        self.assertIn('msgstr[0] "%{count} Minute"\nmsgstr[1] "%{count} Minuten"\n', text)

    def test_what_is_written_reads_back(self):
        entries = self.unchanged()
        entries[2].msgstr = 'Mit "Anführungszeichen" und \\ Backslash'

        self.save(entries)

        self.assertEqual(
            dict(catalogs.read_po_pairs(self.path))["Empty"],
            'Mit "Anführungszeichen" und \\ Backslash',
        )

    def test_obsolete_entries_are_left_alone(self):
        _rewritten, text = self.save(self.unchanged())

        self.assertTrue(text.endswith('#~ msgid "Gone"\n#~ msgstr "Weg"\n'))


class NoPolibSaveTest(unittest.TestCase):
    def test_no_script_writes_a_catalog_through_polib(self):
        scripts = Path(__file__).resolve().parents[1]
        offenders = [
            str(path.relative_to(scripts))
            for path in scripts.rglob("*.py")
            if "tests" not in path.parts and re.search(r"\.save\(\s*(str\()?path", path.read_text(encoding="utf-8"))
        ]

        self.assertEqual(offenders, [], "write catalogs with catalogs.save_po, never po.save")


class SavePoRealCatalogTest(unittest.TestCase):
    """Round-trips the committed catalogs, when polib is there to read them."""

    def test_saving_an_unchanged_catalog_changes_no_byte(self):
        try:
            import polib  # noqa: F401
        except ImportError:
            self.skipTest("polib is only in the translation venv")

        from i18n import locales

        for locale in locales.translatable_locales():
            for path in catalogs.po_files(locale.code):
                before = path.read_bytes()
                po = catalogs.load_po(path)
                copy = Path(tempfile.mkdtemp()) / path.name
                copy.write_bytes(before)

                self.assertEqual(catalogs.save_po(po, copy), 0, f"{path} would be rewritten")
                self.assertEqual(copy.read_bytes(), before)


class RealCatalogTest(unittest.TestCase):
    def test_reads_every_committed_catalog(self):
        from i18n import locales

        for locale in locales.translatable_locales():
            files = catalogs.po_files(locale.code)
            self.assertTrue(files, f"{locale.code} has no catalogs")

            for path in files:
                # A parse error would raise; an empty result would mean the
                # reader silently stopped understanding the format.
                catalogs.read_po_pairs(path)

    def test_locale_of_reads_the_path(self):
        path = Path("apps/retro_hex_chat_web/priv/gettext/pt_BR/LC_MESSAGES/chat.po")

        self.assertEqual(catalogs.locale_of(path), "pt_BR")


if __name__ == "__main__":
    unittest.main()
