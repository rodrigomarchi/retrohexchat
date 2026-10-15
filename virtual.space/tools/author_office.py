#!/usr/bin/env python3
"""Author the ISOMETRIC "Office" scene: the furnished room behind the End of
Time's wooden door.

The Office is the Construct's platform furnished: the same sky (sea, stars,
vignette), the same slab, the same catalog and the same two sheets, so it adds
no art of its own. What it adds is a floor plan — the way
out standing at its edge, a reception by the door with the filing along the
back edge, a meeting room and a kitchenette in glass, desks in cubicles at the
front — placed as
``fixed_items``: pieces of the catalog that the room comes with, which people
use like any other (sit on the chairs, switch the lamps) and never move. The
clear floor in the middle is theirs to build on, with any piece of the
catalog. The glass rooms each have a glass door, and what is inside them
shows through their walls.

Reads ``priv/maps/construct.json`` (run ``author_construct.py`` first) and
writes ``priv/maps/office.json`` through ``furnished_room``, which checks the
plan first. Deterministic.
"""
from author_construct import MATERIALS
from furnished_room import Plan, build

# Floor plan in floor coordinates (u across x, v across y, from the back
# corner). The way out is a door standing on the left edge, with the people
# who arrive standing just in front of it.
EXIT_UV = (0, 4)
SPAWN_UV = [(2, 4, "right"), (2, 5, "right"), (3, 4, "down")]

CARPET = MATERIALS["carpet_blue"][0]
WOOD = MATERIALS["wood"][0]
STONE = MATERIALS["stone"][0]
CHECKER = MATERIALS["checker"][0]

# Each zone is a rectangle of floor painted with a material: (u0, v0, u1, v1),
# later zones over earlier ones. A room's floor is exactly its inner tiles: its
# glass stands on the edge of the tiles around it, so the carpet stops at the
# pane. The rest of the floor is grey stone.
ZONES = [
    (WOOD, (0, 0, 8, 9)),        # the entrance and reception, up to the glass
    (CARPET, (9, 0, 16, 7)),     # the meeting room
    (CHECKER, (17, 0, 23, 7)),   # the kitchenette
    (CARPET, (7, 10, 15, 18)),   # the desks
]

# Which way a piece faces, in three cases:
# - a bulky one-tile piece faces the way its art was drawn: the bookshelf, the
#   vending machine and the fridge show their front as "down" (+v); the file
#   cabinet, the printer, the coffee machine and every seat as "right"'s
#   mirror, "down" facing +u — check the art, not the kind;
# - a two-tile piece runs down v as "down", facing +u, and across u as
#   "right", facing +v;
# - a pane (glass, a glass door, a cubicle partition) stands on one edge of its
#   tile: "down" its +u edge, "up" its -u edge, "right" its +v edge, "left" its
#   -v edge. Its tile is blocked, so it is outside the room it walls (or, for
#   the wall two rooms share, a column the kitchenette gives up); two runs
#   meet at a point.
# A chair faces what it is for; whoever sits at a workstation sits behind it,
# facing the room, its monitor's back to the viewer. The floor's own edge is
# the edge of the platform: no wall stands on it.
MEETING = (9, 16, 7)    # the meeting room's inner tiles: u from, u to, v to
KITCHEN = (17, 23, 7)
MEETING_DOOR_U = 12
KITCHEN_DOOR_U = 20

FURNITURE = [
    # The meeting room: glass on its left, its right (shared with the
    # kitchenette) and in front, a glass door in front.
    *[("glass_wall", MEETING[0] - 1, v, "down") for v in range(0, MEETING[2] + 1)],
    *[("glass_wall", KITCHEN[0], v, "up") for v in range(0, KITCHEN[2] + 1)],
    *[("glass_door" if u == MEETING_DOOR_U else "glass_wall", u, MEETING[2] + 1, "left")
      for u in range(MEETING[0], MEETING[1] + 1)],
    ("meeting_table", 11, 2, "down"),
    ("office_chair", 10, 2, "down"),
    ("office_chair", 10, 3, "down"),
    ("office_chair", 10, 4, "down"),
    ("office_chair", 11, 1, "right"),
    ("office_chair", 12, 1, "right"),
    ("whiteboard", 14, 0, "right"),
    ("screen", 15, 0, "right"),
    ("tall_plant", 9, 0, "down"),
    ("tall_plant", 16, 6, "down"),
    # The kitchenette: glass in front with its door; its machines along the
    # back edge, a table to sit at.
    *[("glass_door" if u == KITCHEN_DOOR_U else "glass_wall", u, KITCHEN[2] + 1, "left")
      for u in range(KITCHEN[0], KITCHEN[1] + 1)],
    ("vending_machine", 18, 0, "down"),
    ("coffee_machine", 19, 0, "right"),
    ("water_cooler", 20, 0, "down"),
    ("trash_bin", 21, 0, "down"),
    ("fridge", 22, 0, "down"),
    ("table", 20, 4, "down"),
    ("chair", 19, 4, "down"),
    ("chair", 20, 3, "right"),
    # Reception, by the way in: the counter, its chair behind it, armchairs to
    # wait in, the filing along the back edge. Armchairs, not a sofa: a piece
    # two tiles long shows that PixelLab draws on a steeper slope than this
    # floor's, and a one-tile piece does not.
    ("coat_rack", 0, 1, "right"),
    ("bookshelf", 4, 0, "down"),
    ("file_cabinet", 5, 0, "right"),
    ("file_cabinet", 6, 0, "right"),
    ("printer", 7, 0, "right"),
    ("reception_desk", 4, 8, "right"),
    ("office_chair", 4, 7, "right"),
    ("tall_plant", 6, 7, "down"),
    ("armchair", 1, 10, "down"),
    ("armchair", 1, 11, "down"),
    ("coffee_table", 2, 10, "down"),
    ("tall_plant", 0, 13, "right"),
    # The desks: two rows of workstations, a chair behind each, a partition
    # in front of each row and between the two columns.
    *[piece for u, v in ((9, 11), (14, 11), (9, 15), (14, 15)) for piece in (
        ("workstation", u, v, "down"),
        ("office_chair", u - 1, v, "down"),
        ("cubicle_partition", u - 1, v + 2, "left"),
        ("cubicle_partition", u, v + 2, "left"),
    )],
    *[("cubicle_partition", 11, v, "down") for v in (11, 12, 15, 16)],
    ("trash_bin", 10, 14, "down"),
    ("cactus", 15, 13, "down"),
    # A corner to sit in at the front, and light in the corners.
    ("armchair", 2, 16, "down"),
    ("armchair", 3, 15, "right"),
    ("coffee_table", 3, 16, "down"),
    ("lamp", 0, 18, "right"),
    ("lamp", 23, 18, "down"),
    ("lamp", 23, 9, "down"),
    ("plant", 19, 18, "down"),
]


PLAN = Plan(
    room="office",
    floor_w=24,
    floor_h=20,
    exit_uv=EXIT_UV,
    spawn_uv=SPAWN_UV,
    ground=STONE,
    zones=ZONES,
    furniture=FURNITURE,
    exit_tile="cst_door",
    exit_light="ffd591",
)


if __name__ == "__main__":
    build(PLAN)
