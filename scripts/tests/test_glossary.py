"""The curated UI label glossary.

These pin decisions that machine translation reliably gets wrong, so a future
re-run cannot quietly undo them.
"""

from __future__ import annotations

import unittest

from i18n import catalogs, glossary, locales
from i18n.quality import has_trailing_stop, looks_like_mojibake


class StructureTest(unittest.TestCase):
    def test_every_row_covers_every_locale(self):
        for term, translations in glossary.GLOSSARY.items():
            self.assertEqual(
                set(translations), set(glossary.LOCALE_ORDER), f"{term} has the wrong locales"
            )

    def test_columns_match_the_enabled_locale_set(self):
        self.assertEqual(set(glossary.LOCALE_ORDER), set(locales.codes()))

    def test_no_value_is_empty(self):
        for term, translations in glossary.GLOSSARY.items():
            for code, value in translations.items():
                self.assertTrue(value.strip(), f"{term}/{code} is empty")

    def test_no_label_ends_in_a_full_stop(self):
        for term, translations in glossary.GLOSSARY.items():
            for code, value in translations.items():
                self.assertFalse(
                    has_trailing_stop(term, value), f"{term}/{code} ends in a full stop: {value!r}"
                )

    def test_no_value_looks_corrupted(self):
        for term, translations in glossary.GLOSSARY.items():
            for code, value in translations.items():
                self.assertFalse(looks_like_mojibake(value), f"{term}/{code}: {value!r}")


class DecisionsTest(unittest.TestCase):
    def test_ok_stays_literal_outside_chinese(self):
        ok = glossary.GLOSSARY["OK"]

        for code, value in ok.items():
            if code.startswith("zh_"):
                continue

            self.assertEqual(value, "OK", f"OK should not be translated for {code}")

    def test_chinese_uses_the_established_confirm_word(self):
        self.assertEqual(glossary.GLOSSARY["OK"]["zh_hans"], "确定")
        self.assertEqual(glossary.GLOSSARY["OK"]["zh_hant"], "確定")

    def test_no_is_not_the_number_abbreviation(self):
        # fr rendered "No" as "Numéro" — it read the source as N°.
        self.assertEqual(glossary.GLOSSARY["No"]["fr"], "Non")

    def test_yes_and_no_are_answers_not_judgements(self):
        # zh had "对" (correct) and "没有" (don't have) for Yes/No.
        self.assertEqual(glossary.GLOSSARY["Yes"]["zh_hans"], "是")
        self.assertEqual(glossary.GLOSSARY["No"]["zh_hans"], "否")

    def test_mute_is_the_audio_sense(self):
        # fr had "Mignon" (cute), de had "Mut" (courage).
        self.assertEqual(glossary.GLOSSARY["Mute"]["fr"], "Couper le son")
        self.assertEqual(glossary.GLOSSARY["Mute"]["de"], "Stummschalten")

    def test_save_is_storage_not_rescue(self):
        # ru had "Спасти" — saving a life, not a file.
        self.assertEqual(glossary.GLOSSARY["Save"]["ru"], "Сохранить")

    def test_description_differs_from_help_in_traditional_chinese(self):
        # zh_hant uses 說明 for the Help menu, so Description must not collide.
        self.assertEqual(glossary.GLOSSARY["Help"]["zh_hant"], "說明")
        self.assertEqual(glossary.GLOSSARY["Description"]["zh_hant"], "描述")

    def test_borrowed_terms_are_recorded_explicitly(self):
        # Identical to English on purpose, not a missing translation.
        self.assertEqual(glossary.GLOSSARY["Menu"]["pt_BR"], "Menu")
        self.assertEqual(glossary.GLOSSARY["Server"]["de"], "Server")
        self.assertEqual(glossary.GLOSSARY["Online"]["nl"], "Online")


class CatalogsMatchTest(unittest.TestCase):
    def test_every_catalog_agrees_with_the_glossary(self):
        for locale in locales.translatable_locales():
            curated = glossary.for_locale(locale.code)

            for path in catalogs.po_files(locale.code):
                for source, translated in catalogs.read_po_pairs(path):
                    wanted = curated.get(source.strip())

                    if wanted is None:
                        continue

                    self.assertEqual(
                        translated.strip(),
                        wanted,
                        f"{locale.code} {path.name}: {source!r} drifted from the glossary",
                    )


if __name__ == "__main__":
    unittest.main()
