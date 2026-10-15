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

    def test_its_floor_is_the_arcade_carpet_the_floor_tab_also_paints(self):
        char = next(m["tile"] for m in self.construct["materials"] if m["id"] == "carpet_arcade")
        self.assertTrue(any(char in row for row in self.room["floor"]))


class EndOfTimeDoorTest(unittest.TestCase):
    def test_the_neon_door_stands_across_the_bridge_from_the_green_gate(self):
        eot = _load("end_of_time")
        portal = next(i for i in eot["interactables"] if i["id"] == "game_room_portal")
        self.assertEqual((portal["x"], portal["y"]), (50, 28))
        self.assertEqual(portal["modal"]["action"], "enter_game_room")
        self.assertTrue(any(d["tile"] == "eot_game_room_door" and (d["x"], d["y"]) == (50, 28)
                            for d in eot["decor"]))


if __name__ == "__main__":
    unittest.main()
