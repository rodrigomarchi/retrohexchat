"""The seated clip is posed, not drawn: one skeleton per frame, the same for every piece."""

from __future__ import annotations

import os
import sys
import unittest

TOOLS = os.path.join(os.path.dirname(__file__), "..", "..", "virtual.space", "tools")
sys.path.insert(0, os.path.abspath(TOOLS))

import creator_pose as pose  # noqa: E402

LABELS = ["NECK", "NOSE", "LEFT EAR", "RIGHT EAR", "LEFT EYE", "RIGHT EYE", "LEFT SHOULDER",
          "RIGHT SHOULDER", "LEFT ELBOW", "RIGHT ELBOW", "LEFT ARM", "RIGHT ARM", "LEFT HIP",
          "RIGHT HIP", "LEFT KNEE", "RIGHT KNEE", "LEFT LEG", "RIGHT LEG"]
HEIGHT = {"NOSE": .85, "LEFT EAR": .87, "RIGHT EAR": .87, "LEFT EYE": .88, "RIGHT EYE": .88, "NECK": .71,
          "LEFT SHOULDER": .72, "RIGHT SHOULDER": .72, "LEFT ELBOW": .56, "RIGHT ELBOW": .56,
          "LEFT ARM": .43, "RIGHT ARM": .43, "LEFT HIP": .47, "RIGHT HIP": .47,
          "LEFT KNEE": .26, "RIGHT KNEE": .26, "LEFT LEG": .09, "RIGHT LEG": .09}


def standing():
    out = {}
    for label in LABELS:
        side = -0.08 if label.startswith("RIGHT") else 0.08 if label.startswith("LEFT") else 0.0
        depth = 0.43 if label in ("NOSE", "LEFT EYE", "RIGHT EYE") else 0.5
        out[label] = [0.5 + side, depth, HEIGHT[label]]
    return out


def south_view(p):
    # An orthographic view from the front, a little from above.
    return (p[0], 1.0 - p[2] * 0.9 + (0.5 - p[1]) * 0.25)


class ProjectionTest(unittest.TestCase):
    def test_an_affine_view_is_recovered_from_its_joints(self):
        points = standing()
        labels = sorted(points)
        fitted = pose.fit_projection([points[l] for l in labels], [south_view(points[l]) for l in labels])
        for l in labels:
            x, y = pose.project(points[l], fitted)
            self.assertAlmostEqual(x, south_view(points[l])[0], places=6)
            self.assertAlmostEqual(y, south_view(points[l])[1], places=6)


class SeatedTest(unittest.TestCase):
    def test_hips_sink_thighs_come_level_and_the_feet_stay_down(self):
        s = standing()
        sat = pose.seated(s, 1.0)
        self.assertAlmostEqual(sat["LEFT HIP"][2], s["LEFT HIP"][2] - pose.SEAT_DROP)
        self.assertAlmostEqual(sat["LEFT KNEE"][2], sat["LEFT HIP"][2] + 0.01)
        self.assertLess(sat["LEFT KNEE"][1], s["LEFT KNEE"][1])  # forward, towards smaller depth
        self.assertAlmostEqual(sat["LEFT LEG"][2], s["LEFT LEG"][2])

    def test_no_way_down_is_standing(self):
        self.assertEqual(pose.seated(standing(), 0.0), standing())

    def test_a_clip_is_one_skeleton_per_step_on_the_padded_canvas(self):
        s = standing()
        skeletons = {"3d": {"keypoints": s},
                     "2d_references": {"south": {"keypoints": {l: dict(zip("xy", south_view(p)))
                                                               for l, p in s.items()}}}}
        first, frames = pose.sit_clip(skeletons, "south", [0.5, 1.0], scale=104 / 144, offset=20 / 144)
        self.assertEqual(len(frames), 2)
        self.assertEqual(len(first), 18)
        for frame in frames:
            self.assertEqual(sorted(k["label"] for k in frame), sorted(LABELS))
            for k in frame:
                self.assertTrue(20 / 144 <= k["x"] <= 124 / 144)


if __name__ == "__main__":
    unittest.main()
