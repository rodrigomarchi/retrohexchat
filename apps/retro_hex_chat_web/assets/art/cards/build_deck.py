"""The platform's deck of playing cards, built into one atlas every card game reads.

    python3 apps/retro_hex_chat_web/assets/art/cards/build_deck.py            # the atlas and its description
    python3 apps/retro_hex_chat_web/assets/art/cards/build_deck.py --preview X.png  # also the atlas, 4x, to look at

A card is 64x88 pixels, drawn at that size and never scaled: the games draw it
pixel for pixel (or by whole multiples). The number cards and the aces are built
here, from the pips and the rank glyphs below, so all 40 follow one layout; the
court cards, the backs and the jokers are pictures made in PixelLab, kept beside
this script, and framed here. Nothing on a card
names a game: Hex Solitaire, Spider, Hearts or Truco all deal from this deck.

Card ids follow `js/lib/games/core/cards.js`: suit by suit (spades, hearts,
diamonds, clubs), each from the ace to the king, so card `id` is suit `id // 13`
and rank `id % 13 + 1`.

The atlas is `priv/static/images/games/cards/cards.png` and `cards.json` beside
it: `card` (the size), `faces` (52 regions by card id), `jokers` (2: red, black),
`backs` (4), `shadows` (resting and lifted). A card turning over is drawn by the
game narrowing the card it shows, unsmoothed, so it needs no pictures of its own.

Sources, beside this script:
  court_king.png, court_queen.png, court_jack.png  the upper half of each court figure, 40x40
  ace_spades.png                                     the ornate spade of the ace of spades
  back_1.png .. back_4.png                           the backs, 64x88
  joker.png                                          the joker's figure
"""

from __future__ import annotations

import argparse
import json
import os
import sys

from PIL import Image

SOURCES = os.path.dirname(os.path.abspath(__file__))
OUTPUT = os.path.abspath(os.path.join(SOURCES, "..", "..", "..", "priv", "static", "images", "games", "cards"))

WIDTH, HEIGHT = 64, 88
SPADES, HEARTS, DIAMONDS, CLUBS = range(4)

# The colours of the deck, taken from the look the deck was chosen in.
FACE = (254, 254, 254, 255)
GLOSS = (228, 229, 228, 255)
EDGE = (130, 130, 132, 255)
RED = (197, 19, 22, 255)
BLACK = (9, 1, 1, 255)
CLEAR = (0, 0, 0, 0)
SHADOW = (0, 0, 0, 90)

# Pips, as rows of characters: "#" is the suit's colour, "." is the card.
PIPS = {
    HEARTS: [
        "..###.###..",
        ".#########.",
        "###########",
        "###########",
        "###########",
        ".#########.",
        "..#######..",
        "...#####...",
        "....###....",
        ".....#.....",
    ],
    DIAMONDS: [
        "....#....",
        "...###...",
        "..#####..",
        "..#####..",
        ".#######.",
        "#########",
        "#########",
        ".#######.",
        "..#####..",
        "..#####..",
        "...###...",
        "....#....",
    ],
    SPADES: [
        ".....#.....",
        "....###....",
        "...#####...",
        "..#######..",
        ".#########.",
        "###########",
        "###########",
        "###########",
        ".####.####.",
        ".....#.....",
        "....###....",
    ],
    CLUBS: [
        "....###....",
        "...#####...",
        "...#####...",
        "....###....",
        ".##.###.##.",
        "###########",
        "###########",
        ".##..#..##.",
        ".....#.....",
        "....###....",
    ],
}

# The suit beside the rank in a corner.
SMALL_PIPS = {
    HEARTS: [".#.#.", "#####", "#####", ".###.", "..#.."],
    DIAMONDS: ["..#..", ".###.", "#####", ".###.", "..#.."],
    SPADES: ["..#..", ".###.", "#####", "#####", "..#..", ".###."],
    CLUBS: [".###.", ".###.", "#####", "#####", "..#..", ".###."],
}

# Rank glyphs, 5 wide and 7 tall, with small serifs like the chosen look's.
GLYPHS = {
    1: ["..#..", ".#.#.", ".#.#.", "#...#", "#####", "#...#", "##.##"],
    2: [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    3: ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
    4: ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "..###"],
    5: ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    6: [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
    7: ["#####", "#...#", "...#.", "..#..", "..#..", ".#...", ".#..."],
    8: [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    9: [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
    10: ["#..##.", "#.#..#", "#.#..#", "#.#..#", "#.#..#", "#.#..#", "#..##."],
    11: ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
    12: [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    13: ["##.##", ".#.#.", ".##..", ".#...", ".##..", ".#.#.", "##.##"],
}

# Where the pips of each number card stand: their centres, the top half
# upright and the bottom half turned round, as on a real card.
_L, _C, _R = 21, 32, 43
_ROWS4 = (18, 36, 53, 71)
PIP_LAYOUT = {
    2: [(_C, 18), (_C, 71)],
    3: [(_C, 18), (_C, 44), (_C, 71)],
    4: [(_L, 18), (_R, 18), (_L, 71), (_R, 71)],
    5: [(_L, 18), (_R, 18), (_C, 44), (_L, 71), (_R, 71)],
    6: [(_L, 18), (_R, 18), (_L, 44), (_R, 44), (_L, 71), (_R, 71)],
    7: [(_L, 18), (_R, 18), (_C, 31), (_L, 44), (_R, 44), (_L, 71), (_R, 71)],
    8: [(_L, 18), (_R, 18), (_C, 31), (_L, 44), (_R, 44), (_C, 58), (_L, 71), (_R, 71)],
    9: [(x, y) for y in _ROWS4 for x in (_L, _R)] + [(_C, 27)],
    10: [(x, y) for y in _ROWS4 for x in (_L, _R)] + [(_C, 27), (_C, 62)],
}

RED_SUITS = (HEARTS, DIAMONDS)

NAVY = (14, 35, 105, 255)
COURT_FILES = {11: "court_jack.png", 12: "court_queen.png", 13: "court_king.png"}
# The court figure's frame: inside the corner indices, the figure's two halves within it.
FRAME = (11, 4, 53, 84)  # left, top, right (exclusive), bottom (exclusive)
HALF = 39  # each half of the figure, top and bottom
CELL = 66  # an atlas column: a card (or the lifted shadow, a pixel wider each way) and its margin

# The joker's mark in its corners, where a number card has its rank.
STAR = ["..#..", "..#..", "#####", ".###.", ".#.#.", "#...#"]


def colour_of(suit: int) -> tuple:
    return RED if suit in RED_SUITS else BLACK


def stamp(image: Image.Image, rows: list[str], x: int, y: int, colour: tuple, turned: bool = False) -> None:
    """Draw a character sprite with its top-left at (x, y), turned round when asked."""
    height, width = len(rows), len(rows[0])
    for row, line in enumerate(rows):
        for col, char in enumerate(line):
            if char != "#":
                continue
            px, py = (width - 1 - col, height - 1 - row) if turned else (col, row)
            image.putpixel((x + px, y + py), colour)


def stamp_centred(image: Image.Image, rows: list[str], cx: int, cy: int, colour: tuple, turned: bool) -> None:
    stamp(image, rows, cx - len(rows[0]) // 2, cy - len(rows) // 2, colour, turned)


def blank() -> Image.Image:
    """An empty card face: white with the chosen look's diagonal gloss, a grey edge, rounded corners."""
    card = Image.new("RGBA", (WIDTH, HEIGHT), FACE)
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if x / WIDTH + y / HEIGHT > 1.05:
                card.putpixel((x, y), GLOSS)
    for x in range(WIDTH):
        card.putpixel((x, 0), EDGE)
        card.putpixel((x, HEIGHT - 1), EDGE)
    for y in range(HEIGHT):
        card.putpixel((0, y), EDGE)
        card.putpixel((WIDTH - 1, y), EDGE)
    round_corners(card)
    return card


def round_corners(card: Image.Image) -> None:
    """Cut the four corners round: two pixels gone, one pixel of edge on the curve."""
    w, h = card.size
    for cx, cy, dx, dy in ((0, 0, 1, 1), (w - 1, 0, -1, 1), (0, h - 1, 1, -1), (w - 1, h - 1, -1, -1)):
        for x, y in ((0, 0), (1, 0), (0, 1)):
            card.putpixel((cx + dx * x, cy + dy * y), CLEAR)
        card.putpixel((cx + dx, cy + dy), EDGE)


def corner_index(card: Image.Image, rank: int, suit: int) -> None:
    """The rank and the suit in the top-left corner, and turned round in the bottom-right."""
    colour = colour_of(suit)
    glyph, pip = GLYPHS[rank], SMALL_PIPS[suit]
    gx = 3 if len(glyph[0]) == 5 else 2
    stamp(card, glyph, gx, 3, colour)
    stamp(card, pip, 3, 12, colour)
    stamp(card, glyph, WIDTH - gx - len(glyph[0]), HEIGHT - 3 - len(glyph), colour, turned=True)
    stamp(card, pip, WIDTH - 3 - len(pip[0]), HEIGHT - 12 - len(pip), colour, turned=True)


def number_card(rank: int, suit: int) -> Image.Image:
    card = blank()
    corner_index(card, rank, suit)
    for cx, cy in PIP_LAYOUT[rank]:
        stamp_centred(card, PIPS[suit], cx, cy, colour_of(suit), turned=cy > HEIGHT // 2)
    return card


def is_red_ink(pixel: tuple) -> bool:
    """A saturated red — a robe, a ribbon — and not a face or hair, which are warm but not red."""
    r, g, b, a = pixel
    return a > 0 and r > 90 and g < r * 0.45 and b < r * 0.45


def navy_of(pixel: tuple) -> tuple:
    """The robe's red, as the navy of the black suits' court cards: same lightness."""
    shade = pixel[0] / 255
    return (int(NAVY[0] * shade * 1.6), int(NAVY[1] * shade * 1.6), min(255, int(NAVY[2] * shade * 1.6)), pixel[3])


def court_figure(rank: int, suit: int) -> Image.Image:
    """A court card's figure for a suit: red robes for hearts and diamonds, navy for spades and clubs."""
    figure = Image.open(os.path.join(SOURCES, COURT_FILES[rank])).convert("RGBA")
    if suit not in RED_SUITS:
        pixels = figure.load()
        for y in range(figure.height):
            for x in range(figure.width):
                if is_red_ink(pixels[x, y]):
                    pixels[x, y] = navy_of(pixels[x, y])
    return figure


def court_card(rank: int, suit: int) -> Image.Image:
    """The figure framed, its upper half upright and mirrored below, as on a real deck."""
    card = blank()
    left, top, right, bottom = FRAME
    inner = Image.new("RGBA", (right - left, bottom - top), FACE)
    figure = court_figure(rank, suit)
    drawn = figure.getbbox()
    waist = drawn[3] if drawn else figure.height
    half = figure.crop((0, max(0, waist - HALF), figure.width, waist))
    middle = inner.height // 2
    x = (inner.width - half.width) // 2
    inner.alpha_composite(half, (x, middle - half.height))
    inner.alpha_composite(half.rotate(180), (inner.width - half.width - x, middle + 1))
    for fx in range(inner.width):
        inner.putpixel((fx, middle), NAVY)
    card.alpha_composite(inner, (left, top))
    for fx in range(left, right):
        card.putpixel((fx, top), NAVY)
        card.putpixel((fx, bottom - 1), NAVY)
    for fy in range(top, bottom):
        card.putpixel((left, fy), NAVY)
        card.putpixel((right - 1, fy), NAVY)
    corner_index(card, rank, suit)
    stamp(card, SMALL_PIPS[suit], left + 2, top + 2, colour_of(suit))
    pip = SMALL_PIPS[suit]
    stamp(card, pip, right - 3 - len(pip[0]), bottom - 3 - len(pip), colour_of(suit), turned=True)
    return card


def doubled(rows: list[str]) -> list[str]:
    """A pip twice its size, each of its pixels two by two."""
    return [line.replace("#", "##").replace(".", "..") for line in rows for _ in range(2)]


def ace(suit: int) -> Image.Image:
    """An ace: the ornate spade for spades, the suit's pip at twice its size for the rest."""
    card = blank()
    corner_index(card, 1, suit)
    if suit == SPADES:
        spade = Image.open(os.path.join(SOURCES, "ace_spades.png")).convert("RGBA")
        card.alpha_composite(spade, ((WIDTH - spade.width) // 2, (HEIGHT - spade.height) // 2))
    else:
        stamp_centred(card, doubled(PIPS[suit]), WIDTH // 2, HEIGHT // 2, colour_of(suit), turned=False)
    return card


def back(index: int) -> Image.Image:
    """A back from its picture, cut to the card's rounded corners."""
    picture = Image.open(os.path.join(SOURCES, f"back_{index}.png")).convert("RGBA")
    card = Image.new("RGBA", (WIDTH, HEIGHT), CLEAR)
    card.alpha_composite(picture.crop((0, 0, WIDTH, HEIGHT)))
    round_corners(card)
    return card


def joker(colour: tuple) -> Image.Image:
    """A joker: its figure on the face, a red one and a black one."""
    card = blank()
    figure = Image.open(os.path.join(SOURCES, "joker.png")).convert("RGBA")
    card.alpha_composite(figure, ((WIDTH - figure.width) // 2, (HEIGHT - figure.height) // 2))
    stamp(card, STAR, 3, 3, colour)
    stamp(card, STAR, WIDTH - 3 - len(STAR[0]), HEIGHT - 3 - len(STAR), colour, turned=True)
    return card


def shadow(spread: int) -> Image.Image:
    """A card's shadow: its shape in translucent black, `spread` pixels wider each way."""
    size = (WIDTH + 2 * spread, HEIGHT + 2 * spread)
    shape = Image.new("RGBA", size, SHADOW)
    round_corners(shape)
    shape.putpixel((1, 1), SHADOW)
    shape.putpixel((size[0] - 2, 1), SHADOW)
    shape.putpixel((1, size[1] - 2), SHADOW)
    shape.putpixel((size[0] - 2, size[1] - 2), SHADOW)
    return shape


def build_faces() -> dict[int, Image.Image]:
    """All 52 faces, by card id."""
    faces = build_number_cards()
    for suit in range(4):
        faces[suit * 13] = ace(suit)
        for rank in (11, 12, 13):
            faces[suit * 13 + rank - 1] = court_card(rank, suit)
    return dict(sorted(faces.items()))


def build_atlas() -> tuple[Image.Image, dict]:
    """The atlas picture and its description."""
    faces = build_faces()
    extras = [joker(RED), joker(BLACK)] + [back(i) for i in range(1, 5)]
    shadows = [shadow(0), shadow(1)]
    # One row per suit, then the jokers, backs and shadows; the lifted shadow is a pixel taller.
    sheet = Image.new("RGBA", (13 * CELL, 5 * (HEIGHT + 2) + 2), CLEAR)

    def put(picture: Image.Image, col: int, row: int) -> dict:
        x, y = col * CELL + 1, row * (HEIGHT + 2) + 1
        sheet.alpha_composite(picture, (x, y))
        return {"x": x, "y": y, "w": picture.width, "h": picture.height}

    description = {
        "image": "cards.png",
        "card": {"width": WIDTH, "height": HEIGHT},
        "faces": [put(faces[i], i % 13, i // 13) for i in range(52)],
        "jokers": [put(extras[0], 0, 4), put(extras[1], 1, 4)],
        "backs": [put(extras[2 + i], 2 + i, 4) for i in range(4)],
        "shadows": [put(shadows[0], 6, 4), put(shadows[1], 7, 4)],
    }
    return sheet, description


def build_number_cards() -> dict[int, Image.Image]:
    return {suit * 13 + rank - 1: number_card(rank, suit) for suit in range(4) for rank in range(2, 11)}


def preview(sheet: Image.Image, path: str, scale: int = 4) -> None:
    """The atlas on felt, `scale` times its size, to look at."""
    felt = Image.new("RGBA", sheet.size, (8, 120, 108, 255))
    felt.alpha_composite(sheet)
    felt.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST).save(path)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", metavar="PNG", help="also write a 4x sheet of every card here")
    args = parser.parse_args(argv)
    sheet, description = build_atlas()
    os.makedirs(OUTPUT, exist_ok=True)
    sheet.save(os.path.join(OUTPUT, description["image"]), optimize=True)
    with open(os.path.join(OUTPUT, "cards.json"), "w", encoding="utf-8") as out:
        json.dump(description, out, indent=1)
        out.write("\n")
    if args.preview:
        preview(sheet, args.preview)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
