"""The Construct's pieces stand at the scale of the people walking among them.

A character is ~90 px tall, about 1.75 m. Pieces are measured as packed on the
sheet (the drawn pixels of their `down` tile) against that person, so a tent
smaller than a person, or a bucket up to someone's chest, fails here. The
table to generate by is in virtual.space/SCENES.md §10 ("Scale").
"""

from __future__ import annotations

import json
import os
import unittest

from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MAP = os.path.join(REPO, "apps", "retro_hex_chat", "priv", "maps", "construct.json")
SPACE = os.path.join(REPO, "apps", "retro_hex_chat_web", "priv", "static", "images", "space")

# A person, in drawn pixels: the character creator's bodies stand about 90 px
# tall. A fixed rule, so a new body never moves a piece out of its band.
PERSON = 90

# Height against a person: (at least, at most), in person heights. The drawn
# height includes the floor diamond the piece stands on, so a big footprint
# reads a little taller than the object stands.
SCALE = {
    "big_top": (1.6, 2.2),
    "fortune_tent": (1.5, 2.1),
    "circus_tent": (1.3, 1.9),
    "purple_tent": (1.3, 1.9),
    "pennant_tent": (1.3, 1.9),
    "striped_tent": (1.3, 1.9),
    "fair_gate": (1.4, 2.0),
    "ancient_gate": (1.6, 2.3),
    "bell_tower": (1.6, 2.2),
    "stone_column": (1.4, 2.0),
    "tree": (1.5, 2.2),
    "pine_tree": (1.6, 2.3),
    "palm_tree": (1.5, 2.2),
    "street_lamp": (1.4, 2.0),
    "weapon_stall": (1.0, 1.6),
    "snack_stall": (1.0, 1.6),
    "giant_mushroom": (1.1, 1.8),
    "door": (1.1, 1.5),
    "magic_portal": (0.9, 1.5),
    "wingback_chair": (0.45, 0.75),
    "crt_tv": (0.3, 0.6),
    "water_bucket": (0.2, 0.4),
    "coffee_table": (0.2, 0.4),
    "whiteboard": (0.9, 1.3),
    "paper_lantern": (0.9, 1.3),
    "notice_board": (0.9, 1.3),
    # The Office's own pieces: a waist-high counter, a partition a desk tall,
    # a wastebasket at the knee, a plant nearly a person high.
    "reception_desk": (0.4, 0.7),
    "cubicle_partition": (0.4, 0.75),
    "trash_bin": (0.2, 0.4),
    "tall_plant": (0.6, 0.9),
}


def _tallest_avatar():
    """The tallest body of the character creator, head to feet, in pixels."""
    with open(os.path.join(SPACE, "creator", "catalog.json")) as handle:
        bodies = json.load(handle)["bodies"]
    return max(b["foot"] - b["top"] + 1 for b in bodies.values())


class ScaleTest(unittest.TestCase):
    def test_pieces_stand_at_the_scale_of_a_person(self):
        with open(MAP) as handle:
            layout = json.load(handle)
        sheet = Image.open(os.path.join(SPACE, "construct.webp")).convert("RGBA")
        # The rule is only as good as its reference: the avatars still stand
        # about a person tall.
        self.assertLessEqual(abs(_tallest_avatar() - PERSON), 6)
        person = PERSON
        for kind, (low, high) in SCALE.items():
            self._check(layout, sheet, person, kind, layout["catalog"][kind]["tiles"]["down"], low, high)
            # A piece is the same size in every state: a door open, a lamp off.
            for state, tiles in layout["catalog"][kind].get("states", {}).items():
                self._check(layout, sheet, person, f"{kind} {state}", tiles["down"], low, high)

    def _check(self, layout, sheet, person, kind, tile_name, low, high):
        tile = layout["vocab"][tile_name]
        self.assertEqual(tile.get("ts", "construct"), "construct", kind)
        cell = sheet.crop((tile["col"] * 32, tile["row"] * 32,
                           (tile["col"] + tile["w"]) * 32, (tile["row"] + tile["h"]) * 32))
        box = cell.getbbox()
        ratio = (box[3] - box[1]) / person
        if low is not None:
            self.assertGreaterEqual(ratio, low, f"{kind} is {ratio:.2f} of a person")
        if high is not None:
            self.assertLessEqual(ratio, high, f"{kind} is {ratio:.2f} of a person")

    def test_a_door_keeps_its_frame_where_it_was_when_it_opens(self):
        with open(MAP) as handle:
            layout = json.load(handle)
        door = layout["catalog"]["door"]
        shut = layout["vocab"][door["tiles"]["down"]]
        opened = layout["vocab"][door["states"]["open"]["down"]]
        # Same cell size, so the bottom-centred anchor puts both in one place.
        self.assertEqual((shut["w"], shut["h"]), (opened["w"], opened["h"]))

if __name__ == "__main__":
    unittest.main()
