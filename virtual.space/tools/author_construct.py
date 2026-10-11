#!/usr/bin/env python3
"""Author the ISOMETRIC "Construct" scene: the empty room a channel builds.

A white loading-program floor that stretches to the edge of a pale void, with
one way out: a white-marble gate whose arch holds the starry End of Time sky.
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

from PIL import Image

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
W, H = 20, 20
SHEET_COLS = 10
SHEET_ROWS = 5
Z_STEP = 16
MAX_ITEMS = 150

FLOOR_FILL = (247, 248, 251, 255)
FLOOR_SEAM = (214, 219, 228, 255)

# The way back sits in the far corner of the room, so the floor opens out in
# front of whoever arrives.
EXIT = (2, 2)
SPAWN = [
    {"x": 4, "y": 4, "dir": "down"},
    {"x": 5, "y": 3, "dir": "down"},
    {"x": 3, "y": 5, "dir": "right"},
]

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
        "backdrop": "eef0f4",
        "vignette": {"color": "c3c9d4", "alpha": 0.45, "inner": 0.5},
        "vocab": vocab,
        "floor": [["cst_floor"] * W for _ in range(H)],
        "decor": [{"x": EXIT[0], "y": EXIT[1], "tile": "cst_exit", "sort": "stand"}],
        "collision": [{"x": EXIT[0], "y": EXIT[1], "w": 1, "h": 1, "kind": "prop"}],
        "spawn": SPAWN,
        "lights": [
            {"x": EXIT[0], "y": EXIT[1], "radius": 2.2, "color": "8fb6ff", "blend": "add"},
            {"x": EXIT[0], "y": EXIT[1], "lift": 50, "radius": 1.2, "color": "c9dcff", "blend": "add"},
        ],
        "zones": [{"id": "construct", "kind": "platform", "x": 0, "y": 0, "w": W, "h": H}],
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
