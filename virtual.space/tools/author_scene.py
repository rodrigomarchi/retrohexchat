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
RECT = {"x0": 8, "x1": 32, "y0": 4, "y1": 20, "bevel": 0}
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


def _shear(img, fw, fh, direction):
    """Project a flat (front-elevation) fence strip onto a diamond edge: shift
    every column down by ``x*tile_h/tile_w`` so the strip's level base traces the
    2:1 edge slope while each vertical bar stays vertical (an iso wall, not a
    staircased billboard). ``dr`` descends left→right, ``dl`` is its mirror."""
    w, h = img.size
    drop = round((w - 1) * fh / fw)
    out = Image.new("RGBA", (w, h + drop), (0, 0, 0, 0))
    src = img.load()
    for x in range(w):
        dy = round(x * fh / fw) if direction == "dr" else round((w - 1 - x) * fh / fw)
        for y in range(h):
            p = src[x, y]
            if p[3]:
                out.putpixel((x, y + dy), p)
    return out


def _col_mass(im):
    """Opaque-alpha mass per column — the fence's vertical-bar signal."""
    px = im.load()
    return [sum(px[x, y][3] for y in range(im.height)) for x in range(im.width)]


def _extend_bars(im, extra):
    """Make the picket taller without deforming: splice `extra` px of the plain
    vertical-bar band into the middle (the bars are uniform, so repeating a thin
    real slice just lengthens them), keeping the finialed top and the bottom rail
    intact. Bars stay 1:1 native pixels — no stretching."""
    if extra <= 0:
        return im
    w, h = im.size
    ycut = int(h * 0.58)  # a row down in the plain-bar region, below the finials
    band = im.crop((0, ycut - 1, w, ycut + 1))  # a 2px bar slice to repeat
    out = Image.new("RGBA", (w, h + extra), (0, 0, 0, 0))
    out.alpha_composite(im.crop((0, 0, w, ycut)), (0, 0))
    for yy in range(ycut, ycut + extra, 2):
        out.alpha_composite(band, (0, yy))
    out.alpha_composite(im.crop((0, ycut, w, h)), (0, ycut + extra))
    return out


def _rail_tiles(fw, fh):
    """Build the golden fence tiles from the native wrought-iron art at its FULL
    height: pick the picket's repeat period (snapped to a divisor of the cell
    width so cells abut seam-free), tile ONE period across a cell edge (``fw/2``
    px), then shear it onto both diamond-edge slopes. The corner post is the
    strip's own tallest column run. Returns (down-right, down-left, corner post)."""
    strip = Image.open(os.path.join(ISO, "rail.png")).convert("RGBA")
    strip = strip.crop(strip.getbbox())  # full fence height, no transparent margin
    strip = _extend_bars(strip, 14)  # taller picket (closer to the ornate posts)
    W, H = strip.size
    cw = fw // 2  # one cell's edge run in px (= half diamond width)

    # Repeat period: strongest autocorrelation lag, snapped to a divisor of cw so
    # every cell tile abuts its neighbour with identical bar spacing (no banding).
    mass = _col_mass(strip)
    mean = sum(mass) / W
    dev = [m - mean for m in mass]
    ac = lambda d: sum(dev[x] * dev[x + d] for x in range(W - d))
    raw = max(range(3, min(16, W // 2)), key=ac)
    divisors = [d for d in (4, 6, 8, 12) if cw % d == 0] or [g for g in range(2, cw + 1) if cw % g == 0]
    p = min(divisors, key=lambda d: abs(d - raw))

    # Start the unit at a bar-gap (low column mass) inside the uniform mid-run,
    # away from any ornate end/centre post, so the tiled seam falls between bars.
    lo, hi = W // 6, max(W // 6 + p + 1, W - W // 6 - p)
    x0 = min(range(lo, hi), key=lambda x: mass[x] + mass[x + p])
    unit = strip.crop((x0, 0, x0 + p, H))
    flat = Image.new("RGBA", (cw, H), (0, 0, 0, 0))
    for i in range(cw // p):
        flat.alpha_composite(unit, (i * p, 0))

    # The ornate spear-tip post is its own native art (a tall billboard capping
    # corners and punctuating the run at intervals).
    post = Image.open(os.path.join(ISO, "rail_post.png")).convert("RGBA")
    post = post.crop(post.getbbox())
    return _shear(flat, fw, fh, "dr"), _shear(flat, fw, fh, "dl"), post


def _cells(w_px, h_px):
    return (w_px + T - 1) // T, (h_px + T - 1) // T


def _place(sheet, vocab, name, im, col, row, anchor="bottom", native=False):
    # `native` packs the art flush to the cell's top-left and records its exact
    # pixel size (wpx/hpx), so the atlas addresses it at true scale-1 size instead
    # of rounding to the 32px cell grid + centring (which shifts an iso floor
    # diamond off the projection's foot anchor → the railing floats off the tile).
    w, h = _cells(im.width, im.height)
    block = Image.new("RGBA", (w * T, h * T), (0, 0, 0, 0))
    dy = 0 if anchor == "top" else h * T - im.height
    dx = 0 if native else (w * T - im.width) // 2
    block.alpha_composite(im, (dx, dy))
    sheet.alpha_composite(block, (col * T, row * T))
    entry = {"col": col, "row": row, "w": w, "h": h}
    if native:
        entry["wpx"], entry["hpx"] = im.width, im.height
    vocab[name] = entry
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
        col = _place(sheet, vocab, f"iso_floor{i}", im, col, 0, anchor="top", native=True)

    # Iso railing tiles: a native wrought-iron strip tiled into a one-cell picket
    # and sheared onto the diamond edge (base follows the 2:1 slope, every bar
    # stays vertical). Two mirror variants wrap all four sides seam-to-seam; a
    # golden post caps each corner. Packed native on the floor row so they blit 1:1.
    rail_dr, rail_dl, rail_post = _rail_tiles(fw, fh)
    col = _place(sheet, vocab, "iso_rail_dr", rail_dr, col, 0, anchor="top", native=True)
    col = _place(sheet, vocab, "iso_rail_dl", rail_dl, col, 0, anchor="top", native=True)
    col = _place(sheet, vocab, "iso_rail_post", rail_post, col, 0, anchor="top", native=True)

    # Props (billboarded): reused upright lamp + anim star.
    props = {}
    for name, fn in [
        ("iso_lamp", os.path.join(SRC, "lamp.png")),
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

    # Ornate spear-tip posts punctuate the fence: one every POST_STEP cells along
    # each edge, sitting on that edge's near diamond-vertex, plus one hard on each
    # of the four platform corners. `corner` (n/e/s/w) is the vertex the post
    # billboards on. Deduped by cell so a corner cell gets a single post.
    hx0, hx1, hy0, hy1 = hull
    POST_STEP = 3
    edge_vertex = {"tr": "n", "tl": "w", "bl": "w", "br": "s"}
    seen, railing_posts = set(), []

    def add_post(x, y, corner):
        if (x, y) not in seen:
            seen.add((x, y))
            railing_posts.append({"x": x, "y": y, "corner": corner})

    for x, y, corner in [(hx0, hy0, "n"), (hx1, hy0, "e"), (hx1, hy1, "s"), (hx0, hy1, "w")]:
        add_post(x, y, corner)
    for edge, corner in edge_vertex.items():
        cells = sorted(
            ((r["x"], r["y"]) for r in rails if r["edge"] == edge),
            key=lambda c: c[0] + c[1],
        )
        for i, (x, y) in enumerate(cells):
            if i % POST_STEP == 0:
                add_post(x, y, corner)

    # Twinkling stars hash-scattered through the void (near the platform so many
    # land on-screen) — keeps the scene alive and fills the abyss with sky.
    stars = [{"x": x, "y": y, "tile": "iso_star", "sort": "flat"}
             for y in range(H) for x in range(W)
             if not full(x, y) and _h(x, y) % 13 == 0]

    decor = stars + [
        {"x": 20, "y": 12, "tile": "iso_lamp", "sort": "stand"},
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
        "railing_posts": railing_posts,
        "vocab": {k: v for k, v in vocab.items() if v is not None},
        "floor": floor_matrix,
        "decor": decor,
        "collision": collision,
        "spawn": [{"x": 18, "y": 12, "dir": "right"}, {"x": 22, "y": 12, "dir": "left"}],
        # The lamppost (decor at 20,12) casts light as TWO stacked glows so it reads
        # as emitting from the lantern head, not the pole base: a soft pool on the
        # ground + a tight bright halo lifted ~106px up to the lantern head.
        "lights": [
            {"x": 20, "y": 12, "radius": 4.2, "color": "ffd591", "blend": "add"},
            {"x": 20, "y": 12, "lift": 152, "radius": 1.6, "color": "ffe6a8", "blend": "add"},
        ],
        "ambient": {"color": "1a2036", "alpha": 0.42},
        "zones": [{"id": "eot", "kind": "private", "x": 6, "y": 4, "w": 28, "h": 16}],
        # The DM nameplate floats above the central lamppost, over its light.
        "labels": [{"id": "dm_nameplate", "kind": "hologram",
                    "x": 20, "y": 12, "w": 6, "h": 1, "text": "", "lift": 150}],
    }
    sheet.save(SHEET_OUT)
    json.dump(layout, open(MAP_OUT, "w"))
    print(f"OK iso scene: sheet={sheet.size} diamond={fw}x{fh} floors={nfloor} "
          f"rails={len(rails)} posts={len(railing_posts)} decor={len(decor)}")


if __name__ == "__main__":
    build()
