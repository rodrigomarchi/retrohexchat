"""Hex Blocks' pictures, built into one atlas the game reads.

    python3 apps/retro_hex_chat_web/assets/art/blocks/build_tiles.py                 # the atlas and its description
    python3 apps/retro_hex_chat_web/assets/art/blocks/build_tiles.py --preview X.png # also the atlas, 4x, to look at

The gem is PixelLab's (`gem.png`, a ruby cut with a round table, drawn over a
bevelled hexagon of ours): here it is cut to the well's own hexagon and
recoloured into the ten pieces' colours, each a ramp of six tones its
lightness picks from, with the outline drawn again on the hexagon's edge.
The hexagon is the cell of the well's honeycomb — flat-topped, 24x20, the
columns 18 apart and every odd one 10 lower — found as the pixels nearer its
centre than any neighbour's, so the gems tile without a gap or an overlap.
Beside them: the well's empty cell, the shadow of where a piece lands, the
flash of a row clearing, the mark of the empty box of the piece held, the
score's lit digits (Hex Mines') and the marks of the level and
the rows cleared.

The atlas is `priv/static/images/games/blocks/tiles.png` and `tiles.json`
beside it: regions by name (`gem_<colour>`, `empty`, `ghost`, `flash`,
`keep`, `digit_0`..`digit_9`, `colon`, `dot`, `level`, `lines`).
Each address carries the version of what it serves (`?vsn=`): the picture's
in `tiles.json`, the description's in `TILES_URL`
(`js/lib/games/hex_blocks/protocol.js`), which this script rewrites.
"""

from __future__ import annotations

import os
import re
import sys

from PIL import Image

SOURCES = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(SOURCES))
import atlas_kit  # noqa: E402

mines = atlas_kit.load(os.path.join(SOURCES, "..", "mines", "build_tiles.py"), "mines_tiles")
sudoku = atlas_kit.load(os.path.join(SOURCES, "..", "sudoku", "build_tiles.py"), "sudoku_tiles")

OUTPUT = os.path.abspath(os.path.join(SOURCES, "..", "..", "..", "priv", "static", "images", "games", "blocks"))
PROTOCOL_JS = os.path.abspath(os.path.join(SOURCES, "..", "..", "js", "lib", "games", "hex_blocks", "protocol.js"))
TILES_URL_RE = re.compile(r'(TILES_URL = "/images/games/blocks/tiles\.json\?vsn=)[0-9a-f]{12}(")')

# The hexagon of the well: its box, the step from a column to the next.
W, H, STEP = 24, 20, 18
CLEAR = atlas_kit.CLEAR

# Each piece's colour, darkest (the outline) to lightest, in the pieces' order (`pieces.js`).
RAMPS = {
    "red": ["#3c0612", "#7a0e22", "#b81c38", "#e03050", "#ff6a80", "#ffd0d8"],
    "orange": ["#3e1404", "#8a3008", "#d0580c", "#f5821c", "#ffb052", "#ffe6c0"],
    "yellow": ["#3a2a04", "#8a6206", "#d09c0c", "#f5c81c", "#ffe45a", "#fff8c8"],
    "lime": ["#1e3004", "#4a7008", "#7cb010", "#a8dc20", "#d0f45a", "#f0ffc8"],
    "green": ["#04301a", "#08703a", "#10a854", "#22d070", "#6af09c", "#d0ffe0"],
    "teal": ["#042e30", "#086a6c", "#0ea29e", "#20c8c0", "#62eadc", "#d0fff8"],
    "cyan": ["#04243e", "#08548a", "#1088cc", "#28b4f0", "#72d8ff", "#d8f4ff"],
    "blue": ["#0a0e44", "#18248e", "#2a44d0", "#4c6cf0", "#8aa0ff", "#dce4ff"],
    "violet": ["#22083e", "#4c1488", "#7a28c8", "#a04cf0", "#c890ff", "#f0e0ff"],
    "pink": ["#3e0630", "#880e6c", "#c81ca4", "#ee40cc", "#ff86e4", "#ffd8f6"],
}
WELL_EDGE = (40, 44, 66, 255)
WELL_FACE = (26, 29, 48, 255)


def rgba(code):
    return tuple(int(code[i : i + 2], 16) for i in (1, 3, 5)) + (255,)


def hexagon():
    """The well's cell: the pixels of the 24x20 box nearer its centre than any neighbour's, ties to the lower centre."""
    centres = [
        (col * STEP + W / 2, row * H + H / 2 + (H / 2 if col % 2 else 0)) for col in range(-2, 3) for row in range(-2, 3)
    ]
    own = (W / 2, H / 2)

    def nearest(x, y):
        return min(centres, key=lambda c: ((x - c[0]) ** 2 + (y - c[1]) ** 2, c[0], c[1]))

    return [[nearest(x + 0.5, y + 0.5) == own for x in range(W)] for y in range(H)]


MASK = hexagon()


def inside(x, y):
    return 0 <= x < W and 0 <= y < H and MASK[y][x]


def edge(x, y):
    return any(not inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))


def lightness(pixel):
    return 0.3 * pixel[0] + 0.59 * pixel[1] + 0.11 * pixel[2]


def source():
    """PixelLab's gem, its 24x20 hexagon cut from the 32x32 it was drawn on."""
    return Image.open(os.path.join(SOURCES, "gem.png")).convert("RGBA").crop((4, 6, 4 + W, 6 + H))


def gem(art, ramp):
    """The gem in one colour: the outline on the hexagon's edge, the rest the tone its lightness falls in."""
    seen = sorted(lightness(art.getpixel((x, y))) for y in range(H) for x in range(W) if inside(x, y))
    bounds = [seen[int(len(seen) * f)] for f in (0.15, 0.45, 0.8, 0.97)]
    tones = [rgba(code) for code in ramp]
    tile = Image.new("RGBA", (W, H), CLEAR)
    for y in range(H):
        for x in range(W):
            if not inside(x, y):
                continue
            pixel = art.getpixel((x, y))
            if edge(x, y) or pixel[3] == 0:
                tile.putpixel((x, y), tones[0])
            else:
                tile.putpixel((x, y), tones[1 + sum(1 for b in bounds if lightness(pixel) > b)])
    return tile


def cell(edge_colour, face_colour):
    """A plain hexagon: its edge in one colour, its face in another."""
    tile = Image.new("RGBA", (W, H), CLEAR)
    for y in range(H):
        for x in range(W):
            if inside(x, y):
                tile.putpixel((x, y), edge_colour if edge(x, y) else face_colour)
    return tile


HOLD = [
    "............",
    "...######...",
    "..#BBBBBB#..",
    ".#BBWWBBBB#.",
    "#BBWBBBBBBB#",
    "#BBBBBBBBBB#",
    "#BBBBBBBBBB#",
    ".#BBBBBBBB#.",
    "..#BBBBBB#..",
    "...######...",
    "............",
    "............",
]


def mark(rows, colour):
    tile = Image.new("RGBA", (len(rows[0]), len(rows)), CLEAR)
    mines.stamp(tile, rows, 0, 0, colour)
    return tile


LEVEL = [
    "...##...",
    "..####..",
    ".######.",
    "########",
    "...##...",
    "...##...",
    "...##...",
    "...##...",
]
LINES = [
    "##.##.##",
    "##.##.##",
    "........",
    "##.##.##",
    "##.##.##",
    "........",
    "##.##.##",
    "##.##.##",
]


def dot():
    led = Image.new("RGBA", (5, 17), mines.LED_BACK)
    for y in (14, 15):
        for x in (1, 2):
            led.putpixel((x + 1, y), mines.LED_ON)
    return led


def keep():
    """The keep mark — a gem put aside — 12x12 drawn twice its size, for the empty box of the piece held."""
    tile = Image.new("RGBA", (12, 12), CLEAR)
    sudoku.paint(tile, HOLD, 0, 0)
    return tile.resize((24, 24), Image.NEAREST)


def build_atlas():
    art = source()
    pieces = {
        **{f"gem_{colour}": gem(art, ramp) for colour, ramp in RAMPS.items()},
        "empty": cell(WELL_EDGE, WELL_FACE),
        "ghost": cell((220, 228, 255, 230), (220, 228, 255, 46)),
        "flash": cell((255, 255, 255, 255), (255, 250, 236, 255)),
        "keep": keep(),
        **{f"digit_{d}": mines.digit(d) for d in "0123456789"},
        "colon": sudoku.colon(),
        "dot": dot(),
        "level": mark(LEVEL, mines.YELLOW),
        "lines": mark(LINES, (120, 200, 255, 255)),
    }
    sheet, regions = atlas_kit.pack(pieces, 26 * 10)
    return sheet, {"image": "tiles.png", "cell": [W, H], "step": STEP, "regions": regions}


def main(argv):
    return atlas_kit.main(argv, __doc__, build_atlas, output=OUTPUT, protocol_js=PROTOCOL_JS, tiles_url_re=TILES_URL_RE)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
