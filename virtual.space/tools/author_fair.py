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
# Gently mute the flat tileset (mostly pulls the grass green down a touch).
FLOOR_BRIGHTNESS = 0.95
FLOOR_SATURATION = 0.78
FLOOR_WARM = (1.0, 1.0, 1.0)


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
W, H = 40, 26
# Floor: a GRASS fairground with a round STONE plaza at the centre and stone
# avenues crossing it (vertical entrance→bell, horizontal). Structures line the
# avenues; grass fills the quadrants.
PLAZA = {"cx": 20.0, "cy": 11.0, "rx": 6.5, "ry": 5.0}   # central stone plaza
PATHS = [(18, 0, 21, 25), (0, 10, 39, 12)]               # vertical + horizontal avenues
SHEET_COLS = 20

# Props are sized in TILES to sit proportional to a 1x2-tile avatar (Chrono
# Trigger scale — a person is ~2 tiles tall). `source` is a PNG (static) or an
# anim/ folder holding {0..N-1}.png (animated, period_ms set). The union-bbox +
# scale-to-fit packer shrinks each object's art to fit its block.
# Sizes in tiles set a realistic HIERARCHY against the ~2-tile-tall avatar:
# carnival tents tower, the belfry/stalls/telepod are mid structures, and the
# small props (lanterns, benches, carts, flowers…) stay person-scale.
# All art is cohesive flat 16-bit (SNES) now; tile sizes match each sprite's
# native pixel size so nothing is up/down-scaled (crisp pixels).
PROPS = [
    ("fair_bell", "anim/bell", 3, 4, 950),
    ("fair_telepod", "anim/telepod", 3, 3, 480),
    ("fair_fountain", "anim/fountain", 3, 3, 1500),
    ("fair_lantern", "anim/lantern", 2, 2, 720),
    ("fair_tent", "bekkler_tent.png", 4, 4, None),
    ("fair_stall", "melchior_stall.png", 3, 3, None),
    ("fair_cart", "drink_cart.png", 3, 3, None),
    ("fair_arch", "arch.png", 5, 3, None),
    ("fair_board", "board.png", 3, 2, None),
    ("fair_bench", "bench.png", 2, 1, None),
    ("fair_flowers", "flowers.png", 3, 2, None),
    ("fair_barrels", "barrels.png", 3, 2, None),
    ("fair_banner", "banner.png", 2, 4, None),
    ("fair_tent2", "bekkler_purple.png", 4, 5, None),
    ("fair_tree", "tree.png", 3, 4, None),
    ("fair_bush", "bush.png", 2, 2, None),
]

_PROP_W = {p[0]: p[2] for p in PROPS}

# Props you can walk through/under — only their end columns block.
WALKTHROUGH = {"fair_arch"}
# Low props you walk over (and sit on) — they add no collision.
NO_COLLIDE = {"fair_bench", "fair_bench_l"}

# Garden beds removed for now (the flat grass squares + potted trees read badly);
# greenery returns once the ground and scale are coherent.
GARDEN_BEDS = []

# Hand-placed, not mirror-stamped: each piece has a reason and a spot. The plaza
# reads as areas — bell & fountain down the middle, Bekkler's tent and Melchior's
# stall to the west, the striped tent, refreshments and Lucca's telepod to the
# east, the arch at the entrance — with greenery gathered in natural clumps and
# the two garden beds, never a repeated ring.
DECOR = [
    # The market street down the middle: bell → fountain → entrance arch.
    ("fair_bell", 18, 0),
    ("fair_banner", 15, 1), ("fair_banner", 23, 1),
    ("fair_fountain", 19, 9),
    ("fair_flowers", 19, 6), ("fair_flowers", 19, 13),
    ("fair_bench", 15, 11), ("fair_bench_l", 24, 11),
    ("fair_arch", 17, 23),
    ("fair_lantern", 15, 21), ("fair_lantern", 23, 21),
    # West of the street: Bekkler's tent, Melchior's stall + barrels, telepod, board.
    ("fair_tent2", 10, 1),
    ("fair_stall", 12, 6), ("fair_barrels", 12, 15),
    ("fair_telepod", 2, 5),
    ("fair_board", 2, 13),
    # East of the street: the striped tent and a refreshment cart.
    ("fair_tent", 25, 1),
    ("fair_cart", 25, 6),
    # Trees and bushes planted in the grass quadrants (natural clumps, framing).
    ("fair_tree", 5, 1), ("fair_bush", 8, 4),
    ("fair_tree", 34, 1), ("fair_bush", 31, 5),
    ("fair_tree", 5, 16), ("fair_bush", 9, 20), ("fair_bush", 2, 21),
    ("fair_tree", 28, 14), ("fair_tree", 34, 19),
    ("fair_bush", 25, 20), ("fair_bush", 32, 16),
]

# Spawns in the open plaza/avenues, clear of props. The first entry is where a
# lone joiner lands (and the notice-board test walks from).
SPAWN = [
    {"x": 19, "y": 18, "dir": "up"},
    {"x": 16, "y": 8, "dir": "down"}, {"x": 23, "y": 9, "dir": "down"},
    {"x": 8, "y": 11, "dir": "right"}, {"x": 31, "y": 11, "dir": "left"},
    {"x": 18, "y": 18, "dir": "up"}, {"x": 21, "y": 18, "dir": "up"},
    {"x": 19, "y": 20, "dir": "up"}, {"x": 20, "y": 4, "dir": "down"},
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
    # Grass base (0); lay stone (1) as the central plaza + the avenues.
    c = PLAZA
    g = [[0] * (W + 1) for _ in range(H + 1)]
    for y in range(H + 1):
        for x in range(W + 1):
            if ((x - c["cx"]) / c["rx"]) ** 2 + ((y - c["cy"]) / c["ry"]) ** 2 <= 1:
                g[y][x] = 1
    for x0, y0, x1, y1 in PATHS:
        for y in range(max(0, y0), min(H, y1) + 1):
            for x in range(max(0, x0), min(W, x1) + 1):
                g[y][x] = 1
    # One majority pass softens the rigid right-angle corners where the plaza
    # meets the avenues, so the stone reads a little more organic.
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
