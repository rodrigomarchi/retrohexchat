"""The character creator's build: how a face item is held to the head it is
drawn on."""

from __future__ import annotations

import os
import sys
import unittest

TOOLS = os.path.join(os.path.dirname(__file__), "..", "..", "virtual.space", "tools")
sys.path.insert(0, os.path.abspath(TOOLS))

import build_creator as build  # noqa: E402


class FaceBoxTest(unittest.TestCase):
    def test_the_hair_and_headwear_of_the_frame_bound_a_face_item_with_slack(self):
        r = build.FACE_REACH
        self.assertEqual(build.face_box([(10, 5, 20, 15), (12, 2, 18, 9), None]),
                         (10 - r, 2 - r, 20 + r, 15 + r))

    def test_with_nothing_on_the_head_there_is_no_bound(self):
        self.assertIsNone(build.face_box([None, None]))


if __name__ == "__main__":
    unittest.main()
