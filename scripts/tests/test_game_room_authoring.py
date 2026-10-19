"""The Game Room: the Construct's platform furnished for play, written the same
every time."""

from __future__ import annotations

import json
import os
import sys
import unittest

TOOLS = os.path.join(os.path.dirname(__file__), "..", "..", "virtual.space", "tools")
sys.path.insert(0, os.path.abspath(TOOLS))

import author_game_room as ag  # noqa: E402
import furnished_room as fr  # noqa: E402

P = ag.PLAN
MAPS = os.path.join(os.path.dirname(__file__), "..", "..", "apps", "retro_hex_chat", "priv", "maps")


def _load(name):
    with open(os.path.join(MAPS, f"{name}.json")) as handle:
        return json.load(handle)


class GameRoomMapTest(unittest.TestCase):
    def setUp(self):
        self.room = _load("game_room")
        self.construct = _load("construct")

    def test_it_is_built_from_the_construct_catalog_and_sheets(self):
        self.assertEqual(self.room["catalog"], self.construct["catalog"])
        self.assertEqual(self.room["vocab"], self.construct["vocab"])
        self.assertEqual(self.room["tilesets"], self.construct["tilesets"])

    def test_the_file_is_what_the_author_writes_now(self):
        catalog = self.construct["catalog"]
        self.assertEqual(self.room["fixed_items"], fr.fixed_items(P, catalog))
        self.assertEqual(self.room["floor"], fr.floor(P))

    def test_the_furniture_leaves_the_way_out_clear_and_every_tile_reachable(self):
        catalog = self.construct["catalog"]
        reserved = {tuple(t) for t in self.room["reserved"]}
        fr.validate(P, catalog, self.room["fixed_items"], P.exit, self.room["spawn"], reserved)

    def test_its_way_out_is_the_neon_door_back_to_the_end_of_time(self):
        exit_ = next(i for i in self.room["interactables"] if i["id"] == "game_room_exit")
        self.assertEqual((exit_["x"], exit_["y"]), P.exit)
        self.assertEqual(exit_["modal"]["action"], "exit_game_room")
        door = [d for d in self.room["decor"] if (d["x"], d["y"]) == P.exit]
        self.assertEqual([d["tile"] for d in door], ["cst_arcade_door"])
        self.assertIn("cst_arcade_door", self.room["vocab"])

    def test_its_arcade_cabinets_open_the_arcade(self):
        catalog = self.construct["catalog"]
        cabinets = [i for i in self.room["fixed_items"] if catalog[i["kind"]].get("use") == "arcade"]
        self.assertGreaterEqual(len(cabinets), 4)

    def test_every_cabinet_plays_a_game_of_its_own(self):
        cabinets = [i for i in self.room["fixed_items"] if i["kind"] in ("arcade", "racing_arcade")]
        games = [i.get("game") for i in cabinets]
        self.assertEqual(len(games), 8)
        self.assertTrue(all(games))
        self.assertEqual(len(set(games)), len(games))

    def test_a_piece_that_plays_no_game_cannot_be_given_one(self):
        catalog = self.construct["catalog"]
        plan = fr.Plan(**{**P.__dict__, "furniture": [("pool_table", 5, 9, "down", "hex_pong")]})
        with self.assertRaises(AssertionError):
            fr.fixed_items(plan, catalog)

    def test_its_floor_is_the_arcade_carpet_the_floor_tab_also_paints(self):
        char = next(m["tile"] for m in self.construct["materials"] if m["id"] == "carpet_arcade")
        self.assertTrue(any(char in row for row in self.room["floor"]))


class EndOfTimeDoorTest(unittest.TestCase):
    def test_the_neon_door_stands_beside_the_offices(self):
        eot = _load("end_of_time")
        portal = next(i for i in eot["interactables"] if i["id"] == "game_room_portal")
        self.assertEqual((portal["x"], portal["y"]), (39, 28))
        self.assertEqual(portal["modal"]["action"], "enter_game_room")
        self.assertTrue(any(d["tile"] == "eot_game_room_door" and (d["x"], d["y"]) == (39, 28)
                            for d in eot["decor"]))


class DoorArtTest(unittest.TestCase):
    # A door stands against the End of Time's railing: a transparent pixel
    # inside its outline lets the railing behind show through it.
    def test_the_doors_have_no_holes_inside_their_outline(self):
        from collections import deque

        from PIL import Image

        art = os.path.join(TOOLS, "..", "scenes", "construct")
        for name in ("door.png", "arcade_door.png"):
            im = Image.open(os.path.join(art, name)).convert("RGBA")
            w, h = im.size
            alpha = im.getchannel("A").load()
            outside = set()
            queue = deque([(x, y) for x in range(w) for y in (0, h - 1)]
                          + [(x, y) for y in range(h) for x in (0, w - 1)])
            while queue:
                x, y = queue.popleft()
                if (x, y) in outside or not (0 <= x < w and 0 <= y < h) or alpha[x, y]:
                    continue
                outside.add((x, y))
                queue.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
            holes = [(x, y) for y in range(h) for x in range(w)
                     if not alpha[x, y] and (x, y) not in outside]
            self.assertEqual(holes, [], name)


if __name__ == "__main__":
    unittest.main()
