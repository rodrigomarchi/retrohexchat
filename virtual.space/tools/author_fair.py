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

from PIL import Image, ImageDraw

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
SHEET_COLS = 20

# Props are sized in TILES to sit proportional to a 1x2-tile avatar (Chrono
# Trigger scale — a person is ~2 tiles tall). `source` is a PNG (static) or an
# anim/ folder holding {0..N-1}.png (animated, period_ms set). The union-bbox +
# scale-to-fit packer shrinks each object's art to fit its block.
PROPS = [
    ("fair_bell", "anim/bell", 3, 4, 950),
    ("fair_telepod", "anim/telepod", 3, 3, 480),
    ("fair_fountain", "anim/fountain", 3, 3, 1500),
    ("fair_lantern", "anim/lantern", 1, 3, 720),
    ("fair_tent", "bekkler_tent.png", 4, 4, None),
    ("fair_stall", "melchior_stall.png", 3, 3, None),
    ("fair_cart", "drink_cart.png", 2, 2, None),
    ("fair_tree", "tree.png", 2, 3, None),
    ("fair_arch", "arch.png", 5, 3, None),
    ("fair_board", "board.png", 2, 2, None),
    ("fair_bench", "bench.png", 2, 2, None),
    ("fair_flowers", "flowers.png", 2, 1, None),
    ("fair_barrels", "barrels.png", 2, 2, None),
    ("fair_banner", "banner.png", 1, 3, None),
    ("fair_hedge", "hedge.png", 2, 2, None),
    ("fair_tent2", "bekkler_purple.png", 4, 4, None),
]

_PROP_W = {p[0]: p[2] for p in PROPS}

# Props you can walk through/under — only their end columns block.
WALKTHROUGH = {"fair_arch"}
# Low props you walk over (and sit on) — they add no collision.
NO_COLLIDE = {"fair_bench"}

# The layout is built symmetrically about the vertical centre line (Leene Square
# is a formal, mirrored plaza). CENTRE props sit on the axis; every PAIR entry
# (a left-half placement) is auto-mirrored to the right; EXTRA holds the few
# deliberately-asymmetric pieces (the two different tents, the notice board and
# its balancing bench). Zoned top→bottom: telepod court, tent row, fountain
# garden, market row, entrance — ringed by a dense green border of trees/hedges.
CENTRE = [
    ("fair_bell", 24, 1),           # Leene's Bell crowns the plaza
    ("fair_fountain", 24, 14),      # fountain at the dead centre
    ("fair_flowers", 25, 12), ("fair_flowers", 25, 18),
    ("fair_arch", 23, 29),          # welcome arch at the foot
]
PAIR = [
    # Telepod court (top) + banners flanking the bell.
    ("fair_telepod", 9, 2), ("fair_banner", 20, 1), ("fair_barrels", 14, 4),
    # Tent row: market stalls + banners + benches.
    ("fair_stall", 4, 9), ("fair_banner", 9, 8), ("fair_bench", 21, 10),
    # Fountain garden: hedges and banners frame it, benches face it.
    ("fair_hedge", 20, 13), ("fair_hedge", 20, 16),
    ("fair_banner", 18, 14), ("fair_bench", 21, 19),
    # Market row (lower-mid).
    ("fair_cart", 14, 22), ("fair_banner", 9, 23), ("fair_flowers", 20, 22),
    # Entrance (bottom).
    ("fair_stall", 14, 27), ("fair_cart", 7, 30),
    ("fair_banner", 20, 28), ("fair_flowers", 19, 31),
    # Dense green border ringing the plaza (trees + trimmed hedges).
    ("fair_tree", 1, 4), ("fair_hedge", 1, 10), ("fair_tree", 1, 15),
    ("fair_hedge", 1, 20), ("fair_tree", 1, 25),
    ("fair_tree", 6, 0), ("fair_hedge", 13, 0),
    ("fair_tree", 8, 31), ("fair_hedge", 16, 32),
]
EXTRA = [
    ("fair_tent2", 11, 8),          # Bekkler's purple tent (left)
    ("fair_tent", 37, 8),           # red-and-white tent (right)
    ("fair_board", 7, 21),          # notice board (left, interactable)
    ("fair_bench", 43, 21),         # bench balancing the board (right)
]


def _decor():
    out = list(CENTRE)
    for name, c, r in PAIR:
        out.append((name, c, r))
        out.append((name, W - c - _PROP_W[name], r))
    out += EXTRA
    return out


DECOR = _decor()

# Spawns spread across the open plaza bands, clear of props. The first entry is
# where a lone joiner lands (and the notice-board test walks from).
SPAWN = [
    {"x": 24, "y": 21, "dir": "up"},
    {"x": 18, "y": 6, "dir": "down"}, {"x": 33, "y": 6, "dir": "down"},
    {"x": 18, "y": 11, "dir": "down"}, {"x": 33, "y": 11, "dir": "down"},
    {"x": 15, "y": 20, "dir": "right"}, {"x": 36, "y": 20, "dir": "left"},
    {"x": 20, "y": 24, "dir": "up"}, {"x": 31, "y": 24, "dir": "up"},
    {"x": 24, "y": 6, "dir": "down"}, {"x": 27, "y": 24, "dir": "up"},
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
    wang = Image.open(os.path.join(SRC, "floor_wang.png")).convert("RGBA")
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
        if cx + span > SHEET_COLS:
            cx, cy, shelf_h = 0, cy + shelf_h, 0
        _pack_prop(sheet, ims, cx, cy, w, h)
        vocab[name] = {"col": cx, "row": cy, "w": w, "h": h}
        if period is not None:
            vocab[name].update(frames=len(ims), period_ms=period)
        cx += span
        shelf_h = max(shelf_h, h)

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
