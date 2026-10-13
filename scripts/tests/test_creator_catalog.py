"""The character creator as committed: its two catalogs agree with their
source, and every sheet they name is on disk."""

from __future__ import annotations

import json
import os
import sys
import unittest

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "virtual.space", "tools"))
import creator_contact_sheet as sheet  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE = os.path.join(REPO, "virtual.space", "characters", "creator", "catalog_src.json")
STATIC = os.path.join(REPO, "apps", "retro_hex_chat_web", "priv", "static")
WEB = os.path.join(STATIC, "images", "space", "creator", "catalog.json")
DOMAIN = os.path.join(REPO, "apps", "retro_hex_chat", "priv", "virtual_space", "character_catalog.json")
# A person, in drawn pixels (see test_construct_scale.py).
PERSON = 90


def load(path):
    with open(path) as handle:
        return json.load(handle)


class CatalogTest(unittest.TestCase):
    def setUp(self):
        self.source, self.web, self.domain = load(SOURCE), load(WEB), load(DOMAIN)

    def test_the_domain_knows_exactly_the_pieces_the_web_can_draw(self):
        items = self.web["items"]
        self.assertEqual(self.domain["bodies"], items["bodies"])
        self.assertEqual(self.domain["bases"], items["bases"])
        self.assertEqual(self.domain["hair"], items["hair"])
        self.assertEqual(sorted(self.domain["headwear"]), sorted(items["headwear"]))
        self.assertEqual(self.domain["face"], sorted(items["face"]))
        self.assertEqual(self.domain["default"], self.web["default"])
        self.assertEqual(self.domain["portrait_version"], self.web["v"])
        for name, ramps in self.web["palettes"].items():
            self.assertEqual(self.domain["palettes"][name], len(ramps))

    def test_the_catalogs_are_built_from_the_source(self):
        self.assertEqual(sorted(self.source["bases"]), self.domain["bases"])
        self.assertEqual([h["id"] for h in self.source["hair"]], self.domain["hair"])
        self.assertEqual(sorted(c["anim"] for c in self.source["clips"]), sorted(self.web["anims"]))

    def test_every_layer_has_every_clip_and_every_file_is_there(self):
        for name, layer in self.web["layers"].items():
            self.assertEqual(sorted(layer["anims"]), sorted(self.web["anims"]), name)
            urls = [a["url"] for a in layer["anims"].values()] + [layer["portrait"]["url"]]
            urls += [a["url"] for a in layer.get("mask", {}).values()]
            for url in urls:
                path = os.path.join(STATIC, url.split("?")[0].lstrip("/"))
                self.assertTrue(os.path.exists(path), path)

    def test_a_ramp_has_a_shade_for_every_index_a_layer_keeps(self):
        shades = {name: len(ramps[0]) for name, ramps in self.web["palettes"].items()}
        for name, layer in self.web["layers"].items():
            for channel, indices in layer["channels"].items():
                self.assertEqual(len(indices), shades[self.web["channelPalette"][channel]], f"{name} {channel}")

    def test_every_body_stands_about_a_person_tall(self):
        for body, bounds in self.web["bodies"].items():
            height = bounds["foot"] - bounds["top"] + 1
            self.assertLessEqual(abs(height - PERSON), 8, f"{body} is {height} px tall")


class GoldenTest(unittest.TestCase):
    """The portraits the server is held to are the reference compositor's."""

    def test_every_golden_portrait_is_what_the_reference_draws(self):
        catalog = load(WEB)
        recipes = sheet.golden_recipes(catalog)
        on_disk = sorted(name[:-4] for name in os.listdir(sheet.GOLDEN))
        self.assertEqual(on_disk, sorted(recipes))
        for recipe in recipes:
            drawn = sheet.portrait(recipe, catalog)
            with Image.open(os.path.join(sheet.GOLDEN, f"{recipe}.png")) as golden:
                self.assertEqual(drawn.tobytes(), golden.convert("RGBA").tobytes(), recipe)


if __name__ == "__main__":
    unittest.main()
