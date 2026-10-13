"""The character creator's pixel work: what a key colour claims, how a channel
is shaded, and that a built sheet recolours by its palette alone."""

from __future__ import annotations

import io
import os
import sys
import unittest

from PIL import Image

TOOLS = os.path.join(os.path.dirname(__file__), "..", "..", "virtual.space", "tools")
sys.path.insert(0, os.path.abspath(TOOLS))

import creator_art as art  # noqa: E402
import creator_contact_sheet as sheet  # noqa: E402

MAGENTA = (220, 40, 200, 255)
DARK_MAGENTA = (60, 30, 60, 255)  # a shadow too grey to read as the key
SKIN = (220, 160, 120, 255)
OUTLINE = (20, 15, 20, 255)
GREY = (150, 150, 155, 255)
CLEAR = (0, 0, 0, 0)


def frame(rows):
    """A frame from rows of single-letter pixels."""
    key = {"M": MAGENTA, "d": DARK_MAGENTA, "s": SKIN, "o": OUTLINE, "g": GREY, ".": CLEAR}
    image = Image.new("RGBA", (len(rows[0]), len(rows)))
    image.putdata([key[c] for row in rows for c in row])
    return art.Frame(image)


class ClassifyTest(unittest.TestCase):
    def test_keys_skin_and_the_rest(self):
        f = frame(["oMMo",
                   "oMMo",
                   "ossg"])
        labels = art.classify(f, {"primary": 310})
        self.assertEqual(labels[1], "primary")
        self.assertEqual(labels[9], "skin")
        self.assertEqual(labels[0], art.NEUTRAL)   # the outline stays as drawn
        self.assertEqual(labels[11], art.NEUTRAL)  # grey cloth is not dyed

    def test_a_shadow_inside_a_key_is_dyed_with_it(self):
        f = frame(["MMM",
                   "MdM",
                   "MMM"])
        self.assertEqual(art.classify(f, {"primary": 310})[4], "primary")

    def test_the_black_outline_is_never_claimed(self):
        f = frame(["MMM",
                   "MoM",
                   "MMM"])
        self.assertEqual(art.classify(f, {"primary": 310})[4], art.NEUTRAL)


class OverlayTest(unittest.TestCase):
    def test_only_the_piece_and_its_rim_are_kept(self):
        f = frame(["......",
                   ".oMMo.",
                   ".oMMo.",
                   ".ssss.",
                   ".gggg."])
        labels = art.overlay(f, {"hair": 310})
        kept = {i for i, label in enumerate(labels) if label is not art.TRANSPARENT}
        self.assertTrue({8, 9, 14, 15} <= kept)          # the key
        self.assertIn(7, kept)                            # its outline
        self.assertTrue(all(labels[i] is art.TRANSPARENT for i in range(18, 30)))  # the mannequin

    def test_an_outline_tinted_with_the_key_is_dyed_with_the_piece(self):
        f = frame(["dddd", "dMMd", "dMMd", "dddd"])
        labels = art.overlay(f, {"hair": 310})
        self.assertEqual(labels[0], "hair")  # a dark magenta rim pixel

    def test_a_plain_black_outline_stays_as_drawn(self):
        f = frame(["oooo", "oMMo", "oMMo", "oooo"])
        labels = art.overlay(f, {"hair": 310})
        self.assertEqual(labels[0], art.NEUTRAL)

    def test_a_speck_of_key_far_from_the_piece_is_dropped(self):
        rows = ["MMMMMM"] * 4 + ["......"] * 4 + ["....M."]
        labels = art.overlay(frame(rows), {"hair": 310})
        self.assertIs(labels[len(labels) - 2], art.TRANSPARENT)


    def test_the_bodys_outline_tinted_with_the_key_is_not_the_piece(self):
        # A state tints the whole outline towards its key: a dark magenta line
        # down the legs, far from the hair, must not come along with it.
        dark_key = (70, 20, 60, 255)
        image = Image.new("RGBA", (12, 14), CLEAR)
        for x in range(2, 8):
            for y in range(1, 5):
                image.putpixel((x, y), MAGENTA)
        for y in range(7, 14):
            image.putpixel((10, y), dark_key)
        labels = art.overlay(art.Frame(image), {"hair": 310})
        self.assertIsNot(labels[2 * 12 + 3], art.TRANSPARENT)
        self.assertTrue(all(labels[y * 12 + 10] is art.TRANSPARENT for y in range(7, 14)))

    def test_a_small_stray_far_from_the_piece_is_dropped(self):
        image = Image.new("RGBA", (20, 20), CLEAR)
        for x in range(2, 10):
            for y in range(2, 10):
                image.putpixel((x, y), MAGENTA)
        for x in range(16, 19):
            for y in range(16, 19):
                image.putpixel((x, y), MAGENTA)
        labels = art.overlay(art.Frame(image), {"hair": 310})
        self.assertIs(labels[17 * 20 + 17], art.TRANSPARENT)
        self.assertIsNot(labels[5 * 20 + 5], art.TRANSPARENT)


class PaletteTest(unittest.TestCase):
    def test_a_channel_gets_exactly_its_shades_shared_by_every_frame(self):
        light, dark = (240, 60, 220, 255), (150, 20, 130, 255)
        a = Image.new("RGBA", (2, 1)); a.putdata([light, dark])
        b = Image.new("RGBA", (2, 1)); b.putdata([dark, dark])
        fa, fb = art.Frame(a), art.Frame(b)
        frames = [(fa, ["primary", "primary"]), (fb, ["primary", "primary"])]
        palette = art.build_palette(frames, {"primary": 3})
        self.assertEqual(len(palette.channels["primary"]), 3)
        # The dark pixel is the same index in both frames.
        self.assertEqual(art.indices(fa, frames[0][1], palette)[1], art.indices(fb, frames[1][1], palette)[0])

    def test_a_built_sheet_recolours_by_rewriting_its_palette(self):
        f = frame(["MM", "ss"])
        labels = art.classify(f, {"primary": 310})
        palette = art.build_palette([(f, labels)], {"primary": 2, "skin": 2})
        image = art.indexed_image((2, 2), art.indices(f, labels, palette), palette)
        buffer = io.BytesIO()
        image.save(buffer, format="PNG", transparency=0)
        red = {i: (255, 0, 0) for i in palette.channels["primary"]}
        patched = Image.open(io.BytesIO(sheet.patch_plte(buffer.getvalue(), red))).convert("RGBA")
        self.assertEqual(patched.getpixel((0, 0))[:3], (255, 0, 0))
        self.assertEqual(patched.getpixel((0, 1))[:3], Image.open(buffer).convert("RGBA").getpixel((0, 1))[:3])


class EncodeTest(unittest.TestCase):
    def test_an_indexed_png_reads_back_and_is_the_same_bytes_every_time(self):
        f = frame(["MM", "ss"])
        labels = art.classify(f, {"primary": 310})
        palette = art.build_palette([(f, labels)], {"primary": 2, "skin": 2})
        image = art.indexed_image((2, 2), art.indices(f, labels, palette), palette)
        png = art.encode_png8(image)
        self.assertEqual(png, art.encode_png8(image))
        back = Image.open(io.BytesIO(png))
        self.assertEqual(back.mode, "P")
        self.assertEqual(back.convert("RGBA").tobytes(), image.convert("RGBA").tobytes())


class MaskTest(unittest.TestCase):
    def test_a_hat_covers_everything_above_its_lowest_pixel_in_its_columns(self):
        f = frame(["......",
                   ".MMMM.",
                   ".MMMM.",
                   "......"])
        labels = art.overlay(f, {"primary": 310})
        cover = art.cover_mask(f, labels)
        self.assertTrue(cover[1] and cover[13])  # above and at the hat
        self.assertFalse(cover[19])              # below it
        self.assertFalse(cover[0])               # beside it


class HeadOffsetTest(unittest.TestCase):
    def test_finds_the_shift_that_lays_one_head_on_the_other(self):
        master = frame([".....", ".ss..", ".ss..", "....."])
        other = frame([".....", "..ss.", "..ss.", "....."])
        ml = art.classify(master, {})
        ol = art.classify(other, {})
        self.assertEqual(art.head_offset(master, ml, other, ol, (0, 0, 5, 4)), (1, 0))
        self.assertEqual(art.head_offset(master, ml, master, ml, (0, 0, 5, 4)), (0, 0))


if __name__ == "__main__":
    unittest.main()
