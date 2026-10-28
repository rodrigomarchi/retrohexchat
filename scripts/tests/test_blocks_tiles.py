"""Hex Blocks' atlas: every picture the game draws, the gems tiling the honeycomb, versioned."""

from __future__ import annotations

import collections
import importlib.util
import json
import os
import unittest

BUILDER = os.path.join(
    os.path.dirname(__file__), "..", "..", "apps", "retro_hex_chat_web", "assets", "art", "blocks", "build_tiles.py"
)
_spec = importlib.util.spec_from_file_location("blocks_tiles", BUILDER)
tiles = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tiles)

COLOURS = ["red", "orange", "yellow", "lime", "green", "teal", "cyan", "blue", "violet", "pink"]
NAMES = (
    [f"gem_{c}" for c in COLOURS]
    + ["empty", "ghost", "flash"]
    + ["keep"]
    + [f"digit_{d}" for d in "0123456789"]
    + ["colon", "dot", "level", "lines"]
)


def overlap(a, b):
    return a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"] and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"]


class HexagonTest(unittest.TestCase):
    def test_the_cell_tiles_the_well_without_a_gap_or_an_overlap(self):
        covered = collections.Counter()
        for col in range(6):
            for row in range(6):
                ox, oy = col * tiles.STEP, row * tiles.H + (tiles.H // 2 if col % 2 else 0)
                for y in range(tiles.H):
                    for x in range(tiles.W):
                        if tiles.MASK[y][x]:
                            covered[(ox + x, oy + y)] += 1
        inner = [(x, y) for x in range(30, 80) for y in range(30, 90)]
        self.assertEqual([p for p in inner if covered[p] != 1], [])

    def test_the_colours_follow_the_pieces(self):
        # pieces.js names a colour for each kind in this order; the atlas holds one gem each.
        self.assertEqual(list(tiles.RAMPS), COLOURS)


class AtlasTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sheet, cls.description = tiles.build_atlas()

    def test_it_holds_every_picture_the_game_draws(self):
        regions = self.description["regions"]
        self.assertEqual(sorted(regions), sorted(NAMES))
        for name in [f"gem_{c}" for c in COLOURS] + ["empty", "ghost", "flash"]:
            self.assertEqual((regions[name]["w"], regions[name]["h"]), (24, 20), name)
        self.assertEqual((regions["keep"]["w"], regions["keep"]["h"]), (24, 24))
        self.assertEqual(self.description["cell"], [24, 20])
        self.assertEqual(self.description["step"], 18)

    def test_a_gem_covers_its_hexagon_and_nothing_else(self):
        art = tiles.source()
        for colour, ramp in tiles.RAMPS.items():
            gem = tiles.gem(art, ramp)
            for y in range(tiles.H):
                for x in range(tiles.W):
                    self.assertEqual(gem.getpixel((x, y))[3] > 0, tiles.MASK[y][x], (colour, x, y))

    def test_a_gem_is_drawn_in_its_own_colours_only(self):
        art = tiles.source()
        for colour, ramp in tiles.RAMPS.items():
            used = {p for p in tiles.gem(art, ramp).getdata() if p[3] > 0}
            self.assertTrue(used <= {tiles.rgba(c) for c in ramp}, colour)
            self.assertGreaterEqual(len(used), 4, colour)

    def test_every_region_lies_inside_the_sheet_and_apart(self):
        regions = list(self.description["regions"].values())
        for i, a in enumerate(regions):
            self.assertTrue(a["x"] >= 0 and a["y"] >= 0)
            self.assertTrue(a["x"] + a["w"] <= self.sheet.width and a["y"] + a["h"] <= self.sheet.height)
            for b in regions[i + 1 :]:
                self.assertFalse(overlap(a, b), (a, b))


class VersionTest(unittest.TestCase):
    def test_each_address_names_the_version_of_what_it_serves(self):
        with open(os.path.join(tiles.OUTPUT, "tiles.json"), "rb") as f:
            text = f.read()
        name, vsn = json.loads(text)["image"].split("?vsn=")
        with open(os.path.join(tiles.OUTPUT, name), "rb") as f:
            self.assertEqual(vsn, tiles.atlas_kit.version(f.read()))
        with open(tiles.PROTOCOL_JS, encoding="utf-8") as f:
            match = tiles.TILES_URL_RE.search(f.read())
        self.assertIsNotNone(match)
        self.assertIn(f"vsn={tiles.atlas_kit.version(text)}", match.group(0))


if __name__ == "__main__":
    unittest.main()
