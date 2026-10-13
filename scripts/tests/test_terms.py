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

    def test_a_space_character_is_a_figure_not_a_letter(self):
        # What the engine gave the character creator's help.
        self.assertTrue(missing_terms("Each tab is one part of your character", "Cada aba é uma parte do seu caractere", "pt_BR"))
        self.assertTrue(missing_terms("makes a new random character", "crée un nouveau caractère aléatoire", "fr"))
        self.assertEqual(missing_terms("makes a new character", "cria um novo personagem", "pt_BR"), [])
        self.assertEqual(missing_terms("the character creator", "de karakterschepper", "nl"), [])

    def test_letters_are_not_held_to_the_figure(self):
        # A count of letters, the character counter and "special characters"
        # are glyphs, and their translations say so.
        for source, translated, code in [
            ("Password must be at least 5 characters", "A senha deve ter pelo menos 5 caracteres", "pt_BR"),
            ("at most %{count} character(s)", "au plus %{count} caractère(s)", "fr"),
            ("A real-time character counter appears", "Ein Zeichenzähler erscheint", "de"),
            ("Can contain letters, numbers, special characters", "Pode conter letras, números, caracteres especiais", "pt_BR"),
        ]:
            self.assertEqual(missing_terms(source, translated, code), [], source)

    def test_a_constructs_sign_is_a_board_not_a_signal(self):
        self.assertEqual(
            missing_terms("That line does not fit on a sign.", "Essa linha não cabe num sinal.", "pt_BR"),
            [r"\bsigns?\b(?![\s-]*(?:in|up|out|on|off)\b)"],
        )
        self.assertEqual(
            missing_terms("That line does not fit on a sign.", "Essa linha não cabe na placa.", "pt_BR"), []
        )
        # Signing in is no sign at all.
        self.assertEqual(missing_terms("Sign in to continue.", "Entre para continuar.", "pt_BR"), [])
        self.assertEqual(missing_terms("Sign-up is closed.", "O cadastro está fechado.", "pt_BR"), [])

    def test_a_die_is_the_games_cube_not_death(self):
        self.assertTrue(missing_terms("rolled the die: 5", "rodó la muerte: 5", "es"))
        self.assertEqual(missing_terms("rolled the dice and got 5", "rodó los dados y sacó 5", "es"), [])
        self.assertEqual(missing_terms("They will die.", "Van a morir.", "es"), [])

    def test_a_piece_is_not_a_scrap_and_pinned_is_not_stuck(self):
        self.assertTrue(missing_terms("Pick a piece.", "Escolha um pedaço.", "pt_BR"))
        self.assertEqual(missing_terms("Pick a piece.", "Escolha uma peça.", "pt_BR"), [])
        self.assertTrue(missing_terms("Its pinned messages.", "Suas mensagens presas.", "pt_BR"))
        self.assertEqual(missing_terms("Its pinned messages.", "Suas mensagens fixadas.", "pt_BR"), [])
        self.assertTrue(missing_terms("Opens in a new tab.", "Abre numa nova página.", "pt_BR"))

    def test_capital_letters_are_letters_not_money(self):
        source = "Capital letters do not matter"
        self.assertTrue(missing_terms(source, "Las letras de capital no importan", "es"))
        self.assertTrue(missing_terms(source, "資本の手紙は重要ではありません", "ja"))
        self.assertEqual(missing_terms(source, "Las mayúsculas no importan", "es"), [])
        self.assertEqual(missing_terms(source, "大文字は関係ありません", "ja"), [])

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

    def test_the_constructs_european_forms_are_foreign_to_pt_br(self):
        self.assertEqual(
            foreign_forms("Senta-te numa cadeira ou levanta-te.", "pt_BR"), ["Senta-te", "levanta-te"]
        )
        self.assertEqual(foreign_forms("No Constructo, rode a peça", "pt_BR"), ["rode a peça"])
        self.assertEqual(foreign_forms("Sente-se numa cadeira", "pt_BR"), [])

    def test_the_european_tu_preterite_is_foreign_to_pt_br(self):
        self.assertEqual(
            foreign_forms("O Construct continua como o deixaste.", "pt_BR"), ["deixaste"]
        )
        self.assertEqual(foreign_forms("O Construct fica como você deixou.", "pt_BR"), [])

    def test_the_european_noun_for_registration_is_foreign_to_pt_br(self):
        # What the engine gave "View channel registration info" for Brazil.
        self.assertEqual(foreign_forms("Ver informações de registo do canal", "pt_BR"), ["registo"])
        self.assertEqual(foreign_forms("Ver informações de registro do canal", "pt_BR"), [])

    def test_the_creators_european_forms_are_foreign_to_pt_br(self):
        self.assertEqual(
            foreign_forms("Toda a gente no espaço vê-te entrar.", "pt_BR"), ["Toda a gente", "vê-te"]
        )
        self.assertEqual(foreign_forms("Da próxima vez que entrares", "pt_BR"), ["entrares"])
        self.assertEqual(foreign_forms("Todo mundo no espaço vê você entrar.", "pt_BR"), [])

    def test_brazilian_text_passes(self):
        self.assertEqual(foreign_forms("Escolha um apelido e pronto.", "pt_BR"), [])

    def test_pt_pt_is_not_judged(self):
        self.assertEqual(foreign_forms("A tua alcunha", "pt_PT"), [])

    def test_a_form_inside_a_longer_word_is_not_matched(self):
        self.assertEqual(foreign_forms("Estude a rua com atenção.", "pt_BR"), [])


if __name__ == "__main__":
    unittest.main()
