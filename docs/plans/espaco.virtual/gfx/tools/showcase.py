"""Render candidate 'outdoor showcase' maps to PNG for design approval.

Composites the real overworld.png tiles (sliced by the catalog col/row/w/h) into
full map images. Nothing here touches the runtime — it's a design mockup tool so
the human can pick a direction before we author the real map JSON.
"""
import json, os
from PIL import Image

TOOLS = os.path.dirname(os.path.abspath(__file__))
GFX = os.path.dirname(TOOLS)
OUT = os.path.join(GFX, "previews")
os.makedirs(OUT, exist_ok=True)

SHEET = Image.open(os.path.join(GFX, "Overworld.png")).convert("RGBA")
T = 16  # tile px
# STANDARD preview zoom for every scene render: 3x = 48px/tile reads natural, not
# "exploded". Never render previews closer than this; high zoom is for deliberate
# defect-inspection crops only, never the default output.
PREVIEW_SCALE = 3

CAT = {e["name"]: e for e in json.load(open(os.path.join(GFX, "catalog", "catalog.json")))
       if e["sheet"] == "overworld"}

# Clean 9-slice autotiles from the runtime vocab (Maps.Overworld) that the flat
# catalog doesn't name — needed for believable pond shorelines and cliff faces.
VOCAB = {
    "grass_tuft": (6, 9), "grass_worn": (6, 10),
    "pond_tl": (2, 6), "pond_tm": (3, 6), "pond_tr": (4, 6),
    "pond_ml": (2, 7), "pond_c": (3, 7), "pond_mr": (4, 7),
    "pond_bl": (2, 8), "pond_bm": (3, 8), "pond_br": (4, 8),
    "cliff_lip_l": (4, 11), "cliff_lip_m": (5, 11), "cliff_lip_r": (6, 11),
    "cliff_face_l": (4, 12), "cliff_face_m": (5, 12), "cliff_face_r": (6, 12),
    "cliff_base_l": (4, 14), "cliff_base_m": (5, 14), "cliff_base_r": (6, 14),
}
for _n, (_c, _r) in VOCAB.items():
    CAT.setdefault(_n, {"name": _n, "sheet": "overworld", "col": _c, "row": _r, "w": 1, "h": 1})

# A horizontal fence panel (post-rail-post) that tiles seamlessly left-to-right —
# the catalog only names the vertical post (fence_wood); this is its horizontal mate.
CAT["fence_h"] = {"name": "fence_h", "sheet": "overworld", "col": 0, "row": 19, "w": 2, "h": 1}

# The closed-lid twin of well_stone (stone rim + hinged wooden double lid) —
# self-contained and grounded, the cleaner standalone read of the two wells.
CAT["well_lidded"] = {"name": "well_lidded", "sheet": "overworld",
                      "col": 31, "row": 5, "w": 2, "h": 2}

# Corrections for catalog entries whose col/row/w/h clip or mis-frame the art
# (verified by grid-inspecting overworld.png). See overworld-catalog-rect-bugs.
RECT_FIX = {
    "house_large": (6, 0, 5, 5),
    "barn_large": (11, 0, 5, 5),     # r5 under the barn is moss + the tent apex, not barn art
    "tent_wood": (13, 5, 2, 3),      # col12 is a moss column; the tent spans cols13-14
    "well_stone": (33, 5, 2, 2),     # r6 caught only the bottom half (mouth + lip);
                                     # the flung-open lid doors live at r5
    "tree_foliage": (5, 16, 2, 2),   # 3x3 caught a lighter bush appendage; keep the canopy
    "haystack": (31, 3, 2, 2),       # col32 caught half a trapdoor to its right
    "fence_wood": (0, 17, 1, 2),     # a single vertical picket post; 4x1 was wrong
    "fence_gate_frame": (6, 6, 2, 3),  # a tall standing gate; 3x3 caught an empty column
    "hedge_block": (0, 14, 1, 2),    # a 1-wide hedge strip; 2x2 caught the topiary next to it
    "bush_dead_grey": (19, 17, 3, 3),  # col18 was mis-aligned onto empty space + 2 half-bushes
    "stone_slab_round": (35, 5, 2, 2),  # 1x1/1x2 caught only the left half of the round slab
    "arch_stone": (24, 31, 4, 3),    # row32 4x2 cut the top span (row31) -> open-topped arch
    # The sheet has no dedicated round bush (the greens are hedge tiles); a 2x1 pair
    # of hedge humps reads as one coherent low, wide bush. 1x1 clipped the base+shadow.
    "bush_round": (0, 16, 2, 1),
    # gravel_light 2x2 caught the uniform gravel + a dark neighbour column -> striped
    # when sub-tiled. The clean seamless gravel is the single tile at col14 row11.
    "gravel_light": (14, 11, 1, 1),
    "statue_pawn": (10, 22, 1, 4),   # 2x4 caught the coal_rocks column beside the pawn
    "tree_stumps": (4, 1, 2, 2),     # row2 2x1 cut off the stump tops (they span rows1-2)
    # The awning stall: col17 is a separate jug-and-bottles table; the stall spans
    # cols18-22 and its counter front reaches row27 (6 rows, not 5).
    "market_stall_awning": (18, 22, 5, 6),
    "barrel_wood": (33, 0, 1, 2),    # 1x1 caught only the lid; the body is at row1
    # Produce crates are produce (r20) + X-braced crate front (r21); 1x1 cut the box off.
    "produce_crate_banana": (26, 20, 1, 2),
    "produce_crate_greens": (27, 20, 1, 2),
    "produce_crate_tomato": (28, 20, 1, 2),
    "produce_crate_lemon": (29, 20, 1, 2),
    "crate_wood": (30, 0, 1, 2),     # a grounded two-crate stack; 1x1 was a topless slice
    "crate_x": (35, 8, 2, 2),        # the wide crate spans c35-36; c36-only cut its left frame
    "stool_wood": (37, 8, 1, 2),     # the stool has a pedestal foot + shadow at r9
    # The table has knobbed legs at all four corners: cols8-10, rows6-8; the
    # catalog 2x2 at c9 cut off the left post column and the bottom row.
    "counter_wood": (8, 6, 3, 3),
    # Only the c24 column is the freestanding forge furnace; c25 is a second anvil
    # sitting on a wooden deck corner (diagonal background baked in).
    "anvil_forge": (24, 17, 1, 3),
}
for _n, (_c, _r, _w, _h) in RECT_FIX.items():
    CAT[_n].update(col=_c, row=_r, w=_w, h=_h)


def rect(name):
    e = CAT[name]
    return e["col"] * T, e["row"] * T, e.get("w", 1), e.get("h", 1)


def slice_tile(name):
    x, y, w, h = rect(name)
    return SHEET.crop((x, y, x + w * T, y + h * T)), w, h


class Map:
    def __init__(self, w, h, ground="grass_plain"):
        self.w, self.h = w, h
        self.ground = [[ground] * w for _ in range(h)]
        self.decor = []          # (name, x, y) painted in order, y-sorted at render
        self.used = set([ground])

    # ---- ground helpers (1x1 terrain/water names) ----
    def g(self, x, y, name):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.ground[y][x] = name
            self.used.add(name)

    def fill(self, x0, y0, x1, y1, name):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g(x, y, name)

    def border(self, x0, y0, x1, y1, name):
        for x in range(x0, x1 + 1):
            self.g(x, y0, name); self.g(x, y1, name)
        for y in range(y0, y1 + 1):
            self.g(x0, y, name); self.g(x1, y, name)

    def hline(self, x0, x1, y, name):
        for x in range(x0, x1 + 1):
            self.g(x, y, name)

    def vline(self, x, y0, y1, name):
        for y in range(y0, y1 + 1):
            self.g(x, y, name)

    def scatter(self, x0, y0, x1, y1, names, step=3, seed=1):
        # deterministic pseudo-scatter (no RNG so renders are reproducible)
        i = seed
        for y in range(y0, y1 + 1, step):
            for x in range(x0, x1 + 1, step):
                i = (i * 1103515245 + 12345) & 0x7FFFFFFF
                name = names[i % len(names)]
                self.g(x + (i >> 4) % 2, y + (i >> 8) % 2, name)

    # ---- scene autotiles ----
    def pond(self, x0, y0, x1, y1, lilies=()):
        """A pond with sand-edged 9-slice shoreline. lilies = list of (x,y)."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                vy = "t" if y == y0 else "b" if y == y1 else "m"
                vx = "l" if x == x0 else "r" if x == x1 else "m"
                key = {"tm": "pond_tm", "bm": "pond_bm", "ml": "pond_ml",
                       "mr": "pond_mr", "mm": "pond_c"}.get(vy + vx)
                if key is None:
                    key = "pond_" + {"tl": "tl", "tr": "tr", "bl": "bl", "br": "br"}[vy + vx]
                self.g(x, y, key)
        for (lx, ly) in lilies:
            self.p(lx, ly, "water_lily")

    def road_v(self, x, y0, y1, w=2, mat="gravel_light"):
        for yy in range(y0, y1 + 1):
            for dx in range(w):
                self.g(x + dx, yy, mat)

    def road_h(self, x0, x1, y, w=2, mat="gravel_light"):
        for xx in range(x0, x1 + 1):
            for dy in range(w):
                self.g(xx, y + dy, mat)

    def road_path(self, cells, mat="gravel_light"):
        """A winding trail through an explicit list of (x, y) cells."""
        for (x, y) in cells:
            self.g(x, y, mat)
            self.g(x + 1, y, mat)

    def road_poly(self, pts, w=2, mat="gravel_light"):
        """A bent road connecting waypoints with straight segments (w-wide brush)."""
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            steps = max(abs(x1 - x0), abs(y1 - y0)) or 1
            for s in range(steps + 1):
                t = s / steps
                cx = round(x0 + (x1 - x0) * t); cy = round(y0 + (y1 - y0) * t)
                for dx in range(w):
                    for dy in range(w):
                        self.g(cx + dx, cy + dy, mat)

    def cliff_south(self, x0, x1, y, walkable_lip=True):
        """A horizontal escarpment facing south: grassy lip, rock face, shadow base."""
        for x in range(x0, x1 + 1):
            vx = "l" if x == x0 else "r" if x == x1 else "m"
            if walkable_lip:
                self.g(x, y, f"cliff_lip_{vx}")
            self.g(x, y + 1, f"cliff_face_{vx}")
            self.g(x, y + 2, f"cliff_base_{vx}")

    # ---- decor (props, may be multi-tile, transparent over ground) ----
    def p(self, x, y, name):
        self.decor.append((name, x, y))
        self.used.add(name)

    def row(self, x, y, names, gap=1):
        cx = x
        for n in names:
            _, w, h = slice_tile(n)
            self.p(cx, y, n)
            cx += w + gap

    def render(self, scale=PREVIEW_SCALE):
        base = Image.new("RGBA", (self.w * T, self.h * T), (58, 190, 65, 255))
        for y in range(self.h):
            for x in range(self.w):
                img, w, h = slice_tile(self.ground[y][x])
                base.alpha_composite(img, (x * T, y * T))
        for name, x, y in sorted(self.decor, key=lambda d: (d[2], d[1])):
            img, w, h = slice_tile(name)
            base.alpha_composite(img, (x * T, y * T))
        if scale != 1:
            base = base.resize((base.width * scale, base.height * scale), Image.NEAREST)
        return base


def save(m, fname, scale=PREVIEW_SCALE):
    img = m.render(scale)
    path = os.path.join(OUT, fname)
    img.convert("RGB").save(path)
    total = len([n for n in CAT])
    print(f"{fname}: {img.width}x{img.height}px  tiles used {len(m.used)}/{total}")
    return m.used
