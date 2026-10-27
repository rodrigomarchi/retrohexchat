"""Hex Sudoku's atlas: every picture the game draws, inside the sheet, versioned."""

from __future__ import annotations

import importlib.util
import json
import os
import unittest

BUILDER = os.path.join(
    os.path.dirname(__file__), "..", "..", "apps", "retro_hex_chat_web", "assets", "art", "sudoku", "build_tiles.py"
)
_spec = importlib.util.spec_from_file_location("sudoku_tiles", BUILDER)
tiles = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tiles)

DIGITS = range(1, 10)
NAMES = (
    [f"{ink}_{n}" for ink in ("given", "mine", "wrong", "hint") for n in DIGITS]
    + [f"{kind}_{n}" for kind in ("note", "key", "spent") for n in DIGITS]
    + ["pencil", "pencil_on", "eraser", "bulb", "undo", "colon", "cross", "lamp"]
    + [f"digit_{d}" for d in "0123456789"]
)


def overlap(a, b):
    return a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"] and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"]


class AtlasTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sheet, cls.description = tiles.build_atlas()

    def test_it_holds_every_picture_the_game_draws(self):
        regions = self.description["regions"]
        self.assertEqual(sorted(regions), sorted(NAMES))
        for name in ["given_1", "mine_9", "note_5"]:
            self.assertEqual((regions[name]["w"], regions[name]["h"]), (16, 16), name)
        for name in ["key_1", "spent_9", "pencil", "undo"]:
            self.assertEqual((regions[name]["w"], regions[name]["h"]), (24, 24), name)

    def test_every_region_lies_inside_the_sheet_and_apart(self):
        regions = list(self.description["regions"].values())
        for i, a in enumerate(regions):
            self.assertTrue(a["x"] >= 0 and a["y"] >= 0)
            self.assertTrue(a["x"] + a["w"] <= self.sheet.width and a["y"] + a["h"] <= self.sheet.height)
            for b in regions[i + 1 :]:
                self.assertFalse(overlap(a, b), (a, b))

    def test_each_ink_draws_its_digit_in_its_own_colour(self):
        for name, ink in tiles.INKS.items():
            for n in DIGITS:
                self.assertIn(ink, set(tiles.square(n, ink).getdata()), (name, n))

    def test_a_note_sits_in_its_own_ninth_of_the_square(self):
        def box(n):
            return tiles.note(n).getbbox()

        for n in DIGITS:
            left, top, right, bottom = box(n)
            col, row = (n - 1) % 3, (n - 1) // 3
            self.assertTrue(col * 5 < left and right <= col * 5 + 6, n)
            self.assertTrue(row * 5 <= top and bottom <= row * 5 + 6, n)

    def test_the_nine_reads_as_the_six_turned_round(self):
        self.assertEqual(tiles.GLYPHS[9][0], tiles.GLYPHS[6][-1][::-1])
        self.assertNotEqual(tiles.GLYPHS[9], tiles.GLYPHS[6])


class VersionTest(unittest.TestCase):
    def test_each_address_names_the_version_of_what_it_serves(self):
        with open(os.path.join(tiles.OUTPUT, "tiles.json"), "rb") as f:
            text = f.read()
        name, vsn = json.loads(text)["image"].split("?vsn=")
        with open(os.path.join(tiles.OUTPUT, name), "rb") as f:
            self.assertEqual(vsn, tiles.version(f.read()))
        with open(tiles.PROTOCOL_JS, encoding="utf-8") as f:
            match = tiles.TILES_URL_RE.search(f.read())
        self.assertIsNotNone(match)
        self.assertIn(f"vsn={tiles.version(text)}", match.group(0))


if __name__ == "__main__":
    unittest.main()
