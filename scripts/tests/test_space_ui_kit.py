"""The Virtual Space UI kit tool: it refuses bad art and builds the same bytes twice."""

from __future__ import annotations

import os
import sys
import unittest

from PIL import Image

TOOLS = os.path.join(os.path.dirname(__file__), "..", "..", "virtual.space", "tools")
sys.path.insert(0, os.path.abspath(TOOLS))

import author_ui  # noqa: E402

INK = (30, 15, 16, 255)
WOOD = (106, 58, 45, 255)
FACE = (240, 215, 185, 255)


def framed(w, h, border=3):
    """A plain frame: an ink outline, wood rim, parchment face."""
    image = Image.new("RGBA", (w, h), FACE)
    px = image.load()
    for y in range(h):
        for x in range(w):
            edge = min(x, y, w - 1 - x, h - 1 - y)
            if edge == 0:
                px[x, y] = INK
            elif edge < border:
                px[x, y] = WOOD
    return image


class NativeArtTest(unittest.TestCase):
    def test_accepts_art_drawn_at_its_size(self):
        author_ui._check_native("frame", framed(20, 12))

    def test_refuses_art_scaled_up(self):
        doubled = framed(10, 6).resize((20, 12), Image.NEAREST)
        with self.assertRaisesRegex(author_ui.KitError, "upscaled 2x"):
            author_ui._check_native("frame", doubled)


class SliceTest(unittest.TestCase):
    def test_a_plain_frame_repeats_cleanly(self):
        author_ui._check_slice("frame", framed(40, 20), [4, 4, 4, 4])

    def test_an_ornament_left_inside_an_edge_is_a_seam(self):
        image = framed(40, 20)
        px = image.load()
        for x in range(8, 30):
            for y in range(0, 4):
                px[x, y] = (219, 158, 88, 255)
        with self.assertRaisesRegex(author_ui.KitError, "top edge"):
            author_ui._check_slice("frame", image, [4, 4, 4, 4])

    def test_a_slice_wider_than_the_piece_is_refused(self):
        with self.assertRaisesRegex(author_ui.KitError, "no edge to repeat"):
            author_ui._check_slice("frame", framed(10, 10), [5, 5, 5, 5])

    def test_the_rect_must_be_the_piece_exactly(self):
        sheet = Image.new("RGBA", (30, 30), (0, 0, 0, 0))
        sheet.paste(framed(10, 10), (5, 5))
        author_ui._check_rect("frame", sheet, (5, 5, 15, 15))
        with self.assertRaisesRegex(author_ui.KitError, "bounding box"):
            author_ui._check_rect("frame", sheet, (4, 4, 15, 15))


class StatesTest(unittest.TestCase):
    def test_every_state_keeps_the_pieces_geometry_and_outline(self):
        image = framed(20, 12)
        for state, recipe in author_ui.STATES.items():
            if recipe is None:
                continue
            out = author_ui._map(image, recipe)
            self.assertEqual(out.size, image.size, state)
            self.assertEqual(out.getpixel((0, 0))[3], 255, state)

    def test_selected_gilds_the_stone_rim(self):
        stone = Image.new("RGBA", (1, 1), (133, 125, 123, 255))
        r, g, b, _ = author_ui._map(stone, author_ui.STATES["selected"]).getpixel((0, 0))
        self.assertGreater(r, b + 40)


class IconsTest(unittest.TestCase):
    def test_flipping_quadrants_turns_outward_corners_inward(self):
        image = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
        image.putpixel((0, 0), INK)
        flipped = author_ui._flip_quadrants("corners", image)
        self.assertEqual(flipped.getpixel((1, 1)), INK)
        self.assertEqual(flipped.getpixel((0, 0))[3], 0)

    def test_a_drawn_sprite_needs_even_rows(self):
        kit = {"palette": {"ink": [1, 2, 3]}, "drawn": {"keys": {"o": "ink"}, "bad": ["oo", "o"]}}
        with self.assertRaisesRegex(author_ui.KitError, "row 1"):
            author_ui._drawn(kit, "bad")


class BuildTest(unittest.TestCase):
    def test_the_kit_builds_the_same_bytes_twice(self):
        first = author_ui.build()
        second = author_ui.build()
        self.assertEqual(first.keys(), second.keys())
        for path in first:
            self.assertEqual(first[path], second[path], path)

    def test_the_committed_kit_is_what_kit_json_builds(self):
        for path, data in author_ui.build().items():
            self.assertTrue(author_ui.same_output(path, data), os.path.relpath(path))


if __name__ == "__main__":
    unittest.main()
