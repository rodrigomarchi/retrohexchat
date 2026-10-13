"""The character creator's PixelLab runner: which jobs are still to run, and
which frames a piece downloads to where."""

from __future__ import annotations

import os
import sys
import unittest

TOOLS = os.path.join(os.path.dirname(__file__), "..", "..", "virtual.space", "tools")
sys.path.insert(0, os.path.abspath(TOOLS))

import creator_generate as gen  # noqa: E402

CATALOG = {
    "master": "m",
    "dirs": ["south", "east"],
    "clips": [{"anim": "walk", "template": "walking-4-frames"}, {"anim": "sit", "pose": "seated", "steps": [1]}],
    "bases": {"av/bas": "m", "av/tun": "t"},
    "hair": [{"id": "lng", "character": "h"}],
    "headwear": [],
    "face": [],
}


def character(*animations):
    return {"rotation_urls": {"south": "r/s.png", "east": "r/e.png"}, "animations": list(animations)}


def animation(group, name, *dirs):
    return {"animation_group_id": group, "display_name": name,
            "directions": [{"direction": d, "frame_count": 2, "frames": [f"{group}/{d}/0", f"{group}/{d}/1"]}
                           for d in dirs]}


class LayersTest(unittest.TestCase):
    def test_every_piece_is_a_named_layer(self):
        self.assertEqual(gen.layers(CATALOG), [("base-av-bas", "m"), ("base-av-tun", "t"), ("hair-lng", "h")])


class PlanTest(unittest.TestCase):
    def test_only_what_is_missing_is_planned(self):
        characters = {
            "m": character(animation("g1", "walk_skel", "south")),
            "t": character(animation("g2", "cc_walk", "south", "east")),
            "h": character(),
        }
        registry = {"characters": {"m": {"groups": {"walk": "g1"}}}}
        posed = {("base-av-bas", "sit", "south")}
        jobs = gen.plan(CATALOG, registry, characters, lambda l, a, d: (l, a, d) in posed)
        self.assertEqual(
            [(layer, clip["anim"], d) for layer, _cid, clip, d in jobs],
            [("base-av-bas", "walk", "east"), ("base-av-bas", "sit", "east"),
             ("base-av-tun", "sit", "south"), ("base-av-tun", "sit", "east"),
             ("hair-lng", "walk", "south"), ("hair-lng", "walk", "east"),
             ("hair-lng", "sit", "south"), ("hair-lng", "sit", "east")],
        )

    def test_a_group_nobody_registered_does_not_count(self):
        # A leftover animation from an experiment, under another name.
        characters = {"m": character(animation("old", "walk_try", "south", "east")), "t": character(), "h": character()}
        jobs = gen.plan(CATALOG, {"characters": {}}, characters, lambda *_: True)
        self.assertIn(("base-av-bas", "walk", "south"), [(l, c["anim"], d) for l, _i, c, d in jobs])


class DownloadsTest(unittest.TestCase):
    def test_rotations_and_the_registered_clips_frames(self):
        ch = character(animation("g1", "walk_skel", "east"), animation("x", "other", "south"))
        rels = [rel for _url, rel in gen.frame_downloads(CATALOG, {"characters": {"m": {"groups": {"walk": "g1"}}}},
                                                          "base-av-bas", "m", ch)]
        self.assertEqual(rels, [
            os.path.join("base-av-bas", "rotations", "east.png"),
            os.path.join("base-av-bas", "rotations", "south.png"),
            os.path.join("base-av-bas", "walk", "east", "0.png"),
            os.path.join("base-av-bas", "walk", "east", "1.png"),
        ])


class BudgetTest(unittest.TestCase):
    def test_jobs_still_running_count_against_the_budget(self):
        # 10 spent, two jobs of 3 running: one more of 3 makes 19.
        self.assertTrue(gen.within_budget(10, [3, 3], 3, 19))
        self.assertFalse(gen.within_budget(10, [3, 3], 3, 18))


class RetryTest(unittest.TestCase):
    def test_a_service_error_is_tried_again_and_a_refusal_is_not(self):
        import urllib.error
        calls = []

        def flaky():
            calls.append(1)
            if len(calls) < 3:
                raise urllib.error.HTTPError("u", 520, "busy", {}, None)
            return "ok"

        self.assertEqual(gen._retrying(flaky, sleep=lambda _s: None), "ok")
        self.assertEqual(len(calls), 3)

        def refused():
            raise urllib.error.HTTPError("u", 404, "gone", {}, None)

        with self.assertRaises(urllib.error.HTTPError):
            gen._retrying(refused, sleep=lambda _s: None)


if __name__ == "__main__":
    unittest.main()
