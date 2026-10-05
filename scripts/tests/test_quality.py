"""Guards deciding whether output is fit to ship.

Every case here is a failure mode found in the shipped catalogs during the
July 2026 translation audit.
"""

from __future__ import annotations

import unittest

from i18n.quality import (
    batch_is_contaminated,
    find_collapses,
    find_shared_headings,
    has_entity_residue,
    has_trailing_stop,
    introduced_degeneration,
    invented_break,
    is_degenerate,
    lost_negation,
    is_usable_translation,
    looks_like_mojibake,
)


class DegenerateTest(unittest.TestCase):
    def test_detects_token_loop(self):
        # tr: "permanently" -> "Sürekli kalıcı kalıcı kalıcı kalıcı kalıcı"
        self.assertTrue(is_degenerate("Sürekli kalıcı kalıcı kalıcı kalıcı kalıcı"))

    def test_detects_repeated_word_pair(self):
        # tr: "Blue" -> "Blue Blue Blue Blue"
        self.assertTrue(is_degenerate("Blue Blue Blue Blue"))

    def test_detects_character_run(self):
        # zh_hant: backslash explosion
        self.assertTrue(is_degenerate("op" + "\\" * 12))

    def test_ignores_short_repetition(self):
        self.assertFalse(is_degenerate("muito muito bom"))

    def test_accepts_normal_prose(self):
        self.assertFalse(is_degenerate("Registre e proteja seu apelido com uma senha"))


class IntroducedDegenerationTest(unittest.TestCase):
    def test_flags_repetition_the_model_added(self):
        self.assertTrue(introduced_degeneration("Blue", "Azul Azul Azul Azul"))

    def test_allows_repetition_the_source_already_had(self):
        # A scroll-area demo string repeats on purpose; echoing it is correct.
        demo = "Another long line: " + "ABCDEFGHIJKLMNOPQRSTUVWXYZ " * 5

        self.assertFalse(introduced_degeneration(demo, demo))


class TrailingStopTest(unittest.TestCase):
    def test_flags_a_full_stop_the_source_lacks(self):
        self.assertTrue(has_trailing_stop("Yes", "Sim."))
        self.assertTrue(has_trailing_stop("No", "いいえ。"))

    def test_allows_a_full_stop_the_source_has(self):
        self.assertFalse(has_trailing_stop("Done.", "Feito."))

    def test_allows_an_ellipsis(self):
        # "Settings..." is the convention for "opens a dialog".
        self.assertFalse(has_trailing_stop("Settings", "Einstellungen..."))
        self.assertFalse(has_trailing_stop("Settings", "設定…"))

    def test_allows_an_ordinal_dot(self):
        # Polish writes decades as "lat 80."
        self.assertFalse(has_trailing_stop("Late 1980s", "Pod koniec lat 80."))

    def test_allows_a_clean_label(self):
        self.assertFalse(has_trailing_stop("Yes", "Sim"))


class MojibakeTest(unittest.TestCase):
    def test_flags_three_scripts_in_one_short_label(self):
        # zh shipped this as the translation of "Next".
        self.assertTrue(looks_like_mojibake("ưμ㼯A"))

    def test_allows_a_single_script(self):
        for value in ("下一步", "Próximo", "Далее", "キャンセル", "OK"):
            self.assertFalse(looks_like_mojibake(value), value)

    def test_allows_two_scripts(self):
        # A borrowed brand next to native text is normal.
        self.assertFalse(looks_like_mojibake("IRC チャンネル"))
        self.assertFalse(looks_like_mojibake("Отмена P2P"))

    def test_ignores_long_strings(self):
        self.assertFalse(looks_like_mojibake("ưμ㼯A" + "x" * 30))


class UsableTranslationTest(unittest.TestCase):
    def test_rejects_sentinel_residue(self):
        # it/zh_hant shipped "<ph0>" to users
        self.assertFalse(is_usable_translation("Usage: /admin", "Uso: XPH0X", {}))

    def test_rejects_lost_placeholder(self):
        self.assertFalse(is_usable_translation("Hello %{name}", "Ola", {"XPH0X": "%{name}"}))

    def test_rejects_mangled_brand(self):
        # bn: "ChanServ" -> "Chad"
        self.assertFalse(is_usable_translation("[ChanServ] hi", "[Chad] oi", {"XPH0X": "ChanServ"}))

    def test_rejects_empty(self):
        self.assertFalse(is_usable_translation("Blue", "   ", {}))

    def test_rejects_degenerate(self):
        self.assertFalse(is_usable_translation("Blue", "Blue Blue Blue Blue", {}))

    def test_accepts_clean_translation(self):
        self.assertTrue(
            is_usable_translation("Hello %{name}", "Ola %{name}", {"XPH0X": "%{name}"})
        )


class BatchContaminationTest(unittest.TestCase):
    def test_detects_injected_running_heading(self):
        # The ja failure: the model invented a heading for the joined batch and
        # repeated it in front of the segments.
        sources = ["Authentication", "Back", "Confirm password"]
        parts = ["の特長\nログイン", "の特長\n戻る", "の特長\nパスワード確認"]

        self.assertTrue(batch_is_contaminated(parts, sources))

    def test_detects_heading_when_the_first_segment_escapes_it(self):
        # What the real model does: the heading only starts after the first
        # separator, so segment one comes back clean.
        sources = ["Authentication", "Back", "Blue", "Cyan"]
        parts = ["認証", "シリーズ\nバックナンバー", "シリーズ\nブルージュ", "シリーズ\nシアン"]

        self.assertTrue(batch_is_contaminated(parts, sources))

    def test_allows_shared_heading_the_sources_also_share(self):
        sources = ["Usage: a\nmore", "Usage: b\nmore", "Usage: c\nmore"]
        parts = ["Usage: a\nmais", "Usage: b\nmais", "Usage: c\nmais"]

        self.assertFalse(batch_is_contaminated(parts, sources))

    def test_allows_normal_batch(self):
        self.assertFalse(
            batch_is_contaminated(["Azul", "Verde", "Vermelho"], ["Blue", "Green", "Red"])
        )

    def test_allows_distinct_multiline_translations(self):
        sources = ["A thing\ndetail", "B thing\ndetail", "C thing\ndetail"]
        parts = ["Coisa A\ndetalhe", "Coisa B\ndetalhe", "Coisa C\ndetalhe"]

        self.assertFalse(batch_is_contaminated(parts, sources))

    def test_ignores_batches_too_short_to_judge(self):
        self.assertFalse(batch_is_contaminated(["x", "x"], ["a", "b"]))

    def test_ignores_length_mismatch(self):
        self.assertFalse(batch_is_contaminated(["x", "x", "x"], ["a", "b"]))


class FindSharedHeadingsTest(unittest.TestCase):
    def test_flags_a_heading_written_across_the_catalog(self):
        # ja shipped 9791 entries prefixed with a heading from batching.
        entries = [(f"Source {index}", f"の特長\n訳{index}") for index in range(8)]

        headings = find_shared_headings(entries)

        self.assertIn("の特長", headings)
        self.assertEqual(len(headings["の特長"]), 8)

    def test_ignores_single_line_translations(self):
        entries = [(f"Source {index}", "の特長") for index in range(8)]

        self.assertEqual(find_shared_headings(entries), {})

    def test_ignores_headings_the_sources_also_have(self):
        entries = [(f"Usage:\narg {index}", f"Usage:\nargumento {index}") for index in range(8)]

        self.assertEqual(find_shared_headings(entries), {})

    def test_ignores_reuse_below_threshold(self):
        entries = [(f"Source {index}", f"Titulo\ncorpo {index}") for index in range(3)]

        self.assertEqual(find_shared_headings(entries), {})


class FindCollapsesTest(unittest.TestCase):
    def test_flags_one_translation_serving_many_sources(self):
        # ko: 275 distinct msgids all became "이름 *"
        entries = [(f"source {index}", "이름 *") for index in range(6)]

        collapses = find_collapses(entries)

        self.assertIn("이름 *", collapses)
        self.assertEqual(len(collapses["이름 *"]), 6)

    def test_ignores_reuse_below_threshold(self):
        entries = [(f"source {index}", "Menu") for index in range(4)]

        self.assertEqual(find_collapses(entries), {})

    def test_ignores_repeated_identical_sources(self):
        entries = [("Menu", "Menü")] * 10

        self.assertEqual(find_collapses(entries), {})

    def test_ignores_empty_translations(self):
        entries = [(f"source {index}", "") for index in range(10)]

        self.assertEqual(find_collapses(entries), {})


class InventedBreakTest(unittest.TestCase):
    """A single-line source that came back as two lines.

    Found in `ja/diagrams.po`: Argos prefixed one entry with シリーズ
    ("series"). `find_shared_headings` needs the same heading on several
    entries before it will act, so one occurrence shipped.
    """

    def test_drops_a_short_heading_the_model_prefixed(self):
        self.assertEqual(
            invented_break(
                "A miniature of the list that shows these.",
                "シリーズ\nこれらのリストのミニチュア。",
            ),
            "これらのリストのミニチュア。",
        )

    def test_rejoins_a_sentence_the_model_split(self):
        self.assertEqual(
            invented_break(
                "People reach the bot by its name and its prefix.",
                "Die Menschen erreichen den Bot\nmit seinem Namen.",
            ),
            "Die Menschen erreichen den Bot mit seinem Namen.",
        )

    def test_leaves_a_single_line_translation_alone(self):
        self.assertIsNone(invented_break("One line in", "Uma linha dentro"))

    def test_leaves_a_break_the_source_asked_for(self):
        self.assertIsNone(invented_break("First\nSecond", "Primeiro\nSegundo"))

    def test_leaves_an_empty_translation_to_the_other_gates(self):
        self.assertIsNone(invented_break("Anything", ""))

    def test_a_long_first_line_is_content_not_a_heading(self):
        source = "The bot answers a prefix."
        translated = "Der Bot antwortet auf ein Präfix\nund nichts sonst."

        self.assertEqual(
            invented_break(source, translated),
            "Der Bot antwortet auf ein Präfix und nichts sonst.",
        )


class LostNegationTest(unittest.TestCase):
    """A source that says "cannot" whose translation says nothing of the kind.

    The one failure every other guard passes: the output is a well-formed
    sentence, so collapse, degeneration and residue all see a healthy entry.
    Found in the shipped catalogues on the line that precedes wiping the
    server — "THIS CANNOT BE UNDONE" reached German as "DIESER KANNES" and
    "Das ist alles", and Japanese turned "No active server bans" into a
    sentence saying there is one.
    """

    def test_catches_a_negation_the_model_dropped(self):
        self.assertTrue(
            lost_negation("THIS CANNOT BE UNDONE", "DIESER KANNES", "de")
        )

    def test_accepts_a_translation_that_negates(self):
        self.assertFalse(
            lost_negation(
                "THIS CANNOT BE UNDONE",
                "Dies kann nicht rückgängig gemacht werden",
                "de",
            )
        )

    def test_accepts_the_impossible_family(self):
        # French and the Romance locales negate with "impossible", which is a
        # negation without a negative particle.
        self.assertFalse(
            lost_negation("Cannot ban a user", "Impossible de bannir un utilisateur", "fr")
        )

    def test_accepts_a_japanese_inflection(self):
        self.assertFalse(
            lost_negation("You cannot write", "書くことができません", "ja")
        )

    def test_nothing_but_means_only_and_is_not_a_negation(self):
        source = "somebody reading a busy channel may want nothing but the words."

        self.assertFalse(lost_negation(source, "может хотеть одних лишь слов.", "ru"))
        self.assertFalse(lost_negation(source, "może chcieć wyłącznie słów.", "pl"))
        # "Nothing" on its own still is one.
        self.assertTrue(lost_negation("Nothing was saved.", "Все сохранено.", "ru"))

    def test_ignores_a_source_with_no_negation(self):
        self.assertFalse(lost_negation("Open in a new tab", "Neuer Tab", "de"))

    def test_ignores_a_bare_no(self):
        # "No topic set" is rendered a dozen ways that carry the sense without
        # a marker; flagging them all would bury the ones that matter.
        self.assertFalse(lost_negation("No topic set", "Sem tópico", "pt_BR"))

    def test_ignores_an_empty_translation(self):
        self.assertFalse(lost_negation("Cannot do that", "", "de"))

    def test_does_not_judge_a_locale_with_no_marker_table(self):
        self.assertFalse(lost_negation("Cannot do that", "whatever", "xx"))

    def test_catches_a_typographic_contraction(self):
        # The home page's own headline. The first version of this guard listed
        # only can't and won't and matched only the ASCII apostrophe, so this
        # reached ten locales saying the community *is* yours.
        self.assertTrue(
            lost_negation("Your community isn’t yours.", "A tua comunidade é tua.", "pt_BR")
        )

    def test_catches_an_ascii_contraction(self):
        # Same sentence, ASCII apostrophe: both spellings have to be seen.
        self.assertTrue(
            lost_negation("Your community isn't yours.", "Tu comunidad es tuya.", "es")
        )

    def test_catches_a_contraction_in_the_middle_of_a_sentence(self):
        # landing.po, eleven locales: the claim the whole privacy story rests
        # on, reaching pt_BR as "if a direct connection *is* possible".
        self.assertTrue(
            lost_negation(
                "If a direct connection isn’t possible (strict firewalls), a",
                "Se uma conexão directa for possível (firewalls restritos), a",
                "pt_BR",
            )
        )

    def test_accepts_a_german_prefix_negation(self):
        # chat.po: "ungelesen" is how German negates this, with no "nicht" in
        # sight. Missing it is what made the guard cry wolf and earned a
        # baseline instead of a fix.
        self.assertFalse(
            lost_negation(
                "Jump to the first message you have not read",
                "Zur ersten ungelesenen Nachricht springen",
                "de",
            )
        )

    def test_accepts_a_russian_prefix_negation(self):
        # chat.po: "непрочитанному" carries the negation as a prefix, which a
        # right word boundary on "не" cannot see.
        self.assertFalse(
            lost_negation(
                "Jump to the first message you have not read",
                "Перейти к первому непрочитанному сообщению",
                "ru",
            )
        )

    def test_accepts_a_french_prefix_negation(self):
        # chat.po: "introuvable" is the idiomatic French for this.
        self.assertFalse(
            lost_negation("That message could not be found.", "Ce message est introuvable.", "fr")
        )

    def test_accepts_a_japanese_prefix_negation(self):
        # diagrams.po: 未選択 is "unselected"; the marker table had 不 and 無
        # but not 未.
        self.assertFalse(
            lost_negation(
                "A miniature of a list of choices. Nothing is selected yet.",
                "選択肢のリストのミニチュア。 未選択です。",
                "ja",
            )
        )


class EntityResidueTest(unittest.TestCase):
    """A translation printing an HTML entity's letters at the reader.

    The other half of the escaping asymmetry that eats negations: the engine
    HTML-escapes the source before translating and never unescapes the result.
    Measured in the shipped catalogues, `& mdash;` alone accounted for 91
    occurrences, and every damaged entry's msgid held a `&`, `’` or `“`.
    """

    def test_catches_a_spaced_named_entity(self):
        # landing.po, es: "Step 1 — Clone".
        self.assertTrue(has_entity_residue("Step 1 — Clone", "Paso 1 & mdash; Clone"))

    def test_catches_a_spaced_numeric_entity(self):
        # landing.po, es: "💻 Contribute code".
        self.assertTrue(
            has_entity_residue("💻 Contribute code", "& #x1F4BB; Gentileza de código")
        )

    def test_catches_a_spaced_entity_even_when_the_source_has_markup(self):
        # A space inside an entity is never markup, whatever the msgid holds.
        self.assertTrue(has_entity_residue("Admin &amp; Server", "Administración & amp; Servidor"))

    def test_catches_an_unspaced_entity_the_source_never_had(self):
        # emoji.po, es: "Smileys & Emotion" came back escaped.
        self.assertTrue(has_entity_residue("Smileys & Emotion", "Smileys &amp; Emotion"))

    def test_allows_markup_the_source_asked_for(self):
        # Landing and help msgids do legitimately carry entities; an unspaced
        # one that the source also has is the markup the writer meant.
        self.assertFalse(has_entity_residue("Admin &amp; Server", "Administración &amp; Servidor"))

    def test_ignores_a_clean_translation(self):
        self.assertFalse(has_entity_residue("Step 1 — Clone", "Paso 1 — Clonar"))

    def test_ignores_an_empty_translation(self):
        self.assertFalse(has_entity_residue("Smileys & Emotion", ""))

    def test_ignores_an_ampersand_that_opens_no_entity(self):
        # An accelerator marker or a bare conjunction is not an entity.
        self.assertFalse(has_entity_residue("Cut & paste", "Cortar & pegar"))


if __name__ == "__main__":
    unittest.main()


class MeaningKeptTest(unittest.TestCase):
    """Round trip: the translation read back into English. The pairs are what
    the engines returned for the mIRC guide pages."""

    def test_a_faithful_reading_keeps_the_meaning(self):
        from i18n.quality import meaning_kept

        self.assertTrue(
            meaning_kept(
                "Any free nickname gets you in. To keep it, register it with NickServ.",
                "Any free nickname will get you in. To keep it, register with NickServ.",
            )
        )

    def test_a_different_sentence_does_not(self):
        from i18n.quality import meaning_kept

        self.assertFalse(
            meaning_kept(
                "+ voiced users, who can speak when the room is moderated.",
                "+ I asked the user to speak properly.",
            )
        )

    def test_short_labels_are_not_judged(self):
        from i18n.quality import meaning_kept

        self.assertTrue(meaning_kept("Games you can play here", "Playable Games"))

    def test_commands_neither_help_nor_hurt(self):
        from i18n.quality import meaning_kept

        self.assertFalse(
            meaning_kept(
                "The nick list beside every channel shows who is there. /names",
                "A list of new features next to all things. /names",
            )
        )

    def test_a_correct_paraphrase_is_kept(self):
        from i18n.quality import meaning_kept

        # French "définir le sujet" for "set the topic", read back literally.
        self.assertTrue(
            meaning_kept(
                "@ operators, who set the topic, the modes, and who stays.",
                "@ operators, who have defined the subject, the modes, and who remain.",
            )
        )


class LostNegationOfEnglishTest(unittest.TestCase):
    def test_an_entry_left_in_english_has_lost_nothing(self):
        from i18n.quality import lost_negation

        self.assertFalse(lost_negation("Free, nothing to install", "Free, nothing to install", "id"))


class JapaneseFreeIsNotNegationTest(unittest.TestCase):
    def test_free_of_charge_does_not_carry_the_negation(self):
        from i18n.quality import lost_negation

        self.assertTrue(lost_negation("Free of charge, nothing to install", "無料でインストールする", "ja"))
        self.assertFalse(lost_negation("Free of charge, nothing to install", "無料、インストール不要", "ja"))
