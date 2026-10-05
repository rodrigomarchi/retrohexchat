"""Plural forms translated as the sentences they render.

The regression: `%{count} game` reached the model masked, and it came back as
"Jeu %{count}" in French, "%{count}-spel" in Dutch and with one word for all
three Polish forms. Each slot is now translated with a number that falls in it.
"""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path
from types import SimpleNamespace

from i18n import locales, numerals

SCRIPT = Path(__file__).resolve().parents[1] / "i18n_machine_translate_po.py"
_spec = importlib.util.spec_from_file_location("machine_translate_po_numerals", SCRIPT)
machine_translate_po = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(machine_translate_po)

RUSSIAN = (
    "nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 "
    "&& (n%100<12 || n%100>14) ? 1 : 2);"
)


class PluralRuleTest(unittest.TestCase):
    def test_evaluates_the_russian_rule(self):
        _nplurals, rule = numerals.parse_plural_forms(RUSSIAN)

        expected = {1: 0, 21: 0, 2: 1, 4: 1, 22: 1, 5: 2, 11: 2, 12: 2, 14: 2, 25: 2, 111: 2}

        for n, slot in expected.items():
            with self.subTest(n=n):
                self.assertEqual(rule(n), slot)

    def test_french_counts_zero_and_one_as_singular(self):
        _nplurals, rule = numerals.parse_plural_forms("nplurals=2; plural=(n > 1);")

        self.assertEqual([rule(0), rule(1), rule(2)], [0, 0, 1])

    def test_every_registered_rule_parses_and_reaches_every_slot(self):
        for locale in locales.translatable_locales():
            with self.subTest(locale=locale.code):
                nplurals, rule = numerals.parse_plural_forms(locale.plural_forms)
                samples = [numerals.sample_number(locale.plural_forms, i) for i in range(nplurals)]

                if nplurals > 1:
                    self.assertEqual([rule(n) for n in samples], list(range(nplurals)))

    def test_sample_numbers_read_naturally(self):
        self.assertEqual([numerals.sample_number(RUSSIAN, i) for i in range(3)], [1, 2, 5])
        self.assertEqual(numerals.sample_number("nplurals=2; plural=(n != 1);", 1), 2)
        # A one-form language is shown a plural, never "1 games".
        self.assertEqual(numerals.sample_number("nplurals=1; plural=0;", 0), 5)

    def test_relational_binds_tighter_than_equality_as_in_c(self):
        # C reads `n == 1 < 2` as `n == (1 < 2)`, which is `n == 1`.
        _nplurals, rule = numerals.parse_plural_forms("nplurals=2; plural=(n == 1 < 2);")

        self.assertEqual([rule(0), rule(1), rule(2)], [0, 1, 0])

    def test_reaches_a_slot_only_zero_falls_in(self):
        latvian = "nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n != 0 ? 1 : 2);"

        self.assertEqual([numerals.sample_number(latvian, i) for i in range(3)], [1, 2, 0])

    def test_rejects_what_is_not_a_rule(self):
        with self.assertRaises(ValueError):
            numerals.parse_plural_forms("plural=n")


class NumeralRoundTripTest(unittest.TestCase):
    def test_writes_the_count_as_a_number(self):
        self.assertEqual(numerals.as_numeral("%{count} games", 5), "5 games")

    def test_leaves_alone_a_source_with_no_count_or_two(self):
        self.assertIsNone(numerals.as_numeral("%{name} games", 5))
        self.assertIsNone(numerals.as_numeral("%{count} of %{count}", 5))

    def test_turns_the_number_back_into_the_placeholder(self):
        self.assertEqual(numerals.from_numeral("5 игр", 5), "%{count} игр")
        self.assertEqual(numerals.from_numeral("5 個のゲーム", 5), "%{count} 個のゲーム")

    def test_refuses_a_number_that_is_gone_repeated_or_part_of_another(self):
        self.assertIsNone(numerals.from_numeral("um jogo", 1))
        self.assertIsNone(numerals.from_numeral("5 jogos em 5 salas", 5))
        self.assertIsNone(numerals.from_numeral("15 jogos", 5))
        self.assertIsNone(numerals.from_numeral("5.5 jogos", 5))
        # The start of a longer number is not the number.
        self.assertIsNone(numerals.from_numeral("55 jogos", 5))
        self.assertIsNone(numerals.from_numeral("50 games", 5))


class PluralRepairTest(unittest.TestCase):
    """Repair only lands where it removes a mechanical defect, because a
    retranslation rewrites the whole sentence: run over every plural, it fixed
    "Heures %{count}" and also turned "Ouvrir le fil" into "Thème ouvert"."""

    def test_flags_a_count_moved_after_the_noun(self):
        self.assertEqual(
            numerals.plural_defects(["%{count} heure", "Heures %{count}"], "%{count} hour", 2),
            {"order"},
        )

    def test_a_one_form_language_places_the_count_freely(self):
        self.assertEqual(numerals.plural_defects(["スペースに%{count}人"], "%{count} in the space", 1), set())

    def test_a_source_not_led_by_the_count_is_never_an_order_defect(self):
        forms = ["Ouvrir le fil (%{count} réponse)", "Ouvrir le fil (%{count} réponses)"]
        self.assertEqual(numerals.plural_defects(forms, "Open Thread (%{count} reply)", 2), set())

    def test_flags_collapsed_few_and_many(self):
        forms = ["%{count} час", "%{count} часы", "%{count} часы"]
        self.assertEqual(numerals.plural_defects(forms, "%{count} hour", 3), {"collapsed"})

    def test_a_fix_wins(self):
        self.assertTrue(
            numerals.repair_wins(
                ["%{count} час", "%{count} часы", "%{count} часы"],
                ["%{count} час", "%{count} часа", "%{count} часов"],
                "%{count} hour",
                3,
            )
        )

    def test_a_repair_that_fixes_nothing_keeps_the_old_wording(self):
        # Polish really says "2 dni" and "5 dni": the retranslation agrees, so
        # nothing is gained and the current text stays.
        old = ["%{count} dzień", "%{count} dni", "%{count} dni"]
        self.assertFalse(numerals.repair_wins(old, list(old), "%{count} day", 3))

    def test_a_sentence_is_never_repaired(self):
        # Retranslating the sentence fixed the forms and broke the words around
        # them: Polish "muted" came back as "damaged".
        self.assertFalse(numerals.repairable("%{actor} muted %{count} conference microphone."))
        self.assertFalse(
            numerals.repair_wins(
                ["Otwórz wątek (%{count} odpowiedź)"] + ["Otwórz wątek (%{count} odpowiedzi)"] * 2,
                [
                    "Otwórz wątek (%{count} odpowiedź)",
                    "Otwórz wątek (%{count} replies)",
                    "Otwórz wątek (%{count} odpowiedzi)",
                ],
                "Open Thread (%{count} reply)",
                3,
            )
        )

    def test_forms_that_count_different_words_lose(self):
        self.assertFalse(
            numerals.repair_wins(
                ["Entrée %{count}", "Entrées %{count}"],
                ["%{count} entrée", "%{count} rubriques"],
                "%{count} entry",
                2,
            )
        )
        self.assertFalse(
            numerals.repair_wins(
                ["%{count} в пространстве"] * 3,
                ["%{count} в пространстве", "%{count} в пространстве", "%{count} В космосе"],
                "%{count} in the space",
                3,
            )
        )

    def test_the_slavic_forms_of_one_word_agree(self):
        self.assertTrue(
            numerals.repair_wins(
                ["%{count} gra", "%{count} gry", "%{count} gry"],
                ["%{count} gra", "%{count} gry", "%{count} gier"],
                "%{count} game",
                3,
                "%{count} games",
            )
        )

    def test_the_english_source_never_wins(self):
        # The pipeline keeps the source when a model fails; it has no "order"
        # defect, and is still worse than any French.
        self.assertFalse(
            numerals.repair_wins(
                ["Heures %{count}", "Heures %{count}"],
                ["%{count} hour", "%{count} hours"],
                "%{count} hour",
                2,
                "%{count} hours",
            )
        )

    def test_a_repair_that_adds_a_defect_loses(self):
        self.assertFalse(
            numerals.repair_wins(
                ["%{count} heure", "Heures %{count}"],
                ["Heure %{count}", "Heures %{count}"],
                "%{count} hour",
                2,
            )
        )


class PluralLookupTest(unittest.TestCase):
    """The script's own path: what it sends, and what it writes back."""

    def locale(self, plural_forms: str, code: str = "pl"):
        return SimpleNamespace(code=code, plural_forms=plural_forms, one_form=False)

    def test_each_slot_comes_from_its_own_numeral(self):
        locale = self.locale(
            "nplurals=3; plural=(n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<12 || n%100>14) ? 1 : 2);"
        )
        cache = {
            machine_translate_po.cache_key("pl", "1 game"): "1 gra",
            machine_translate_po.cache_key("pl", "2 games"): "2 gry",
            machine_translate_po.cache_key("pl", "5 games"): "5 gier",
        }

        forms = [
            machine_translate_po.plural_lookup(cache, locale, 0, "%{count} game"),
            machine_translate_po.plural_lookup(cache, locale, 1, "%{count} games"),
            machine_translate_po.plural_lookup(cache, locale, 2, "%{count} games"),
        ]

        self.assertEqual(forms, ["%{count} gra", "%{count} gry", "%{count} gier"])

    def test_falls_back_to_the_masked_source_when_the_number_is_lost(self):
        locale = self.locale("nplurals=2; plural=(n > 1);", code="fr")
        cache = {
            machine_translate_po.cache_key("fr", "1 game"): "un jeu",
            machine_translate_po.cache_key("fr", "%{count} game"): "%{count} jeu",
        }

        self.assertEqual(
            machine_translate_po.plural_lookup(cache, locale, 0, "%{count} game"), "%{count} jeu"
        )

    def test_an_english_numeral_is_a_miss_not_a_result(self):
        locale = self.locale("nplurals=2; plural=(n > 1);", code="fr")
        cache = {
            machine_translate_po.cache_key("fr", "1 hour"): "1 hour",
            machine_translate_po.cache_key("fr", "%{count} hour"): "%{count} heure",
        }

        self.assertEqual(
            machine_translate_po.plural_lookup(cache, locale, 0, "%{count} hour"), "%{count} heure"
        )

    def test_a_named_msgid_is_retranslated_though_it_has_a_translation(self):
        entry = SimpleNamespace(msgid="%{count} game", msgid_plural="%{count} games", flags=[])

        self.assertFalse(
            machine_translate_po.needs_translation("Jeu %{count}", "%{count} game", entry, False, False)
        )
        self.assertTrue(
            machine_translate_po.needs_translation(
                "Jeu %{count}", "%{count} game", entry, False, False, frozenset({"%{count} game"})
            )
        )


if __name__ == "__main__":
    unittest.main()


class RepairPathTest(unittest.TestCase):
    """The script's repair mode: what it touches, what it leaves, what it writes."""

    POLISH = "nplurals=3; plural=(n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<12 || n%100>14) ? 1 : 2);"

    def locale(self):
        return SimpleNamespace(code="pl", plural_forms=self.POLISH, one_form=False)

    def entry(self, msgid, forms, flags=None):
        return SimpleNamespace(
            msgid=msgid,
            msgid_plural=msgid + "s",
            msgstr="",
            msgstr_plural=dict(enumerate(forms)),
            flags=list(flags or []),
            obsolete=False,
            msgctxt=None,
        )

    def cache(self, **translations):
        return {machine_translate_po.cache_key("pl", k): v for k, v in translations.items()}

    def test_a_defective_short_phrase_is_repaired_and_unfuzzied(self):
        entry = self.entry("%{count} hour", ["%{count} godzina", "%{count} godziny", "%{count} godziny"], ["fuzzy"])
        cache = self.cache(**{"1 hour": "1 godzina", "2 hours": "2 godziny", "5 hours": "5 godzin"})

        self.assertTrue(machine_translate_po.needs_plural_repair(entry, self.locale()))
        self.assertEqual(machine_translate_po.repair_plural(entry, self.locale(), cache), 3)
        self.assertEqual(
            list(entry.msgstr_plural.values()),
            ["%{count} godzina", "%{count} godziny", "%{count} godzin"],
        )
        self.assertNotIn("fuzzy", entry.flags)

    def test_a_sound_entry_is_not_a_candidate(self):
        entry = self.entry("%{count} hour", ["%{count} godzina", "%{count} godziny", "%{count} godzin"])

        self.assertFalse(machine_translate_po.needs_plural_repair(entry, self.locale()))

    def test_a_sentence_is_not_a_candidate(self):
        entry = self.entry("%{actor} muted %{count} microphone.", ["a %{count} b", "a %{count} c", "a %{count} c"])

        self.assertFalse(machine_translate_po.needs_plural_repair(entry, self.locale()))

    def test_a_repair_that_loses_leaves_the_entry_alone(self):
        forms = ["%{count} godzina", "%{count} godziny", "%{count} godziny"]
        entry = self.entry("%{count} hour", forms)
        # The model failed every numeral: the source comes back, and loses.
        cache = self.cache(**{"1 hour": "1 hour", "2 hours": "2 hours", "5 hours": "5 hours"})

        self.assertEqual(machine_translate_po.repair_plural(entry, self.locale(), cache), 0)
        self.assertEqual(list(entry.msgstr_plural.values()), forms)

    def test_repair_mode_leaves_unrelated_empty_entries_for_another_run(self):
        po = [
            self.entry("%{count} hour", ["%{count} godzina", "%{count} godziny", "%{count} godziny"]),
            SimpleNamespace(msgid="Unrelated", msgid_plural="", msgstr="", msgstr_plural={}, flags=[], obsolete=False, msgctxt=None),
        ]

        pending = machine_translate_po.collect_pending(po, self.locale(), {}, False, False, frozenset(), True)

        self.assertNotIn("Unrelated", pending)
        self.assertIn("5 hours", pending)
