#!/usr/bin/env python3
"""Author the ISOMETRIC "Game Room" scene: the furnished room behind the End of
Time's neon door.

The Game Room is the Construct's platform furnished for play, on a dark arcade
carpet: a row of arcade cabinets along the back edge, each opening the
arcade, a pool table and a ping-pong table down the left side, a lounge of
beanbags under the jukebox and the screens, and a LAN corner of desks with
gaming chairs at the front. The clear floor in the middle is the players' to
build on, with any piece of the catalog.

Reads ``priv/maps/construct.json`` (run ``author_construct.py`` first) and
writes ``priv/maps/game_room.json`` through ``furnished_room``, which checks the
plan first. Deterministic.
"""
from author_construct import MATERIALS
from furnished_room import Plan, build

# Floor plan in floor coordinates (u across x, v across y, from the back
# corner). The way out is the neon door on the left edge, with the people who
# arrive standing just in front of it.
EXIT_UV = (0, 4)
SPAWN_UV = [(2, 4, "right"), (2, 5, "right"), (3, 4, "down")]

ARCADE = MATERIALS["carpet_arcade"][0]
CHECKER = MATERIALS["checker"][0]
RED = MATERIALS["carpet_red"][0]
WOOD = MATERIALS["wood"][0]

# Each zone is a rectangle of floor painted with a material: (u0, v0, u1, v1),
# later zones over earlier ones, on the arcade carpet.
ZONES = [
    (CHECKER, (2, 0, 12, 2)),    # the walk along the cabinets
    (RED, (14, 0, 23, 6)),       # the lounge
    (WOOD, (3, 8, 8, 17)),       # the tables
]

# Which way a piece faces: the cabinets, the jukebox and the other one-tile
# pieces along the back edge face "down" (+v), their fronts to the room as
# drawn; a two-tile piece along it (the television's stand) runs across u as
# "right", facing +v; along the left edge a bulky piece faces "right",
# mirrored to show its front to the room.
# A seat "down" faces +u and "right" faces +v. A desk with a gaming chair
# behind it turns its monitor's back on the viewer, so whoever plays at it
# faces the room. Two-tile tables run down v as "down".
CABINETS = ["arcade", "racing_arcade"] * 4

FURNITURE = [
    # The arcade: cabinets shoulder to shoulder along the back edge, a neon
    # totem at each end of the row.
    ("neon_totem", 2, 0, "down"),
    *[(kind, 3 + n, 0, "down") for n, kind in enumerate(CABINETS)],
    ("neon_totem", 11, 0, "down"),
    # The lounge: the jukebox, a television on its stand, a vending
    # machine, a console and a neon sign, server racks humming in the corner,
    # beanbags to sink into.
    ("jukebox", 13, 0, "down"),
    ("tv_stand", 15, 0, "right"),
    ("vending_machine", 18, 0, "down"),
    ("retro_console", 19, 0, "down"),
    ("neon_sign", 20, 0, "down"),
    ("server_rack", 22, 0, "down"),
    ("server_rack", 23, 0, "down"),
    ("beanbag", 15, 3, "right"),
    ("beanbag", 17, 3, "right"),
    ("beanbag", 19, 3, "right"),
    ("coffee_table", 17, 5, "down"),
    # The tables down the left side: pool and ping-pong, room to walk around
    # both.
    ("pool_table", 5, 9, "down"),
    ("ping_pong_table", 5, 14, "down"),
    # Along the left edge: the robot and the hologram keep watch, the cryo pod
    # stands near the front corner.
    ("robot", 0, 8, "right"),
    ("hologram", 0, 12, "down"),
    ("cryo_pod", 0, 17, "right"),
    # The LAN corner at the front: desks with gaming chairs behind them.
    *[piece for u in (12, 15, 18) for piece in (
        ("workstation", u, 16, "down"),
        ("gaming_chair", u - 1, 16, "down"),
    )],
    ("neon_totem", 23, 19, "down"),
    ("neon_totem", 0, 19, "down"),
]

PLAN = Plan(
    room="game_room",
    floor_w=24,
    floor_h=20,
    exit_uv=EXIT_UV,
    spawn_uv=SPAWN_UV,
    ground=ARCADE,
    zones=ZONES,
    furniture=FURNITURE,
    exit_tile="cst_arcade_door",
    exit_light="ff6fd8",
)


if __name__ == "__main__":
    build(PLAN)
