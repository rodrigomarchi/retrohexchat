"""The chat's vocabulary, held to the same word in every translation."""

from __future__ import annotations

import unittest

from i18n.terms import foreign_forms, missing_terms

MODES = "+m lets only voiced users speak, +i lets in only who is invited."


class MissingTermsTest(unittest.TestCase):
    def test_a_sung_user_is_not_a_voiced_one(self):
        # What the German model shipped for the guide's channel modes.
        translated = "+m lässt nur gesungene Benutzer sprechen, +i lässt nur Eingeladene herein."

        self.assertTrue(missing_terms(MODES, translated, "de"))

    def test_the_voice_term_passes_in_any_accepted_form(self):
        translated = "+m lässt nur Benutzer mit Voice sprechen, +i lässt nur Eingeladene herein."

        self.assertEqual(missing_terms(MODES, translated, "de"), [])

    def test_a_bedroom_is_not_a_chat_room(self):
        self.assertTrue(missing_terms("How a room works", "Cómo funciona una habitación", "es"))
        self.assertEqual(missing_terms("How a room works", "Cómo funciona una sala", "es"), [])

    def test_portuguese_locales_share_their_forms(self):
        self.assertEqual(missing_terms("Your nickname", "A sua alcunha", "pt_PT"), [])
        self.assertTrue(missing_terms("Your nickname", "Seu nome", "pt_BR"))

    def test_a_term_inside_a_command_is_syntax_not_vocabulary(self):
        self.assertEqual(missing_terms("Type /channel now", "Digite /channel agora", "pt_BR"), [])

    def test_a_source_without_the_terms_asks_for_nothing(self):
        self.assertEqual(missing_terms("Free, nothing to install", "Grátis", "pt_BR"), [])

    def test_inflected_forms_match_by_stem(self):
        self.assertEqual(missing_terms("Leave the channel", "Opuść kanału", "pl"), [])


class ForeignFormsTest(unittest.TestCase):
    def test_european_forms_are_foreign_to_pt_br(self):
        # What the single Portuguese model gave the Brazilian page.
        self.assertEqual(
            foreign_forms("Escolhe uma alcunha e entras.", "pt_BR"), ["alcunha", "entras"]
        )

    def test_the_european_noun_for_registration_is_foreign_to_pt_br(self):
        # What the engine gave "View channel registration info" for Brazil.
        self.assertEqual(foreign_forms("Ver informações de registo do canal", "pt_BR"), ["registo"])
        self.assertEqual(foreign_forms("Ver informações de registro do canal", "pt_BR"), [])

    def test_brazilian_text_passes(self):
        self.assertEqual(foreign_forms("Escolha um apelido e pronto.", "pt_BR"), [])

    def test_pt_pt_is_not_judged(self):
        self.assertEqual(foreign_forms("A tua alcunha", "pt_PT"), [])

    def test_a_form_inside_a_longer_word_is_not_matched(self):
        self.assertEqual(foreign_forms("Estude a rua com atenção.", "pt_BR"), [])


if __name__ == "__main__":
    unittest.main()
