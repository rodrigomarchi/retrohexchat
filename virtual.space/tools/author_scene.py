#!/usr/bin/env python3
"""Author the ISOMETRIC "End of Time" DM scene (P3+).

Reads real iso art from ``virtual.space/scenes/end_of_time/iso/`` — the diamond
cobblestone floor variations, an ornate golden railing, and the reused upright
props (lamp/gate/bucket, billboarded on the iso floor) — and emits the packed
sheet + an isometric ``end_of_time.json`` (diamond floor matrix, edge railings,
slab thickness, vignette, amber lamp pool, twinkling stars).

The diamond ratio is taken from the floor art's NATIVE size (never deformed):
`iso.tile_w`/`tile_h` = the cropped floor tile's width/height, so the engine's
projection tessellates the real pixels 1:1. Deterministic.
"""
import json
import os

from PIL import Image, ImageDraw

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(TOOLS, "..", ".."))
SRC = os.path.join(REPO, "virtual.space", "scenes", "end_of_time")
ISO = os.path.join(SRC, "iso")
SHEET_OUT = os.path.join(
    REPO, "apps", "retro_hex_chat_web", "priv", "static", "images", "space", "endoftime.png"
)
MAP_OUT = os.path.join(REPO, "apps", "retro_hex_chat/priv/maps/end_of_time.json")

T = 32                 # sheet addressing cell (tile_size); scale = 32/T = 1
W, H = 40, 24
# A beveled-rectangle (octagon) platform in TILE space. In iso this projects to a
# clean diamond with STRAIGHT diagonal screen edges — so the railings run
# continuous, not staircased (a wobbly super-ellipse made the fence stagger).
# The bevel softens the four points into short corners (CT-like octagon).
RECT = {"x0": 9, "x1": 31, "y0": 5, "y1": 19, "bevel": 0}
SHEET_COLS = 20
Z_STEP = 16


def _crop(im):
    return im.crop(im.getbbox() or (0, 0, im.width, im.height))


def _floor_tiles():
    """Load the diamond floor variations at their NATIVE canvas size (never
    cropped/resized — the exact 2:1 rhombus must tessellate seam-free)."""
    tiles = []
    i = 0
    while os.path.exists(os.path.join(ISO, f"floor_{i}.png")):
        tiles.append(Image.open(os.path.join(ISO, f"floor_{i}.png")).convert("RGBA"))
        i += 1
    if not tiles:
        raise FileNotFoundError(f"no floor_*.png in {ISO}")
    return tiles


def _cells(w_px, h_px):
    return (w_px + T - 1) // T, (h_px + T - 1) // T


def _place(sheet, vocab, name, im, col, row, anchor="bottom"):
    w, h = _cells(im.width, im.height)
    block = Image.new("RGBA", (w * T, h * T), (0, 0, 0, 0))
    dy = 0 if anchor == "top" else h * T - im.height
    block.alpha_composite(im, ((w * T - im.width) // 2, dy))
    sheet.alpha_composite(block, (col * T, row * T))
    vocab[name] = {"col": col, "row": row, "w": w, "h": h}
    return col + w


def build():
    floor = _floor_tiles()
    fw, fh = floor[0].size                       # native diamond size (2:1 or 1:1)
    hw, hh = fw / 2, fh / 2
    sheet = Image.new("RGBA", (SHEET_COLS * T, SHEET_COLS * T), (0, 0, 0, 0))
    vocab = {}
    vocab["g"] = {"col": SHEET_COLS - 1, "row": SHEET_COLS - 1, "w": 1, "h": 1}  # transparent void

    # Floor variations laid top-anchored on a row.
    col = 0
    fcells_w, fcells_h = _cells(fw, fh)
    for i, im in enumerate(floor):
        vocab[f"iso_floor{i}"] = None
        col = _place(sheet, vocab, f"iso_floor{i}", im, col, 0, anchor="top")

    # Props (billboarded): railing + reused upright lamp/gate/bucket + anim star.
    props = {}
    for name, fn in [
        ("iso_lamp", os.path.join(SRC, "lamp.png")),
        ("iso_bucket", os.path.join(SRC, "bucket.png")),
    ]:
        if os.path.exists(fn):
            props[name] = _crop(Image.open(fn).convert("RGBA"))

    row = fcells_h
    col = 0
    for name, im in props.items():
        w, h = _cells(im.width, im.height)
        if col + w > SHEET_COLS:
            col, row = 0, row + 6
        col = _place(sheet, vocab, name, im, col, row, anchor="bottom")


    # A 4-frame twinkling star packed on its own row (flat void decor; also keeps
    # the scene animating for the e2e liveness check — the sparkle is a few px so
    # the frame-to-frame pixel change is sampled).
    srow = row + 6
    for i, r in enumerate((1, 2, 3, 2)):
        star = Image.new("RGBA", (T, T), (0, 0, 0, 0))
        c = T // 2
        ImageDraw.Draw(star).ellipse([c - r, c - r, c + r, c + r], fill=(232, 238, 255, 255))
        sheet.alpha_composite(star, (i * T, srow * T))
    vocab["iso_star"] = {"col": 0, "row": srow, "w": 1, "h": 1, "frames": 4, "period_ms": 1100}

    # ── Layout ──────────────────────────────────────────────────────
    # Vertex mask: a beveled rectangle → clean straight edges (no smoothing pass;
    # the shape is already geometric, unlike the old super-ellipse).
    def raw(x, y):
        r = RECT
        if not (r["x0"] <= x <= r["x1"] and r["y0"] <= y <= r["y1"]):
            return 0
        b = r["bevel"]
        dxl, dxr = x - r["x0"], r["x1"] - x
        dyt, dyb = y - r["y0"], r["y1"] - y
        if dxl + dyt < b or dxr + dyt < b or dxl + dyb < b or dxr + dyb < b:
            return 0
        return 1
    g = [[raw(x, y) for x in range(W + 1)] for y in range(H + 1)]

    def full(x, y):
        return g[y][x] and g[y][x + 1] and g[y + 1][x] and g[y + 1][x + 1]

    # Solid-cell bounding rect (the platform hull) — the renderer draws the slab
    # underside from it, converging to a diamond point below.
    solid_cells = [(x, y) for y in range(H) for x in range(W) if full(x, y)]
    hull = [min(c[0] for c in solid_cells), max(c[0] for c in solid_cells),
            min(c[1] for c in solid_cells), max(c[1] for c in solid_cells)]

    nfloor = len([k for k in vocab if k.startswith("iso_floor")])
    def _h(x, y):
        return (x * 928371 + y * 1237) & 0xFFFF
    floor_matrix = [
        [f"iso_floor{_h(x, y) % nfloor}" if full(x, y) else "g" for x in range(W)]
        for y in range(H)
    ]

    # Railings fully enclose the platform (all four diamond edges), matching the
    # sloped iso art to each edge by screen direction:
    #   down-right slope (iso_rail):   back-right edge (x,y-1 void) + front-left (x,y+1 void)
    #   down-left  slope (iso_rail_l): back-left edge (x-1,y void) + front-right (x+1,y void)
    # A cell takes at most one railing (corners pick the first match).
    def bfull(x, y):
        return 0 <= x < W and 0 <= y < H and full(x, y)
    # The railing is emitted as EDGE CELLS (not billboards): each platform cell
    # bordering the void contributes a fence segment on that shared diamond edge.
    # The renderer draws them geometrically so they abut into one continuous fence
    # wrapping the square's four sides (corner cells emit two edges → they wrap).
    rails = []
    for y in range(H):
        for x in range(W):
            if not full(x, y):
                continue
            if not bfull(x, y - 1):
                rails.append({"x": x, "y": y, "edge": "tr"})
            if not bfull(x - 1, y):
                rails.append({"x": x, "y": y, "edge": "tl"})
            if not bfull(x, y + 1):
                rails.append({"x": x, "y": y, "edge": "bl"})
            if not bfull(x + 1, y):
                rails.append({"x": x, "y": y, "edge": "br"})

    # Twinkling stars hash-scattered through the void (near the platform so many
    # land on-screen) — keeps the scene alive and fills the abyss with sky.
    stars = [{"x": x, "y": y, "tile": "iso_star", "sort": "flat"}
             for y in range(H) for x in range(W)
             if not full(x, y) and _h(x, y) % 13 == 0]

    decor = stars + [
        {"x": 20, "y": 12, "tile": "iso_lamp", "sort": "stand"},
        {"x": 17, "y": 13, "tile": "iso_bucket", "sort": "stand"},
    ]

    collision = [{"x": x, "y": y, "w": 1, "h": 1, "kind": "void"}
                 for y in range(H) for x in range(W) if not full(x, y)]

    layout = {
        "width": W, "height": H, "tile_size": T, "ground": "g", "columns": SHEET_COLS,
        "projection": "isometric",
        "iso": {"tile_w": fw, "tile_h": fh, "z_step": Z_STEP, "headroom": 8},
        "slab": {"thickness": 10, "taper": 0.78, "hull": hull},
        "vignette": {"color": "04050c", "alpha": 0.78, "inner": 0.36},
        "sea": {"top": "0c1e42", "bottom": "05060f", "band": "1a3d7a", "bands": 9, "amp": 5},
        "railings": rails,
        "railing_style": {"height": 22, "color": "b98d3e", "hi": "e8c874",
                          "base": "1c1a24", "posts": 4},
        "vocab": {k: v for k, v in vocab.items() if v is not None},
        "floor": floor_matrix,
        "decor": decor,
        "collision": collision,
        "spawn": [{"x": 18, "y": 12, "dir": "right"}, {"x": 22, "y": 12, "dir": "left"}],
        "lights": [{"x": 20.5, "y": 12.5, "radius": 4.5, "color": "ffd591", "blend": "add"}],
        "ambient": {"color": "0c1024", "alpha": 0.52},
        "zones": [{"id": "eot", "kind": "private", "x": 6, "y": 4, "w": 28, "h": 16}],
        # The DM nameplate floats above the central lamppost, over its light.
        "labels": [{"id": "dm_nameplate", "kind": "hologram",
                    "x": 20, "y": 12, "w": 6, "h": 1, "text": "", "lift": 150}],
    }
    sheet.save(SHEET_OUT)
    json.dump(layout, open(MAP_OUT, "w"))
    print(f"OK iso scene: sheet={sheet.size} diamond={fw}x{fh} floors={nfloor} "
          f"rails={len(rails)} decor={len(decor)}")


if __name__ == "__main__":
    build()
