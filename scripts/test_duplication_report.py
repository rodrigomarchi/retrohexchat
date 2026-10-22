"""Tests for the pure parts of scripts/duplication_report.py (no mix, no npx)."""

import unittest

import duplication_report as dr


class CensusTest(unittest.TestCase):
    def test_private_helper_in_three_modules_is_reported_with_public_namesake(self):
        sources = [
            ("a.ex", "defp blank_to_nil(nil), do: nil\ndefp blank_to_nil(v), do: v\n"),
            ("b.ex", "  defp blank_to_nil(value) do\n    value\n  end\n"),
            ("c.ex", "defp blank_to_nil(x), do: x"),
            ("d.ex", "def blank_to_nil(x), do: x"),
        ]
        [row] = dr.census(sources)
        self.assertEqual(row["helper"], "blank_to_nil/1")
        self.assertEqual(row["copies"], 3)
        self.assertEqual(row["files"], ["a.ex", "b.ex", "c.ex"])
        self.assertEqual(row["public"], ["d.ex"])

    def test_arity_separates_helpers_and_callbacks_are_skipped(self):
        sources = [(f"{n}.ex", "defp fetch(a, b), do: a\ndefp fetch(a), do: a\ndefp mount(s), do: s") for n in "abc"]
        sources.append(("d.ex", "defp fetch(a), do: a"))
        rows = {r["helper"]: r["copies"] for r in dr.census(sources)}
        self.assertEqual(rows, {"fetch/1": 4, "fetch/2": 3})

    def test_below_minimum_is_not_reported(self):
        sources = [("a.ex", "defp once(x), do: x"), ("b.ex", "defp once(x), do: x")]
        self.assertEqual(dr.census(sources), [])


class CompareTest(unittest.TestCase):
    def test_flatten_keeps_numbers_and_counts(self):
        report = {
            "exdna_exact": {"clones": 68, "top": [{"mass": 1}]},
            "census": [{"copies": 3}, {"copies": 5}],
            "markers": {"topic_strings_by_hand": {"count": 9, "sites": []}},
        }
        self.assertEqual(
            dr.flatten(report),
            {
                "exdna_exact.clones": 68,
                "census.helpers": 2,
                "census.copies": 8,
                "marker.topic_strings_by_hand": 9,
            },
        )

    def test_delta_against_previous_and_first_run(self):
        now = {"a": 10, "b": 4, "c": 1}
        self.assertEqual(
            dr.delta_rows(now, {"a": 12, "b": 4}),
            [("a", 10, 12, "-2"), ("b", 4, 4, "0"), ("c", 1, "", "")],
        )
        self.assertEqual(dr.delta_rows({"a": 1}, None), [("a", 1, "", "")])

    def test_games_split(self):
        game = "apps/retro_hex_chat_web/assets/js/lib/games/pong/engine.js"
        other = "apps/retro_hex_chat_web/assets/js/hooks/ui/nicklist_hook.js"
        self.assertEqual(dr.games_split(game, game.replace("pong", "warlords")), "games")
        self.assertEqual(dr.games_split(game, other), "other")


if __name__ == "__main__":
    unittest.main()
