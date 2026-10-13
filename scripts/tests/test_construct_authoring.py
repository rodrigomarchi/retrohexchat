"""The Construct's sheet tool: animated pieces stand still, fit the sheet, and refuse bad frames."""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from unittest import mock

from PIL import Image

TOOLS = os.path.join(os.path.dirname(__file__), "..", "..", "virtual.space", "tools")
sys.path.insert(0, os.path.abspath(TOOLS))

import author_construct as ac  # noqa: E402

INK = (40, 30, 30, 255)


def frame(size, box):
    """A transparent frame with one solid rectangle in it."""
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    image.paste(INK, box)
    return image


class UnionCropTest(unittest.TestCase):
    def test_every_frame_is_cut_to_the_box_that_holds_them_all(self):
        # A flag that waves to the right: frame 1 reaches further than frame 0.
        frames = ac._union_crop([frame((40, 40), (10, 10, 20, 30)),
                                 frame((40, 40), (10, 5, 30, 30))])
        self.assertEqual({f.size for f in frames}, {(20, 25)})
        # The still part stays where it was in both.
        self.assertEqual(frames[0].getbbox(), (0, 5, 10, 25))
        self.assertEqual(frames[1].getbbox(), (0, 0, 20, 25))


class StripTest(unittest.TestCase):
    def shelf(self):
        sheet = Image.new("RGBA", (ac.SHEET_COLS * ac.T, 8 * ac.T), (0, 0, 0, 0))
        return ac._Shelf(sheet, {})

    def test_frames_lie_side_by_side_as_one_tile(self):
        shelf = self.shelf()
        shelf.put_strip("cst_bell", [frame((64, 64), (0, 0, 64, 64))] * 3, 900)
        self.assertEqual(shelf.vocab, {"cst_bell": {"col": 0, "row": 0, "w": 2, "h": 2,
                                                    "frames": 3, "period_ms": 900}})
        self.assertEqual(shelf.col, 6)

    def test_a_strip_wider_than_the_sheet_is_refused(self):
        with self.assertRaises(AssertionError):
            self.shelf().put_strip("cst_wide", [frame((160, 32), (0, 0, 160, 32))] * 6, 900)

    def test_a_strip_that_does_not_fit_the_row_starts_the_next(self):
        shelf = self.shelf()
        shelf.put("cst_wide", frame((ac.T * 20, ac.T), (0, 0, ac.T * 20, ac.T)))
        shelf.put_strip("cst_flag", [frame((32, 64), (0, 0, 32, 64))] * 6, 900)
        self.assertEqual((shelf.vocab["cst_flag"]["col"], shelf.vocab["cst_flag"]["row"]), (0, 1))


class FramesTest(unittest.TestCase):
    def test_an_opaque_frame_is_a_failed_generation(self):
        with tempfile.TemporaryDirectory() as src:
            folder = os.path.join(src, "anim", "sparkle")
            os.makedirs(folder)
            with open(os.path.join(folder, "0.png"), "wb") as out:
                frame((32, 32), (8, 8, 24, 24)).save(out, format="PNG")
            with open(os.path.join(folder, "1.png"), "wb") as out:
                Image.new("RGBA", (32, 32), (127, 125, 124, 255)).save(out, format="PNG")
            with mock.patch.object(ac, "SRC", src), self.assertRaises(AssertionError):
                ac._frames("sparkle")


if __name__ == "__main__":
    unittest.main()
