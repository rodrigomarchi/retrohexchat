"""The locale registry parser.

Guards the single-source-of-truth property: if this drifts from
config/i18n_locales.exs, every generated list drifts with it.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from i18n import locales

REGISTRY = """[
  %{
    code: "en",
    bcp47: "en",
    open_graph: "en_US",
    label: "English",
    direction: "ltr",
    plural_forms: "nplurals=2; plural=(n != 1);",
    aliases: ~w(en en_US),
    wave: 0,
    status: :enabled
  },
  %{
    code: "pt_BR",
    bcp47: "pt-BR",
    open_graph: "pt_BR",
    label: "Português (Brasil)",
    direction: "ltr",
    plural_forms: "nplurals=2; plural=(n>1);",
    aliases: ~w(pt pt_BR),
    wave: 0,
    status: :enabled
  },
  %{
    code: "he",
    bcp47: "he",
    open_graph: "he_IL",
    label: "עברית",
    direction: "rtl",
    plural_forms: "nplurals=2; plural=(n != 1);",
    aliases: ~w(he),
    wave: 4,
    status: :disabled
  }
]
"""


class ParseTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.NamedTemporaryFile("w", suffix=".exs", delete=False, encoding="utf-8")
        self.tmp.write(REGISTRY)
        self.tmp.close()
        self.path = Path(self.tmp.name)

    def tearDown(self):
        self.path.unlink()

    def test_reads_every_entry(self):
        self.assertEqual([item.code for item in locales.all_locales(self.path)], ["en", "pt_BR", "he"])

    def test_reads_fields(self):
        found = {item.code: item for item in locales.all_locales(self.path)}

        self.assertEqual(found["pt_BR"].label, "Português (Brasil)")
        self.assertEqual(found["he"].direction, "rtl")
        self.assertEqual(found["pt_BR"].wave, 0)

    def test_enabled_excludes_disabled_status(self):
        self.assertEqual([item.code for item in locales.enabled_locales(self.path)], ["en", "pt_BR"])

    def test_translatable_excludes_the_source_locale(self):
        self.assertEqual(locales.codes(self.path), ("pt_BR",))

    def test_export_names_are_uppercase_codes(self):
        self.assertEqual(locales.locale_exports(self.path), {"pt_BR": "PT_BR"})


class RealRegistryTest(unittest.TestCase):
    def test_matches_the_committed_registry(self):
        enabled = locales.enabled_locales()

        self.assertIn("en", [item.code for item in enabled])
        self.assertTrue(all(item.status == "enabled" for item in enabled))

    def test_every_translatable_locale_has_an_argos_model(self):
        for locale in locales.translatable_locales():
            self.assertIn(locale.code, locales.LOCALE_TO_ARGOS, f"{locale.code} has no Argos mapping")

    def test_every_translatable_locale_has_catalogs_on_disk(self):
        from i18n import catalogs

        for locale in locales.translatable_locales():
            self.assertTrue(catalogs.po_files(locale.code), f"{locale.code} has no PO catalogs")

    def test_argos_code_rejects_unknown_locale(self):
        with self.assertRaises(SystemExit):
            locales.argos_code("xx")


if __name__ == "__main__":
    unittest.main()
