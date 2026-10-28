"""Hex Mines' pictures, built into one atlas the game reads.

    python3 apps/retro_hex_chat_web/assets/art/mines/build_tiles.py                 # the atlas and its description
    python3 apps/retro_hex_chat_web/assets/art/mines/build_tiles.py --preview X.png # also the atlas, 4x, to look at

Everything is drawn here, pixel by pixel, in the look of the platform's deck
("Win98 de luxo"): raised squares with a soft gloss, numbers in the classic
colours in a lettering of our own, a flag, a mine, the counter's and the
clock's lit digits, the four faces and the dig/flag switch. A square is 16x16
and is drawn at whole or half multiples, never smoothed.

The atlas is `priv/static/images/games/mines/tiles.png` and `tiles.json` beside
it: regions by name (`closed`, `pressed`, `open`, `n1`..`n8`, `flag`, `mine`,
`boom`, `wrong`, `face_*`, `digit_0`..`digit_9`, `digit_minus`, `dig`, `mark`).
Each address carries the version of what it serves (`?vsn=`): the picture's in
`tiles.json`, the description's in `TILES_URL` (`js/lib/games/hex_mines/protocol.js`),
which this script rewrites.
"""

from __future__ import annotations

import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import atlas_kit  # noqa: E402

SOURCES = os.path.dirname(os.path.abspath(__file__))
OUTPUT = os.path.abspath(os.path.join(SOURCES, "..", "..", "..", "priv", "static", "images", "games", "mines"))
PROTOCOL_JS = os.path.abspath(os.path.join(SOURCES, "..", "..", "js", "lib", "games", "hex_mines", "protocol.js"))
TILES_URL_RE = re.compile(r'(TILES_URL = "/images/games/mines/tiles\.json\?vsn=)[0-9a-f]{12}(")')

TILE = 16
CLEAR = (0, 0, 0, 0)
FACE = (204, 206, 212, 255)
GLOSS = (222, 224, 230, 255)
LIGHT = (254, 254, 254, 255)
SHADE = (128, 130, 138, 255)
DARK = (72, 74, 82, 255)
OPEN = (189, 191, 197, 255)
GRID = (150, 152, 160, 255)
INK = (16, 16, 20, 255)
RED = (205, 28, 30, 255)
DEEP_RED = (150, 12, 14, 255)
WHITE = (255, 255, 255, 255)
YELLOW = (255, 210, 40, 255)
AMBER = (200, 140, 10, 255)
LED_ON = (255, 40, 30, 255)
LED_OFF = (22, 5, 5, 255)
LED_BACK = (12, 6, 6, 255)

# The classic colours of the numbers, in the deck's tones.
NUMBER_INK = {
    1: (28, 72, 214, 255),
    2: (14, 128, 44, 255),
    3: (205, 28, 30, 255),
    4: (14, 35, 105, 255),
    5: (136, 18, 18, 255),
    6: (10, 128, 128, 255),
    7: (16, 16, 20, 255),
    8: (110, 112, 120, 255),
}

# The numbers, 7 wide and 10 tall, heavy strokes so a phone reads them.
GLYPHS = {
    1: ["...##..", "..###..", ".####..", "...##..", "...##..", "...##..", "...##..", "...##..", ".######", ".######"],
    2: [".#####.", "##...##", ".....##", ".....##", "....##.", "...##..", "..##...", ".##....", "#######", "#######"],
    3: ["######.", ".....##", ".....##", "..####.", "..####.", ".....##", ".....##", ".....##", "######.", "#####.."],
    4: ["....##.", "...###.", "..####.", ".##.##.", "##..##.", "#######", "#######", "....##.", "....##.", "....##."],
    5: ["#######", "##.....", "##.....", "######.", ".....##", ".....##", ".....##", "##...##", "#######", ".#####."],
    6: [".#####.", "##...##", "##.....", "######.", "##...##", "##...##", "##...##", "##...##", "#######", ".#####."],
    7: ["#######", "#######", ".....##", "....##.", "...##..", "...##..", "..##...", "..##...", "..##...", "..##..."],
    8: [".#####.", "##...##", "##...##", ".#####.", "##...##", "##...##", "##...##", "##...##", "#######", ".#####."],
}

FLAG = [
    "................",
    "................",
    "......##........",
    "....####........",
    "..######........",
    ".#######........",
    "..######........",
    "....####........",
    "......##........",
    ".......#........",
    ".......#........",
    ".......#........",
    ".....#####......",
    "...#########....",
    "................",
    "................",
]

MINE = [
    "................",
    ".......#........",
    ".......#........",
    "...#.#####.#....",
    "....#######.....",
    "...#########....",
    "...#..######....",
    ".######.######..",
    "...#..######....",
    "...#########....",
    "....#######.....",
    "...#.#####.#....",
    ".......#........",
    ".......#........",
    "................",
    "................",
]

# A lit digit: seven segments on a 9x15 cell (a, b, c, d, e, f, g).
SEGMENTS = {
    "a": [(x, 0) for x in range(2, 7)] + [(x, 1) for x in range(3, 6)],
    "b": [(8, y) for y in range(2, 7)] + [(7, y) for y in range(3, 6)],
    "c": [(8, y) for y in range(8, 13)] + [(7, y) for y in range(9, 12)],
    "d": [(x, 14) for x in range(2, 7)] + [(x, 13) for x in range(3, 6)],
    "e": [(0, y) for y in range(8, 13)] + [(1, y) for y in range(9, 12)],
    "f": [(0, y) for y in range(2, 7)] + [(1, y) for y in range(3, 6)],
    "g": [(x, 7) for x in range(2, 7)] + [(x, 6) for x in range(3, 6)] + [(x, 8) for x in range(3, 6)],
}
LIT = {
    "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
    "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg", "minus": "g",
}

FACES = {
    "smile": ["......", "......", ".#..#.", ".#..#.", "......", "#....#", ".####."],
    "wow": ["......", "......", ".#..#.", ".#..#.", "......", "..##..", "..##.."],
    "dead": ["......", "#.#..#.#", ".#....#.", "#.#..#.#", "......", ".####.", "#....#"],
    "cool": ["......", "........", "########", ".###.###", "........", "#......#", ".######."],
}

SHOVEL = [
    "........##......",
    "........##......",
    "........##......",
    "........##......",
    "........##......",
    "........##......",
    ".....########...",
    ".....########...",
    ".....########...",
    "......######....",
    "......######....",
    ".......####.....",
    "........##......",
    "................",
]


def stamp(image, rows, x, y, colour):
    for row, line in enumerate(rows):
        for col, char in enumerate(line):
            if char == "#":
                image.putpixel((x + col, y + row), colour)


def raised(size=TILE):
    """A raised square: its face with a gloss, light edges top-left, shaded bottom-right."""
    tile = Image.new("RGBA", (size, size), FACE)
    for y in range(size):
        for x in range(size):
            if x + y < size * 0.6:
                tile.putpixel((x, y), GLOSS)
    for i in range(size):
        for d in (0, 1):
            tile.putpixel((i, d), LIGHT)
            tile.putpixel((d, i), LIGHT)
            tile.putpixel((i, size - 1 - d), SHADE if d else DARK)
            tile.putpixel((size - 1 - d, i), SHADE if d else DARK)
    return tile


def opened(fill=OPEN):
    """An open square: flat, a grid line top and left."""
    tile = Image.new("RGBA", (TILE, TILE), fill)
    for i in range(TILE):
        tile.putpixel((i, 0), GRID)
        tile.putpixel((0, i), GRID)
    return tile


def number(n):
    tile = opened()
    stamp(tile, GLYPHS[n], 5, 3, NUMBER_INK[n])
    return tile


def flag():
    tile = raised()
    rows = FLAG
    for row, line in enumerate(rows):
        for col, char in enumerate(line):
            if char != "#":
                continue
            colour = RED if col < 7 and row < 9 else INK
            if col < 7 and row < 9 and (col + row) % 5 == 0:
                colour = DEEP_RED
            tile.putpixel((col + 3, row), colour)
    return tile


def mine(fill=OPEN):
    tile = opened(fill)
    stamp(tile, MINE, 0, 0, INK)
    tile.putpixel((6, 5), WHITE)
    tile.putpixel((5, 6), WHITE)
    tile.putpixel((6, 6), WHITE)
    return tile


def wrong():
    tile = mine()
    for i in range(2, 14):
        tile.putpixel((i, i), RED)
        tile.putpixel((i + 1, i), RED)
        tile.putpixel((15 - i, i), RED)
        tile.putpixel((14 - i, i), RED)
    return tile


def digit(name):
    cell = Image.new("RGBA", (11, 17), LED_BACK)
    for segment, pixels in SEGMENTS.items():
        colour = LED_ON if segment in LIT[name] else LED_OFF
        for x, y in pixels:
            cell.putpixel((x + 1, y + 1), colour)
    return cell


def face(mood):
    """A round yellow face, 24x24, on a raised button."""
    button = raised(24)
    cx, cy, r = 11.5, 11.5, 8.5
    for y in range(24):
        for x in range(24):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= r:
                button.putpixel((x, y), YELLOW if d < r - 1 else AMBER)
    if mood == "cool":
        stamp(button, FACES[mood], 8, 6, INK)
    else:
        rows = FACES[mood]
        stamp(button, rows, 9 if len(rows[1]) == 6 else 8, 6, INK)
    return button


def switch(icon):
    """The dig/flag switch's face: the shovel or the flag on a raised button, 24x24."""
    button = raised(24)
    if icon == "dig":
        for row, line in enumerate(SHOVEL):
            for col, char in enumerate(line):
                if char == "#":
                    button.putpixel((col + 4, row + 5), (90, 60, 30, 255) if row < 6 else SHADE)
    else:
        small = flag()
        button.alpha_composite(small.crop((0, 2, 14, 15)), (6, 6))
    return button


def build_atlas():
    pieces = {
        "closed": raised(),
        "pressed": opened(GLOSS),
        "open": opened(),
        **{f"n{n}": number(n) for n in range(1, 9)},
        "flag": flag(),
        "mine": mine(),
        "boom": mine(RED),
        "wrong": wrong(),
        **{f"face_{m}": face(m) for m in FACES},
        **{f"digit_{d}": digit(d) for d in LIT},
        "dig": switch("dig"),
        "mark": switch("mark"),
    }
    sheet, regions = atlas_kit.pack(pieces, 26 * 8)
    return sheet, {"image": "tiles.png", "tile": TILE, "regions": regions}


version = atlas_kit.version


def main(argv):
    return atlas_kit.main(argv, __doc__, build_atlas, output=OUTPUT, protocol_js=PROTOCOL_JS, tiles_url_re=TILES_URL_RE)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
