"""The chat's vocabulary, held to the same word in every translation."""

from __future__ import annotations

import unittest

from i18n.terms import brazilian_forms, foreign_forms, italian_accents, missing_terms

MODES = "+m lets only voiced users speak, +i lets in only who is invited."


class MissingTermsTest(unittest.TestCase):
    def test_a_sung_user_is_not_a_voiced_one(self):
        # What the German model shipped for the guide's channel modes.
        translated = "+m lässt nur gesungene Benutzer sprechen, +i lässt nur Eingeladene herein."

        self.assertTrue(missing_terms(MODES, translated, "de"))

    def test_the_voice_term_passes_in_any_accepted_form(self):
        translated = "+m lässt nur Benutzer mit Voice sprechen, +i lässt nur Eingeladene herein."

        self.assertEqual(missing_terms(MODES, translated, "de"), [])

    def test_a_card_of_a_card_game_is_a_playing_card(self):
        # What the Spanish model shipped for Hex Solitaire's help.
        source = "A face-down card turns over by itself once nothing lies on it."
        self.assertTrue(
            missing_terms(source, "Una tarjeta boca abajo se vuelve por sí sola.", "es")
        )
        self.assertEqual(
            missing_terms(source, "Una carta boca abajo se da la vuelta sola.", "es"), []
        )
        # The interface's cards stay the interface's.
        for source in (
            "Open it from the card below",
            "Its card is the line below",
            "a card with one open seat",
            "The card shows the start in your own time zone",
        ):
            self.assertEqual(missing_terms(source, "Una tarjeta.", "es"), [], source)

    def test_a_tap_is_a_finger_on_the_screen_not_a_kick(self):
        source = "Tap to play, or drag with the mouse or a finger"
        self.assertTrue(missing_terms(source, "踢打游戏,或用鼠标或手指拖动", "zh_hans"))
        self.assertEqual(missing_terms(source, "轻点即可出牌，或用鼠标或手指拖动", "zh_hans"), [])

    def test_the_deck_is_the_cards_pile_not_a_ships(self):
        source = "Hex Solitaire draws one card at a time from the deck."
        self.assertTrue(
            missing_terms(source, "Hex Solitaire dibuja una carta a la vez desde la cubierta.", "es")
        )
        self.assertEqual(
            missing_terms(source, "Hex Solitaire roba una carta cada vez del mazo.", "es"), []
        )

    def test_a_rooms_host_is_a_person_not_a_machine(self):
        # What the engine shipped for the match room's help.
        source = "The connection only begins when the host presses Start."
        self.assertTrue(
            missing_terms(source, "A conexão só começa quando a máquina pressiona Iniciar.", "pt_BR")
        )
        self.assertEqual(
            missing_terms(source, "A conexão só começa quando o anfitrião aperta Iniciar.", "pt_BR"),
            [],
        )
        self.assertTrue(missing_terms("You are the host.", "Você é o servidor.", "pt_BR"))
        # The server's host is the machine, and stays the other word.
        self.assertEqual(
            missing_terms("Readings the host will not report", "Leituras que a máquina não relata", "pt_BR"),
            [],
        )
        self.assertEqual(
            missing_terms("the host's processors", "os processadores da máquina", "pt_BR"), []
        )

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

    def test_a_browser_tab_is_not_a_page(self):
        source = "The Space opens in a new browser tab."
        self.assertTrue(missing_terms(source, "O Espaço abre numa nova página do navegador.", "pt_BR"))
        self.assertEqual(missing_terms(source, "O Espaço abre em uma nova aba do navegador.", "pt_BR"), [])

    def test_a_german_tab_may_be_a_registerkarte(self):
        source = "Press Join on the card to open the Space in a new tab."
        self.assertEqual(missing_terms(source, "Öffnen Sie den Raum in einer neuen Registerkarte.", "de"), [])

    def test_a_space_is_the_product_not_outer_space(self):
        source = "See the places of a Space"
        self.assertTrue(missing_terms(source, "宇宙の場所を見る", "ja"))
        self.assertTrue(missing_terms("Talking in a Space", "Разговор в космосе", "ru"))
        self.assertEqual(missing_terms(source, "スペースの場所を見る", "ja"), [])

    def test_the_space_bar_keeps_its_own_word(self):
        self.assertEqual(missing_terms("Press the space bar to jump.", "Нажмите пробел.", "ru"), [])

    def test_an_account_is_not_a_bill(self):
        source = "That is all the account needs."
        self.assertTrue(missing_terms(source, "Это все, что нужно для счета.", "ru"))
        self.assertEqual(missing_terms(source, "Это всё, что нужно аккаунту.", "ru"), [])

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

    def test_a_feed_is_a_news_source_not_fodder(self):
        source = "Add an RSS/Atom feed"

        # What the engines shipped: animal feed, and a seed.
        self.assertTrue(missing_terms(source, "Dodaj paszę RSS/Atom", "pl"))
        self.assertTrue(missing_terms(source, "Добавить RSS/Atom кормить", "ru"))
        self.assertTrue(missing_terms(source, "添加 RSS/Atom 种子", "zh_hans"))
        self.assertEqual(missing_terms(source, "Ajouter un flux RSS/Atom", "fr"), [])
        self.assertEqual(missing_terms(source, "Добавить RSS/Atom ленту", "ru"), [])

    def test_a_feed_travels_masked_and_comes_back_in_the_languages_form(self):
        from i18n.pipeline import Pipeline
        from i18n.protection import protect

        masked, replacements = protect("Feed removed. Add another feed.")
        self.assertNotIn("eed", masked)
        self.assertEqual(sorted(replacements.values()), ["Feed", "feed"])

        class Echo:
            def translate(self, text):
                return text.replace("removed. Add another", "supprimé. Ajoutez un autre")

        pipeline = Pipeline(Echo(), locale_code="fr")
        self.assertEqual(
            pipeline.translate_one("Feed removed. Add another feed."),
            "Flux supprimé. Ajoutez un autre flux.",
        )

    def test_a_feed_with_no_space_around_it_is_still_swapped(self):
        from i18n import names

        self.assertEqual(names.localize("feedは大きすぎます。", "ja"), "フィードは大きすぎます。")
        self.assertEqual(names.localize("feedback", "ja"), "feedback")

    def test_a_games_title_is_kept_not_translated(self):
        from i18n import names

        # The engine made Hex Jungle "Selva Hex" and "六角ジャングル".
        self.assertEqual(names.form("Hex Jungle", "pt_BR"), "Hex Jungle")
        self.assertEqual(names.form("Hex Jungle", "ja"), "ヘックスジャングル")

    def test_a_url_a_placeholder_a_command_and_a_channel_keep_their_feed(self):
        from i18n import names
        from i18n.protection import protect, restore

        text = "dans %{feed}. Voir https://blog.example.com/feed.xml #feeds /feed le feed"
        self.assertEqual(
            names.localize(text, "fr"),
            "dans %{feed}. Voir https://blog.example.com/feed.xml #feeds /feed le flux",
        )

        masked, replacements = protect("Join #feeds or run /feed now")
        self.assertEqual(restore(masked, replacements), "Join #feeds or run /feed now")

    def test_a_camera_feed_is_not_masked(self):
        from i18n.protection import protect

        _, replacements = protect("Your screen is replacing the camera feed.")
        self.assertNotIn("feed", replacements.values())

    def test_a_camera_feed_is_a_picture_not_a_news_feed(self):
        source = "Your screen is replacing the camera feed."

        self.assertEqual(missing_terms(source, "Je scherm vervangt de camerabeelden.", "nl"), [])

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

    def test_a_vine_is_swung_on_not_a_grapevine(self):
        source = "— Let go of the vine"
        self.assertTrue(missing_terms(source, "— Soltar a videira", "pt_BR"))
        self.assertEqual(missing_terms(source, "— Soltar o cipó", "pt_BR"), [])
        self.assertTrue(missing_terms(source, "— ぶどうに行く", "ja"))
        self.assertEqual(missing_terms(source, "— ツタを放す", "ja"), [])

    def test_quicksand_is_not_plain_sand(self):
        source = "A pit, quicksand or fire costs a life."
        self.assertTrue(missing_terms(source, "Un pozo, arena o fuego cuesta una vida.", "es"))
        self.assertEqual(
            missing_terms(source, "Un pozo, arenas movedizas o fuego cuesta una vida.", "es"), []
        )

    def test_a_treasure_is_not_jewellery(self):
        self.assertTrue(missing_terms("treasures", "ジュエリー", "ja"))
        self.assertEqual(missing_terms("treasures", "宝物", "ja"), [])

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

    def test_the_browsers_call_strings_european_forms_are_foreign_to_pt_br(self):
        # What the model gave the browser catalog's P2P and Space messages.
        self.assertEqual(
            foreign_forms("Autorização da câmara negada.", "pt_BR"), ["câmara"]
        )
        self.assertEqual(foreign_forms("Erro ao ler o ficheiro.", "pt_BR"), ["ficheiro"])
        self.assertEqual(foreign_forms("A ligar ao espaço...", "pt_BR"), ["A ligar"])
        self.assertEqual(
            foreign_forms("À espera da oferta dos media.", "pt_BR"), ["À espera", "dos media"]
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

    def test_a_desk_is_not_a_secretary_in_brazil(self):
        self.assertTrue(foreign_forms("Um escritório com secretárias e uma mesa", "pt_BR"))

    def test_brazilian_text_passes(self):
        self.assertEqual(foreign_forms("Escolha um apelido e pronto.", "pt_BR"), [])

    def test_pt_pt_is_not_judged(self):
        self.assertEqual(foreign_forms("A tua alcunha", "pt_PT"), [])

    def test_a_form_inside_a_longer_word_is_not_matched(self):
        self.assertEqual(foreign_forms("Estude a rua com atenção.", "pt_BR"), [])


class BrazilianFormsTest(unittest.TestCase):
    # The one Portuguese model writes Portugal's Portuguese. What has a single
    # Brazilian equivalent is rewritten on the way out, so the translation
    # ships instead of being refused by foreign_forms and kept in English.
    def test_rewrites_portugals_words(self):
        self.assertEqual(
            brazilian_forms("O microfone e a câmara estão desligados."),
            "O microfone e a câmera estão desligados.",
        )
        self.assertEqual(brazilian_forms("Erro ao ler o ficheiro."), "Erro ao ler o arquivo.")
        self.assertEqual(brazilian_forms("A reacção da conferência"), "A reação da conferência")
        self.assertEqual(brazilian_forms("A tua câmara"), "A sua câmera")

    def test_rewrites_spellings_and_phrases_of_the_same_gender(self):
        self.assertEqual(
            brazilian_forms("À espera da oferta dos media."), "Aguardando a oferta da mídia."
        )
        self.assertEqual(
            brazilian_forms("O dispositivo seleccionado não está disponível."),
            "O dispositivo selecionado não está disponível.",
        )

    def test_leaves_a_noun_of_another_gender_to_the_variant_check(self):
        # "A partilha de ecrã foi desactivada" would become "O compartilhamento
        # de tela foi desativada": the agreement breaks, so it is refused instead.
        out = brazilian_forms("A partilha de ecrã foi desactivada.")
        self.assertEqual(foreign_forms(out, "pt_BR"), ["partilha", "ecrã"])

    def test_turns_the_european_progressive_into_the_gerund(self):
        self.assertEqual(brazilian_forms("A carregar o Espaço..."), "Carregando o Espaço...")
        self.assertEqual(brazilian_forms("A desenhar o Espaço..."), "Desenhando o Espaço...")
        self.assertEqual(
            brazilian_forms("A câmera não está a ser enviada."), "A câmera não está sendo enviada."
        )
        self.assertEqual(brazilian_forms("A tentar recuperar."), "Tentando recuperar.")

    def test_leaves_brazilian_infinitives_alone(self):
        # "começou a falar" is Brazilian too; only the sentence-opening and
        # "estar a" progressives are Portugal's.
        self.assertEqual(brazilian_forms("Ele começou a falar."), "Ele começou a falar.")
        self.assertEqual(brazilian_forms("A câmera está ligada."), "A câmera está ligada.")

    def test_rewritten_output_passes_the_variant_check(self):
        out = brazilian_forms("A tua câmara não está a ser enviada.")
        self.assertEqual(foreign_forms(out, "pt_BR"), [])



if __name__ == "__main__":
    unittest.main()
