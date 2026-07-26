"""Fragments a translator must not touch."""

from __future__ import annotations

import unittest

from i18n.protection import (
    has_sentinel_residue,
    protect,
    restore,
    should_machine_translate,
)


class ProtectTest(unittest.TestCase):
    def test_sentinels_carry_no_markup(self):
        # Markup-shaped tokens are what the model mangled before.
        protected, _ = protect("Open %{channel} via /join now")

        self.assertNotIn("<", protected)
        self.assertNotIn(">", protected)

    def test_masks_placeholders_and_commands(self):
        _, replacements = protect("Open %{channel} via /join now")

        self.assertEqual(set(replacements.values()), {"%{channel}", "/join"})

    def test_masks_brands(self):
        _, replacements = protect("Register through NickServ and ChanServ")

        self.assertIn("NickServ", replacements.values())
        self.assertIn("ChanServ", replacements.values())

    def test_masks_audit_log_keys(self):
        _, replacements = protect("Action channel.create was logged")

        self.assertIn("channel.create", replacements.values())

    def test_masks_urls_and_code_spans(self):
        _, replacements = protect("See https://example.com or `mix test`")

        self.assertIn("https://example.com", replacements.values())
        self.assertIn("`mix test`", replacements.values())

    def test_sentinels_are_unique_per_fragment(self):
        _, replacements = protect("%{a} and %{b} and %{c}")

        self.assertEqual(len(replacements), 3)
        self.assertEqual(len(set(replacements)), 3)


class RestoreTest(unittest.TestCase):
    def test_round_trips_unchanged_output(self):
        protected, replacements = protect("Join %{channel} with /join")

        self.assertEqual(restore(protected, replacements), "Join %{channel} with /join")

    def test_tolerates_recased_and_padded_sentinels(self):
        protected, replacements = protect("Join %{channel}")
        token = next(iter(replacements))
        mangled = protected.replace(token, token.lower().replace("PH", " ph "))

        self.assertEqual(restore(mangled, replacements), "Join %{channel}")

    def test_keeps_backslashes_in_restored_values(self):
        self.assertEqual(restore("see XPH0X", {"XPH0X": r"C:\path\to"}), r"see C:\path\to")

    def test_keeps_regex_group_syntax_in_restored_values(self):
        self.assertEqual(restore("XPH0X", {"XPH0X": r"\g<0>"}), r"\g<0>")


class ResidueTest(unittest.TestCase):
    def test_detects_current_sentinel(self):
        self.assertTrue(has_sentinel_residue("Uso: XPH0X"))

    def test_detects_retired_markup_sentinel(self):
        # Cached values from the old scheme must be treated as unusable.
        self.assertTrue(has_sentinel_residue("Uso: <ph0></ph0>"))

    def test_clean_text_has_no_residue(self):
        self.assertFalse(has_sentinel_residue("Uso: /admin canal"))


class ShouldMachineTranslateTest(unittest.TestCase):
    def test_skips_strings_without_words(self):
        self.assertFalse(should_machine_translate("%{count} — %{total}"))

    def test_skips_bare_slash_commands(self):
        self.assertFalse(should_machine_translate("/admin channel delete"))

    def test_accepts_prose(self):
        self.assertTrue(should_machine_translate("Channel created and registered."))


if __name__ == "__main__":
    unittest.main()
