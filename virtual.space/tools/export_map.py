"""Export the composed full map as the platform layout JSON.

Reads the authored Scene from full_map.py and emits
`apps/retro_hex_chat/priv/maps/elfic_forest.json` in the runtime contract:
floor (h x w matrix of tile names / null=ground), decor ([{x,y,tile}] in
painter order) and blocked ([[x,y]]). Also prints the Elixir vocabulary
entries (name -> sheet rect) for every tile name the map uses, generated
from the verified showcase CAT so the runtime rects are the corrected ones.

    python3 export_map.py
"""
import json
import os

from showcase import CAT
from pipeline import WATER_PROPS, _rect, T  # noqa: F401  (T documents tile size)
from full_map import full_map, W, H

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_JSON = os.path.join(REPO, "apps", "retro_hex_chat", "priv", "maps", "elfic_forest.json")

# pipeline material -> runtime floor tile name(s). crops is a 2x2 seamless
# patch: each cell gets the quarter matching its parity, exactly like the
# pipeline's wrapped sub-tile fill.
MAT_TILE = {"grass": None, "gravel": "gravel_light", "dirt": "dirt",
            "grass_dark": "grass_scrub"}
CROP_QUARTERS = [["crops_tl", "crops_tr"], ["crops_bl", "crops_br"]]

# Floor names that are not 1x1 CAT entries (quarters of crops_field, plain grass).
FLOOR_RECTS = {
    "grass_plain": ("overworld", 0, 0),
    "gravel_light": ("overworld", 14, 11),
    "grass_scrub": ("overworld", 0, 29),
    "dirt": ("overworld", 1, 30),
    "crops_tl": ("overworld", 0, 34), "crops_tr": ("overworld", 1, 34),
    "crops_bl": ("overworld", 0, 35), "crops_br": ("overworld", 1, 35),
}

# Props a participant can stand on (accents) or must stand on (crossings,
# seats). Everything else blocks its full footprint.
WALKABLE = {"flowers_white", "bush_clover", "rock_pebbles_scatter",
            "pebble_stone", "bone", "skull", "bench_wood",
            "stepping_stones", "stepping_stone",
            "water_lily", "water_lilies_cluster", "water_ripple"}

# Details that block cells the exporter cannot infer (arch pillars, fire).
EXTRA_BLOCKED = (
    [(45, y) for y in (34, 35, 36)] + [(48, y) for y in (34, 35, 36)]  # gate arch
    + [(7, 58), (8, 58)]                                               # witch fire
)


def floor_matrix(s):
    rows = []
    for y in range(s.h):
        row = []
        for x in range(s.w):
            m = s.mat[y][x]
            if m == "water":
                row.append(s._water_tile(x, y))
            elif m == "crops":
                row.append(CROP_QUARTERS[y % 2][x % 2])
            else:
                row.append(MAT_TILE[m])
        rows.append(row)
    return rows


def fence_decor(s):
    """Replicate the renderer's per-rect fence walk as decor pieces."""
    pieces = []
    for (xL, yT, xR, yB) in s.fence_rects:
        for yy in {yT, yB}:
            x = xL
            while x <= xR:
                if not s.fence[yy][x]:
                    x += 1; continue
                if x + 1 <= xR and s.fence[yy][x + 1] and x + 1 < s.w:
                    pieces.append({"x": x, "y": yy, "tile": "fence_h"}); x += 2
                elif x - 1 >= xL and s.fence[yy][x - 1]:
                    pieces.append({"x": x - 1, "y": yy, "tile": "fence_h"}); x += 1
                else:
                    pieces.append({"x": x, "y": yy, "tile": "fence_wood"}); x += 1
        for xx in {xL, xR}:
            y = yT + 1
            while y < yB:
                if not s.fence[y][xx]:
                    y += 1; continue
                pieces.append({"x": xx, "y": y, "tile": "fence_wood"}); y += 2
    return pieces


def blocked_set(s):
    blocked = set()
    stones = set()
    for name, x, y in s.props:
        _, _, w, h = _rect(name)
        cells = {(x + dx, y + dy) for dy in range(h) for dx in range(w)}
        if name in ("stepping_stones", "stepping_stone"):
            stones |= cells
        if name in WALKABLE:
            continue
        blocked |= cells
    for y in range(s.h):
        for x in range(s.w):
            if s.mat[y][x] == "water" and (x, y) not in stones:
                blocked.add((x, y))
            if s.fence[y][x]:
                blocked.add((x, y))
    blocked |= set(EXTRA_BLOCKED)
    return blocked


def main():
    s = full_map()
    issues = s.validate()
    assert not issues, issues

    floor = floor_matrix(s)
    decor = fence_decor(s)
    decor += [{"x": x, "y": y, "tile": n}
              for (n, x, y) in sorted(s.props, key=lambda p: (p[2], p[1]))]
    decor += [{"x": x, "y": y, "tile": n} for (n, x, y) in s.details]

    blocked = blocked_set(s)
    spawn = [(x, y) for y in (26, 27) for x in range(41, 45)]
    for cell in spawn:
        assert cell not in blocked, f"spawn cell {cell} is blocked"

    data = {
        "width": s.w, "height": s.h, "ground": "grass_plain",
        "floor": floor, "decor": decor,
        "blocked": sorted([x, y] for (x, y) in blocked),
    }
    with open(OUT_JSON, "w") as f:
        json.dump(data, f)
    print(f"wrote {OUT_JSON}: {s.w}x{s.h}, decor={len(decor)}, blocked={len(blocked)}")

    # ---- the Elixir vocabulary for every name this map references ----------
    names = {p["tile"] for p in decor}
    names |= {c for row in floor for c in row if c}
    names |= {"grass_plain"}
    lines = []
    for n in sorted(names):
        if n in FLOOR_RECTS:
            ts, c, r = FLOOR_RECTS[n]
            w = h = 1
        elif n in CAT:
            e = CAT[n]
            ts, c, r = e.get("sheet", "overworld"), e["col"], e["row"]
            w, h = e.get("w", 1), e.get("h", 1)
        else:
            raise KeyError(n)
        wh = f", w: {w}, h: {h}" if (w, h) != (1, 1) else ""
        lines.append(f'    "{n}" => %{{ts: "{ts}", col: {c}, row: {r}{wh}}},')
    print("\n# --- paste into Overworld @tiles ---")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
