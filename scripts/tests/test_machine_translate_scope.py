"""What a translation run is allowed to touch.

The regression these lock down is not a bad translation, it is a bad *scope*.
`needs_translation` used to treat "this msgstr still reads as the English
source" as pending work, so every run swept up every English fallback in the
catalog: a pass meant for 96 new strings rewrote 16.000 entries, and each
unrelated one had to be reverted by hand before the diff could be read. New
entries and old debt are now separate jobs.
"""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "i18n_machine_translate_po.py"
_spec = importlib.util.spec_from_file_location("machine_translate_po", SCRIPT)
machine_translate_po = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(machine_translate_po)

needs_translation = machine_translate_po.needs_translation


class FakeEntry:
    """The two attributes `needs_translation` reads off a polib entry."""

    def __init__(self, msgid: str, flags: list[str] | None = None, msgid_plural: str = ""):
        self.msgid = msgid
        self.msgid_plural = msgid_plural
        self.flags = flags or []


class NeedsTranslationTest(unittest.TestCase):
    def test_an_empty_entry_is_always_pending(self):
        entry = FakeEntry("Save Topic")

        self.assertTrue(needs_translation("", "Save Topic", entry, False, False))

    def test_a_fuzzy_entry_is_always_pending(self):
        # The msgstr under a fuzzy mark was copied from a different msgid, so
        # it is a guess whatever it looks like.
        entry = FakeEntry("Join throttle", flags=["fuzzy"])

        self.assertTrue(
            needs_translation("Ligar o acelerador", "Join throttle", entry, False, False)
        )

    def test_an_english_fallback_is_left_alone_by_default(self):
        entry = FakeEntry("Save Topic")

        self.assertFalse(needs_translation("Save Topic", "Save Topic", entry, False, False))

    def test_an_english_fallback_is_pending_when_repairing_fallbacks(self):
        entry = FakeEntry("Save Topic")

        self.assertTrue(needs_translation("Save Topic", "Save Topic", entry, False, True))

    def test_a_real_translation_is_never_touched_without_overwrite(self):
        entry = FakeEntry("Save Topic")

        for fallbacks in (False, True):
            with self.subTest(fallbacks=fallbacks):
                self.assertFalse(
                    needs_translation("Salvar tópico", "Save Topic", entry, False, fallbacks)
                )

    def test_overwrite_takes_everything(self):
        entry = FakeEntry("Save Topic")

        self.assertTrue(needs_translation("Salvar tópico", "Save Topic", entry, True, False))

    def test_a_plural_form_matching_the_plural_source_is_debt_too(self):
        entry = FakeEntry("%{count} entry", msgid_plural="%{count} entries")

        self.assertFalse(
            needs_translation("%{count} entries", "%{count} entries", entry, False, False)
        )
        self.assertTrue(
            needs_translation("%{count} entries", "%{count} entries", entry, False, True)
        )


class SourceLocaleTest(unittest.TestCase):
    """`en` is expo-only: the msgid is its own translation.

    The run used to refuse it outright — "Not an enabled locale: en" — which
    left filling the source catalog as the one step with no tool behind it.
    The engine already has an identity branch for it.
    """

    def test_en_is_an_enabled_locale(self):
        from i18n import locales

        codes = {locale.code for locale in locales.enabled_locales()}

        self.assertIn("en", codes)
        self.assertNotIn("en", locales.codes())

    def test_en_builds_an_identity_translator(self):
        from i18n.translator import IdentityTranslator, build

        translator = build("en", "en")

        self.assertIsInstance(translator, IdentityTranslator)
        self.assertEqual(translator.translate("Save Topic"), "Save Topic")


if __name__ == "__main__":
    unittest.main()
