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

    def test_arity_counts_only_top_level_commas(self):
        source = (
            "defp dispatch({:ok, a, b}, %{c: d, e: f}, opts), do: a\n"
            "defp dispatch(fun.(x, y), z), do: z\n"
            "defp settle(state, [h | t] = list, key \\\\ {:a, :b}), do: state\n"
        )
        rows = {r["helper"] for r in dr.census([(f"{n}.ex", source) for n in "abc"])}
        self.assertEqual(rows, {"dispatch/3", "dispatch/2", "settle/3"})

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


class DecidedClonesTest(unittest.TestCase):
    def test_disabled_ranges_read_both_markers(self):
        text = "a\n  # ex_dna:disable-for-lines:3 kept on purpose\nb\nc\nd\ne\n# ex_dna:disable-for-next-line why\nf\n"
        self.assertEqual(dr.disabled_ranges(text), [(3, 5), (8, 8)])

    def test_a_clone_inside_a_decided_range_is_set_aside_and_counted(self):
        report = {
            "statistics": {"total": {"lines": 100, "duplicatedLines": 18, "percentage": 18.0, "clones": 2}},
            "duplicates": [
                {"lines": 11, "firstFile": {"name": "a.ex", "start": 10, "end": 20},
                 "secondFile": {"name": "b.ex", "start": 1, "end": 11}},
                {"lines": 9, "firstFile": {"name": "c.ex", "start": 1, "end": 9},
                 "secondFile": {"name": "d.ex", "start": 1, "end": 9}},
            ],
        }
        summary = dr.jscpd_summary(report, 10, disabled={"a.ex": [(12, 30)]})
        self.assertEqual(summary["clones"], 1)
        self.assertEqual(summary["duplicated_lines"], 8)
        self.assertEqual(summary["decided_clones"], 1)
        self.assertEqual(summary["decided_lines"], 10)
        self.assertEqual(summary["duplicated_lines_raw"], 18)
        self.assertEqual([p["files"] for p in summary["top"]], [["c.ex", "d.ex"]])
