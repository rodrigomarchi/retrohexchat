"""The chat's vocabulary, held to the same word in every translation."""

from __future__ import annotations

import unittest

from i18n.terms import foreign_forms, italian_accents, missing_terms

MODES = "+m lets only voiced users speak, +i lets in only who is invited."


class MissingTermsTest(unittest.TestCase):
    def test_a_sung_user_is_not_a_voiced_one(self):
        # What the German model shipped for the guide's channel modes.
        translated = "+m lässt nur gesungene Benutzer sprechen, +i lässt nur Eingeladene herein."

        self.assertTrue(missing_terms(MODES, translated, "de"))

    def test_the_voice_term_passes_in_any_accepted_form(self):
        translated = "+m lässt nur Benutzer mit Voice sprechen, +i lässt nur Eingeladene herein."

        self.assertEqual(missing_terms(MODES, translated, "de"), [])

    def test_a_match_is_a_game_played_not_a_correspondence(self):
        # What the engine shipped for the watch link's label.
        self.assertTrue(missing_terms("Watching a match", "Observando uma correspondência", "pt_BR"))
        self.assertTrue(missing_terms("Watching a match", "Ver una coincidencia", "es"))
        self.assertTrue(missing_terms("Watch the match", "Eine Übereinstimmung beobachten", "de"))
        self.assertEqual(missing_terms("Watch the match", "Assistir à partida", "pt_BR"), [])
        self.assertEqual(missing_terms("Watch the Match", "Смотреть матч", "ru"), [])
        # "No match" is a game too, and Italian gave "nessuna corrispondenza".
        self.assertTrue(missing_terms("No match is being played.", "Non c'è nessuna corrispondenza.", "it"))
        self.assertTrue(missing_terms("It opens a new match.", "Il ouvre une nouvelle correspondance.", "fr"))

    def test_matching_is_not_held_to_the_game(self):
        for source in [
            "Passwords do not match",
            "A miniature of the conversation with the matching line wearing its highlight",
            "The active match is highlighted in orange.",
            "If nothing matches, you get a line that says no entries were found.",
            "in the search input to jump between matches. The chat scrolls to each match automatically.",
        ]:
            self.assertEqual(missing_terms(source, "irrelevante", "pt_BR"), [], source)

    def test_a_player_is_not_a_media_player(self):
        self.assertTrue(
            missing_terms("Right-click a player and choose Watch the Match.", "Faites un clic droit sur un lecteur et choisissez Regarder la partie.", "fr")
        )
        self.assertEqual(
            missing_terms("Right-click a player and choose Watch the Match.", "Faites un clic droit sur un joueur et choisissez Regarder la partie.", "fr"),
            [],
        )
        self.assertEqual(missing_terms("Audio and video attachments use native players", "lecteurs natifs", "fr"), [])

    def test_playing_a_game_is_not_playing_back(self):
        source = "Play browser-native games against the computer."
        self.assertTrue(missing_terms(source, "ブラウザネイティブのゲームをコンピュータと再生します。", "ja"))
        self.assertEqual(missing_terms(source, "ブラウザネイティブのゲームでコンピュータと遊びます。", "ja"), [])
        # A recording is still played back.
        self.assertEqual(missing_terms("Play the voice message.", "ボイスメッセージを再生します。", "ja"), [])

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

    def test_the_game_room_is_a_room_to_play_in(self):
        self.assertTrue(missing_terms("The game room is full.", "A partida está cheia.", "pt_BR"))
        self.assertEqual(missing_terms("The game room is full.", "A sala de jogos está cheia.", "pt_BR"), [])
        self.assertTrue(missing_terms("The game room is full.", "Le jeu est plein.", "fr"))
        self.assertEqual(missing_terms("The game room is full.", "La salle de jeux est pleine.", "fr"), [])

    def test_a_word_for_the_game_room_need_not_be_the_chats_room(self):
        self.assertEqual(missing_terms("The game room is full.", "Das Spielzimmer ist voll.", "de"), [])
        self.assertEqual(missing_terms("The game room is full.", "游戏室已满。", "zh_hans"), [])
        self.assertTrue(missing_terms("The room is full.", "Das Zimmer ist voll.", "de"))

    def test_the_office_is_a_room_not_a_post(self):
        self.assertTrue(missing_terms("Go into the office.", "Entre no gabinete.", "pt_BR"))
        self.assertTrue(missing_terms("The office is full.", "El cargo está lleno.", "es"))
        self.assertEqual(missing_terms("The office is full.", "O escritório está cheio.", "pt_BR"), [])
        self.assertEqual(missing_terms("The office is full.", "Das Büro ist voll.", "de"), [])
        self.assertTrue(missing_terms("Loading the office...", "役職をロードする...", "ja"))
        self.assertEqual(missing_terms("Loading the office...", "オフィスをロード中...", "ja"), [])

    def test_capital_letters_are_letters_not_money(self):
        source = "Capital letters do not matter"
        self.assertTrue(missing_terms(source, "Las letras de capital no importan", "es"))
        self.assertTrue(missing_terms(source, "資本の手紙は重要ではありません", "ja"))
        self.assertEqual(missing_terms(source, "Las mayúsculas no importan", "es"), [])
        self.assertEqual(missing_terms(source, "大文字は関係ありません", "ja"), [])

    def test_a_letter_of_the_alphabet_is_not_a_letter_in_the_post(self):
        source = "Start with a letter."
        self.assertTrue(missing_terms(source, "Começa com uma carta.", "pt_BR"))
        self.assertTrue(missing_terms(source, "Beginnen Sie mit einem Brief.", "de"))
        self.assertEqual(missing_terms(source, "Comece com uma letra.", "pt_BR"), [])
        self.assertEqual(missing_terms(source, "Beginnen Sie mit einem Buchstaben.", "de"), [])

    def test_spaces_between_characters_are_not_places(self):
        self.assertTrue(missing_terms("No spaces.", "Keine Plätze.", "de"))
        self.assertEqual(missing_terms("No spaces.", "Keine Leerzeichen.", "de"), [])

    def test_signing_in_is_not_signing_up(self):
        source = "Sign in or create an account"
        self.assertTrue(missing_terms(source, "Registrieren oder ein Konto erstellen", "de"))
        self.assertEqual(missing_terms(source, "Anmelden oder ein Konto erstellen", "de"), [])

    # Measured on the Arcade's strings.
    def test_the_arcade_is_the_windows_name_not_an_arch(self):
        self.assertTrue(missing_terms("Arcade: Adventures", "Arcada: Aventuras", "es"))
        self.assertTrue(missing_terms("Arcade: FPS", "拱门:FPS", "zh_hans"))
        self.assertTrue(missing_terms("Arcade flow diagram", "Ablaufdiagramm", "de"))
        self.assertEqual(missing_terms("Arcade: FPS", "街机：FPS", "zh_hans"), [])
        self.assertEqual(missing_terms("Arcade: FPS", "Аркада: FPS", "ru"), [])

    def test_a_shooter_is_a_game_not_a_marksman(self):
        source = "The Arcade lets you play classic shooters and adventures."
        self.assertTrue(missing_terms(source, "O Arcade permite jogar atiradores clássicos.", "pt_BR"))
        self.assertEqual(
            missing_terms(source, "O Arcade permite jogar clássicos de tiro e aventuras.", "pt_BR"),
            [],
        )

    def test_reviewing_details_is_not_a_critics_review(self):
        source = "Review details, then press %{play}"
        self.assertTrue(missing_terms(source, "Detalles de la reseña, luego presione %{play}", "es"))
        self.assertTrue(missing_terms(source, "Подробности обзора, затем нажмите %{play}", "ru"))
        self.assertEqual(missing_terms(source, "Revise los detalles y pulse %{play}", "es"), [])

    def test_tips_are_advice_not_ends(self):
        self.assertTrue(missing_terms("its keyboard controls and tips", "sus controles y las puntas", "es"))
        self.assertEqual(missing_terms("its keyboard controls and tips", "sus controles y consejos", "es"), [])

    def test_a_separable_sign_in_verb_still_signs_in(self):
        source = "so it asks you to sign in first"
        self.assertEqual(missing_terms(source, "so dass es Sie bittet, sich zuerst anzumelden", "de"), [])
        self.assertEqual(missing_terms(source, "dus vraagt het je om je eerst aan te melden", "nl"), [])
        self.assertTrue(missing_terms(source, "więc prosi o wpisanie się najpierw", "pl"))

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
    def test_a_link_stays_a_link(self):
        self.assertTrue(missing_terms("%{count} links", "%{count} ligações", "pt_BR"))
        self.assertTrue(missing_terms("1 link", "Plik 1", "pl"))
        self.assertEqual(missing_terms("%{count} links", "%{count} links", "pt_BR"), [])

    def test_european_forms_are_foreign_to_pt_br(self):
        # What the single Portuguese model gave the Brazilian page.
        self.assertEqual(
            foreign_forms("Escolhe uma alcunha e entras.", "pt_BR"), ["alcunha", "entras"]
        )

    def test_the_construct_helps_european_forms_are_foreign_to_pt_br(self):
        self.assertEqual(
            foreign_forms("As peças movem-se quando as arrastas, e todos vêem.", "pt_BR"),
            ["arrastas", "vêem"],
        )
        self.assertEqual(foreign_forms("As pessoas decoram-na juntas.", "pt_BR"), ["decoram-na"])
        self.assertEqual(foreign_forms("Arraste-a com o rato.", "pt_BR"), ["com o rato"])
        self.assertEqual(foreign_forms("Pressione R para rodar uma peça.", "pt_BR"), ["rodar uma peça"])

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

    def test_the_offices_european_forms_are_foreign_to_pt_br(self):
        self.assertTrue(foreign_forms("O escritório vem mobilado.", "pt_BR"))
        self.assertTrue(foreign_forms("Todos podem adicionar-lhe peças.", "pt_BR"))
        self.assertTrue(foreign_forms("A carregar o escritório...", "pt_BR"))
        self.assertTrue(foreign_forms("A porta leva-te de volta.", "pt_BR"))
        self.assertEqual(foreign_forms("O escritório vem mobiliado.", "pt_BR"), [])

    def test_the_arcades_european_forms_are_foreign_to_pt_br(self):
        for text in (
            "O Arcade permite-lhe jogar no navegador.",
            "O botão abre-o numa aba.",
            "Estes partilham o mesmo gestor de janelas.",
            "Reveja os detalhes.",
            "Por isso pede-lhe para entrar quando o seu não está registado.",
        ):
            self.assertTrue(foreign_forms(text, "pt_BR"), text)

    def test_the_accented_stopping_verb_is_foreign_to_pt_br(self):
        self.assertEqual(foreign_forms("Um administrador pára o bot.", "pt_BR"), ["pára"])
        self.assertEqual(foreign_forms("Um administrador para o bot.", "pt_BR"), [])

    def test_italian_is_written_with_its_accent(self):
        self.assertEqual(italian_accents("L'ufficio e' pieno."), "L'ufficio è pieno.")
        self.assertEqual(italian_accents("E' chiuso, e' vero"), "È chiuso, è vero")
        # An apostrophe that elides a word is left alone.
        self.assertEqual(italian_accents("l'ufficio e l'arcade"), "l'ufficio e l'arcade")

    def test_brazilian_text_passes(self):
        self.assertEqual(foreign_forms("Escolha um apelido e pronto.", "pt_BR"), [])

    def test_pt_pt_is_not_judged(self):
        self.assertEqual(foreign_forms("A tua alcunha", "pt_PT"), [])

    def test_a_form_inside_a_longer_word_is_not_matched(self):
        self.assertEqual(foreign_forms("Estude a rua com atenção.", "pt_BR"), [])


if __name__ == "__main__":
    unittest.main()
