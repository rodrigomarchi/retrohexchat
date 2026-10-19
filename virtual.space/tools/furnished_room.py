"""A furnished room behind one of the End of Time's doors, written as a map.

A furnished room is the Construct's platform with a floor plan on it: the same
sky (sea, stars, vignette), the same slab, the same catalog and the same two
sheets, so it adds no art of its own. What it adds is a door out at its edge,
its floor painted by zones, and its furniture placed as ``fixed_items``:
pieces of the catalog the room comes with, which people use like any other and
never move. The clear floor between them is theirs to build on.

A room's author (``author_office.py``, ``author_game_room.py``) describes it as
a ``Plan`` and calls ``build``. The plan is checked before it is written: every
fixed piece on the floor and off the way out, no two overlapping, every free
tile reachable from the door (through doors where a room is walled in) and
every seat reachable.
"""
import json
import os
from collections import deque
from dataclasses import dataclass, field

from author_construct import SEA, VIGNETTE, VOID, Z_STEP

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(TOOLS, "..", ".."))
MAPS = os.path.join(REPO, "apps", "retro_hex_chat", "priv", "maps")
CONSTRUCT_MAP = os.path.join(MAPS, "construct.json")


@dataclass
class Plan:
    """A room's floor plan, in floor coordinates: u across x, v across y,
    from the floor's back corner.

    ``room`` names the map (``<room>.json``), its zone, its exit
    (``<room>_exit``) and the exit's action (``exit_<room>``). ``zones`` paint
    the floor, later ones over earlier ones, on ``ground``. ``furniture`` is
    ``(kind, u, v, dir)``, or ``(kind, u, v, dir, game)`` for a cabinet that
    plays one Retro Game (a catalogue id such as ``"hex_pong"``). ``exit_tile`` is the vocab tile of the door out and
    ``exit_light`` its glow."""

    room: str
    floor_w: int
    floor_h: int
    exit_uv: tuple
    spawn_uv: list
    ground: str
    zones: list
    furniture: list
    exit_tile: str
    exit_light: str
    margin: int = 8
    max_items: int = 200
    extra_lights: list = field(default_factory=list)

    @property
    def x0(self):
        return self.margin

    @property
    def y0(self):
        return self.margin

    @property
    def x1(self):
        return self.margin + self.floor_w - 1

    @property
    def y1(self):
        return self.margin + self.floor_h - 1

    @property
    def width(self):
        return self.floor_w + 2 * self.margin

    @property
    def height(self):
        return self.floor_h + 2 * self.margin

    @property
    def exit(self):
        return (self.x0 + self.exit_uv[0], self.y0 + self.exit_uv[1])

    def spawn(self):
        return [{"x": self.x0 + u, "y": self.y0 + v, "dir": d} for u, v, d in self.spawn_uv]

    def on_floor(self, x, y):
        return self.x0 <= x <= self.x1 and self.y0 <= y <= self.y1


def load_construct():
    with open(CONSTRUCT_MAP) as handle:
        return json.load(handle)


def footprint(catalog, kind, x, y, dir_):
    w, h = catalog[kind].get("size", [1, 1])
    if dir_ in ("right", "left"):
        w, h = h, w
    return [(x + dx, y + dy) for dy in range(h) for dx in range(w)]


def fixed_items(plan, catalog):
    items = []
    for n, (kind, u, v, dir_, *game) in enumerate(plan.furniture):
        if kind not in catalog:
            raise AssertionError(f"{kind} is not in the Construct's catalog")
        if dir_ not in catalog[kind].get("dirs", ["down", "right"]):
            raise AssertionError(f"{kind} does not face {dir_}")
        if game and catalog[kind].get("use") != "arcade":
            raise AssertionError(f"{kind} plays no game, so it cannot be given one")
        item = {"id": f"fixed:{n}", "kind": kind, "x": plan.x0 + u, "y": plan.y0 + v, "dir": dir_}
        if game:
            item["game"] = game[0]
        items.append(item)
    return items


def validate(plan, catalog, items, exit_, spawn, reserved):
    taken = {}
    for item in items:
        for tile in footprint(catalog, item["kind"], item["x"], item["y"], item["dir"]):
            if not plan.on_floor(*tile):
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
            if plan.on_floor(*nxt) and nxt not in blocked and nxt not in seen:
                seen.add(nxt)
                queue.append(nxt)
    free = {(x, y) for y in range(plan.y0, plan.y1 + 1)
            for x in range(plan.x0, plan.x1 + 1)} - blocked
    if free - seen:
        raise AssertionError(f"cut off from the door: {sorted(free - seen)}")
    # Every seat can be reached: somebody walks up to it to sit down. A piece
    # with seats of its own is reached at one of its seats.
    for item in items:
        spec = catalog[item["kind"]]
        if spec.get("seat") or spec.get("seats"):
            tiles = footprint(catalog, item["kind"], item["x"], item["y"], item["dir"])
            if not any(n in seen for x, y in tiles
                       for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))):
                raise AssertionError(f"nobody can reach the seat {item}")


def floor(plan):
    rows = []
    for y in range(plan.height):
        row = []
        for x in range(plan.width):
            if not plan.on_floor(x, y):
                row.append(VOID)
                continue
            u, v = x - plan.x0, y - plan.y0
            tile = plan.ground
            for material, (u0, v0, u1, v1) in plan.zones:
                if u0 <= u <= u1 and v0 <= v <= v1:
                    tile = material
            row.append(tile)
        rows.append("".join(row))
    return rows


def reserved(plan):
    """The way out, the tiles in front of it and the spawns: clear for good."""
    ex, ey = plan.exit
    return sorted({(ex + 1, ey + dy) for dy in (-1, 0, 1)}
                  | {(s["x"], s["y"]) for s in plan.spawn()})


def build(plan):
    construct = load_construct()
    catalog = construct["catalog"]
    exit_ = plan.exit
    spawn = plan.spawn()
    kept = reserved(plan)
    items = fixed_items(plan, catalog)
    validate(plan, catalog, items, exit_, spawn, set(kept))
    W, H = plan.width, plan.height

    def _h(x, y):
        return (x * 928371 + y * 1237) & 0xFFFF

    stars = [{"x": x, "y": y, "tile": "iso_star", "sort": "flat"}
             for y in range(H) for x in range(W)
             if not plan.on_floor(x, y) and _h(x, y) % 13 == 0]

    void = []
    for y in range(H):
        x = 0
        while x < W:
            if plan.on_floor(x, y):
                x += 1
                continue
            start = x
            while x < W and not plan.on_floor(x, y):
                x += 1
            void.append({"x": start, "y": y, "w": x - start, "h": 1, "kind": "void"})

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
        "slabs": [{"thickness": 10, "taper": 0.78, "hull": [plan.x0, plan.x1, plan.y0, plan.y1]}],
        "vocab": construct["vocab"],
        "floor": floor(plan),
        "decor": stars + [{"x": exit_[0], "y": exit_[1], "tile": plan.exit_tile, "sort": "stand",
                           "shadow": False}],
        "collision": void + [{"x": exit_[0], "y": exit_[1], "w": 1, "h": 1, "kind": "prop"}],
        "spawn": spawn,
        "lights": [{"x": exit_[0], "y": exit_[1], "radius": 2.0, "color": plan.exit_light,
                    "blend": "add"}] + plan.extra_lights,
        "zones": [{"id": plan.room, "kind": "platform", "x": plan.x0, "y": plan.y0,
                   "w": plan.floor_w, "h": plan.floor_h}],
        "interactables": [
            {
                "id": f"{plan.room}_exit",
                "kind": "portal",
                "x": exit_[0],
                "y": exit_[1],
                "title": "End of Time",
                "modal": {"kind": "confirm", "action": f"exit_{plan.room}"},
            }
        ],
        "reserved": [[x, y] for x, y in kept],
        "fixed_items": items,
        "tilesets": construct["tilesets"],
        "catalog": catalog,
        "materials": construct["materials"],
        "max_items": plan.max_items,
    }

    with open(os.path.join(MAPS, f"{plan.room}.json"), "w") as out:
        json.dump(layout, out)
    print(f"OK {plan.room}: {W}x{H} fixed={len(items)} reserved={len(kept)}")
