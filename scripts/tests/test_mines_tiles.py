"""Hex Mines' atlas: every picture the game draws, inside the sheet, versioned."""

from __future__ import annotations

import json
import os
import sys
import unittest

ART = os.path.join(os.path.dirname(__file__), "..", "..", "apps", "retro_hex_chat_web", "assets", "art", "mines")
sys.path.insert(0, os.path.abspath(ART))

import build_tiles as tiles  # noqa: E402

NAMES = (
    ["closed", "pressed", "open", "flag", "mine", "boom", "wrong", "dig", "mark"]
    + [f"n{n}" for n in range(1, 9)]
    + [f"face_{m}" for m in ("smile", "wow", "dead", "cool")]
    + [f"digit_{d}" for d in list("0123456789") + ["minus"]]
)


def overlap(a, b):
    return a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"] and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"]


class AtlasTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sheet, cls.description = tiles.build_atlas()

    def test_it_holds_every_picture_the_game_draws(self):
        self.assertEqual(sorted(self.description["regions"]), sorted(NAMES))
        for name in ["closed", "open", "flag", "mine", "n1", "n8"]:
            r = self.description["regions"][name]
            self.assertEqual((r["w"], r["h"]), (16, 16), name)

    def test_every_region_lies_inside_the_sheet_and_apart(self):
        regions = list(self.description["regions"].values())
        for i, a in enumerate(regions):
            self.assertTrue(a["x"] >= 0 and a["y"] >= 0)
            self.assertTrue(a["x"] + a["w"] <= self.sheet.width and a["y"] + a["h"] <= self.sheet.height)
            for b in regions[i + 1 :]:
                self.assertFalse(overlap(a, b), (a, b))

    def test_each_number_is_drawn_in_its_own_colour(self):
        for n in range(1, 9):
            colours = {p for p in tiles.number(n).getdata() if p == tiles.NUMBER_INK[n]}
            self.assertTrue(colours, n)

    def test_a_digit_lights_only_its_segments(self):
        one = tiles.digit("1")
        lit = sum(1 for p in one.getdata() if p == tiles.LED_ON)
        eight = sum(1 for p in tiles.digit("8").getdata() if p == tiles.LED_ON)
        self.assertLess(lit, eight)


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
