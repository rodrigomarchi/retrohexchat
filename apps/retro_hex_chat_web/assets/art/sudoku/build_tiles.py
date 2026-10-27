"""Hex Sudoku's pictures, built into one atlas the game reads.

    python3 apps/retro_hex_chat_web/assets/art/sudoku/build_tiles.py                 # the atlas and its description
    python3 apps/retro_hex_chat_web/assets/art/sudoku/build_tiles.py --preview X.png # also the atlas, 4x, to look at

Drawn here pixel by pixel in the look of Hex Mines (whose squares, lettering
and lit digits this borrows from `../mines/build_tiles.py`): the digits a
square shows in four inks (given, the player's, wrong, revealed by a hint),
the small digits of a note, the keypad's keys (and spent ones, every copy of
their digit placed), the tools (pencil, on and off; eraser; hint; undo), the
clock's lit digits and its colon, and the marks of the mistakes and the
hints counted. A square is 16x16, a key or a tool 24x24; all are drawn at
whole or half multiples, never smoothed.

The atlas is `priv/static/images/games/sudoku/tiles.png` and `tiles.json`
beside it: regions by name (`given_1`..`given_9`, `mine_*`, `wrong_*`,
`hint_*`, `note_1`..`note_9`, `key_*`, `spent_*`, `pencil`, `pencil_on`,
`eraser`, `bulb`, `undo`, `digit_0`..`digit_9`, `colon`, `cross`, `lamp`).
Each address carries the version of what it serves (`?vsn=`): the picture's
in `tiles.json`, the description's in `TILES_URL`
(`js/lib/games/hex_sudoku/protocol.js`), which this script rewrites.
"""

from __future__ import annotations

import argparse
import importlib.util
import io
import json
import os
import re
import sys

from PIL import Image

SOURCES = os.path.dirname(os.path.abspath(__file__))


def _mines():
    """Hex Mines' builder, by its path: it is a `build_tiles` too."""
    spec = importlib.util.spec_from_file_location("mines_tiles", os.path.join(SOURCES, "..", "mines", "build_tiles.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


mines = _mines()

OUTPUT = os.path.abspath(os.path.join(SOURCES, "..", "..", "..", "priv", "static", "images", "games", "sudoku"))
PROTOCOL_JS = os.path.abspath(os.path.join(SOURCES, "..", "..", "js", "lib", "games", "hex_sudoku", "protocol.js"))
TILES_URL_RE = re.compile(r'(TILES_URL = "/images/games/sudoku/tiles\.json\?vsn=)[0-9a-f]{12}(")')

TILE = mines.TILE
KEY = 24
CLEAR = mines.CLEAR
INK = mines.INK
SPENT = (168, 170, 178, 255)

# The four inks of a square's digit.
INKS = {
    "given": INK,
    "mine": (28, 72, 214, 255),
    "wrong": mines.RED,
    "hint": (156, 96, 0, 255),
}
NOTE_INK = (90, 92, 104, 255)

# The digits, 7 wide and 10 tall: the minesweeper's numbers, and a 9 of the same hand (its 6 turned round).
GLYPHS = {**mines.GLYPHS, 9: [row[::-1] for row in reversed(mines.GLYPHS[6])]}

# A note's digits, 3 wide and 5 tall, three to a row of a square.
NOTES = {
    1: [".#.", "##.", ".#.", ".#.", "###"],
    2: ["##.", "..#", ".#.", "#..", "###"],
    3: ["##.", "..#", ".#.", "..#", "##."],
    4: ["#.#", "#.#", "###", "..#", "..#"],
    5: ["###", "#..", "##.", "..#", "##."],
    6: [".##", "#..", "###", "#.#", "###"],
    7: ["###", "..#", ".#.", ".#.", ".#."],
    8: ["###", "#.#", "###", "#.#", "###"],
    9: ["###", "#.#", "###", "..#", "##."],
}

PENCIL = [
    "..........##",
    ".........#PP",
    "........#YPP",
    ".......#YYY.",
    "......#YYY#.",
    ".....#YYY#..",
    "....#YYY#...",
    "...#YYY#....",
    "..#YYY#.....",
    ".TTYY#......",
    ".TTT#.......",
    ".##.........",
]
ERASER = [
    "............",
    "......####..",
    ".....#PPPP#.",
    "....#PPPPPP#",
    "...#PPPPPP#.",
    "..#WWPPPP#..",
    ".#WWWWPP#...",
    "#WWWWWW#....",
    ".#WWWW#.....",
    "..####......",
    "............",
    "....########",
]
BULB = [
    "....####....",
    "..##YYYY##..",
    ".#YYWWYYYY#.",
    ".#YWYYYYYY#.",
    "#YYWYYYYYYY#",
    "#YYYYYYYYYY#",
    ".#YYYYYYYY#.",
    "..#YYYYYY#..",
    "...#YYYY#...",
    "...######...",
    "...#SSSS#...",
    "....####....",
]
UNDO = [
    "...#........",
    "..##........",
    ".#B#####....",
    "#BBBBBBB##..",
    ".#B######B#.",
    "..##.....#B#",
    "...#......#B",
    "..........#B",
    ".........#B#",
    "...######B#.",
    "...#BBBBB#..",
    "...######...",
]
CROSS = [
    "##....##",
    "###..###",
    ".######.",
    "..####..",
    "..####..",
    ".######.",
    "###..###",
    "##....##",
]
PALETTE = {
    "#": INK,
    "Y": mines.YELLOW,
    "P": (236, 120, 150, 255),
    "T": (232, 196, 150, 255),
    "W": mines.WHITE,
    "S": mines.SHADE,
    "B": (28, 72, 214, 255),
}


def paint(image, rows, x, y):
    """Rows of palette letters drawn at `x`, `y`; a dot is left clear."""
    for row, line in enumerate(rows):
        for col, char in enumerate(line):
            if char in PALETTE:
                image.putpixel((x + col, y + row), PALETTE[char])


def square(n, ink):
    """A square's digit, on nothing: the board's square is drawn beneath it."""
    tile = Image.new("RGBA", (TILE, TILE), CLEAR)
    mines.stamp(tile, GLYPHS[n], 5, 3, ink)
    return tile


def note(n):
    """A note's digit in its ninth of a square: 1 top left to 9 bottom right."""
    tile = Image.new("RGBA", (TILE, TILE), CLEAR)
    mines.stamp(tile, NOTES[n], 1 + ((n - 1) % 3) * 5 + 1, ((n - 1) // 3) * 5 + 1, NOTE_INK)
    return tile


def key(n, ink=INK):
    """A key of the keypad: the digit on a raised button."""
    button = mines.raised(KEY)
    mines.stamp(button, GLYPHS[n], 8, 7, ink)
    return button


def sunken(size=KEY):
    """A button held down: the raised one's edges the other way round, its face without gloss."""
    button = Image.new("RGBA", (size, size), mines.OPEN)
    for i in range(size):
        for d in (0, 1):
            button.putpixel((i, d), mines.DARK if d == 0 else mines.SHADE)
            button.putpixel((d, i), mines.DARK if d == 0 else mines.SHADE)
            button.putpixel((i, size - 1 - d), mines.LIGHT)
            button.putpixel((size - 1 - d, i), mines.LIGHT)
    return button


def tool(icon, held=False):
    """A tool's button: its picture on a raised button, or a held-down one (the pencil while it is on)."""
    button = sunken() if held else mines.raised(KEY)
    paint(button, icon, 6 + held, 6 + held)
    return button


def colon():
    cell = Image.new("RGBA", (5, 17), mines.LED_BACK)
    for y in (5, 6, 11, 12):
        for x in (1, 2):
            cell.putpixel((x + 1, y), mines.LED_ON)
    return cell


def mark(rows, palette_colour=None):
    """A small mark beside a count: the mistakes' cross, the hints' lamp."""
    size = max(len(rows), len(rows[0]))
    tile = Image.new("RGBA", (size, size), CLEAR)
    if palette_colour:
        mines.stamp(tile, rows, 0, 0, palette_colour)
    else:
        paint(tile, rows, 0, 0)
    return tile


def build_atlas():
    pieces = {
        **{f"{name}_{n}": square(n, ink) for name, ink in INKS.items() for n in range(1, 10)},
        **{f"note_{n}": note(n) for n in range(1, 10)},
        **{f"key_{n}": key(n) for n in range(1, 10)},
        **{f"spent_{n}": key(n, SPENT) for n in range(1, 10)},
        "pencil": tool(PENCIL),
        "pencil_on": tool(PENCIL, held=True),
        "eraser": tool(ERASER),
        "bulb": tool(BULB),
        "undo": tool(UNDO),
        **{f"digit_{d}": mines.digit(d) for d in "0123456789"},
        "colon": colon(),
        "cross": mark(CROSS, mines.RED),
        "lamp": mark(BULB),
    }
    width = 26 * 10
    x = y = 1
    row_height = 0
    regions = {}
    placed = []
    for name, picture in pieces.items():
        if x + picture.width + 1 > width:
            x, y = 1, y + row_height + 2
            row_height = 0
        regions[name] = {"x": x, "y": y, "w": picture.width, "h": picture.height}
        placed.append((picture, x, y))
        x += picture.width + 2
        row_height = max(row_height, picture.height)
    sheet = Image.new("RGBA", (width, y + row_height + 1), CLEAR)
    for picture, px, py in placed:
        sheet.alpha_composite(picture, (px, py))
    return sheet, {"image": "tiles.png", "tile": TILE, "key": KEY, "regions": regions}


version = mines.version


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", metavar="PNG")
    args = parser.parse_args(argv)
    sheet, description = build_atlas()
    os.makedirs(OUTPUT, exist_ok=True)
    out = io.BytesIO()
    sheet.save(out, format="PNG", optimize=True)
    picture = out.getvalue()
    with open(os.path.join(OUTPUT, "tiles.png"), "wb") as f:
        f.write(picture)
    description["image"] += f"?vsn={version(picture)}"
    text = (json.dumps(description, indent=1) + "\n").encode()
    with open(os.path.join(OUTPUT, "tiles.json"), "wb") as f:
        f.write(text)
    with open(PROTOCOL_JS, encoding="utf-8") as f:
        module = f.read()
    module, found = TILES_URL_RE.subn(rf"\g<1>{version(text)}\g<2>", module)
    if found != 1:
        print(f"TILES_URL not found once in {PROTOCOL_JS}", file=sys.stderr)
        return 1
    with open(PROTOCOL_JS, "w", encoding="utf-8") as f:
        f.write(module)
    if args.preview:
        back = Image.new("RGBA", sheet.size, (8, 120, 108, 255))
        back.alpha_composite(sheet)
        back.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(args.preview)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
