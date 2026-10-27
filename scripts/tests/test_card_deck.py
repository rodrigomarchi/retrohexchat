"""The platform's deck: the layout every card follows and the atlas every card game reads."""

from __future__ import annotations

import os
import sys
import unittest

DECK = os.path.join(os.path.dirname(__file__), "..", "..", "apps", "retro_hex_chat_web", "assets", "art", "cards")
sys.path.insert(0, os.path.abspath(DECK))

import build_deck as deck  # noqa: E402


def box(cx: int, cy: int, rows: list[str]) -> tuple[int, int, int, int]:
    left, top = cx - len(rows[0]) // 2, cy - len(rows) // 2
    return left, top, left + len(rows[0]), top + len(rows)


def pixels(image) -> list[tuple]:
    data = image.load()
    return [data[x, y] for y in range(image.height) for x in range(image.width)]


def overlap(a: tuple, b: tuple) -> bool:
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


# Where the corner indices stand (rank above suit), top-left and bottom-right.
CORNERS = [(2, 3, 9, 18), (deck.WIDTH - 9, deck.HEIGHT - 18, deck.WIDTH - 2, deck.HEIGHT - 3)]


class NumberCardLayoutTest(unittest.TestCase):
    def test_a_number_card_has_as_many_pips_as_its_rank(self):
        for rank, places in deck.PIP_LAYOUT.items():
            self.assertEqual(len(places), rank, rank)

    def test_no_pip_touches_another_or_a_corner_or_leaves_the_card(self):
        for suit, rows in deck.PIPS.items():
            for rank, places in deck.PIP_LAYOUT.items():
                boxes = [box(cx, cy, rows) for cx, cy in places]
                for i, a in enumerate(boxes):
                    self.assertTrue(0 < a[0] and a[2] < deck.WIDTH and 0 < a[1] and a[3] < deck.HEIGHT, (suit, rank))
                    for corner in CORNERS:
                        self.assertFalse(overlap(a, corner), (suit, rank, a))
                    for b in boxes[i + 1 :]:
                        self.assertFalse(overlap(a, b), (suit, rank, a, b))

    def test_every_rank_glyph_is_seven_rows_and_the_same_width_on_each(self):
        for rank, rows in deck.GLYPHS.items():
            self.assertEqual(len(rows), 7, rank)
            self.assertEqual(len({len(row) for row in rows}), 1, rank)

    def test_the_red_suits_are_red_and_the_black_suits_black(self):
        self.assertEqual(deck.colour_of(deck.HEARTS), deck.RED)
        self.assertEqual(deck.colour_of(deck.DIAMONDS), deck.RED)
        self.assertEqual(deck.colour_of(deck.SPADES), deck.BLACK)
        self.assertEqual(deck.colour_of(deck.CLUBS), deck.BLACK)


class FacesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.faces = deck.build_faces()

    def test_there_are_52_faces_by_card_id_each_a_card_in_size(self):
        self.assertEqual(sorted(self.faces), list(range(52)))
        for face in self.faces.values():
            self.assertEqual(face.size, (deck.WIDTH, deck.HEIGHT))

    def test_the_corners_are_cut_round(self):
        for face in self.faces.values():
            self.assertEqual(face.getpixel((0, 0))[3], 0)
            self.assertEqual(face.getpixel((deck.WIDTH - 1, deck.HEIGHT - 1))[3], 0)

    def test_the_court_cards_of_the_black_suits_carry_no_red(self):
        for suit in (deck.SPADES, deck.CLUBS):
            for rank in (11, 12, 13):
                face = self.faces[suit * 13 + rank - 1]
                reds = [p for p in pixels(face) if deck.is_red_ink(p)]
                self.assertEqual(reds, [], (suit, rank))

    def test_the_court_cards_of_the_red_suits_keep_their_red(self):
        face = self.faces[deck.HEARTS * 13 + 12]
        self.assertTrue(any(deck.is_red_ink(p) for p in pixels(face)))


class AtlasTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sheet, cls.description = deck.build_atlas()

    def regions(self):
        d = self.description
        return d["faces"] + d["jokers"] + d["backs"] + d["shadows"]

    def test_it_describes_every_picture_a_card_game_needs(self):
        d = self.description
        self.assertEqual(d["card"], {"width": deck.WIDTH, "height": deck.HEIGHT})
        self.assertEqual((len(d["faces"]), len(d["jokers"]), len(d["backs"]), len(d["shadows"])), (52, 2, 4, 2))
        self.assertEqual(d["image"], "cards.png")

    def test_every_region_lies_inside_the_picture_and_apart_from_the_others(self):
        regions = [(r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]) for r in self.regions()]
        for i, a in enumerate(regions):
            self.assertTrue(a[0] >= 0 and a[1] >= 0 and a[2] <= self.sheet.width and a[3] <= self.sheet.height, a)
            for b in regions[i + 1 :]:
                self.assertFalse(overlap(a, b), (a, b))

    def test_a_face_in_the_atlas_is_the_face_built(self):
        faces = deck.build_faces()
        for card_id in (0, 13, 25, 51):
            r = self.description["faces"][card_id]
            cut = self.sheet.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]))
            self.assertEqual(cut.tobytes(), faces[card_id].tobytes(), card_id)


if __name__ == "__main__":
    unittest.main()
