"""Tile-map pipeline: author *intent* (a semantic material grid + props), let a
DETERMINISTIC layer resolve tiles, validate, and render — instead of hand-placing
sprites and eyeballing. Mirrors the community pattern (semantic layer -> autotile
-> validate -> layered render). See the outdoor-showcase-mockup memory.

Wins over manual placement:
  * fills tile by 16px SUB-TILE aligned to the region -> exact per-cell coverage,
    no 2x2 bleed/overdraw (the "path came out 2 wide not 3" bug is impossible).
  * water edges are AUTOTILED from a boolean mask (9-slice pond_*), any shape.
  * fences are a single deterministic primitive (rect + opening), never per-post.
  * every scene is checked (bounds / prop overlap / reachability) before it renders.
"""
import os
from PIL import Image
from showcase import CAT, T, PREVIEW_SCALE   # CAT carries the verified RECT_FIX rects

GFX = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = Image.open(os.path.join(GFX, "Overworld.png")).convert("RGBA")
OUT = os.path.join(GFX, "previews", "pipeline")
os.makedirs(OUT, exist_ok=True)
GRASS_RGBA = (58, 190, 65, 255)

# --- material registry: a semantic name -> the source fill tile (any WxH) --------
FILL = {
    "grass": "grass_plain", "grass_dark": "grass_dark", "dirt": "dirt_field_tilled",
    "gravel": "gravel_light", "crops": "crops_field", "cobble": "cobblestone_path",
    "tuft": "grass_tuft", "worn": "grass_worn", "flowers": "flowers_white",
}
# water is special: it autotiles via the 9-slice pond_* set (from the vocab).
POND = {"tl": "pond_tl", "tm": "pond_tm", "tr": "pond_tr",
        "ml": "pond_ml", "mm": "pond_c", "mr": "pond_mr",
        "bl": "pond_bl", "bm": "pond_bm", "br": "pond_br"}
WATER_PROPS = {"water_lily", "water_lilies_cluster", "water_ripple"}   # must sit on water


def _rect(name):
    e = CAT[name]
    return e["col"] * T, e["row"] * T, e.get("w", 1), e.get("h", 1)


def slice_full(name):
    x, y, w, h = _rect(name)
    return SHEET.crop((x, y, x + w * T, y + h * T)), w, h


def sub_tile(name, cx, cy):
    """The 16x16 sub-cell (cx, cy) of a WxH tile, wrapped — for seamless fills."""
    x, y, w, h = _rect(name)
    sx, sy = (cx % w) * T, (cy % h) * T
    return SHEET.crop((x + sx, y + sy, x + sx + T, y + sy + T))


class Scene:
    def __init__(self, w, h, ground="grass"):
        self.w, self.h = w, h
        self.mat = [[ground] * w for _ in range(h)]      # semantic material grid
        self.fence = [[False] * w for _ in range(h)]     # fence overlay mask
        self.opening = set()                             # entrance cells (no fence)
        self.props = []                                  # standalone objects (overlap-checked)
        self.details = []                                # overlays (door/chimney/window) on a prop

    def inb(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    # ---- authoring: intent, not pixels ------------------------------------
    def fill(self, x0, y0, x1, y1, mat):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if self.inb(x, y):
                    self.mat[y][x] = mat

    def water(self, x0, y0, x1, y1):
        self.fill(x0, y0, x1, y1, "water")

    def prop(self, name, x, y):
        self.props.append((name, x, y))

    def detail(self, name, x, y):
        """An overlay meant to sit ON a prop (door in a wall, chimney on a roof,
        banner on a tower) — rendered on top, bounds-checked but not overlap-checked."""
        self.details.append((name, x, y))

    def fence_rect(self, x0, y0, x1, y1, openings=()):
        """Mark a fence around a rectangle. `openings` = list of (x, y) cells to
        leave open (the entrance). The renderer picks h/v/corner tiles."""
        for x in range(x0, x1 + 1):
            for y in (y0, y1):
                self.fence[y][x] = True
        for y in range(y0, y1 + 1):
            for x in (x0, x1):
                self.fence[y][x] = True
        for (ox, oy) in openings:
            if self.inb(ox, oy):
                self.fence[oy][ox] = False
                self.opening.add((ox, oy))

    # ---- deterministic resolution -----------------------------------------
    def _is_water(self, x, y):
        return self.inb(x, y) and self.mat[y][x] == "water"

    # Diagonal -> the OPPOSITE convex corner tile whose foam already wraps that corner.
    _INNER = [((1, 1), "pond_br"), ((-1, 1), "pond_bl"),
              ((1, -1), "pond_tr"), ((-1, -1), "pond_tl")]

    def _water_tile(self, x, y):
        # Concave (inner) corner: all four orthogonal neighbours are water but a
        # diagonal is land (inside an L, or an island's corner). The sheet has no
        # concave tile, so use the OPPOSITE convex corner — its foam already curls
        # around that corner. (This is just "flip the corner", per Rodrigo's insight.)
        if all(self._is_water(x + dx, y + dy) for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0))):
            for (dx, dy), tile in self._INNER:
                if not self._is_water(x + dx, y + dy):
                    return tile
        vy = "t" if not self._is_water(x, y - 1) else ("b" if not self._is_water(x, y + 1) else "m")
        vx = "l" if not self._is_water(x - 1, y) else ("r" if not self._is_water(x + 1, y) else "m")
        return POND[vy + vx]

    def _draw_fence(self, base):
        """Draw the fence as 4 runs so multi-tile pieces align and never overflow:
        horizontal sides use fence_h (2x1) stepped by 2; vertical sides use
        fence_wood (1x2) stepped by 2."""
        cells = [(x, y) for y in range(self.h) for x in range(self.w) if self.fence[y][x]]
        if not cells:
            return
        xs = [c[0] for c in cells]; ys = [c[1] for c in cells]
        xL, xR, yT, yB = min(xs), max(xs), min(ys), max(ys)

        def put(name, x, y):
            base.alpha_composite(slice_full(name)[0], (x * T, y * T))

        for yy in (yT, yB):                          # top & bottom (horizontal)
            x = xL
            while x <= xR:
                if not self.fence[yy][x]:
                    x += 1; continue
                if x + 1 <= xR and self.fence[yy][x + 1] and x + 1 < self.w:
                    put("fence_h", x, yy); x += 2
                elif x - 1 >= xL and self.fence[yy][x - 1]:
                    put("fence_h", x - 1, yy); x += 1   # tail of a run: overlap-extend, no orphan post
                else:
                    put("fence_wood", x, yy); x += 1   # a genuinely isolated single cell
        for xx in (xL, xR):                          # left & right (vertical)
            y = yT + 1
            while y < yB:
                if not self.fence[y][xx]:
                    y += 1; continue
                put("fence_wood", xx, y); y += 2

    # ---- validation (runs before render) ----------------------------------
    def validate(self):
        issues = []
        blocked = [[False] * self.w for _ in range(self.h)]
        for y in range(self.h):
            for x in range(self.w):
                if self.mat[y][x] == "water" or self.fence[y][x]:
                    blocked[y][x] = True
        # props: footprint bounds + pairwise overlap (+ mark blocked)
        boxes = []
        for name, x, y in self.props:
            _, _, w, h = _rect(name)
            if x < 0 or y < 0 or x + w > self.w or y + h > self.h:
                issues.append(f"OFF-MAP: {name} at ({x},{y}) {w}x{h}")
            boxes.append((name, x, y, w, h))
            on_fence = False
            for dy in range(h):
                for dx in range(w):
                    if self.inb(x + dx, y + dy):
                        if self.fence[y + dy][x + dx]:
                            on_fence = True
                        blocked[y + dy][x + dx] = True
            if on_fence:
                issues.append(f"PROP-ON-FENCE: {name} at ({x},{y}) overlaps the fence")
            if name in WATER_PROPS and not all(
                    self.inb(x + dx, y + dy) and self.mat[y + dy][x + dx] == "water"
                    for dy in range(h) for dx in range(w)):
                issues.append(f"WATER-PROP-ON-LAND: {name} at ({x},{y}) is not on water")
        for i in range(len(boxes)):
            for j in range(i + 1, len(boxes)):
                if _overlap(boxes[i][1:], boxes[j][1:]):
                    issues.append(f"OVERLAP: {boxes[i][0]} x {boxes[j][0]}")
        for name, x, y in self.details:                  # overlays: bounds only
            _, _, w, h = _rect(name)
            if x < 0 or y < 0 or x + w > self.w or y + h > self.h:
                issues.append(f"OFF-MAP detail: {name} at ({x},{y}) {w}x{h}")
        # reachability: every opening should reach the map interior (flood over free cells)
        if self.opening:
            free = [[not blocked[y][x] for x in range(self.w)] for y in range(self.h)]
            seen = set()
            stack = [o for o in self.opening]
            while stack:
                x, y = stack.pop()
                if (x, y) in seen or not self.inb(x, y) or not free[y][x]:
                    continue
                seen.add((x, y))
                stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
            if len(seen) < 3:
                issues.append("REACHABILITY: opening does not connect to a free interior")
        return issues

    # ---- layered render ---------------------------------------------------
    def render(self, scale=PREVIEW_SCALE, strict=True):
        issues = self.validate()
        if issues and strict:
            raise ValueError("scene invalid:\n  " + "\n  ".join(issues))
        base = Image.new("RGBA", (self.w * T, self.h * T), GRASS_RGBA)
        # 1) material fills (sub-tile, exact per-cell), skipping water
        for y in range(self.h):
            for x in range(self.w):
                m = self.mat[y][x]
                if m == "water":
                    continue
                base.alpha_composite(sub_tile(FILL[m], x, y), (x * T, y * T))
        # 2) autotiled water: 9-slice convex edges + opposite-corner tiles for inner corners
        for y in range(self.h):
            for x in range(self.w):
                if self.mat[y][x] == "water":
                    base.alpha_composite(slice_full(self._water_tile(x, y))[0], (x * T, y * T))
        # 3) fence, drawn as aligned runs (h on top/bottom, v on the sides)
        self._draw_fence(base)
        # 4) props, painter-sorted (back-to-front), then overlay details on top
        for name, x, y in sorted(self.props, key=lambda p: (p[2], p[1])):
            base.alpha_composite(slice_full(name)[0], (x * T, y * T))
        for name, x, y in self.details:
            base.alpha_composite(slice_full(name)[0], (x * T, y * T))
        if scale != 1:
            base = base.resize((base.width * scale, base.height * scale), Image.NEAREST)
        return base, issues


def _overlap(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return (max(ax, bx) < min(ax + aw, bx + bw)) and (max(ay, by) < min(ay + ah, by + bh))


def build(name, scene):
    img, issues = scene.render(strict=False)
    img.convert("RGB").save(os.path.join(OUT, name + ".png"))
    tag = "OK" if not issues else "ISSUES: " + "; ".join(issues)
    print(f"{name}: {scene.w}x{scene.h}  [{tag}]")
    return issues
