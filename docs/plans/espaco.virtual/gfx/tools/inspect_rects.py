"""Grid-inspect the true tile bounds of multi-tile props. The 218-tile catalog
has wrong w/h/col for several big structures (e.g. house starts at col6 5x5, not
col7 4x5). Crops each catalog rect with a 2-tile margin and overlays a red tile
grid + the catalog rect in yellow so the true extent is readable by eye.
"""
import json, os
from PIL import Image, ImageDraw

GFX = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
im = Image.open(os.path.join(GFX, "Overworld.png")).convert("RGBA")
T = 16
CAT = {e["name"]: e for e in json.load(open(os.path.join(GFX, "catalog", "catalog.json")))
       if e["sheet"] == "overworld"}


def inspect(names, out, scale=6, margin=2):
    cells = []
    for n in names:
        e = CAT[n]
        c, r, w, h = e["col"], e["row"], e.get("w", 1), e.get("h", 1)
        x0 = max(0, (c - margin) * T); y0 = max(0, (r - margin) * T)
        x1 = (c + w + margin) * T; y1 = (r + h + margin) * T
        crop = im.crop((x0, y0, x1, y1)).resize(((x1 - x0) * scale, (y1 - y0) * scale), Image.NEAREST)
        d = ImageDraw.Draw(crop)
        cols = (x1 - x0) // T; rows = (y1 - y0) // T
        for i in range(cols + 1):
            d.line([(i * T * scale, 0), (i * T * scale, crop.height)], fill=(255, 0, 0, 120))
        for j in range(rows + 1):
            d.line([(0, j * T * scale), (crop.width, j * T * scale)], fill=(255, 0, 0, 120))
        # catalog rect in yellow
        rx0 = margin * T * scale; ry0 = margin * T * scale
        rx1 = (margin + w) * T * scale; ry1 = (margin + h) * T * scale
        d.rectangle([rx0, ry0, rx1, ry1], outline=(255, 255, 0, 255), width=3)
        d.text((4, 2), f"{n} c{c}r{r} {w}x{h}", fill=(255, 255, 255, 255))
        cells.append(crop)
    per = 4
    cw = max(c.width for c in cells) + 12
    ch = max(c.height for c in cells) + 12
    rows = (len(cells) + per - 1) // per
    canvas = Image.new("RGBA", (per * cw + 12, rows * ch + 12), (40, 40, 48, 255))
    for i, c in enumerate(cells):
        r, cc = divmod(i, per)
        canvas.alpha_composite(c, (12 + cc * cw, 12 + r * ch))
    canvas.convert("RGB").save(os.path.join(GFX, "previews", out))
    print(out, "->", [f"{n}:{CAT[n]['col']},{CAT[n]['row']},{CAT[n].get('w',1)}x{CAT[n].get('h',1)}" for n in names])


inspect(["house_large", "barn_large", "market_stall_awning", "tent_wood",
         "castle_gate", "bridge_castle", "tower_stone_round", "gate_arch_wood",
         "fountain_stone", "cave_entrance", "tree_foliage", "boulder_large"],
        "_rects_a.png")
inspect(["roof_round_orange", "roof_tile_large", "cellar_door_dark", "well_stone",
         "statue_pawn", "statue_relief", "stump_table", "anvil_forge",
         "arch_stone", "stone_wall_arch", "stairs_stone", "signpost_tall"],
        "_rects_b.png")
