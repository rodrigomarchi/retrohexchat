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

    def test_masks_mirc_and_irc(self):
        _, replacements = protect("A chat in the style of mIRC, not an IRC network")

        self.assertEqual(set(replacements.values()), {"mIRC", "IRC"})

    def test_masks_modes_and_alias_variables(self):
        _, replacements = protect("Modes such as +m and -v, with $1 to $9 and $nick")

        self.assertEqual(set(replacements.values()), {"+m", "-v", "$1", "$9", "$nick"})

    def test_masks_protocol_names(self):
        # Russian shipped CTCP transliterated as "КТКП".
        _, replacements = protect("There is no CTCP, and no DCC either. Do NOT retry.")

        self.assertEqual(set(replacements.values()), {"CTCP", "DCC"})

    def test_masks_the_brand_as_written_in_prose(self):
        # Dutch dropped "— Retro Hex Chat" from the page titles.
        _, replacements = protect("IRC chat rooms in your browser — Retro Hex Chat")

        self.assertIn("Retro Hex Chat", replacements.values())

    def test_leaves_hyphenated_words_alone(self):
        _, replacements = protect("Half-ops keep an e-mail list")

        self.assertEqual(replacements, {})

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

    def test_skips_a_command_example_even_when_it_ends_in_a_full_stop(self):
        # Its words are what the reader types: "set" must not become "definir".
        self.assertFalse(should_machine_translate("/bot set GreeterBot greeting Hello there."))

    def test_accepts_prose(self):
        self.assertTrue(should_machine_translate("Channel created and registered."))


if __name__ == "__main__":
    unittest.main()
