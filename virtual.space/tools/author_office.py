#!/usr/bin/env python3
"""Author the ISOMETRIC "Office" scene: the furnished room behind the End of
Time's wooden door.

The Office is the Construct's platform furnished: the same sky (sea, stars,
vignette), the same slab, the same catalog and the same two sheets, so it adds
no art of its own. What it adds is a floor plan — two back walls with the way
out in one of them, a reception by the door with the filing along the back
wall, a meeting room and a kitchenette in glass, desks in cubicles at the
front — placed as
``fixed_items``: pieces of the catalog that the room comes with, which people
use like any other (sit on the chairs, switch the lamps) and never move. The
clear floor in the middle is theirs to build on, with any piece of the
catalog. The glass rooms each have a glass door, and what is inside them
shows through their walls.

Reads ``priv/maps/construct.json`` (run ``author_construct.py`` first) and
writes ``priv/maps/office.json``. Deterministic; the layout is checked before
it is written: every fixed piece on the floor and off the way out, no two
overlapping, and every free tile reachable from the door, through the glass
doors where a room is walled in.
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
# later zones over earlier ones, each running right up to the walls around it.
# The rest of the floor is grey stone.
ZONES = [
    (WOOD, (0, 0, 7, 9)),        # the entrance and reception
    (CARPET, (8, 0, 17, 8)),     # the meeting room
    (CHECKER, (18, 0, 23, 7)),   # the kitchenette
    (CARPET, (6, 10, 16, 19)),   # the desks
]

# Which way a piece faces, by what it stands against, in three cases:
# - a bulky one-tile piece (a cabinet, a machine, a chair) faces +v as "down"
#   and +u as "right": against the back wall along v = 0 it is "down", against
#   the one along u = 0 "right";
# - a two-tile piece runs down v as "down", facing +u, and across u as
#   "right", facing +v;
# - a flat panel (a wall, a pane of glass, the whiteboard, the screen) runs
#   down v as "down", facing +u: along the back wall at v = 0 it is "right".
# A chair faces what it is for; whoever sits at a workstation sits behind it,
# facing the room, its monitor's back to the viewer.
MEETING_U = (8, 17)   # the meeting room's glass walls, left and right
MEETING_V = 8         # and in front
MEETING_DOOR_U = 12
KITCHEN_V = 7         # the kitchenette's glass wall in front
KITCHEN_DOOR_U = 20

FURNITURE = [
    # The back walls, meeting in the far corner, with a gap for the door.
    ("corner", 0, 0, "down"),
    *[("wall", u, 0, "right") for u in range(1, FLOOR_W)],
    *[("wall", 0, v, "down") for v in range(1, FLOOR_H) if v != EXIT_UV[1]],
    # The meeting room: glass on its three open sides, a glass door in front.
    *[("glass_wall", MEETING_U[0], v, "down") for v in range(1, MEETING_V)],
    *[("glass_wall", MEETING_U[1], v, "down") for v in range(1, MEETING_V)],
    *[("glass_door" if u == MEETING_DOOR_U else "glass_wall", u, MEETING_V, "right")
      for u in range(MEETING_U[0], MEETING_U[1] + 1)],
    ("meeting_table", 11, 3, "down"),
    ("office_chair", 10, 3, "right"),
    ("office_chair", 10, 4, "right"),
    ("office_chair", 10, 5, "right"),
    ("office_chair", 11, 2, "down"),
    ("office_chair", 12, 2, "down"),
    ("whiteboard", 14, 1, "right"),
    ("screen", 15, 1, "right"),
    ("tall_plant", 9, 1, "down"),
    ("tall_plant", 16, 7, "down"),
    # The kitchenette, in the far-right corner: glass in front, a glass door.
    *[("glass_door" if u == KITCHEN_DOOR_U else "glass_wall", u, KITCHEN_V, "right")
      for u in range(MEETING_U[1] + 1, FLOOR_W)],
    ("vending_machine", 18, 1, "down"),
    ("coffee_machine", 19, 1, "down"),
    ("water_cooler", 20, 1, "down"),
    ("fridge", 22, 1, "down"),
    ("trash_bin", 21, 1, "down"),
    ("table", 20, 4, "down"),
    ("chair", 19, 4, "right"),
    ("chair", 20, 3, "down"),
    # Reception, by the way in: the counter, its chair behind it, a sofa
    # against the wall to wait on, the filing along the back wall.
    ("coat_rack", 1, 1, "right"),
    ("reception_desk", 4, 8, "right"),
    ("office_chair", 4, 7, "down"),
    ("tall_plant", 6, 7, "down"),
    ("sofa", 1, 10, "down"),
    ("tall_plant", 1, 13, "right"),
    ("bookshelf", 4, 1, "down"),
    ("file_cabinet", 5, 1, "down"),
    ("file_cabinet", 6, 1, "down"),
    ("printer", 7, 1, "down"),
    # The desks: two rows of workstations, a chair behind each, partitions
    # between them.
    *[piece for u, v in ((9, 11), (14, 11), (9, 15), (14, 15)) for piece in (
        ("workstation", u, v, "down"),
        ("office_chair", u - 1, v, "right"),
        ("cubicle_partition", u - 1, v + 2, "right"),
        ("cubicle_partition", u, v + 2, "right"),
    )],
    *[("cubicle_partition", 11, v, "down") for v in (11, 12, 15, 16)],
    ("trash_bin", 10, 13, "down"),
    ("cactus", 15, 13, "down"),
    # A corner to sit in at the front, and light in the corners.
    ("sofa", 2, 15, "down"),
    ("coffee_table", 3, 16, "down"),
    ("lamp", 1, 18, "right"),
    ("lamp", 22, 18, "down"),
    ("lamp", 22, 9, "down"),
    ("plant", 19, 18, "down"),
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
    # A door is a way through: it opens on E, so what is behind it counts as
    # reached.
    blocked = {t for t, i in taken.items()
               if catalog[i["kind"]].get("blocks", True) and catalog[i["kind"]].get("use") != "door"}
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
        "decor": stars + [{"x": exit_[0], "y": exit_[1], "tile": door, "sort": "stand",
                           "shadow": False}],
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
