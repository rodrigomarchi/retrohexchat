#!/usr/bin/env python3
"""Author the ISOMETRIC "Construct" scene: the empty room a channel builds.

A white loading-program floor floating in the End of Time's own sky — the same
deep-blue sea, twinkling stars and vignette, under a dark slab like the
islands' — with one way out: a white-marble gate whose arch holds that sky.
Everything else on it is placed by the people inside. The scene therefore
carries no furniture of its own, only the **catalog** of what can be placed:
each kind's tile per facing, whether it can be sat on, and the light it casts.

Reads the PixelLab art in ``virtual.space/scenes/construct/`` and emits the
packed ``construct.webp`` sheet and ``priv/maps/construct.json``.

The floor diamond is drawn here, not generated. It reuses the End of Time
floor's own alpha, so it is exactly the diamond the projection tessellates,
filled flat white with a faint grey seam that gives builders a grid to place
on. Deterministic.
"""
import json
import os

from PIL import Image, ImageDraw

from sheet_io import save_sheet

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(TOOLS, "..", ".."))
SRC = os.path.join(REPO, "virtual.space", "scenes", "construct")
EOT_FLOOR = os.path.join(REPO, "virtual.space", "scenes", "end_of_time", "iso", "floor_0.png")
SHEET_OUT = os.path.join(
    REPO, "apps", "retro_hex_chat_web", "priv", "static", "images", "space", "construct.webp"
)
MAP_OUT = os.path.join(REPO, "apps", "retro_hex_chat", "priv", "maps", "construct.json")

T = 32
# A 48×48 floor with a margin of sky on every side, so the stars and the sea
# show around the island however far the camera follows a builder to an edge.
MARGIN = 8
FLOOR = 48
W = H = FLOOR + 2 * MARGIN
SHEET_COLS = 10
SHEET_ROWS = 5
Z_STEP = 16
MAX_ITEMS = 400

FLOOR_FILL = (247, 248, 251, 255)
FLOOR_SEAM = (214, 219, 228, 255)

# The way back sits in the far corner of the floor, so the room opens out in
# front of whoever arrives.
X0 = Y0 = MARGIN
X1 = Y1 = MARGIN + FLOOR - 1
EXIT = (X0 + 2, Y0 + 2)
SPAWN = [
    {"x": EXIT[0] + 2, "y": EXIT[1] + 2, "dir": "down"},
    {"x": EXIT[0] + 3, "y": EXIT[1] + 1, "dir": "down"},
    {"x": EXIT[0] + 1, "y": EXIT[1] + 3, "dir": "right"},
]
# The End of Time's sky, value for value (`author_scene.py`).
SEA = {"top": "0c1e42", "bottom": "05060f", "band": "1a3d7a", "bands": 9, "amp": 5}
VIGNETTE = {"color": "04050c", "alpha": 0.78, "inner": 0.36}

# Placeable kinds: art file and how the kind behaves once placed. The art faces
# screen down-left, which is tile "down"; its mirror is tile "right".
KINDS = {
    "chair": {"file": "chair.png", "seat": True},
    "table": {"file": "table.png"},
    "tree": {"file": "tree.png"},
    "lamp": {
        "file": "lamp.png",
        "lights": [
            {"radius": 2.4, "color": "ffd591", "blend": "add"},
            {"lift": 72, "radius": 1.0, "color": "ffe6a8", "blend": "add"},
        ],
    },
}


def _crop(im):
    return im.crop(im.getbbox() or (0, 0, im.width, im.height))


def _cells(w_px, h_px):
    return (w_px + T - 1) // T, (h_px + T - 1) // T


def _place(sheet, vocab, name, im, col, row, native=False):
    """Pack `im` bottom-centred (props) or flush top-left (`native`, the floor
    diamond) in its cell block and record the vocab rect."""
    w, h = _cells(im.width, im.height)
    block = Image.new("RGBA", (w * T, h * T), (0, 0, 0, 0))
    if native:
        block.alpha_composite(im, (0, 0))
    else:
        block.alpha_composite(im, ((w * T - im.width) // 2, h * T - im.height))
    sheet.alpha_composite(block, (col * T, row * T))
    entry = {"col": col, "row": row, "w": w, "h": h}
    if native:
        entry["wpx"], entry["hpx"] = im.width, im.height
    vocab[name] = entry
    return col + w


def _floor_tile():
    """A flat white diamond on the End of Time floor's exact alpha: interior
    pixels filled, pixels on the diamond's edge drawn as a light seam."""
    shape = Image.open(EOT_FLOOR).convert("RGBA")
    w, h = shape.size
    src = shape.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dst = out.load()

    def solid(x, y):
        return 0 <= x < w and 0 <= y < h and src[x, y][3] >= 128

    for y in range(h):
        for x in range(w):
            if not solid(x, y):
                continue
            edge = not all(solid(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            dst[x, y] = FLOOR_SEAM if edge else FLOOR_FILL
    return out


def build():
    floor = _floor_tile()
    fw, fh = floor.size
    sheet = Image.new("RGBA", (SHEET_COLS * T, SHEET_ROWS * T), (0, 0, 0, 0))
    vocab = {"g": {"col": SHEET_COLS - 1, "row": 0, "w": 1, "h": 1}}

    _place(sheet, vocab, "cst_floor", floor, 0, 0, native=True)

    col = 0
    row = 1
    col = _place(sheet, vocab, "cst_exit", _crop(Image.open(os.path.join(SRC, "exit.png")).convert("RGBA")), col, row)

    catalog = {}
    for kind, spec in KINDS.items():
        im = _crop(Image.open(os.path.join(SRC, spec["file"])).convert("RGBA"))
        name = f"cst_{kind}"
        col = _place(sheet, vocab, name, im, col, row)
        if col > SHEET_COLS - 1:
            raise AssertionError(f"{name}: sheet is {SHEET_COLS} columns, packing reached {col}")
        if im.height > (SHEET_ROWS - row) * T:
            raise AssertionError(f"{name}: {im.height}px does not fit under row {row}")
        vocab[f"{name}_r"] = dict(vocab[name], flip_x=True)
        entry = {"tiles": {"down": name, "right": f"{name}_r"}}
        if spec.get("seat"):
            entry["seat"] = True
        if spec.get("lights"):
            entry["lights"] = spec["lights"]
        catalog[kind] = entry

    # The End of Time's twinkling star, drawn the same way into this sheet.
    srow = SHEET_ROWS - 1
    for i, r in enumerate((1, 2, 3, 2)):
        star = Image.new("RGBA", (T, T), (0, 0, 0, 0))
        c = T // 2
        ImageDraw.Draw(star).ellipse([c - r, c - r, c + r, c + r], fill=(232, 238, 255, 255))
        sheet.alpha_composite(star, ((SHEET_COLS - 5 + i) * T, srow * T))
    vocab["iso_star"] = {"col": SHEET_COLS - 5, "row": srow, "w": 1, "h": 1,
                         "frames": 4, "period_ms": 1100}

    def on_floor(x, y):
        return X0 <= x <= X1 and Y0 <= y <= Y1

    def _h(x, y):
        return (x * 928371 + y * 1237) & 0xFFFF

    stars = [{"x": x, "y": y, "tile": "iso_star", "sort": "flat"}
             for y in range(H) for x in range(W)
             if not on_floor(x, y) and _h(x, y) % 13 == 0]

    # The sky is the void around the floor: blocked, as merged row runs.
    void = []
    for y in range(H):
        x = 0
        while x < W:
            if on_floor(x, y):
                x += 1
                continue
            start = x
            while x < W and not on_floor(x, y):
                x += 1
            void.append({"x": start, "y": y, "w": x - start, "h": 1, "kind": "void"})

    reserved = sorted(
        {(EXIT[0] + dx, EXIT[1] + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
        | {(s["x"], s["y"]) for s in SPAWN}
    )
    reserved = [[x, y] for x, y in reserved if 0 <= x < W and 0 <= y < H]

    layout = {
        "width": W,
        "height": H,
        "tile_size": T,
        "ground": "g",
        "columns": SHEET_COLS,
        "projection": "isometric",
        "iso": {"tile_w": fw, "tile_h": fh, "z_step": Z_STEP, "headroom": 8},
        "sea": SEA,
        "vignette": VIGNETTE,
        "slabs": [{"thickness": 10, "taper": 0.78, "hull": [X0, X1, Y0, Y1]}],
        "vocab": vocab,
        "floor": [["cst_floor" if on_floor(x, y) else "g" for x in range(W)] for y in range(H)],
        "decor": stars + [{"x": EXIT[0], "y": EXIT[1], "tile": "cst_exit", "sort": "stand"}],
        "collision": void + [{"x": EXIT[0], "y": EXIT[1], "w": 1, "h": 1, "kind": "prop"}],
        "spawn": SPAWN,
        "lights": [
            {"x": EXIT[0], "y": EXIT[1], "radius": 2.2, "color": "8fb6ff", "blend": "add"},
            {"x": EXIT[0], "y": EXIT[1], "lift": 50, "radius": 1.2, "color": "c9dcff", "blend": "add"},
        ],
        "zones": [{"id": "construct", "kind": "platform", "x": X0, "y": Y0, "w": FLOOR, "h": FLOOR}],
        "interactables": [
            {
                "id": "construct_exit",
                "kind": "portal",
                "x": EXIT[0],
                "y": EXIT[1],
                "title": "End of Time",
                "modal": {"kind": "confirm", "action": "exit_construct"},
            }
        ],
        "reserved": reserved,
        "catalog": catalog,
        "max_items": MAX_ITEMS,
    }

    for s in SPAWN:
        if (s["x"], s["y"]) == EXIT:
            raise AssertionError(f"spawn {s} stands on the exit")

    save_sheet(sheet, SHEET_OUT)
    with open(MAP_OUT, "w") as out:
        json.dump(layout, out)
    print(f"OK construct: sheet={sheet.size} diamond={fw}x{fh} kinds={sorted(catalog)} "
          f"reserved={len(reserved)}")


if __name__ == "__main__":
    build()
