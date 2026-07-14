#!/usr/bin/env python3
"""Author the ISOMETRIC "End of Time" DM scene (P3+).

Reads real iso art from ``virtual.space/scenes/end_of_time/iso/`` — the diamond
cobblestone floor variations and an ornate golden railing strip + post — plus
the upright lamp (billboarded on the iso floor), and emits the packed
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
W, H = 96, 72
# Five equal platforms in a cross — the CT End of Time is several square
# platforms adrift in the sea, joined by bridges: the original room at the
# centre and one satellite per cardinal side, each linked by a 2-cell-wide
# bridge. Every rect is an inclusive CELL range {x0,x1,y0,y1}; straight edges
# keep the railings continuous (a super-ellipse staircases the fence).
PLATFORMS = {
    "center": {"x0": 36, "x1": 59, "y0": 28, "y1": 43},
    "north": {"x0": 36, "x1": 59, "y0": 6, "y1": 21},
    "south": {"x0": 36, "x1": 59, "y0": 50, "y1": 65},
    "west": {"x0": 6, "x1": 29, "y0": 28, "y1": 43},
    "east": {"x0": 66, "x1": 89, "y0": 28, "y1": 43},
}
BRIDGES = {
    "bridge_n": {"x0": 47, "x1": 48, "y0": 22, "y1": 27},
    "bridge_s": {"x0": 47, "x1": 48, "y0": 44, "y1": 49},
    "bridge_w": {"x0": 30, "x1": 35, "y0": 35, "y1": 36},
    "bridge_e": {"x0": 60, "x1": 65, "y0": 35, "y1": 36},
}
SOLIDS = {**PLATFORMS, **BRIDGES}
# One lamppost per platform centre (except the north platform — the Matrix
# nook's TV is its light source); the central one anchors the spawns, the
# lights and the DM nameplate.
LAMPS = [(48, 36), (48, 58), (17, 36), (78, 36)]
# Animated props (real PixelLab frames, packed as horizontal strips):
# name -> (frames folder under scenes/end_of_time/, block w×h in cells,
# period_ms, flip_x). The Matrix nook on the north platform: Morpheus (west
# seat, the `east` rotation of his 8-direction set — a seated profile facing
# east) and Neo (east seat, his `west` rotation facing west) breathe facing
# EACH OTHER in red wingback armchairs, with the vintage CRT flickering static
# to the north between them — the Construct loading-room framing.
ANIM_PROPS = {
    "eot_morpheus": ("anim/morpheus", 3, 3, 2000, False),
    "eot_neo": ("anim/neo", 3, 3, 2200, False),
    "eot_tv": ("anim/tv", 2, 3, 420, False),
}
# Matrix nook placement: decor anchor tile + solid ground footprint. The TV
# sits on the pair's perpendicular bisector pushed north — (46,10) projects
# ~95px from EACH chair base (equidistant, not merely mid-x) and two tiles
# behind their row — the Construct loading-room framing.
FURNITURE = [
    ("eot_tv", 46, 10, {"x": 45, "y": 9, "w": 2, "h": 2}),
    ("eot_morpheus", 45, 13, {"x": 44, "y": 13, "w": 2, "h": 2}),
    ("eot_neo", 51, 13, {"x": 51, "y": 13, "w": 2, "h": 2}),
]
SHEET_COLS = 24
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


def _pack_anim(sheet, vocab, name, folder, w, h, period_ms, flip, row):
    """Pack an animated prop as a horizontal frame strip at (0, row).

    The rules that keep a "still" prop still (ANIMATIONS.md §4): every frame is
    cropped to ONE shared union bbox (per-frame crops wobble the base), content
    larger than the block is scaled preserving aspect (never cropped), and each
    frame is bottom-centre anchored like a standing prop.
    """
    import glob
    files = sorted(glob.glob(os.path.join(SRC, folder, "*.png")),
                   key=lambda p: int(os.path.splitext(os.path.basename(p))[0]))
    if not files:
        raise FileNotFoundError(f"no frames in {folder}")
    ims = [Image.open(f).convert("RGBA") for f in files]
    if w * len(ims) > SHEET_COLS:
        raise AssertionError(
            f"{name}: strip {w}x{len(ims)} frames = {w * len(ims)} cols > {SHEET_COLS}")
    boxes = [im.getbbox() for im in ims]
    if any(b is None for b in boxes):
        raise AssertionError(f"{name}: an empty frame slipped in")
    union = (min(b[0] for b in boxes), min(b[1] for b in boxes),
             max(b[2] for b in boxes), max(b[3] for b in boxes))
    bw, bh = w * T, h * T
    uw, uh = union[2] - union[0], union[3] - union[1]
    scale = min(1.0, bw / uw, bh / uh)
    for i, im in enumerate(ims):
        crop = im.crop(union)
        if scale < 1.0:
            crop = crop.resize((max(1, round(uw * scale)), max(1, round(uh * scale))),
                               Image.NEAREST)
        block = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
        block.alpha_composite(crop, ((bw - crop.width) // 2, bh - crop.height))
        sheet.alpha_composite(block, (i * w * T, row * T))
        # the cheapest blink check: the packed cell must hold pixels
        if sheet.crop((i * w * T, row * T, (i + 1) * w * T, (row + h) * T)).getbbox() is None:
            raise AssertionError(f"{name}: frame {i} packed empty")
    entry = {"col": 0, "row": row, "w": w, "h": h,
             "frames": len(ims), "period_ms": period_ms}
    if flip:
        entry["flip_x"] = True
    vocab[name] = entry
    return row + h


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

    # Animated props (Matrix nook): one horizontal strip per prop, stacked
    # below the star row.
    arow = srow + 1
    for name, (folder, w, h, period_ms, flip) in ANIM_PROPS.items():
        arow = _pack_anim(sheet, vocab, name, folder, w, h, period_ms, flip, arow)

    # ── Layout ──────────────────────────────────────────────────────
    def _in(r, x, y):
        return r["x0"] <= x <= r["x1"] and r["y0"] <= y <= r["y1"]

    def full(x, y):
        return any(_in(r, x, y) for r in SOLIDS.values())

    def _hull(r):
        return [r["x0"], r["x1"], r["y0"], r["y1"]]

    # One 3D underside per solid block: platforms taper to a floating-gem apex,
    # bridges stay thin straight prisms (taper 0) so they read as stone walkways
    # slung between the islands. The renderer draws them far→near.
    slabs = [
        {"thickness": 10, "taper": 0.78, "hull": _hull(r)} for r in PLATFORMS.values()
    ] + [
        {"thickness": 3, "taper": 0.0, "hull": _hull(r)} for r in BRIDGES.values()
    ]

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

    # Ornate spear-tip posts punctuate the fence: one on each platform's four
    # hull corners, plus one every POST_STEP cells along each block's own edge
    # runs (bridges included) so the spacing restarts per block and flanks the
    # bridge openings. `corner` (n/e/s/w) is the vertex the post billboards on.
    # Deduped by cell so a corner cell gets a single post.
    POST_STEP = 3
    edge_vertex = {"tr": "n", "tl": "w", "bl": "w", "br": "s"}
    seen, railing_posts = set(), []

    def add_post(x, y, corner):
        if (x, y) not in seen:
            seen.add((x, y))
            railing_posts.append({"x": x, "y": y, "corner": corner})

    for r in PLATFORMS.values():
        x0, x1, y0, y1 = r["x0"], r["x1"], r["y0"], r["y1"]
        for x, y, corner in [(x0, y0, "n"), (x1, y0, "e"), (x1, y1, "s"), (x0, y1, "w")]:
            add_post(x, y, corner)
    for region in SOLIDS.values():
        for edge, corner in edge_vertex.items():
            cells = sorted(
                ((c["x"], c["y"]) for c in rails
                 if c["edge"] == edge and _in(region, c["x"], c["y"])),
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
        {"x": x, "y": y, "tile": "iso_lamp", "sort": "stand"} for x, y in LAMPS
    ] + [
        {"x": x, "y": y, "tile": name, "sort": "stand"} for name, x, y, _fp in FURNITURE
    ]

    # Collision is the void — the complement of the solid cross — plus the
    # furniture ground footprints. Void is emitted as merged per-row runs (not
    # 1×1 cells) so the space_init payload stays small on a big map; the server
    # expands rects into its blocked MapSet anyway.
    collision = []
    for y in range(H):
        x = 0
        while x < W:
            if full(x, y):
                x += 1
                continue
            x0 = x
            while x < W and not full(x, y):
                x += 1
            collision.append({"x": x0, "y": y, "w": x - x0, "h": 1, "kind": "void"})
    collision += [dict(fp, kind="prop") for _name, _x, _y, fp in FURNITURE]

    # Every lamppost casts light as TWO stacked glows so it reads as emitting
    # from the lantern head, not the pole base: a soft pool on the ground + a
    # tight bright halo lifted up to the lantern head. The north platform has
    # no lamp — the Matrix nook is lit by the CRT alone: a dim cool pool spills
    # on the floor IN FRONT of the set (toward the pair) + a tight pale halo at
    # screen height. Deliberately faint — a television in the dark, not a lamp.
    lights = []
    for x, y in LAMPS:
        lights.append({"x": x, "y": y, "radius": 4.2, "color": "ffd591", "blend": "add"})
        lights.append({"x": x, "y": y, "lift": 152, "radius": 1.6, "color": "ffe6a8",
                       "blend": "add"})
    lights.append({"x": 47, "y": 11, "radius": 2.6, "color": "7d9cc9", "blend": "add"})
    lights.append({"x": 46, "y": 10, "lift": 46, "radius": 1.1, "color": "a9c4e8",
                   "blend": "add"})

    zones = [{"id": name, "kind": "platform", "x": r["x0"], "y": r["y0"],
              "w": r["x1"] - r["x0"] + 1, "h": r["y1"] - r["y0"] + 1}
             for name, r in PLATFORMS.items()]

    spawn = [{"x": 46, "y": 36, "dir": "right"}, {"x": 50, "y": 36, "dir": "left"}]
    _validate(full, spawn, collision)

    layout = {
        "width": W, "height": H, "tile_size": T, "ground": "g", "columns": SHEET_COLS,
        "projection": "isometric",
        "iso": {"tile_w": fw, "tile_h": fh, "z_step": Z_STEP, "headroom": 8},
        "slabs": slabs,
        "vignette": {"color": "04050c", "alpha": 0.78, "inner": 0.36},
        "sea": {"top": "0c1e42", "bottom": "05060f", "band": "1a3d7a", "bands": 9, "amp": 5},
        "railings": rails,
        "railing_posts": railing_posts,
        "vocab": {k: v for k, v in vocab.items() if v is not None},
        "floor": floor_matrix,
        "decor": decor,
        "collision": collision,
        "spawn": spawn,
        "lights": lights,
        "ambient": {"color": "1a2036", "alpha": 0.42},
        "zones": zones,
        # The DM nameplate floats above the central lamppost, over its light.
        "labels": [{"id": "dm_nameplate", "kind": "hologram",
                    "x": 48, "y": 36, "w": 6, "h": 1, "text": "", "lift": 150}],
    }
    sheet.save(SHEET_OUT)
    json.dump(layout, open(MAP_OUT, "w"))
    print(f"OK iso scene: sheet={sheet.size} diamond={fw}x{fh} floors={nfloor} "
          f"platforms={len(PLATFORMS)} bridges={len(BRIDGES)} rails={len(rails)} "
          f"posts={len(railing_posts)} decor={len(decor)} collision={len(collision)}")


def _validate(full, spawn, collision):
    """Assert the authored layout before writing it: spawns on walkable ground
    and every platform centre BFS-reachable from the first spawn over the real
    collision set (void + furniture) — a bridge misaligned by one cell or a
    prop dropped across a corridor would strand a whole platform silently."""
    blocked = {(r["x"] + dx, r["y"] + dy)
               for r in collision for dx in range(r["w"]) for dy in range(r["h"])}

    def walkable(x, y):
        return 0 <= x < W and 0 <= y < H and full(x, y) and (x, y) not in blocked

    for s in spawn:
        if not walkable(s["x"], s["y"]):
            raise AssertionError(f"spawn {s} is not on walkable ground")
    start = (spawn[0]["x"], spawn[0]["y"])
    seen = {start}
    frontier = [start]
    while frontier:
        x, y = frontier.pop()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) not in seen and walkable(nx, ny):
                seen.add((nx, ny))
                frontier.append((nx, ny))
    for r in PLATFORMS.values():
        cx, cy = (r["x0"] + r["x1"]) // 2, (r["y0"] + r["y1"]) // 2
        if (cx, cy) not in seen:
            raise AssertionError(f"platform centre {(cx, cy)} is unreachable from spawn")


if __name__ == "__main__":
    build()
