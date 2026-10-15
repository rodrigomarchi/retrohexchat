#!/usr/bin/env python3
"""Author the ISOMETRIC "Office" scene: the furnished room behind the End of
Time's wooden door.

The Office is the Construct's platform furnished: the same sky (sea, stars,
vignette), the same slab, the same catalog and the same two sheets, so it adds
no art of its own. What it adds is a floor plan — two back walls with the way
out in one of them, a reception by the door, a row of filing and a meeting
corner along the back, a kitchenette, a desk island at the front — placed as
``fixed_items``: pieces of the catalog that the room comes with, which people
use like any other (sit on the chairs, switch the lamps) and never move. The
clear floor in the middle is theirs to build on, with any piece of the
catalog.

Reads ``priv/maps/construct.json`` (run ``author_construct.py`` first) and
writes ``priv/maps/office.json``. Deterministic; the layout is checked before
it is written: every fixed piece on the floor and off the way out, no two
overlapping, and every free tile reachable from the door.
"""
import json
import os
from collections import deque

from author_construct import SEA, VIGNETTE, VOID, Z_STEP, MATERIALS

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(TOOLS, "..", ".."))
CONSTRUCT_MAP = os.path.join(REPO, "apps", "retro_hex_chat", "priv", "maps", "construct.json")
MAP_OUT = os.path.join(REPO, "apps", "retro_hex_chat", "priv", "maps", "office.json")

MARGIN = 8
FLOOR_W, FLOOR_H = 24, 20
W, H = FLOOR_W + 2 * MARGIN, FLOOR_H + 2 * MARGIN
X0 = Y0 = MARGIN
X1, Y1 = X0 + FLOOR_W - 1, Y0 + FLOOR_H - 1
MAX_ITEMS = 200

# Floor plan in floor coordinates (u across x, v across y, from the back
# corner). The back walls run along v = 0 and u = 0; the way out is a door in
# the left one, with the people who arrive standing just inside it.
EXIT_UV = (0, 4)
SPAWN_UV = [(2, 4, "right"), (2, 5, "right"), (3, 4, "down")]

CARPET = MATERIALS["carpet_blue"][0]
WOOD = MATERIALS["wood"][0]
STONE = MATERIALS["stone"][0]
CHECKER = MATERIALS["checker"][0]

# Each zone is a rectangle of floor painted with a material: (u0, v0, u1, v1),
# later zones over earlier ones. The rest of the floor is grey stone.
ZONES = [
    (WOOD, (1, 1, 5, 10)),       # the entrance and reception
    (CARPET, (11, 1, 17, 7)),    # the meeting corner
    (CARPET, (6, 12, 16, 19)),   # the desk island
    (CHECKER, (18, 1, 22, 4)),   # the kitchenette
]

# (kind, u, v, dir): the piece's back corner, as `Construct.Layout` places it.
# A "down" piece faces screen down-left and runs down the v axis; "right" is
# its mirror and runs across u. Somebody at a desk sits behind it, facing the
# room, so a chair stands on the desk's far side.
FURNITURE = [
    # The back walls, meeting in the far corner, with a gap for the door.
    ("corner", 0, 0, "down"),
    *[("wall", u, 0, "right") for u in range(1, FLOOR_W)],
    *[("wall", 0, v, "down") for v in range(1, FLOOR_H) if v != EXIT_UV[1]],
    # Reception: the desk a few steps in from the door, its chair behind it,
    # a waiting sofa — clear of where people arrive.
    ("coat_rack", 1, 2, "down"),
    ("reception_desk", 3, 9, "right"),
    ("office_chair", 3, 8, "down"),
    ("tall_plant", 5, 8, "down"),
    ("sofa", 1, 12, "right"),
    ("tall_plant", 1, 14, "down"),
    # Along the back wall: the filing, the printer, a plant.
    ("bookshelf", 6, 1, "right"),
    ("file_cabinet", 7, 1, "right"),
    ("file_cabinet", 8, 1, "right"),
    ("printer", 9, 1, "right"),
    ("trash_bin", 10, 1, "down"),
    # The meeting corner: the table, its chairs, the whiteboard and a screen.
    ("whiteboard", 13, 1, "right"),
    ("screen", 14, 1, "right"),
    ("meeting_table", 13, 3, "down"),
    ("office_chair", 12, 3, "right"),
    ("office_chair", 12, 4, "right"),
    ("office_chair", 12, 5, "right"),
    ("office_chair", 14, 2, "down"),
    ("tall_plant", 16, 1, "down"),
    # The kitchenette, against the back wall.
    ("vending_machine", 19, 1, "right"),
    ("coffee_machine", 20, 1, "right"),
    ("water_cooler", 21, 1, "right"),
    ("trash_bin", 22, 1, "down"),
    # The desk island at the front: two rows of two, a partition between them.
    ("office_desk", 8, 13, "down"),
    ("office_chair", 7, 13, "right"),
    ("office_desk", 13, 13, "down"),
    ("office_chair", 12, 13, "right"),
    ("cubicle_partition", 7, 15, "right"),
    ("cubicle_partition", 8, 15, "right"),
    ("cubicle_partition", 12, 15, "right"),
    ("cubicle_partition", 13, 15, "right"),
    ("office_desk", 8, 16, "down"),
    ("office_chair", 7, 16, "right"),
    ("office_desk", 13, 16, "down"),
    ("office_chair", 12, 16, "right"),
    ("cactus", 14, 18, "down"),
    ("trash_bin", 9, 18, "down"),
    # Light in the corners, and a plant by the kitchenette.
    ("lamp", 1, 18, "down"),
    ("lamp", 22, 18, "down"),
    ("lamp", 22, 6, "down"),
    ("plant", 22, 8, "down"),
]


def _footprint(catalog, kind, x, y, dir_):
    w, h = catalog[kind].get("size", [1, 1])
    if dir_ in ("right", "left"):
        w, h = h, w
    return [(x + dx, y + dy) for dy in range(h) for dx in range(w)]


def _on_floor(x, y):
    return X0 <= x <= X1 and Y0 <= y <= Y1


def _fixed_items(catalog):
    items = []
    for n, (kind, u, v, dir_) in enumerate(FURNITURE):
        if kind not in catalog:
            raise AssertionError(f"{kind} is not in the Construct's catalog")
        if dir_ not in catalog[kind].get("dirs", ["down", "right"]):
            raise AssertionError(f"{kind} does not face {dir_}")
        items.append({"id": f"fixed:{n}", "kind": kind, "x": X0 + u, "y": Y0 + v, "dir": dir_})
    return items


def _validate(catalog, items, exit_, spawn, reserved):
    taken = {}
    for item in items:
        for tile in _footprint(catalog, item["kind"], item["x"], item["y"], item["dir"]):
            if not _on_floor(*tile):
                raise AssertionError(f"{item} runs off the floor at {tile}")
            if tile in reserved or tile == exit_:
                raise AssertionError(f"{item} stands on the way out at {tile}")
            if tile in taken:
                raise AssertionError(f"{item} overlaps {taken[tile]} at {tile}")
            taken[tile] = item
    blocked = {t for t, i in taken.items() if catalog[i["kind"]].get("blocks", True)}
    blocked.add(exit_)
    start = (spawn[0]["x"], spawn[0]["y"])
    seen, queue = {start}, deque([start])
    while queue:
        x, y = queue.popleft()
        for nxt in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if _on_floor(*nxt) and nxt not in blocked and nxt not in seen:
                seen.add(nxt)
                queue.append(nxt)
    free = {(x, y) for y in range(Y0, Y1 + 1) for x in range(X0, X1 + 1)} - blocked
    if free - seen:
        raise AssertionError(f"cut off from the door: {sorted(free - seen)}")
    # Every chair can be reached: somebody walks up to it to sit down.
    for item in items:
        if catalog[item["kind"]].get("seat") or catalog[item["kind"]].get("seats"):
            x, y = item["x"], item["y"]
            if not any(n in seen for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))):
                raise AssertionError(f"nobody can reach the seat {item}")


def _floor():
    rows = []
    for y in range(H):
        row = []
        for x in range(W):
            if not _on_floor(x, y):
                row.append(VOID)
                continue
            u, v = x - X0, y - Y0
            tile = STONE
            for material, (u0, v0, u1, v1) in ZONES:
                if u0 <= u <= u1 and v0 <= v <= v1:
                    tile = material
            row.append(tile)
        rows.append("".join(row))
    return rows


def build():
    with open(CONSTRUCT_MAP) as handle:
        construct = json.load(handle)
    catalog = construct["catalog"]

    exit_ = (X0 + EXIT_UV[0], Y0 + EXIT_UV[1])
    spawn = [{"x": X0 + u, "y": Y0 + v, "dir": d} for u, v, d in SPAWN_UV]
    # The way out, the tile in front of it and the spawns stay clear for good.
    reserved = sorted({(exit_[0] + 1, exit_[1] + dy) for dy in (-1, 0, 1)}
                      | {(s["x"], s["y"]) for s in spawn})
    items = _fixed_items(catalog)
    _validate(catalog, items, exit_, spawn, set(reserved))

    def _h(x, y):
        return (x * 928371 + y * 1237) & 0xFFFF

    stars = [{"x": x, "y": y, "tile": "iso_star", "sort": "flat"}
             for y in range(H) for x in range(W)
             if not _on_floor(x, y) and _h(x, y) % 13 == 0]

    void = []
    for y in range(H):
        x = 0
        while x < W:
            if _on_floor(x, y):
                x += 1
                continue
            start = x
            while x < W and not _on_floor(x, y):
                x += 1
            void.append({"x": start, "y": y, "w": x - start, "h": 1, "kind": "void"})

    door = catalog["door"]["tiles"]["down"]
    layout = {
        "width": W,
        "height": H,
        "tile_size": construct["tile_size"],
        "ground": VOID,
        "columns": construct["columns"],
        "projection": "isometric",
        "iso": dict(construct["iso"], z_step=Z_STEP),
        "sea": SEA,
        "vignette": VIGNETTE,
        "slabs": [{"thickness": 10, "taper": 0.78, "hull": [X0, X1, Y0, Y1]}],
        "vocab": construct["vocab"],
        "floor": _floor(),
        "decor": stars + [{"x": exit_[0], "y": exit_[1], "tile": door, "sort": "stand"}],
        "collision": void + [{"x": exit_[0], "y": exit_[1], "w": 1, "h": 1, "kind": "prop"}],
        "spawn": spawn,
        "lights": [{"x": exit_[0], "y": exit_[1], "radius": 2.0, "color": "ffd591", "blend": "add"}],
        "zones": [{"id": "office", "kind": "platform", "x": X0, "y": Y0, "w": FLOOR_W, "h": FLOOR_H}],
        "interactables": [
            {
                "id": "office_exit",
                "kind": "portal",
                "x": exit_[0],
                "y": exit_[1],
                "title": "End of Time",
                "modal": {"kind": "confirm", "action": "exit_office"},
            }
        ],
        "reserved": [[x, y] for x, y in reserved],
        "fixed_items": items,
        "tilesets": construct["tilesets"],
        "catalog": catalog,
        "materials": construct["materials"],
        "max_items": MAX_ITEMS,
    }

    with open(MAP_OUT, "w") as out:
        json.dump(layout, out)
    print(f"OK office: {W}x{H} fixed={len(items)} reserved={len(reserved)}")


if __name__ == "__main__":
    build()
