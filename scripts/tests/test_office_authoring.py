"""The Office: the Construct's platform furnished, written the same every time."""

from __future__ import annotations

import json
import os
import sys
import unittest

TOOLS = os.path.join(os.path.dirname(__file__), "..", "..", "virtual.space", "tools")
sys.path.insert(0, os.path.abspath(TOOLS))

import author_office as ao  # noqa: E402

MAPS = os.path.join(os.path.dirname(__file__), "..", "..", "apps", "retro_hex_chat", "priv", "maps")


def _load(name):
    with open(os.path.join(MAPS, f"{name}.json")) as handle:
        return json.load(handle)


class OfficeMapTest(unittest.TestCase):
    def setUp(self):
        self.office = _load("office")
        self.construct = _load("construct")

    def test_it_is_built_from_the_construct_catalog_and_sheets(self):
        self.assertEqual(self.office["catalog"], self.construct["catalog"])
        self.assertEqual(self.office["vocab"], self.construct["vocab"])
        self.assertEqual(self.office["tilesets"], self.construct["tilesets"])
        for item in self.office["fixed_items"]:
            self.assertIn(item["kind"], self.construct["catalog"])

    def test_the_file_is_what_the_author_writes_now(self):
        catalog = self.construct["catalog"]
        items = ao._fixed_items(catalog)
        self.assertEqual(self.office["fixed_items"], items)
        self.assertEqual(self.office["floor"], ao._floor())

    def test_the_furniture_leaves_the_way_out_clear_and_every_tile_reachable(self):
        catalog = self.construct["catalog"]
        exit_ = tuple(next((i["x"], i["y"]) for i in self.office["interactables"]
                           if i["id"] == "office_exit"))
        reserved = {tuple(t) for t in self.office["reserved"]}
        # Raises on an overlap, a piece off the floor or on the way out, a
        # cut-off tile or an unreachable chair.
        ao._validate(catalog, self.office["fixed_items"], exit_, self.office["spawn"], reserved)

    def test_a_piece_on_the_way_out_is_refused(self):
        catalog = self.construct["catalog"]
        exit_ = (ao.X0 + ao.EXIT_UV[0], ao.Y0 + ao.EXIT_UV[1])
        spawn = self.office["spawn"]
        blocking = [{"id": "fixed:0", "kind": "plant", "x": spawn[0]["x"], "y": spawn[0]["y"],
                     "dir": "down"}]
        with self.assertRaises(AssertionError):
            ao._validate(catalog, blocking, exit_, spawn, {(spawn[0]["x"], spawn[0]["y"])})

    def test_a_wall_of_furniture_that_cuts_off_the_floor_is_refused(self):
        catalog = self.construct["catalog"]
        exit_ = (ao.X0 + ao.EXIT_UV[0], ao.Y0 + ao.EXIT_UV[1])
        spawn = self.office["spawn"]
        wall = [{"id": f"fixed:{n}", "kind": "wall", "x": ao.X0 + 6, "y": y, "dir": "down"}
                for n, y in enumerate(range(ao.Y0, ao.Y1 + 1))]
        with self.assertRaises(AssertionError):
            ao._validate(catalog, wall, exit_, spawn, set())


if __name__ == "__main__":
    unittest.main()
