"""Catalog reading.

The stdlib PO reader exists so the CI gate needs no third-party packages; these
tests pin its behaviour against the format's awkward corners.
"""

from __future__ import annotations

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
