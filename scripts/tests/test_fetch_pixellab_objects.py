"""The Construct's PixelLab fetcher: which files it asks for, and where they land."""

from __future__ import annotations

import json
import os
import sys
import unittest

TOOLS = os.path.join(os.path.dirname(__file__), "..", "..", "virtual.space", "tools")
sys.path.insert(0, os.path.abspath(TOOLS))

import fetch_pixellab_objects as fetch  # noqa: E402

REGISTRY = {
    "base": "https://art.example/objects/acct/",
    "objects": {
        "tent": {"object": "obj-1"},
        "bell": {"object": "obj-2", "animation": "anim-9", "frames": 2},
        "gate": {"map_object": "map-3"},
        "flag": {"map_object": "map-5", "image_job": "job-4", "frames": 2},
    },
}


class DownloadsTest(unittest.TestCase):
    def test_a_still_piece_is_its_one_rotation(self):
        self.assertEqual(
            fetch.downloads(REGISTRY, ["tent"]),
            [("https://art.example/objects/acct/obj-1/rotations/unknown.png", "tent.png")],
        )

    def test_an_animated_piece_is_one_file_per_frame(self):
        self.assertEqual(
            fetch.downloads(REGISTRY, ["bell"]),
            [
                ("https://art.example/objects/acct/obj-2/animations/anim-9/unknown/0.png",
                 os.path.join("anim", "bell", "0.png")),
                ("https://art.example/objects/acct/obj-2/animations/anim-9/unknown/1.png",
                 os.path.join("anim", "bell", "1.png")),
            ],
        )

    def test_a_map_object_is_its_download(self):
        self.assertEqual(
            fetch.downloads(REGISTRY, ["gate"]),
            [("https://api.pixellab.ai/mcp/map-objects/map-3/download", "gate.png")],
        )

    def test_an_image_animation_is_its_job_frames_not_the_still_it_began_from(self):
        self.assertEqual(
            [path for _url, path in fetch.downloads(REGISTRY, ["flag"])],
            [os.path.join("anim", "flag", "0.png"), os.path.join("anim", "flag", "1.png")],
        )
        self.assertTrue(fetch.downloads(REGISTRY, ["flag"])[1][0].endswith("job-4/download?index=1"))

    def test_everything_in_kind_order_by_default(self):
        paths = [path for _url, path in fetch.downloads(REGISTRY)]
        self.assertEqual(paths[0], os.path.join("anim", "bell", "0.png"))
        self.assertEqual(paths[-1], "tent.png")

    def test_an_unknown_kind_is_refused(self):
        with self.assertRaises(KeyError):
            fetch.downloads(REGISTRY, ["sofa"])


class RegistryTest(unittest.TestCase):
    """The committed registry names only art the Construct can find."""

    def test_every_entry_is_complete_and_its_art_is_committed(self):
        with open(fetch.REGISTRY) as handle:
            registry = json.load(handle)
        for kind, entry in registry["objects"].items():
            self.assertRegex(kind, r"^[a-z_]+$")
            self.assertTrue({"object", "map_object", "image_job"} & set(entry), kind)
            if "animation" in entry or "image_job" in entry:
                self.assertGreater(entry["frames"], 1, kind)
        for _url, rel in fetch.downloads(registry):
            self.assertTrue(os.path.exists(os.path.join(fetch.CONSTRUCT, rel)), rel)


if __name__ == "__main__":
    unittest.main()
