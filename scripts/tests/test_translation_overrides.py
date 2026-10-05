"""What a curated override may write into a plural entry.

The regression: an override names one plural ("%{count} games" -> "%{count}
gry"), and the pass wrote it into both of Polish's plural slots, though five
games is "gier". A language with more than two forms keeps its own plurals.
"""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "i18n_apply_translation_overrides.py"
_spec = importlib.util.spec_from_file_location("apply_translation_overrides", SCRIPT)
overrides = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(overrides)

POLISH_BLOCK = """#: lib/app.ex:1
msgid "%{count} game"
msgid_plural "%{count} games"
msgstr[0] "%{count} gra"
msgstr[1] "%{count} gry"
msgstr[2] "%{count} gier\""""

FRENCH_BLOCK = """#: lib/app.ex:1
#, fuzzy
msgid "%{count} entry"
msgid_plural "%{count} entries"
msgstr[0] "Entrée %{count}"
msgstr[1] "Entrées %{count}\""""


class PluralOverrideTest(unittest.TestCase):
    def setUp(self):
        self.saved = dict(overrides.PO_OVERRIDES)

    def tearDown(self):
        overrides.PO_OVERRIDES.clear()
        overrides.PO_OVERRIDES.update(self.saved)

    def entry(self, block):
        return overrides.parse_po_block(block)

    def test_a_three_form_language_keeps_its_plurals(self):
        overrides.PO_OVERRIDES["%{count} game"] = {"pl": "%{count} gra"}
        overrides.PO_OVERRIDES["%{count} games"] = {"pl": "%{count} gry"}

        block, changed = overrides.apply_po_block_overrides(POLISH_BLOCK, self.entry(POLISH_BLOCK), "pl")

        self.assertEqual(changed, 0)
        self.assertIn('msgstr[2] "%{count} gier"', block)

    def test_a_two_form_language_takes_both_and_loses_fuzzy(self):
        overrides.PO_OVERRIDES["%{count} entry"] = {"fr": "%{count} entrée"}
        overrides.PO_OVERRIDES["%{count} entries"] = {"fr": "%{count} entrées"}

        block, changed = overrides.apply_po_block_overrides(FRENCH_BLOCK, self.entry(FRENCH_BLOCK), "fr")

        self.assertEqual(changed, 2)
        self.assertIn('msgstr[0] "%{count} entrée"', block)
        self.assertIn('msgstr[1] "%{count} entrées"', block)
        self.assertNotIn("fuzzy", block)


class GlossaryOwnsLabelsTest(unittest.TestCase):
    def setUp(self):
        self.saved = dict(overrides.PO_OVERRIDES)

    def tearDown(self):
        overrides.PO_OVERRIDES.clear()
        overrides.PO_OVERRIDES.update(self.saved)

    def test_an_override_never_rewrites_a_glossary_term(self):
        block = 'msgid "Kick"\nmsgstr "Kicken"'
        overrides.PO_OVERRIDES["Kick"] = {"de": "Kick"}

        block, changed = overrides.apply_po_block_overrides(
            block, overrides.parse_po_block(block), "de"
        )

        self.assertEqual(changed, 0)
        self.assertIn('msgstr "Kicken"', block)


if __name__ == "__main__":
    unittest.main()
