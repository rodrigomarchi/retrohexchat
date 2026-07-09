"""Slice each reference sheet into individual per-tile PNGs + a contact sheet.

The sliced PNGs under `sliced/<sheet>/cCC_rRR.png` are the full browsable
library (freedom to pick any tile later); the labeled `_contact_<sheet>.png`
images help locate coordinates. Only the tiles you name in `manifest.json` get
migrated to code by `migrate.py`.

Usage:
    python3 slice.py            # slice every sheet
"""

import os

from PIL import Image, ImageDraw

TOOLS = os.path.dirname(os.path.abspath(__file__))
GFX = os.path.dirname(TOOLS)
SLICED = os.path.join(GFX, "sliced")

SHEETS = ["Overworld", "Inner", "cave", "objects", "character", "NPC_test", "log"]
TILE = 16


def _empty(tile):
    return tile.getchannel("A").getbbox() is None


def slice_sheet(name, tile=TILE):
    im = Image.open(os.path.join(GFX, f"{name}.png")).convert("RGBA")
    w, h = im.size
    cols, rows = w // tile, h // tile
    out = os.path.join(SLICED, name)
    os.makedirs(out, exist_ok=True)
    kept = 0
    for r in range(rows):
        for c in range(cols):
            t = im.crop((c * tile, r * tile, (c + 1) * tile, (r + 1) * tile))
            if _empty(t):
                continue
            t.save(os.path.join(out, f"c{c:02d}_r{r:02d}.png"))
            kept += 1
    _contact(name, im, w, h, cols, rows, tile)
    print(f"{name}: {cols}x{rows} tiles, kept {kept} non-empty -> {out}")


def _contact(name, im, w, h, cols, rows, tile, scale=4):
    sheet = im.resize((w * scale, h * scale), Image.NEAREST).convert("RGBA")
    d = ImageDraw.Draw(sheet)
    for c in range(cols + 1):
        d.line([(c * tile * scale, 0), (c * tile * scale, h * scale)], fill=(255, 0, 0, 90))
    for r in range(rows + 1):
        d.line([(0, r * tile * scale), (w * scale, r * tile * scale)], fill=(255, 0, 0, 90))
    for c in range(0, cols, 4):
        d.text((c * tile * scale + 1, 1), str(c), fill=(255, 255, 0, 255))
    for r in range(0, rows, 4):
        d.text((1, r * tile * scale + 1), str(r), fill=(0, 255, 255, 255))
    sheet.save(os.path.join(SLICED, f"_contact_{name}.png"))


if __name__ == "__main__":
    os.makedirs(SLICED, exist_ok=True)
    for sheet in SHEETS:
        slice_sheet(sheet)
