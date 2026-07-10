#!/usr/bin/env python3
"""Author the "End of Time" direct-message scene.

Reads the PixelLab-generated raw art from
``virtual.space/scenes/end_of_time/`` (the Wang floor tileset + its metadata and
the six map-object props) and produces two runtime artifacts:

- ``apps/retro_hex_chat_web/priv/static/images/space/endoftime.png`` — the packed
  16px tileset (16 Wang floor tiles + 6 starfield-void variants + a soft lamp
  glow + the six props).
- ``apps/retro_hex_chat/priv/maps/end_of_time.json`` — the full map layout:
  the autotiled floor matrix, decor placements, collision, spawns, zones, labels,
  and the tile ``vocab`` (name -> {col,row,w,h}) the Elixir module turns into
  ``tiles``.

The stone island is a smoothed super-ellipse; each floor cell picks its Wang tile
by the terrain of its four corners (upper=stone / lower=void). Deterministic:
same inputs -> identical outputs. Re-run after regenerating any raw art.

See ``virtual.space/SCENES.md`` for the full scene pipeline.
"""
import json
import math
import os

from PIL import Image, ImageDraw

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(TOOLS, "..", ".."))
SRC = os.path.join(REPO, "virtual.space", "scenes", "end_of_time")
SHEET_OUT = os.path.join(
    REPO, "apps", "retro_hex_chat_web", "priv", "static", "images", "space", "endoftime.png"
)
MAP_OUT = os.path.join(REPO, "apps", "retro_hex_chat", "priv", "maps", "end_of_time.json")

T = 16
W, H = 40, 24
ELLIPSE = {"cx": 20.0, "cy": 12.0, "rx": 15.5, "ry": 9.2, "p": 2.6}

# Decor placements: (tile name, top-left col, row). Painter order (glow first).
# The two red leather armchairs + old TV are the Matrix "construct" nook: the
# chairs face each other (left one faces right, right one is the mirror) with
# the TV set between them, a little higher up.
DECOR = [
    ("eot_glow", 17, 10),
    ("eot_pillar", 11, 3),
    ("eot_pillar", 27, 3),
    ("eot_sapling", 25, 6),
    ("eot_armchair", 6, 9),
    ("eot_armchair_l", 11, 9),
    ("eot_tv", 9, 7),
    ("eot_nu", 25, 10),
    ("eot_artifact", 15, 3),
    ("eot_bench", 11, 14),
    ("eot_bucket", 27, 15),
    ("eot_signpost", 18, 17),
    ("eot_lamp", 19, 8),
]
# Solid footprints (the tiles a prop blocks): (col, row, w, h).
SOLID = [(11, 6, 2, 1), (27, 6, 2, 1), (25, 8, 2, 1), (11, 15, 3, 1),
         (27, 16, 2, 1), (18, 19, 1, 1), (19, 11, 2, 1),
         (6, 11, 3, 1), (11, 11, 3, 1), (9, 9, 2, 1),
         (25, 12, 3, 1), (16, 7, 6, 1)]
SPAWN = [{"x": 18, "y": 12, "dir": "right"}, {"x": 22, "y": 12, "dir": "left"}]


def _compose_sheet():
    wang = Image.open(os.path.join(SRC, "floor_wang.png")).convert("RGBA")
    lut = json.load(open(os.path.join(SRC, "wang_lut.json")))
    cols = 16
    sheet = Image.new("RGBA", (cols * T, 19 * T), (0, 0, 0, 0))
    vocab = {}
    sheet.alpha_composite(wang, (0, 0))
    for combo, (x, y) in lut.items():
        vocab["f" + combo] = {"col": x // T, "row": y // T, "w": 1, "h": 1}
    vx, vy = lut["0000"]
    base = wang.crop((vx, vy, vx + T, vy + T))
    star = [(220, 232, 255, 255), (180, 200, 255, 255), (255, 244, 214, 255)]
    for i in range(6):
        v = base.copy()
        px = v.load()
        for k in range((i % 3) + 1 if i else 0):
            sx = (i * 5 + k * 7 + 3) % 14 + 1
            sy = (i * 3 + k * 11 + 2) % 14 + 1
            px[sx, sy] = star[(i + k) % 3]
        sheet.alpha_composite(v, (i * T, 4 * T))
        vocab[f"void{i}"] = {"col": i, "row": 4, "w": 1, "h": 1}
    gw = 5 * T
    glow = Image.new("RGBA", (gw, gw), (0, 0, 0, 0))
    gp = glow.load()
    for y in range(gw):
        for x in range(gw):
            d = math.hypot(x - gw / 2, y - gw / 2) / (gw / 2)
            gp[x, y] = (255, 190, 95, int(max(0.0, 1 - d) ** 2 * 0.6 * 255))
    sheet.alpha_composite(glow, (0, 5 * T))
    vocab["eot_glow"] = {"col": 0, "row": 5, "w": 5, "h": 5}
    props = {
        "eot_lamp": ("lamp.png", 6, 0, 2, 4), "eot_pillar": ("pillar.png", 8, 0, 2, 4),
        "eot_sapling": ("sapling.png", 10, 0, 2, 3), "eot_signpost": ("signpost.png", 12, 0, 2, 3),
        "eot_bench": ("bench.png", 6, 5, 3, 2), "eot_bucket": ("bucket.png", 9, 5, 2, 2),
        "eot_tv": ("tv.png", 14, 0, 2, 3), "eot_armchair": ("armchair_side.png", 6, 7, 3, 3),
        "eot_nu": ("nu.png", 11, 5, 3, 3), "eot_artifact": ("artifact2.png", 0, 14, 8, 5),
    }
    for name, (fn, col, row, w, h) in props.items():
        im = Image.open(os.path.join(SRC, fn)).convert("RGBA")
        crop = im.crop(im.getbbox() or (0, 0, im.width, im.height))
        if crop.width > w * T:
            off = (crop.width - w * T) // 2
            crop = crop.crop((off, 0, off + w * T, crop.height))
        if crop.height > h * T:
            crop = crop.crop((0, crop.height - h * T, crop.width, crop.height))
        block = Image.new("RGBA", (w * T, h * T), (0, 0, 0, 0))
        block.alpha_composite(crop, ((w * T - crop.width) // 2, h * T - crop.height))
        sheet.alpha_composite(block, (col * T, row * T))
        vocab[name] = {"col": col, "row": row, "w": w, "h": h}
    # Mirror of the side armchair (same sheet rect, flipped at render time) so
    # the two chairs face each other.
    av = vocab["eot_armchair"]
    vocab["eot_armchair_l"] = {**av, "flip_x": True}
    return sheet, vocab, cols


def _stone_grid():
    c = ELLIPSE
    def raw(vx, vy):
        return 1 if (abs(vx - c["cx"]) / c["rx"]) ** c["p"] + (abs(vy - c["cy"]) / c["ry"]) ** c["p"] <= 1 else 0
    g = [[raw(x, y) for x in range(W + 1)] for y in range(H + 1)]
    out = [row[:] for row in g]
    for y in range(H + 1):
        for x in range(W + 1):
            n = sum(g[y + dy][x + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                    if 0 <= x + dx <= W and 0 <= y + dy <= H)
            out[y][x] = 1 if n >= 6 else (0 if n <= 2 else g[y][x])
    return out


def _hash(x, y):
    return (x * 928371 + y * 1237) & 0xFFFF


def build():
    sheet, vocab, cols = _compose_sheet()
    g = _stone_grid()
    def full(x, y):
        return g[y][x] and g[y][x + 1] and g[y + 1][x] and g[y + 1][x + 1]
    floor = []
    for y in range(H):
        row = []
        for x in range(W):
            nw, ne, sw, se = g[y][x], g[y][x + 1], g[y + 1][x], g[y + 1][x + 1]
            row.append(f"void{_hash(x, y) % 6}" if not (nw or ne or sw or se) else f"f{nw}{ne}{sw}{se}")
        floor.append(row)
    solid = {(x + dx, y + dy) for (x, y, w, h) in SOLID for dx in range(w) for dy in range(h)}
    collision = []
    for y in range(H):
        for x in range(W):
            if not full(x, y):
                collision.append({"x": x, "y": y, "w": 1, "h": 1, "kind": "void"})
            elif (x, y) in solid:
                collision.append({"x": x, "y": y, "w": 1, "h": 1, "kind": "prop"})
    layout = {
        "width": W, "height": H, "tile_size": T, "ground": "void0", "columns": cols,
        "vocab": vocab,
        "floor": floor,
        "decor": [{"x": c, "y": r, "tile": n} for (n, c, r) in DECOR],
        "collision": collision,
        "spawn": SPAWN,
        "zones": [{"id": "eot", "kind": "private", "x": 6, "y": 4, "w": 28, "h": 16}],
        "labels": [{"id": "dm_nameplate", "kind": "hologram",
                    "x": 16, "y": 4, "w": 6, "h": 1, "text": ""}],
    }
    os.makedirs(os.path.dirname(SHEET_OUT), exist_ok=True)
    os.makedirs(os.path.dirname(MAP_OUT), exist_ok=True)
    sheet.save(SHEET_OUT)
    json.dump(layout, open(MAP_OUT, "w"))
    # visual preview alongside the source art
    prev = Image.new("RGBA", (W * T, H * T), (10, 10, 26, 255))
    def rect(n):
        v = vocab[n]
        img = sheet.crop((v["col"] * T, v["row"] * T, (v["col"] + v["w"]) * T, (v["row"] + v["h"]) * T))
        return img.transpose(Image.FLIP_LEFT_RIGHT) if v.get("flip_x") else img
    for y in range(H):
        for x in range(W):
            prev.alpha_composite(rect(floor[y][x]), (x * T, y * T))
    for n, c, r in DECOR:
        prev.alpha_composite(rect(n), (c * T, r * T))
    d = ImageDraw.Draw(prev)
    for s in SPAWN:
        d.ellipse([s["x"] * T + 3, s["y"] * T + 3, s["x"] * T + 13, s["y"] * T + 13],
                  outline=(120, 255, 160, 255), width=2)
    prev.resize((W * T * 2, H * T * 2), Image.NEAREST).save(os.path.join(SRC, "scene_preview.png"))
    print(f"OK sheet={sheet.size} cols={cols} tiles={len(vocab)} collision={len(collision)}")
    print(f"  -> {os.path.relpath(SHEET_OUT, REPO)}")
    print(f"  -> {os.path.relpath(MAP_OUT, REPO)}")


if __name__ == "__main__":
    build()
