#!/usr/bin/env python3
"""Author the ISOMETRIC "Construct" scene: the empty room a channel builds.

A white loading-program floor floating in the End of Time's own sky — the same
deep-blue sea, twinkling stars and vignette, under a dark slab like the
islands' — with one way out: a white-marble gate whose arch holds that sky.
Everything else on it is placed by the people inside. The scene therefore
carries no furniture of its own, only the **catalog** of what can be placed:
each kind's tile per facing, whether it can be sat on, the light it casts,
what pressing E on it does, and the sprites it wears in each of its states —
and the floor **materials** the floor can be painted with.

Reads the PixelLab art in ``virtual.space/scenes/construct/`` and emits the
packed ``construct.webp`` sheet and ``priv/maps/construct.json``.

The floor diamonds are drawn here, not generated. They reuse the End of Time
floor's own alpha, so each is exactly the diamond the projection tessellates:
the white floor with a faint grey seam that gives builders a grid to place
on, and one painted diamond per material. So are the variants a piece needs
that are the same art seen differently — a lamp switched off, a silver coin,
the four corners cut from the wall. Deterministic.

Floor tile ids are one character each ("w" white, "g" the void, a digit per
material), so a floor row is a string and the whole floor travels small.
"""
import json
import os

from PIL import Image, ImageDraw

from sheet_io import save_sheet

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(TOOLS, "..", ".."))
SRC = os.path.join(REPO, "virtual.space", "scenes", "construct")
EOT_FLOOR = os.path.join(REPO, "virtual.space", "scenes", "end_of_time", "iso", "floor_0.png")
SHEET_OUT = os.path.join(
    REPO, "apps", "retro_hex_chat_web", "priv", "static", "images", "space", "construct.webp"
)
MAP_OUT = os.path.join(REPO, "apps", "retro_hex_chat", "priv", "maps", "construct.json")

T = 32
# A 48×48 floor with a margin of sky on every side, so the stars and the sea
# show around the island however far the camera follows a builder to an edge.
MARGIN = 8
FLOOR = 48
W = H = FLOOR + 2 * MARGIN
SHEET_COLS = 40
Z_STEP = 16
MAX_ITEMS = 400

WHITE = "w"
VOID = "g"

FLOOR_FILL = (247, 248, 251, 255)
FLOOR_SEAM = (214, 219, 228, 255)

# The way back sits in the far corner of the floor, so the room opens out in
# front of whoever arrives.
X0 = Y0 = MARGIN
X1 = Y1 = MARGIN + FLOOR - 1
EXIT = (X0 + 2, Y0 + 2)
SPAWN = [
    {"x": EXIT[0] + 2, "y": EXIT[1] + 2, "dir": "down"},
    {"x": EXIT[0] + 3, "y": EXIT[1] + 1, "dir": "down"},
    {"x": EXIT[0] + 1, "y": EXIT[1] + 3, "dir": "right"},
]
# The End of Time's sky, value for value (`author_scene.py`).
SEA = {"top": "0c1e42", "bottom": "05060f", "band": "1a3d7a", "bands": 9, "amp": 5}
VIGNETTE = {"color": "04050c", "alpha": 0.78, "inner": 0.36}

# Placeable kinds: art file and how the kind behaves once placed. The art faces
# screen down-left, which is tile "down"; its mirror is tile "right". `group`
# is the palette tab; `use` is what E does (see `Construct.Layout.use/5`);
# `states` names the variant art a state wears, made by `VARIANTS`.
LAMP_LIGHTS = [
    {"radius": 2.4, "color": "ffd591", "blend": "add"},
    {"lift": 72, "radius": 1.0, "color": "ffe6a8", "blend": "add"},
]
# A line a piece shows floats over it white on a dark outline, readable over
# the white floor and the night sky alike.
SIGN_INK = {"color": "ffffff", "glow": "1b1f2a"}

KINDS = {
    "chair": {"file": "chair.png", "seat": True, "group": "furniture"},
    "armchair": {"file": "armchair.png", "seat": True, "group": "furniture"},
    "table": {"file": "table.png", "group": "furniture"},
    "long_table": {"file": "long_table.png", "group": "furniture", "size": [1, 2]},
    "coffee_table": {"file": "coffee_table.png", "group": "furniture"},
    "bookshelf": {"file": "bookshelf.png", "group": "furniture"},
    "lamp": {"file": "lamp.png", "lights": LAMP_LIGHTS, "group": "furniture",
             "use": "toggle_light", "states": {"off": "lamp_off"}},
    "tree": {"file": "tree.png", "group": "furniture"},
    "plant": {"file": "plant.png", "group": "furniture"},
    "wall": {"file": "wall.png", "group": "structure", "shadow": False},
    "corner": {"group": "structure", "dirs": ["down", "right", "up", "left"], "shadow": False,
               "tiles": {"down": "corner_up", "right": "corner_right",
                         "up": "corner_down", "left": "corner_left"}},
    "door": {"file": "door.png", "group": "structure", "use": "door", "mirror": True,
             "states": {"open": "door_open"}},
    "teleporter": {"file": "teleporter.png", "group": "fun", "use": "teleport",
                   "blocks": False,
                   "lights": [{"radius": 1.4, "color": "7fe8ff", "blend": "add"}]},
    "die": {"file": "die.png", "group": "fun", "use": "roll_die",
            "label": {"w": 1, "lift": 34, **SIGN_INK}},
    "coin": {"file": "coin.png", "group": "fun", "use": "flip_coin",
             "states": {"tails": "coin_tails"}},
    "sign": {"file": "sign.png", "group": "fun", "use": "sign",
             "label": {"w": 3, "lift": 66, **SIGN_INK}},
    "arcade": {"file": "arcade.png", "group": "fun", "use": "arcade"},
    "board": {"file": "board.png", "group": "fun", "use": "board", "only": ["channel"]},
    "screen": {"file": "screen.png", "group": "fun", "use": "screen"},
}

# The library: one art file per kind (`<kind>.png`), a palette tab, and what
# the kind brings beyond standing there. A piece longer than a tile names its
# `size` ([w, h] tiles, long side down the y axis, the way its art runs from
# the bottom-left up to the top-right); a sofa or a bench names its `seats`.
WARM = {"radius": 2.2, "color": "ffd591", "blend": "add"}


def _lit(color, radius=2.0, lift=None):
    light = {"radius": radius, "color": color, "blend": "add"}
    if lift is not None:
        light["lift"] = lift
    return [light]


LIBRARY = {
    "office": {
        "office_desk": {"size": [1, 2]},
        "meeting_table": {"size": [2, 3]},
        "office_chair": {"seat": True},
        "file_cabinet": {},
        "printer": {},
        "whiteboard": {"mirror": True},
        "water_cooler": {},
        "vending_machine": {"lights": _lit("bfe6ff", 1.4, 40)},
        "coffee_machine": {},
        "coat_rack": {},
        "cactus": {},
        "reception_desk": {"size": [1, 2]},
        "cubicle_partition": {"pane": True, "shadow": False},
        "trash_bin": {},
        "tall_plant": {},
        # Glass walls and a glass door to make rooms of the floor, and a desk
        # whose monitor turns its back on the viewer, so whoever sits at it
        # faces the room.
        "glass_wall": {"pane": True, "shadow": False},
        "glass_door": {"pane": True, "shadow": False, "use": "door",
                       "states": {"open": "glass_door_open"}},
        "workstation": {"size": [1, 2]},
    },
    "furniture": {
        "sofa": {"size": [1, 2], "seats": [[0, 0], [0, 1]]},
        "bed": {"size": [2, 2]},
        "fridge": {},
        "stove": {},
        "kitchen_counter": {"size": [1, 2]},
        "tv_stand": {"size": [1, 2], "lights": _lit("9fc4ff", 1.6, 30)},
        "dresser": {},
        "wardrobe": {},
        "piano": {"size": [1, 2], "mirror": True},
        "fireplace": {"size": [1, 2], "lights": _lit("ff9a4d", 3.0, 12)},
        "grandfather_clock": {},
        "table_lamp": {"lights": [WARM], "use": "toggle_light", "states": {"off": "table_lamp_off"}},
        "big_vase": {},
        "nightstand": {},
    },
    "garden": {
        "bush": {},
        "flower_bed": {},
        "boulder": {},
        "park_bench": {"size": [1, 2], "seats": [[0, 0], [0, 1]]},
        "fountain": {"size": [2, 2]},
        "fence": {"mirror": True},
        "street_lamp": {"lights": _lit("ffe6a8", 2.6, 140), "use": "toggle_light",
                        "states": {"off": "street_lamp_off"}},
        "pond": {"size": [2, 2]},
        "palm_tree": {},
        "pine_tree": {},
        "giant_mushroom": {},
        "mailbox": {},
    },
    "gamer": {
        "pool_table": {"size": [1, 2], "mirror": True},
        "ping_pong_table": {"size": [1, 2]},
        "beanbag": {"seat": True},
        "gaming_chair": {"seat": True},
        "neon_sign": {"lights": _lit("ff5fd2", 1.8, 40)},
        "server_rack": {"lights": _lit("6dffb0", 1.2, 40)},
        "robot": {},
        "retro_console": {"lights": _lit("9fc4ff", 1.4, 30)},
        "jukebox": {"lights": _lit("ffb35f", 1.8, 40)},
        "cryo_pod": {"lights": _lit("7fe8ff", 1.8, 50)},
        "hologram": {"lights": _lit("7fe8ff", 2.0, 40)},
        "racing_arcade": {"use": "arcade", "lights": _lit("ff6b6b", 1.4, 50)},
        "neon_totem": {"lights": _lit("b07bff", 2.0, 60)},
        "crt_tv": {"anim": True, "period_ms": 600, "lights": _lit("c9d6e8", 1.2, 20)},
    },
    "fair": {
        "big_top": {"size": [3, 3]},
        "fortune_tent": {"size": [3, 3]},
        "circus_tent": {"size": [2, 2]},
        "purple_tent": {"size": [2, 2]},
        "pennant_tent": {"anim": True, "period_ms": 900, "size": [2, 2]},
        "striped_tent": {"anim": True, "period_ms": 900, "size": [2, 2]},
        "weapon_stall": {"size": [2, 3]},
        "snack_stall": {"size": [2, 2], "mirror": True},
        "fair_gate": {"size": [1, 4]},
        "bunting": {"anim": True, "period_ms": 1100, "size": [1, 2], "mirror": True},
        "flag_pole": {},
        "paper_lantern": {"anim": True, "period_ms": 900, "lights": _lit("ffb35f", 1.6, 66)},
        "splash_fountain": {"anim": True, "period_ms": 900, "size": [2, 2]},
        "crates": {},
        "planter": {},
        "fair_bench": {"seat": True},
        "notice_board": {"mirror": True},
        "hedge": {},
        "potted_tree": {},
    },
    "fantasy": {
        "telepod": {"anim": True, "period_ms": 600, "size": [1, 3],
                    "lights": _lit("7fb8ff", 1.8, 40)},
        "bell_tower": {"anim": True, "period_ms": 1200, "size": [2, 2]},
        "nu": {"anim": True, "period_ms": 1400, "size": [2, 2]},
        "brazier": {"anim": True, "period_ms": 660, "lights": _lit("ff9a4d", 2.2, 30)},
        "magic_portal": {"anim": True, "period_ms": 900, "blocks": False,
                         "lights": _lit("8fe3ff", 1.6, 24)},
        "sparkle": {"anim": True, "period_ms": 1000, "blocks": False},
        "ancient_gate": {"size": [3, 3]},
        "stone_altar": {},
        "stone_totem": {},
        "stone_arch": {"size": [1, 2], "mirror": True},
        "glowing_arch": {"size": [1, 2], "mirror": True, "lights": _lit("7fd0ff", 2.0, 50)},
        "stone_column": {},
    },
}

# The Victorian pieces join the tabs they belong in.
LIBRARY["structure"] = {
    "golden_gate": {"mirror": True},
    "golden_railing": {"size": [1, 2]},
    "iron_fence": {"size": [1, 2], "mirror": True},
}
LIBRARY["garden"].update({
    "victorian_lamp": {"lights": _lit("ffe6a8", 2.6, 120), "use": "toggle_light",
                       "states": {"off": "victorian_lamp_off"}},
    "water_bucket": {},
    "signpost": {},
})
LIBRARY["furniture"]["wingback_chair"] = {"seat": True}

# An animated piece (`anim`) is a directory of frames, `anim/<kind>/<i>.png`,
# instead of one file. `mirror` flips art drawn running the other diagonal, so
# it runs from bottom-left to top-right like every other piece; `dirs` limits a
# piece to the facings it has.
for _group, _kinds in LIBRARY.items():
    for _kind, _spec in _kinds.items():
        _art_key = {"anim": _kind} if _spec.get("anim") else {"file": f"{_kind}.png"}
        KINDS[_kind] = {**_art_key, "group": _group, **{k: v for k, v in _spec.items() if k != "anim"}}

# The End of Time itself, piece by piece: its art is the End of Time's own
# sheet, drawn from there rather than copied. `foot` is where each sprite was
# authored to stand (its anchor in `author_scene.py`), `size` the ground it
# covers there, and the lights are the scene's own.
EOT = {
    "eot_tv": {"size": [2, 2], "foot": [1, 1],
               "lights": [{"radius": 2.6, "color": "7d9cc9", "blend": "add"},
                          {"lift": 46, "radius": 1.1, "color": "a9c4e8", "blend": "add"}]},
    "eot_morpheus": {"size": [2, 2], "foot": [1, 0]},
    "eot_neo": {"size": [2, 2], "foot": [0, 0]},
    "eot_delorean": {"size": [4, 2], "foot": [2, 1],
                     "lights": [{"lift": 40, "radius": 1.1, "color": "a8c8ff", "blend": "add"}]},
    "eot_fire": {"blocks": False,
                 "lights": [{"radius": 2.2, "color": "ff9a4d", "blend": "add"}]},
    "eot_balrog": {"size": [5, 2], "foot": [2, 1],
                   "layers": [{"eot": "eot_balrogfire", "foot": [2, 1]}],
                   "lights": [{"radius": 3.2, "color": "ff7a2d", "blend": "add"},
                              {"lift": 24, "radius": 1.6, "color": "ffb060", "blend": "add"}]},
    "eot_gandalf": {"lights": [{"lift": 75, "radius": 1.1, "color": "e8f4ff", "blend": "add"}]},
    "eot_goku": {"size": [2, 1], "foot": [0, 0],
                 "lights": [{"radius": 3.6, "color": "9fd4ff", "blend": "add"}]},
    "eot_dama": {"blocks": False,
                 "lights": [{"lift": 65, "radius": 2.2, "color": "d9f2ff", "blend": "add"}]},
}
for _kind, _spec in EOT.items():
    KINDS[_kind] = {"eot": _kind, "group": "eot", **_spec}

# Two more of the island's own pieces, among the fantasy ones: its lamppost,
# which switches off like any lamp (the unlit copy is packed here, made from the
# island's art), and its gate of falling code — a gate to nowhere in a room.
KINDS["eot_lamp"] = {"eot": "iso_lamp", "group": "fantasy", "use": "toggle_light",
                     "states": {"off": "eot_lamp_off"},
                     "lights": [{"radius": 4.2, "color": "ffd591", "blend": "add"},
                                {"lift": 152, "radius": 1.6, "color": "ffe6a8", "blend": "add"}]}
KINDS["eot_portal"] = {"eot": "eot_portal", "group": "fantasy",
                       "lights": [{"radius": 2.4, "color": "4dff9a", "blend": "add"},
                                  {"lift": 50, "radius": 1.2, "color": "9dffc8", "blend": "add"}]}
EOT_LAMP = os.path.join(REPO, "virtual.space", "scenes", "end_of_time", "lamp.png")

EOT_MAP = os.path.join(REPO, "apps", "retro_hex_chat", "priv", "maps", "end_of_time.json")
EOT_SHEET = "endoftime"

# Floor paint: id → (tile char, fill colours). A painted diamond keeps the
# white floor's seam so the grid still reads under it.
MATERIALS = {
    "wood": ("1", [(176, 122, 74), (160, 108, 62)]),
    "stone": ("2", [(160, 164, 172), (140, 145, 154)]),
    "grass": ("3", [(108, 170, 84), (92, 152, 72)]),
    "carpet_red": ("4", [(170, 52, 58), (156, 44, 52)]),
    "carpet_blue": ("5", [(60, 92, 170), (52, 80, 154)]),
    "checker": ("6", [(240, 240, 236), (52, 54, 62)]),
    "carpet_arcade": ("7", [(46, 30, 78), (236, 84, 196), (84, 222, 236)]),
}


def _crop(im):
    return im.crop(im.getbbox() or (0, 0, im.width, im.height))


def _cells(w_px, h_px):
    return (w_px + T - 1) // T, (h_px + T - 1) // T


def _place(sheet, vocab, name, im, col, row, native=False):
    """Pack `im` bottom-centred (props) or flush top-left (`native`, the floor
    diamond) in its cell block and record the vocab rect."""
    w, h = _cells(im.width, im.height)
    block = Image.new("RGBA", (w * T, h * T), (0, 0, 0, 0))
    if native:
        block.alpha_composite(im, (0, 0))
    else:
        block.alpha_composite(im, ((w * T - im.width) // 2, h * T - im.height))
    sheet.alpha_composite(block, (col * T, row * T))
    entry = {"col": col, "row": row, "w": w, "h": h}
    if native:
        entry["wpx"], entry["hpx"] = im.width, im.height
    vocab[name] = entry
    return col + w


def _floor_tile(fill=None, seam=FLOOR_SEAM):
    """A flat diamond on the End of Time floor's exact alpha: interior pixels
    filled by `fill(x, y)` (white by default), pixels on the diamond's edge
    drawn as a light seam."""
    shape = Image.open(EOT_FLOOR).convert("RGBA")
    w, h = shape.size
    src = shape.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dst = out.load()
    fill = fill or (lambda _x, _y: FLOOR_FILL)

    def solid(x, y):
        return 0 <= x < w and 0 <= y < h and src[x, y][3] >= 128

    for y in range(h):
        for x in range(w):
            if not solid(x, y):
                continue
            edge = not all(solid(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            dst[x, y] = seam if edge else fill(x, y)
    return out


def _material_tile(material, colours):
    """One painted diamond. Wood runs in planks along the iso axis, stone and
    grass are mottled, carpets are plain, the checker is a 2×2 board, and the
    arcade carpet is dark with sparse specks of pink and cyan neon."""
    a, b = colours[:2]
    w, h = Image.open(EOT_FLOOR).size

    def mottled(x, y):
        return b if ((x * 7 + y * 13) ^ (x * y)) % 5 == 0 else a

    def planks(x, y):
        return b if (x + 2 * y) % 12 in (0, 1) else a

    def checker(x, y):
        u, v = x / w + y / h, x / w - y / h + 1
        return a if (int(u * 2) + int(v * 2)) % 2 == 0 else b

    def specks(x, y):
        n = (x * 37 + y * 101 + (x * y) % 7) % 23
        return b if n == 0 else colours[2] if n == 11 else a

    fill = {"wood": planks, "stone": mottled, "grass": mottled, "checker": checker,
            "carpet_arcade": specks}.get(
        material, lambda _x, _y: a
    )
    return _floor_tile(lambda x, y: (*fill(x, y), 255),
                       seam=tuple(max(0, c - 28) for c in a) + (255,))


def _lamp_off(im):
    """The lamp switched off: its glowing shade (the bright warm pixels) dimmed
    to unlit fabric, the brass and the pole untouched."""
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a and r > 170 and g > 120 and r >= b:
                px[x, y] = (int(r * 0.55), int(g * 0.5), int(b * 0.5), a)
    return out


# A pane standing on one edge of its tile: the edge runs 24 px across and 10 px
# up, the floor's own slope, so the far end of one pane is exactly the near end
# of the next and a run of them reads as one wall. Each facing is a different
# edge of the tile — "down" its +x edge, "up" its -x edge, "right" its +y edge,
# "left" its -y edge — so whoever is inside a room walled with them has the
# whole of every inner tile, and its floor stops at the pane. The point each
# stands on is level with its edge's low end and centred across it.
PANE_W = 25
PANE_FEET = {"down": [0.75, 0.25], "up": [-0.25, 0.25],
             "right": [0.25, 0.75], "left": [0.25, -0.25]}
PANE_DIRS = ["down", "right", "up", "left"]

GLASS = (196, 232, 240, 100)
GLASS_GLINT = (238, 250, 255, 170)
ALU = (204, 209, 216, 255)
ALU_DARK = (146, 152, 163, 255)
HANDLE = (92, 98, 110, 255)
FABRIC = (126, 132, 145, 255)
FABRIC_DARK = (112, 118, 131, 255)


def _pane(height, paint):
    """A pane on the floor's slope, `height` px tall, coloured column by column
    by `paint(i, d, height)` (`d` rows above the base, `None` to leave
    clear). Column 0 is its near end, low on the left; column 24 its far end."""
    full = height + 11
    im = Image.new("RGBA", (PANE_W, full), (0, 0, 0, 0))
    px = im.load()
    for i in range(PANE_W):
        base = full - 1 - (i * 5) // 12
        for d in range(height + 1):
            colour = paint(i, d, height)
            if colour:
                px[i, base - d] = colour
    return im


def _glass_pane(i, d, height):
    if i == 0 or i == PANE_W - 1 or d <= 1 or d >= height - 1:
        return ALU_DARK if d == 0 or i == 0 else ALU
    # Two glints across the glass, the way light catches a pane.
    return GLASS_GLINT if (d + i * 2) % 41 in (0, 1) and 6 < d < height - 6 else GLASS


def _door_pane(open_):
    def paint(i, d, height):
        frame = i <= 1 or i >= PANE_W - 2 or d >= height - 2
        if frame:
            return ALU_DARK if i == 0 else ALU
        if open_:
            return ALU_DARK if d == 0 else None
        if d <= 1:
            return ALU
        if 17 <= i <= 18 and abs(d - height // 2) <= 9:
            return HANDLE
        return GLASS_GLINT if (d + i * 2) % 41 in (0, 1) and 6 < d < height - 6 else GLASS
    return paint


def _partition_pane(i, d, height):
    if d >= height - 1:
        return ALU
    if i == 0 or i == PANE_W - 1:
        return ALU_DARK
    if d <= 2:
        return ALU_DARK if d == 0 or i % 6 in (2, 3) else None
    return FABRIC_DARK if (d + i) % 4 == 0 else FABRIC


def _put_pane(shelf, vocab, name, im):
    """A pane per facing: drawn as it is for the edges along y ("down", "up"),
    mirrored for the ones along x ("right", "left")."""
    shelf.put(name, im, native=True)
    vocab[f"{name}_r"] = dict(vocab[name], flip_x=True)
    return {d: (name if d in ("down", "up") else f"{name}_r") for d in PANE_DIRS}


def _coin_tails(im):
    """The coin's other face: the same coin struck in silver, mirrored."""
    out = im.transpose(Image.FLIP_LEFT_RIGHT)
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a and r > 150 and g > 100 and b < 120:
                v = (r + g + b) // 3
                px[x, y] = (v, v + 4, min(255, v + 18), a)
    return out


def _wall_halves(wall):
    """The wall cut down its middle: the half rising from the near-left end to
    the centre, and the half running on from the centre to the far-right end."""
    mid = wall.width // 2
    left = Image.new("RGBA", wall.size, (0, 0, 0, 0))
    right = Image.new("RGBA", wall.size, (0, 0, 0, 0))
    left.alpha_composite(wall.crop((0, 0, mid, wall.height)), (0, 0))
    right.alpha_composite(wall.crop((mid, 0, wall.width, wall.height)), (mid, 0))
    return left, right


def _corners(wall):
    """The four corners a run of wall turns through, each two half walls meeting
    at the tile's centre: pointing away (up), toward the viewer (down), left and
    right. The far half draws first so the near one covers the joint."""
    left, right = _wall_halves(wall)
    flip = Image.FLIP_LEFT_RIGHT

    def join(far, near):
        out = far.copy()
        out.alpha_composite(near)
        return out

    return {
        "corner_up": join(left.transpose(flip), left),
        "corner_down": join(right, right.transpose(flip)),
        "corner_left": join(right.transpose(flip), left),
        "corner_right": join(right, left.transpose(flip)),
    }


class _Shelf:
    """Packs blocks left to right in rows of the sheet, a new row starting when
    one is full; each row is as tall as its tallest block."""

    def __init__(self, sheet, vocab):
        self.sheet, self.vocab = sheet, vocab
        self.col = self.row = self.row_h = 0

    def put(self, name, im, native=False):
        w, h = _cells(im.width, im.height)
        if self.col + w > SHEET_COLS:
            self.col, self.row, self.row_h = 0, self.row + self.row_h, 0
        if (self.row + h) * T > self.sheet.height:
            raise AssertionError(f"{name}: the sheet is full at row {self.row}")
        self.col = _place(self.sheet, self.vocab, name, im, self.col, self.row, native)
        self.row_h = max(self.row_h, h)

    def put_strip(self, name, frames, period_ms):
        """Pack an animation's frames side by side, one block each, as one tile
        the atlas steps through (`col + frame * w`)."""
        w, h = _cells(frames[0].width, frames[0].height)
        if w * len(frames) > SHEET_COLS:
            raise AssertionError(f"{name}: {len(frames)} frames of {w} cells overrun the sheet")
        if self.col + w * len(frames) > SHEET_COLS:
            self.col, self.row, self.row_h = 0, self.row + self.row_h, 0
        if (self.row + h) * T > self.sheet.height:
            raise AssertionError(f"{name}: the sheet is full at row {self.row}")
        col = self.col
        for i, frame in enumerate(frames):
            _place(self.sheet, self.vocab, f"{name}_{i}", frame, col + i * w, self.row)
            del self.vocab[f"{name}_{i}"]
        self.vocab[name] = {"col": col, "row": self.row, "w": w, "h": h,
                            "frames": len(frames), "period_ms": period_ms}
        self.col = col + w * len(frames)
        self.row_h = max(self.row_h, h)


def _art(name):
    return _crop(Image.open(os.path.join(SRC, name)).convert("RGBA"))


def _union_crop(frames):
    """Crop every frame to the box that holds all of them, so the piece stands
    still while what moves in it moves."""
    boxes = [f.getbbox() for f in frames if f.getbbox()]
    if not boxes:
        return frames
    box = (min(b[0] for b in boxes), min(b[1] for b in boxes),
           max(b[2] for b in boxes), max(b[3] for b in boxes))
    return [f.crop(box) for f in frames]


def _frames(kind):
    """An animated piece's frames, in order, from `anim/<kind>/`."""
    folder = os.path.join(SRC, "anim", kind)
    count = len([f for f in os.listdir(folder) if f.endswith(".png")])
    if count < 2:
        raise AssertionError(f"{kind}: an animation needs at least two frames")
    frames = [Image.open(os.path.join(folder, f"{i}.png")).convert("RGBA") for i in range(count)]
    for i, frame in enumerate(frames):
        # A frame with no transparent pixel is a failed generation (PixelLab
        # returns a solid block), not art: a piece standing in a square.
        if frame.getchannel("A").getextrema()[0] == 255:
            raise AssertionError(f"{kind}: frame {i} is opaque from edge to edge")
    return _union_crop(frames)


def build():
    floor = _floor_tile()
    fw, fh = floor.size
    sheet = Image.new("RGBA", (SHEET_COLS * T, 96 * T), (0, 0, 0, 0))
    vocab = {}
    shelf = _Shelf(sheet, vocab)

    # Row 0: the void ground, the star, the floors.
    shelf.put(VOID, Image.new("RGBA", (T, T), (0, 0, 0, 0)))
    star_col = shelf.col
    for i, r in enumerate((1, 2, 3, 2)):
        star = Image.new("RGBA", (T, T), (0, 0, 0, 0))
        c = T // 2
        ImageDraw.Draw(star).ellipse([c - r, c - r, c + r, c + r], fill=(232, 238, 255, 255))
        shelf.put(f"_star{i}", star)
    vocab["iso_star"] = {"col": star_col, "row": 0, "w": 1, "h": 1,
                         "frames": 4, "period_ms": 1100}
    for i in range(4):
        del vocab[f"_star{i}"]
    shelf.put(WHITE, floor, native=True)
    materials = []
    for material, (char, colours) in MATERIALS.items():
        shelf.put(char, _material_tile(material, colours), native=True)
        materials.append({"id": material, "tile": char})

    shelf.put("cst_exit", _art("exit.png"))
    # The Game Room's way out, a door in neon: drawn by its room, never placed
    # from the catalog, and mirrored like the catalog's door it was made from.
    shelf.put("cst_arcade_door", _art("arcade_door.png").transpose(Image.FLIP_LEFT_RIGHT))

    wall = _art("wall.png")
    variants = {"lamp_off": _lamp_off(_art("lamp.png")),
                "table_lamp_off": _lamp_off(_art("table_lamp.png")),
                "street_lamp_off": _lamp_off(_art("street_lamp.png")),
                "victorian_lamp_off": _lamp_off(_art("victorian_lamp.png")),
                "eot_lamp_off": _lamp_off(_crop(Image.open(EOT_LAMP).convert("RGBA"))),
                "coin_tails": _coin_tails(_art("coin.png")),
                **_corners(wall)}
    door_open = os.path.join(SRC, "door_open.png")
    variants["door_open"] = _art("door_open.png") if os.path.exists(door_open) else _art("door.png")

    catalog = {}
    eot = json.load(open(EOT_MAP))

    def eot_tiles(name):
        """The End of Time's own tile, from its sheet, and its mirror."""
        if name not in vocab:
            vocab[name] = dict(eot["vocab"][name], ts=EOT_SHEET)
            vocab[f"{name}_r"] = dict(vocab[name], flip_x=True)
        return {"down": name, "right": f"{name}_r"}

    # The panes are drawn, not generated: only drawn panes meet exactly from one
    # tile to the next.
    panes = {
        # Glass and its door are one height, so a run's top is one line.
        "glass_wall": _put_pane(shelf, vocab, "cst_glass_wall", _pane(96, _glass_pane)),
        "glass_door": _put_pane(shelf, vocab, "cst_glass_door", _pane(96, _door_pane(False))),
        "glass_door_open": _put_pane(shelf, vocab, "cst_glass_door_open", _pane(96, _door_pane(True))),
        "cubicle_partition": _put_pane(shelf, vocab, "cst_cubicle_partition", _pane(42, _partition_pane)),
    }

    for kind, spec in KINDS.items():
        if spec.get("pane"):
            tiles = panes[kind]
        elif "eot" in spec:
            tiles = eot_tiles(spec["eot"])
        elif "anim" in spec or "file" in spec:
            name = f"cst_{kind}"
            if "anim" in spec:
                frames = _frames(spec["anim"])
                if spec.get("mirror"):
                    frames = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in frames]
                shelf.put_strip(name, frames, spec["period_ms"])
            else:
                art = _art(spec["file"])
                # A state drawn as art of its own (the door open) is cut to the
                # box that holds the piece in every state, so the piece stays
                # put while it changes, the way an animation's frames do.
                drawn = [v for v in spec.get("states", {}).values()
                         if os.path.exists(os.path.join(SRC, f"{v}.png"))]
                if drawn:
                    together = _union_crop([Image.open(os.path.join(SRC, f)).convert("RGBA")
                                            for f in [spec["file"]] + [f"{v}.png" for v in drawn]])
                    art = together[0]
                    variants.update(zip(drawn, together[1:]))
                shelf.put(name, art.transpose(Image.FLIP_LEFT_RIGHT) if spec.get("mirror") else art)
            # A piece that keeps one facing (lettering that would read
            # backwards mirrored) has only the tiles of the facings it has.
            tiles = {d: t for d, t in {"down": name, "right": f"{name}_r"}.items()
                     if d in spec.get("dirs", ("down", "right"))}
            if "right" in tiles:
                vocab[f"{name}_r"] = dict(vocab[name], flip_x=True)
        else:
            tiles = {}
            for dir_, variant in spec["tiles"].items():
                name = f"cst_{variant}"
                if name not in vocab:
                    shelf.put(name, variants[variant])
                tiles[dir_] = name
        entry = {"tiles": tiles, "group": spec["group"]}
        if spec.get("pane"):
            entry["dirs"], entry["feet"] = PANE_DIRS, PANE_FEET
            entry["states"] = {state: panes[variant] for state, variant in spec.get("states", {}).items()}
        for state, variant in ({} if spec.get("pane") else spec.get("states", {})).items():
            name = f"cst_{variant}"
            # A state is the same piece seen otherwise, so it runs the way the
            # piece does: mirrored with it.
            art = variants[variant]
            shelf.put(name, art.transpose(Image.FLIP_LEFT_RIGHT) if spec.get("mirror") else art)
            vocab[f"{name}_r"] = dict(vocab[name], flip_x=True)
            entry.setdefault("states", {})[state] = {"down": name, "right": f"{name}_r"}
        for key in ("seat", "lights", "use", "only", "dirs", "label", "size", "foot", "seats"):
            if key in spec:
                entry[key] = spec[key]
        if spec.get("shadow") is False:
            entry["shadow"] = False
        if spec.get("blocks") is False:
            entry["blocks"] = False
        if spec.get("layers"):
            entry["layers"] = [{"tiles": eot_tiles(layer["eot"]), "foot": layer["foot"]}
                               for layer in spec["layers"]]
        catalog[kind] = entry

    rows_used = shelf.row + shelf.row_h
    sheet = sheet.crop((0, 0, SHEET_COLS * T, rows_used * T))

    def on_floor(x, y):
        return X0 <= x <= X1 and Y0 <= y <= Y1

    def _h(x, y):
        return (x * 928371 + y * 1237) & 0xFFFF

    stars = [{"x": x, "y": y, "tile": "iso_star", "sort": "flat"}
             for y in range(H) for x in range(W)
             if not on_floor(x, y) and _h(x, y) % 13 == 0]

    # The sky is the void around the floor: blocked, as merged row runs.
    void = []
    for y in range(H):
        x = 0
        while x < W:
            if on_floor(x, y):
                x += 1
                continue
            start = x
            while x < W and not on_floor(x, y):
                x += 1
            void.append({"x": start, "y": y, "w": x - start, "h": 1, "kind": "void"})

    reserved = sorted(
        {(EXIT[0] + dx, EXIT[1] + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
        | {(s["x"], s["y"]) for s in SPAWN}
    )
    reserved = [[x, y] for x, y in reserved if 0 <= x < W and 0 <= y < H]

    layout = {
        "width": W,
        "height": H,
        "tile_size": T,
        "ground": VOID,
        "columns": SHEET_COLS,
        "projection": "isometric",
        "iso": {"tile_w": fw, "tile_h": fh, "z_step": Z_STEP, "headroom": 8},
        "sea": SEA,
        "vignette": VIGNETTE,
        "slabs": [{"thickness": 10, "taper": 0.78, "hull": [X0, X1, Y0, Y1]}],
        "vocab": vocab,
        "floor": ["".join(WHITE if on_floor(x, y) else VOID for x in range(W)) for y in range(H)],
        "decor": stars + [{"x": EXIT[0], "y": EXIT[1], "tile": "cst_exit", "sort": "stand"}],
        "collision": void + [{"x": EXIT[0], "y": EXIT[1], "w": 1, "h": 1, "kind": "prop"}],
        "spawn": SPAWN,
        "lights": [
            {"x": EXIT[0], "y": EXIT[1], "radius": 2.2, "color": "8fb6ff", "blend": "add"},
            {"x": EXIT[0], "y": EXIT[1], "lift": 50, "radius": 1.2, "color": "c9dcff", "blend": "add"},
        ],
        "zones": [{"id": "construct", "kind": "platform", "x": X0, "y": Y0, "w": FLOOR, "h": FLOOR}],
        "interactables": [
            {
                "id": "construct_exit",
                "kind": "portal",
                "x": EXIT[0],
                "y": EXIT[1],
                "title": "End of Time",
                "modal": {"kind": "confirm", "action": "exit_construct"},
            }
        ],
        "reserved": reserved,
        "tilesets": [{"id": "construct", "columns": SHEET_COLS},
                     {"id": EOT_SHEET, "columns": eot["columns"]}],
        "catalog": catalog,
        "materials": materials,
        "max_items": MAX_ITEMS,
    }

    for s in SPAWN:
        if (s["x"], s["y"]) == EXIT:
            raise AssertionError(f"spawn {s} stands on the exit")

    save_sheet(sheet, SHEET_OUT)
    with open(MAP_OUT, "w") as out:
        json.dump(layout, out)
    print(f"OK construct: sheet={sheet.size} diamond={fw}x{fh} kinds={sorted(catalog)} "
          f"materials={len(materials)} reserved={len(reserved)}")


if __name__ == "__main__":
    build()
