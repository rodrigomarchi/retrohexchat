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
    introduced_degeneration,
    is_degenerate,
    is_usable_translation,
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


if __name__ == "__main__":
    unittest.main()
