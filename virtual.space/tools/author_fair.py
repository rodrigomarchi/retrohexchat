#!/usr/bin/env python3
"""Author the "Millennial Fair" channel scene (Leene Square, Chrono Trigger).

A bustling cobblestone festival plaza ringed by lawn: Leene's Bell in its
belfry at the centre, Lucca's crackling Telepod, Norstein Bekkler's striped
game tent, Melchior's weapon stall, refreshment carts, a rippling fountain,
paper lanterns, trees and a welcome arch. The lively multi-user hub behind
every channel, in deliberate contrast to the intimate cosmic End of Time DM.

Reads the PixelLab art from ``virtual.space/scenes/millennial_fair/`` (the
grass↔cobblestone Wang floor + the props, animated ones as frame folders under
``anim/<name>/``) and emits two runtime artifacts:

- ``priv/static/images/space/millennialfair.png`` — the packed 16px sheet.
- ``priv/maps/millennial_fair.json`` — the full layout (autotiled plaza floor,
  decor, collision, spawns, zones, labels, tile vocab).

Every prop is packed with the shared union-bbox + scale-to-fit rule from
``ANIMATIONS.md`` (a static prop is just a one-frame animation), so nothing
wobbles and nothing gets cropped. Deterministic; re-run after regenerating art.

See ``virtual.space/SCENES.md`` and ``virtual.space/ANIMATIONS.md``.
"""
import json
import os

from PIL import Image, ImageDraw, ImageEnhance

# Soften the generated stone: the raw Wang floor reads too dark/strong, so we
# lighten it, pull a little saturation out and warm it slightly toward a gentle
# weathered-stone tone. Tunable (brightness, saturation, warm RGB multipliers).
FLOOR_BRIGHTNESS = 1.32
FLOOR_SATURATION = 0.62
FLOOR_WARM = (1.11, 1.05, 0.88)


def _grade_floor(img):
    img = ImageEnhance.Brightness(img).enhance(FLOOR_BRIGHTNESS)
    img = ImageEnhance.Color(img).enhance(FLOOR_SATURATION)
    r, g, b, a = img.split()
    r = r.point(lambda v: min(255, round(v * FLOOR_WARM[0])))
    g = g.point(lambda v: min(255, round(v * FLOOR_WARM[1])))
    b = b.point(lambda v: min(255, round(v * FLOOR_WARM[2])))
    return Image.merge("RGBA", (r, g, b, a))

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(TOOLS, "..", ".."))
SRC = os.path.join(REPO, "virtual.space", "scenes", "millennial_fair")
SHEET_OUT = os.path.join(
    REPO, "apps", "retro_hex_chat_web", "priv", "static", "images", "space", "millennialfair.png"
)
MAP_OUT = os.path.join(REPO, "apps", "retro_hex_chat", "priv", "maps", "millennial_fair.json")

T = 16
W, H = 52, 34
# The cobblestone plaza is a big rounded rectangle (squarish super-ellipse);
# grass fills the rest of the lawn. Everything is walkable — the map bounds are
# the only edge, so there is no "void" collision. The map is larger than the
# viewport so the camera follows the avatar and pans across the fair.
PLAZA = {"cx": 25.5, "cy": 17.0, "rx": 23.0, "ry": 15.5, "p": 5.0}
# Wide enough for the widest animated frame strip (w × frames). An animated
# 4-tile prop with 6 frames is 24 tiles; keep headroom.
SHEET_COLS = 26

# Props are sized in TILES to sit proportional to a 1x2-tile avatar (Chrono
# Trigger scale — a person is ~2 tiles tall). `source` is a PNG (static) or an
# anim/ folder holding {0..N-1}.png (animated, period_ms set). The union-bbox +
# scale-to-fit packer shrinks each object's art to fit its block.
# Sizes in tiles set a realistic HIERARCHY against the ~2-tile-tall avatar:
# carnival tents tower, the belfry/stalls/telepod are mid structures, and the
# small props (lanterns, benches, carts, flowers…) stay person-scale.
PROPS = [
    ("fair_bell", "anim/bell", 4, 5, 950),
    ("fair_telepod", "anim/telepod", 4, 4, 480),
    ("fair_fountain", "anim/fountain", 4, 3, 1500),
    ("fair_lantern", "anim/lantern", 1, 3, 720),
    ("fair_tent", "bekkler_tent.png", 5, 5, None),
    ("fair_stall", "melchior_stall.png", 4, 4, None),
    ("fair_cart", "drink_cart.png", 3, 3, None),
    ("fair_tree", "tree.png", 3, 4, None),
    ("fair_arch", "arch.png", 6, 3, None),
    ("fair_board", "board.png", 2, 2, None),
    ("fair_bench", "bench.png", 2, 2, None),
    ("fair_flowers", "flowers.png", 2, 1, None),
    ("fair_barrels", "barrels.png", 2, 2, None),
    ("fair_banner", "banner.png", 1, 4, None),
    ("fair_hedge", "hedge.png", 2, 2, None),
    ("fair_tent2", "bekkler_purple.png", 5, 5, None),
]

_PROP_W = {p[0]: p[2] for p in PROPS}

# Props you can walk through/under — only their end columns block.
WALKTHROUGH = {"fair_arch"}
# Low props you walk over (and sit on) — they add no collision.
NO_COLLIDE = {"fair_bench", "fair_bench_l"}

# Grass garden beds carved into the stone plaza (vertex rects x0,y0,x1,y1) so the
# floor is not a uniform slab — each holds a tree/flowers, like a real square.
GARDEN_BEDS = [(12, 6, 18, 12), (33, 18, 40, 25)]

# Hand-placed, not mirror-stamped: each piece has a reason and a spot. The plaza
# reads as areas — bell & fountain down the middle, Bekkler's tent and Melchior's
# stall to the west, the striped tent, refreshments and Lucca's telepod to the
# east, the arch at the entrance — with greenery gathered in natural clumps and
# the two garden beds, never a repeated ring.
DECOR = [
    # Landmarks — the plaza's spine.
    ("fair_bell", 23, 1),
    ("fair_banner", 20, 2), ("fair_banner", 29, 2),
    ("fair_fountain", 24, 15),
    ("fair_flowers", 24, 13), ("fair_flowers", 24, 19),
    ("fair_hedge", 20, 16), ("fair_hedge", 30, 16),
    ("fair_bench", 18, 16), ("fair_bench_l", 32, 16),
    # West — Bekkler's fortune tent, the notice board, Melchior's market corner.
    ("fair_tent2", 5, 9),
    ("fair_board", 4, 17),
    ("fair_stall", 7, 25), ("fair_barrels", 12, 26),
    # East — the striped tent, a refreshment cart, Lucca's telepod.
    ("fair_tent", 40, 4), ("fair_cart", 40, 11),
    ("fair_telepod", 41, 24),
    # Entrance at the foot, lit by a pair of lanterns.
    ("fair_arch", 22, 30),
    ("fair_lantern", 20, 27), ("fair_lantern", 31, 27),
    # Garden bed A (west) and B (east): a tree and blooms in each grass patch.
    ("fair_tree", 13, 7), ("fair_flowers", 14, 11),
    ("fair_tree", 35, 19), ("fair_hedge", 38, 22),
    # Greenery gathered in corner clumps (framing, not a ring).
    ("fair_tree", 2, 2), ("fair_hedge", 5, 4),
    ("fair_tree", 47, 2),
    ("fair_tree", 2, 29), ("fair_hedge", 5, 30),
    ("fair_tree", 47, 29), ("fair_hedge", 44, 30),
]

# Spawns in the open plaza, clear of props. The first entry is where a lone
# joiner lands (and the notice-board test walks from).
SPAWN = [
    {"x": 24, "y": 8, "dir": "down"},
    {"x": 16, "y": 13, "dir": "right"}, {"x": 33, "y": 13, "dir": "left"},
    {"x": 12, "y": 20, "dir": "down"}, {"x": 24, "y": 23, "dir": "up"},
    {"x": 30, "y": 21, "dir": "up"}, {"x": 18, "y": 24, "dir": "up"},
    {"x": 35, "y": 16, "dir": "left"}, {"x": 20, "y": 8, "dir": "down"},
    {"x": 31, "y": 8, "dir": "down"}, {"x": 24, "y": 27, "dir": "up"},
]


def _load_frames(source):
    if source.startswith("anim/"):
        adir = os.path.join(SRC, "anim", source.split("/", 1)[1])
        paths, i = [], 0
        while os.path.exists(os.path.join(adir, f"{i}.png")):
            paths.append(os.path.join(adir, f"{i}.png"))
            i += 1
        if not paths:
            raise FileNotFoundError(f"no animation frames in {adir}")
        return [Image.open(p).convert("RGBA") for p in paths]
    return [Image.open(os.path.join(SRC, source)).convert("RGBA")]


def _pack_prop(sheet, ims, col, row, w, h):
    """Pack frames as a horizontal strip from (col,row): one shared union-bbox
    window (stable base), scaled to fit the w×h block (never cropped), bottom
    anchored. Returns the number of frames packed."""
    boxes = [im.getbbox() or (0, 0, im.width, im.height) for im in ims]
    union = (min(b[0] for b in boxes), min(b[1] for b in boxes),
             max(b[2] for b in boxes), max(b[3] for b in boxes))
    bw, bh = w * T, h * T
    uw, uh = union[2] - union[0], union[3] - union[1]
    scale = min(1.0, bw / uw, bh / uh)
    for i, im in enumerate(ims):
        crop = im.crop(union)
        if scale != 1.0:
            crop = crop.resize((max(1, round(uw * scale)),
                                max(1, round(uh * scale))), Image.LANCZOS)
        block = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
        block.alpha_composite(crop, ((bw - crop.width) // 2, bh - crop.height))
        sheet.alpha_composite(block, ((col + i * w) * T, row * T))
    return len(ims)


def _compose_sheet():
    wang = _grade_floor(Image.open(os.path.join(SRC, "floor_wang.png")).convert("RGBA"))
    lut = json.load(open(os.path.join(SRC, "wang_lut.json")))
    sheet = Image.new("RGBA", (SHEET_COLS * T, 40 * T), (0, 0, 0, 0))
    vocab = {}
    # Wang floor tiles pack into the 4×4 grid at the sheet origin.
    sheet.alpha_composite(wang, (0, 0))
    for combo, (x, y) in lut.items():
        vocab["f" + combo] = {"col": x // T, "row": y // T, "w": 1, "h": 1}

    # Auto-pack every prop onto shelves below the Wang grid (rows 4+).
    cx, cy, shelf_h = 0, 4, 0
    for name, source, w, h, period in PROPS:
        ims = _load_frames(source)
        span = w * len(ims)
        if span > SHEET_COLS:
            raise ValueError(
                f"{name} strip is {span} tiles wide but SHEET_COLS={SHEET_COLS}; "
                "frames would fall off the sheet and flicker — widen SHEET_COLS"
            )
        if cx + span > SHEET_COLS:
            cx, cy, shelf_h = 0, cy + shelf_h, 0
        _pack_prop(sheet, ims, cx, cy, w, h)
        vocab[name] = {"col": cx, "row": cy, "w": w, "h": h}
        if period is not None:
            vocab[name].update(frames=len(ims), period_ms=period)
        cx += span
        shelf_h = max(shelf_h, h)

    # Flipped bench variant (same sheet rect, mirrored at render time) so the
    # right-hand benches face back toward the plaza centre.
    vocab["fair_bench_l"] = {**vocab["fair_bench"], "flip_x": True}

    return sheet, vocab


def _plaza_grid():
    c = PLAZA
    def inside(vx, vy):
        return 1 if (abs(vx - c["cx"]) / c["rx"]) ** c["p"] + (abs(vy - c["cy"]) / c["ry"]) ** c["p"] <= 1 else 0
    g = [[inside(x, y) for x in range(W + 1)] for y in range(H + 1)]
    # One majority-smoothing pass erodes lone spikes/notches on the plaza edge.
    out = [row[:] for row in g]
    for y in range(H + 1):
        for x in range(W + 1):
            n = sum(g[y + dy][x + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                    if 0 <= x + dx <= W and 0 <= y + dy <= H)
            out[y][x] = 1 if n >= 6 else (0 if n <= 2 else g[y][x])
    # Carve grass garden beds back into the stone (0 = grass vertices).
    for x0, y0, x1, y1 in GARDEN_BEDS:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if 0 <= x <= W and 0 <= y <= H:
                    out[y][x] = 0
    return out


def build():
    sheet, vocab = _compose_sheet()
    g = _plaza_grid()
    floor = []
    for y in range(H):
        row = []
        for x in range(W):
            nw, ne, sw, se = g[y][x], g[y][x + 1], g[y + 1][x], g[y + 1][x + 1]
            row.append(f"f{nw}{ne}{sw}{se}")
        floor.append(row)

    # Collision is auto-derived: each prop blocks its base row (the tiles it
    # stands on); a walk-through prop blocks only its two end columns.
    solid = set()
    for name, c, r in DECOR:
        if name in NO_COLLIDE:
            continue
        v = vocab[name]
        base = r + v["h"] - 1
        if name in WALKTHROUGH:
            solid |= {(c, base), (c + v["w"] - 1, base)}
        else:
            solid |= {(c + dx, base) for dx in range(v["w"])}
    collision = [
        {"x": x, "y": y, "w": 1, "h": 1, "kind": "prop"}
        for (x, y) in sorted(solid)
        if 0 <= x < W and 0 <= y < H
    ]

    layout = {
        "width": W, "height": H, "tile_size": T, "ground": "f0000", "columns": SHEET_COLS,
        "vocab": vocab,
        "floor": floor,
        "decor": [{"x": c, "y": r, "tile": n} for (n, c, r) in DECOR],
        "collision": collision,
        "spawn": SPAWN,
        "zones": [{"id": "fair", "kind": "public", "x": 3, "y": 3, "w": 46, "h": 28}],
        "labels": [],
    }
    os.makedirs(os.path.dirname(SHEET_OUT), exist_ok=True)
    os.makedirs(os.path.dirname(MAP_OUT), exist_ok=True)
    sheet.save(SHEET_OUT)
    json.dump(layout, open(MAP_OUT, "w"))

    # Visual preview alongside the source art.
    prev = Image.new("RGBA", (W * T, H * T), (40, 30, 20, 255))
    def rect(n):
        v = vocab[n]
        return sheet.crop((v["col"] * T, v["row"] * T, (v["col"] + v["w"]) * T, (v["row"] + v["h"]) * T))
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
    print(f"OK sheet={sheet.size} tiles={len(vocab)} collision={len(collision)}")
    print(f"  -> {os.path.relpath(SHEET_OUT, REPO)}")
    print(f"  -> {os.path.relpath(MAP_OUT, REPO)}")


if __name__ == "__main__":
    build()
