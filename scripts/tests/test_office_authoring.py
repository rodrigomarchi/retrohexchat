"""The Office: the Construct's platform furnished, written the same every time."""

from __future__ import annotations

import json
import os
import sys
import unittest

TOOLS = os.path.join(os.path.dirname(__file__), "..", "..", "virtual.space", "tools")
sys.path.insert(0, os.path.abspath(TOOLS))

import author_office as ao  # noqa: E402
import furnished_room as fr  # noqa: E402

P = ao.PLAN

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
        items = fr.fixed_items(P, catalog)
        self.assertEqual(self.office["fixed_items"], items)
        self.assertEqual(self.office["floor"], fr.floor(P))

    def test_the_furniture_leaves_the_way_out_clear_and_every_tile_reachable(self):
        catalog = self.construct["catalog"]
        exit_ = tuple(next((i["x"], i["y"]) for i in self.office["interactables"]
                           if i["id"] == "office_exit"))
        reserved = {tuple(t) for t in self.office["reserved"]}
        # Raises on an overlap, a piece off the floor or on the way out, a
        # cut-off tile or an unreachable chair.
        fr.validate(P, catalog, self.office["fixed_items"], exit_, self.office["spawn"], reserved)

    def test_a_piece_on_the_way_out_is_refused(self):
        catalog = self.construct["catalog"]
        exit_ = P.exit
        spawn = self.office["spawn"]
        blocking = [{"id": "fixed:0", "kind": "plant", "x": spawn[0]["x"], "y": spawn[0]["y"],
                     "dir": "down"}]
        with self.assertRaises(AssertionError):
            fr.validate(P, catalog, blocking, exit_, spawn, {(spawn[0]["x"], spawn[0]["y"])})

    def test_a_wall_of_furniture_that_cuts_off_the_floor_is_refused(self):
        catalog = self.construct["catalog"]
        exit_ = P.exit
        spawn = self.office["spawn"]
        wall = [{"id": f"fixed:{n}", "kind": "wall", "x": P.x0 + 6, "y": y, "dir": "down"}
                for n, y in enumerate(range(P.y0, P.y1 + 1))]
        with self.assertRaises(AssertionError):
            fr.validate(P, catalog, wall, exit_, spawn, set())


class PaneTest(unittest.TestCase):
    def test_a_pane_runs_on_the_floor_slope_so_the_next_one_meets_it(self):
        import author_construct as ac
        im = ac._pane(40, ac._glass_pane)
        self.assertEqual(im.width, ac.PANE_W)
        alpha = im.getchannel("A").load()

        def lowest(col):
            return max(y for y in range(im.height) if alpha[col, y])

        # The near end is the pane's lowest point; the far end is 10 px up, a
        # tile's edge on the 48x20 floor, so the next pane's near end is there.
        self.assertEqual(lowest(0), im.height - 1)
        self.assertEqual(lowest(ac.PANE_W - 1), im.height - 11)

    def test_the_office_stands_no_wall_on_its_edge(self):
        office = _load("office")
        self.assertFalse({i["kind"] for i in office["fixed_items"]} & {"wall", "corner"})


class DoorsTest(unittest.TestCase):
    def test_a_door_is_a_way_through_a_wall_and_a_wall_without_one_is_not(self):
        construct = _load("construct")
        catalog = construct["catalog"]
        exit_ = P.exit
        spawn = _load("office")["spawn"]
        x = P.x0 + 6

        def run(door_at):
            return [{"id": f"fixed:{n}", "kind": "glass_door" if y == door_at else "glass_wall",
                     "x": x, "y": y, "dir": "down"}
                    for n, y in enumerate(range(P.y0, P.y1 + 1))]

        fr.validate(P, catalog, run(P.y0 + 5), exit_, spawn, set())
        with self.assertRaises(AssertionError):
            fr.validate(P, catalog, run(None), exit_, spawn, set())


if __name__ == "__main__":
    unittest.main()
