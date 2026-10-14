"""The character creator's audit: the numbers that find a generated facing
gone wrong before anyone looks at it."""

from __future__ import annotations

import os
import sys
import unittest

from PIL import Image

TOOLS = os.path.join(os.path.dirname(__file__), "..", "..", "virtual.space", "tools")
sys.path.insert(0, os.path.abspath(TOOLS))

import creator_audit as audit  # noqa: E402


def figure(x0, y0, x1, y1, size=40):
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    image.paste((200, 100, 80, 255), (x0, y0, x1, y1))
    return audit.silhouette(image)


class BodyTest(unittest.TestCase):
    def test_the_same_body_matches_whatever_sits_on_its_head(self):
        master = figure(10, 0, 20, 40)
        with_hat = figure(10, 0, 20, 40)
        with_hat.paste(1, (5, 0, 25, 6))  # a wide brim, above the cut
        self.assertEqual(audit.body_match(with_hat, master), 1.0)

    def test_a_body_somewhere_else_does_not(self):
        self.assertLess(audit.body_match(figure(25, 0, 35, 40), figure(10, 0, 20, 40)), audit.BODY_MIN)


class PieceTest(unittest.TestCase):
    def test_a_piece_is_measured_against_its_idle_size(self):
        self.assertEqual(audit.piece_shares([100, 50, 0], [90, 100, 110]), [1.0, 0.5, 0.0])

    def test_a_posed_clip_must_keep_the_piece_and_lying_down_may_hide_it(self):
        self.assertEqual(audit.piece_min({"anim": "wave", "pose": "wave", "steps": [1]}), 0.75)
        self.assertEqual(audit.piece_min({"anim": "walk", "template": "walking-4-frames"}), 0.25)
        self.assertIsNone(audit.piece_min({"anim": "ko", "template": "falling-back-death"}))

    def test_a_piece_barely_seen_idle_is_not_judged(self):
        self.assertEqual(audit.piece_shares([0, 3], []), [1.0, 1.0])
        self.assertEqual(audit.piece_shares([0, 12], [12, 12, 9]), [1.0, 1.0])


if __name__ == "__main__":
    unittest.main()
