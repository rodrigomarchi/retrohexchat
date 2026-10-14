#!/usr/bin/env python3
"""Compose Space characters from the built creator catalog, the way the game does.

The reference compositor: a recipe is parsed, each piece's sheet has its
palette rewritten with the chosen colour ramps (the same PLTE patch the browser
and the server apply), and the pieces are drawn base, face, hair, hat -- the
hair first cut by the hat's mask when the hat hides it -- with the base's head
offset added to every overlay.

It writes contact sheets to review a build by eye, and the golden images the
server's portrait test compares against.

    python3 virtual.space/tools/creator_contact_sheet.py OUT.png [recipe ...]
    python3 virtual.space/tools/creator_contact_sheet.py OUT.png --random 20
"""
from __future__ import annotations

import argparse
import io
import json
import os
import random
import struct
import sys
import zlib

from PIL import Image

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(TOOLS, "..", ".."))
STATIC = os.path.join(REPO, "apps", "retro_hex_chat_web", "priv", "static")
CATALOG = os.path.join(STATIC, "images", "space", "creator", "catalog.json")


# ------------------------------------------------------------------- recipe

def parse(recipe, catalog):
    """A recipe string as a dict, or ValueError. Mirrors CharacterRecipe.parse/1."""
    parts = recipe.split(".")
    if len(parts) != 7 or parts[0] != "c1":
        raise ValueError(f"not a recipe: {recipe}")
    fields = {}
    for part, tag in zip(parts[1:], "bsohwf"):
        if not part.startswith(tag + "-"):
            raise ValueError(f"field {tag} missing in {recipe}")
        fields[tag] = part[2:].split("-")
    items = catalog["items"]
    body = fields["b"][0]
    out = {"body": body, "skin": int(fields["s"][0], 36)}
    oid, p, s = fields["o"]
    out["outfit"] = (oid, int(p, 36), int(s, 36))
    out["hair"] = None if fields["h"] == ["0"] else (fields["h"][0], int(fields["h"][1], 36))
    out["hat"] = None if fields["w"] == ["0"] else (fields["w"][0], int(fields["w"][1], 36), int(fields["w"][2], 36))
    out["face"] = None if fields["f"] == ["0"] else (fields["f"][0], int(fields["f"][1], 36))
    if f"{body}/{oid}" not in items["bases"]:
        raise ValueError(f"no outfit {oid} for body {body}")
    return out


def random_recipe(catalog, rng):
    items, pal = catalog["items"], catalog["palettes"]
    base = rng.choice(items["bases"])
    body, outfit = base.split("/")
    n = lambda name: base36(rng.randrange(len(pal[name])))  # noqa: E731
    hair = rng.choice([None] + items["hair"])
    hat = rng.choice([None] + sorted(items["headwear"]))
    face = rng.choice([None] + sorted(items["face"]))
    face_palette = catalog["channelPalette"][items["face"][face]["channel"]] if face else None
    return ".".join([
        "c1", f"b-{body}", f"s-{n('skin')}",
        f"o-{outfit}-{_dye(catalog, outfit, 0, rng.randrange(16))}-{_dye(catalog, outfit, 1, rng.randrange(16))}",
        f"h-{hair}-{n('hair')}" if hair else "h-0",
        f"w-{hat}-{n('fabric')}-{n('fabric')}" if hat else "w-0",
        f"f-{face}-{n(face_palette)}" if face else "f-0"])


def base36(n):
    digits = "0123456789abcdefghijklmnopqrstuvwxyz"
    return digits[n]


# ------------------------------------------------------------- PNG palette

def patch_plte(png, entries):
    """Rewrite palette entries {index: (r, g, b)} of a PNG; returns new bytes."""
    out = bytearray(png[:8])
    pos = 8
    while pos < len(png):
        length = struct.unpack(">I", png[pos:pos + 4])[0]
        kind = png[pos + 4:pos + 8]
        data = bytearray(png[pos + 8:pos + 8 + length])
        if kind == b"PLTE":
            for index, rgb in entries.items():
                data[index * 3:index * 3 + 3] = bytes(rgb)
        out += struct.pack(">I", length) + kind + data
        out += struct.pack(">I", zlib.crc32(kind + bytes(data)) & 0xFFFFFFFF)
        pos += 12 + length
    return bytes(out)


def recolour_entries(layer, colours, catalog):
    """{palette index: rgb} for a layer given {channel: palette entry index}."""
    entries = {}
    for channel, idx in layer["channels"].items():
        if channel not in colours:
            continue
        palette = catalog["palettes"][catalog["channelPalette"][channel]]
        ramp = palette[colours[channel] % len(palette)]
        for k, i in enumerate(idx):
            entries[i] = tuple(ramp[k])
    return entries


def load(url, entries=None):
    path = os.path.join(STATIC, url.split("?")[0].lstrip("/"))
    with open(path, "rb") as handle:
        png = handle.read()
    if entries:
        png = patch_plte(png, entries)
    return Image.open(io.BytesIO(png)).convert("RGBA")


# --------------------------------------------------------------- compose

def plan(recipe, catalog):
    """[(layer name, colours, kind)] in drawing order."""
    r = parse(recipe, catalog)
    out = [(f"base-{r['body']}-{r['outfit'][0]}",
            {"skin": r["skin"], "primary": r["outfit"][1], "secondary": r["outfit"][2]}, "base")]
    if r["face"]:
        channel = catalog["items"]["face"][r["face"][0]]["channel"]
        out.append((f"face-{r['face'][0]}", {channel: r["face"][1]}, "face"))
    if r["hair"]:
        out.append((f"hair-{r['hair'][0]}", {"hair": r["hair"][1]}, "hair"))
    if r["hat"]:
        out.append((f"hat-{r['hat'][0]}", {"primary": r["hat"][1], "secondary": r["hat"][2]}, "hat"))
    return out


def compose(recipe, catalog, anim, d, frame):
    """One composed frame, the size of the catalog's box."""
    bx, by, bw, bh = catalog["box"]
    di = catalog["dirs"].index(d)
    layers = plan(recipe, catalog)
    base = catalog["layers"][layers[0][0]]
    dx, dy = base["delta"][anim][di][frame]
    hat = next((name for name, _c, kind in layers if kind == "hat"), None)
    out = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    for name, colours, kind in layers:
        layer = catalog["layers"][name]
        a = layer["anims"][anim]
        sheet = load(a["url"], recolour_entries(layer, colours, catalog))
        cw, ch = a["cell"]
        piece = sheet.crop((frame * cw, di * ch, frame * cw + cw, di * ch + ch))
        ox, oy = a["origin"][0] - bx, a["origin"][1] - by
        if kind != "base":
            ox, oy = ox + dx, oy + dy
        if kind == "hair" and hat and catalog["layers"][hat].get("mask"):
            m = catalog["layers"][hat]["mask"][anim]
            mask = load(m["url"])
            mw, mh = m["cell"]
            mpiece = mask.crop((frame * mw, di * mh, frame * mw + mw, di * mh + mh))
            # Cut the hair where the hat covers it, in the box's coordinates.
            canvas = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
            canvas.alpha_composite(piece, (ox, oy))
            cut = Image.new("L", (bw, bh), 0)
            cut.paste(mpiece.getchannel("A"), (m["origin"][0] - bx + dx, m["origin"][1] - by + dy))
            alpha = canvas.getchannel("A").point(lambda v: v)
            alpha.paste(0, mask=cut)
            canvas.putalpha(alpha)
            out.alpha_composite(canvas)
            continue
        out.alpha_composite(piece, (ox, oy))
    return out


def portrait(recipe, catalog, view="portrait"):
    """A still of a recipe: each piece's crop for `view` -- "portrait", the
    head the chat shows, "figure", the whole character, or "head", all it
    wears on the head -- recoloured and stacked."""
    x, y, w, h = catalog[view]["rect"]
    layers = plan(recipe, catalog)
    hat = next((name for name, _c, kind in layers if kind == "hat"), None)
    dx, dy = catalog["layers"][layers[0][0]]["delta"]["idle"][0][0]
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for name, colours, kind in layers:
        layer = catalog["layers"][name]
        piece = load(layer[view]["url"], recolour_entries(layer, colours, catalog))
        if kind == "hair" and hat and catalog["layers"][hat].get(f"{view}Mask"):
            cut = load(catalog["layers"][hat][f"{view}Mask"]["url"]).getchannel("A")
            alpha = piece.getchannel("A")
            alpha.paste(0, mask=cut)
            piece.putalpha(alpha)
        if kind != "base" and (dx or dy):
            # The overlays move by the base's head offset, as in the space.
            moved = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            moved.paste(piece, (dx, dy), piece)
            piece = moved
        out.alpha_composite(piece)
    return out


FIXTURES = os.path.join(REPO, "apps", "retro_hex_chat_web", "test", "fixtures")
GOLDEN = os.path.join(FIXTURES, "character_portraits")
# Each view's goldens: the same recipes, every still the server draws.
GOLDENS = {"portrait": GOLDEN, "figure": os.path.join(FIXTURES, "character_figures"),
           "head": os.path.join(FIXTURES, "character_heads")}


def golden_recipes(catalog):
    """A handful of recipes covering every piece: the default, then one per
    piece worn alone, then everything at once, in colours off the defaults."""
    items, out = catalog["items"], [catalog["default"]]
    for base in items["bases"]:
        body, outfit = base.split("/")
        out.append(f"c1.b-{body}.s-3.o-{outfit}-{_dye(catalog, outfit, 0, 5)}-{_dye(catalog, outfit, 1, 9)}.h-0.w-0.f-0")
    body, outfit = items["bases"][0].split("/")
    for hair in items["hair"]:
        out.append(f"c1.b-{body}.s-6.o-{outfit}-0-0.h-{hair}-7.w-0.f-0")
    for hat in sorted(items["headwear"]):
        hair = items["hair"][0] if items["hair"] else None
        out.append(".".join(["c1", f"b-{body}", "s-1",
                             f"o-{outfit}-{_dye(catalog, outfit, 0, 2)}-{_dye(catalog, outfit, 1, 4)}",
                             f"h-{hair}-3" if hair else "h-0", f"w-{hat}-b-6", "f-0"]))
    for face in sorted(items["face"]):
        out.append(f"c1.b-{body}.s-4.o-{outfit}-0-0.h-0.w-0.f-{face}-3")
    return list(dict.fromkeys(out))


def _dye(catalog, outfit, slot, value):
    return base36(value) if slot < len(catalog["items"]["outfits"][outfit]["channels"]) else "0"


def write_goldens(catalog, folders=None):
    """Each view's still of each golden recipe, as the server must also draw it."""
    for view, folder in (folders or GOLDENS).items():
        os.makedirs(folder, exist_ok=True)
        for name in os.listdir(folder):
            os.remove(os.path.join(folder, name))
        for recipe in golden_recipes(catalog):
            portrait(recipe, catalog, view).save(os.path.join(folder, f"{recipe}.png"), format="PNG")


def stale_goldens(catalog, folders=None):
    """Golden stills that are missing, extra, or not what the art draws."""
    out = []
    for view, folder in (folders or GOLDENS).items():
        wanted = {f"{r}.png": r for r in golden_recipes(catalog)}
        present = set(os.listdir(folder)) if os.path.isdir(folder) else set()
        out += [os.path.join(folder, n) for n in sorted(present - set(wanted))]
        for name, recipe in sorted(wanted.items()):
            path = os.path.join(folder, name)
            if name not in present:
                out.append(path)
                continue
            with Image.open(path) as golden:
                if golden.convert("RGBA").tobytes() != portrait(recipe, catalog, view).tobytes():
                    out.append(path)
    return out


def contact_sheet(recipes, catalog, anims=None):
    anims = anims or list(catalog["anims"])
    bw, bh = catalog["box"][2], catalog["box"][3]
    rows = []
    for recipe in recipes:
        for anim in anims:
            for d in catalog["dirs"]:
                rows.append([compose(recipe, catalog, anim, d, i) for i in range(catalog["anims"][anim]["frames"])])
    cols = max(len(r) for r in rows)
    sheet = Image.new("RGBA", (cols * bw, len(rows) * bh), (90, 110, 90, 255))
    for ri, row in enumerate(rows):
        for ci, image in enumerate(row):
            sheet.alpha_composite(image, (ci * bw, ri * bh))
    return sheet


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("out")
    parser.add_argument("recipes", nargs="*")
    parser.add_argument("--random", type=int, default=0)
    parser.add_argument("--anim", action="append")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--catalog", default=CATALOG)
    args = parser.parse_args(argv)
    with open(args.catalog) as handle:
        catalog = json.load(handle)
    rng = random.Random(args.seed)
    recipes = list(args.recipes) + [random_recipe(catalog, rng) for _ in range(args.random)]
    if not recipes:
        recipes = [catalog["default"]]
    contact_sheet(recipes, catalog, args.anim).save(args.out)
    print("\n".join(recipes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
