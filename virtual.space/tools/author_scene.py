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
    ("eot_pillar", 11, 3),
    ("eot_pillar", 27, 3),
    ("eot_artifact", 15, 3),
    ("eot_portal", 17, 5),
    ("eot_fire", 14, 6),
    ("eot_fire", 21, 6),
    ("eot_lamp", 19, 8),
    ("eot_tv", 9, 10),
    ("eot_armchair", 6, 13),
    ("eot_armchair_l", 11, 13),
    ("eot_sapling", 31, 10),
    ("eot_nu", 26, 13),
    ("eot_signpost", 18, 17),
]
# Solid footprints (the tiles a prop blocks): (col, row, w, h).
SOLID = [(11, 6, 2, 1), (27, 6, 2, 1), (31, 12, 2, 1),
         (18, 19, 1, 1), (19, 11, 2, 1),
         (6, 15, 3, 1), (11, 15, 3, 1), (9, 12, 2, 1),
         (26, 15, 3, 1), (16, 7, 6, 1), (14, 9, 3, 1), (21, 9, 3, 1)]
SPAWN = [{"x": 18, "y": 12, "dir": "right"}, {"x": 22, "y": 12, "dir": "left"}]

# Animated props: real PixelLab object animations. name -> (frames folder under
# scenes/end_of_time/anim/, sheet col, sheet row, w, h, period_ms). Frames are
# packed as a horizontal strip from (col,row); the atlas cycles them.
ANIM_PROPS = {
    "eot_fire": ("fire", 0, 19, 3, 4, 660),
    "eot_lamp": ("lamp", 0, 23, 2, 4, 780),
    "eot_portal": ("portal", 0, 27, 3, 3, 700),
    "eot_star": ("star", 0, 30, 2, 2, 1400),
    # The same twinkle art, shrunk to a faint pinpoint: the deep-sky field.
    "eot_star_far": ("star", 0, 32, 1, 1, 1600),
    # The Matrix nook TV crackling with off-air static, and the Nu breathing.
    "eot_tv": ("tv", 0, 33, 2, 3, 420),
    "eot_nu": ("nu", 0, 36, 3, 3, 1800),
}

# Animated tiles whose frames are scaled down to a small point (px) centred in
# the block, instead of packed at native size — used for the distant stars.
SCALE_TO_FIT = {"eot_star_far": 5}

# A few bright twinkling stars near the island — the foreground of the sky. The
# per-position seed desyncs each one's twinkle so nothing pulses in lockstep.
STARS = [(3, 2), (30, 2), (33, 4), (2, 11), (36, 10), (5, 20), (33, 20)]

# The deep-sky field: tiny distant pinpoints twinkling far away, scattered
# across the void by a hash so they read as an endless starfield (not a grid).
# A void cell gets a far star when its hash clears this threshold.
FAR_STAR_MOD = 5


def _compose_sheet():
    wang = Image.open(os.path.join(SRC, "floor_wang.png")).convert("RGBA")
    lut = json.load(open(os.path.join(SRC, "wang_lut.json")))
    cols = 18
    sheet = Image.new("RGBA", (cols * T, 40 * T), (0, 0, 0, 0))
    vocab = {}
    sheet.alpha_composite(wang, (0, 0))
    for combo, (x, y) in lut.items():
        vocab["f" + combo] = {"col": x // T, "row": y // T, "w": 1, "h": 1}

    # Static starfield void tile — the PixelLab Wang tileset's own void terrain
    # (image-based; no procedural stars).
    vx, vy = lut["0000"]
    sheet.alpha_composite(wang.crop((vx, vy, vx + T, vy + T)), (0, 4 * T))
    vocab["void"] = {"col": 0, "row": 4, "w": 1, "h": 1}

    props = {
        "eot_pillar": ("pillar.png", 8, 0, 2, 4),
        "eot_sapling": ("sapling.png", 10, 0, 2, 3), "eot_signpost": ("signpost.png", 12, 0, 2, 3),
        "eot_armchair": ("armchair_side.png", 6, 7, 3, 3),
        "eot_artifact": ("artifact2.png", 0, 14, 8, 5),
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

    # Animated props: real PixelLab object animations (frames downloaded into
    # scenes/end_of_time/anim/<name>/) packed as horizontal frame strips. All
    # frames share ONE union bbox + placement so only the moving parts (flame,
    # vortex) change between frames — the base/post stays perfectly still. The
    # atlas cycles them on the global clock.
    for name, (folder, col, row, w, h, period) in ANIM_PROPS.items():
        adir = os.path.join(SRC, "anim", folder)
        paths = []
        i = 0
        while os.path.exists(os.path.join(adir, f"{i}.png")):
            paths.append(os.path.join(adir, f"{i}.png"))
            i += 1
        if not paths:
            raise FileNotFoundError(f"no animation frames for {name} in {adir}")
        ims = [Image.open(p).convert("RGBA") for p in paths]
        boxes = [im.getbbox() or (0, 0, im.width, im.height) for im in ims]
        union = (min(b[0] for b in boxes), min(b[1] for b in boxes),
                 max(b[2] for b in boxes), max(b[3] for b in boxes))
        # Crop every frame to ONE shared window (the union bbox) so the moving
        # parts animate while the base stays pinned; then scale the whole object
        # to fit its w×h block (never crop content away). SCALE_TO_FIT shrinks to
        # a tiny centred pinpoint instead (the deep-sky stars).
        bw, bh = w * T, h * T
        uw, uh = union[2] - union[0], union[3] - union[1]
        fit = SCALE_TO_FIT.get(name)
        scale = fit / max(uw, uh) if fit else min(1.0, bw / uw, bh / uh)
        for i, im in enumerate(ims):
            crop = im.crop(union)
            if scale != 1.0:
                crop = crop.resize((max(1, round(uw * scale)),
                                    max(1, round(uh * scale))), Image.LANCZOS)
            block = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
            dy = (bh - crop.height) // 2 if fit else bh - crop.height
            block.alpha_composite(crop, ((bw - crop.width) // 2, dy))
            sheet.alpha_composite(block, ((col + i * w) * T, row * T))
        vocab[name] = {"col": col, "row": row, "w": w, "h": h,
                       "frames": len(ims), "period_ms": period}

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
            row.append("void" if not (nw or ne or sw or se) else f"f{nw}{ne}{sw}{se}")
        floor.append(row)
    # Deep-sky field: a hash-scattered pinpoint in a fraction of the void cells.
    far_stars = [(x, y) for y in range(H) for x in range(W)
                 if floor[y][x] == "void" and _hash(x, y) % FAR_STAR_MOD == 0]
    solid = {(x + dx, y + dy) for (x, y, w, h) in SOLID for dx in range(w) for dy in range(h)}
    collision = []
    for y in range(H):
        for x in range(W):
            if not full(x, y):
                collision.append({"x": x, "y": y, "w": 1, "h": 1, "kind": "void"})
            elif (x, y) in solid:
                collision.append({"x": x, "y": y, "w": 1, "h": 1, "kind": "prop"})
    layout = {
        "width": W, "height": H, "tile_size": T, "ground": "void", "columns": cols,
        "vocab": vocab,
        "floor": floor,
        "decor": [{"x": x, "y": y, "tile": "eot_star_far"} for (x, y) in far_stars]
        + [{"x": x, "y": y, "tile": "eot_star"} for (x, y) in STARS]
        + [{"x": c, "y": r, "tile": n} for (n, c, r) in DECOR],
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
    for x, y in far_stars:
        prev.alpha_composite(rect("eot_star_far"), (x * T, y * T))
    for x, y in STARS:
        prev.alpha_composite(rect("eot_star"), (x * T, y * T))
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
