#!/usr/bin/env python3
"""Compose the 8-direction isometric avatar sheet from PixelLab exports.

Unlike ``compose_avatars.py`` (the 4-direction top-down class roster), this packs
a premium **8-direction** character with four animations — walk, idle (breathing),
attack, sleep — into one sheet the engine addresses via the ``av_iso_knight``
atlas entry.

Input (raw PixelLab frames, kept in the repo so the sheet recomposes without
re-spending generations):
    virtual.space/characters/iso_knight/pixellab/animations/<anim>/<dir>/*.png
    (walk|idle|attack have all 8 directions; sleep is south-only — a seated pose)

Layout: every frame is cropped to ONE shared vertical window (feet flush to the
bottom, full 92px width kept so the body stays centred through the attack swing),
then stacked in direction-major blocks:
    rows  0- 7  walk    (south, south-east, east, north-east, north,
    rows  8-15  idle     north-west, west, south-west)
    rows 16-23  attack
    row  24     sleep    (south only)

Deterministic: same frames in → identical bytes out. Prints the atlas geometry.
"""
import glob
import json
import os

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(REPO, "virtual.space/characters/iso_knight/pixellab/animations")
OUT = os.path.join(REPO, "apps/retro_hex_chat_web/priv/static/images/space/avatars/iso_knight.png")

DIRS8 = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
FRAMES = 4  # per animation, per direction


def _load(anim, direction):
    files = sorted(glob.glob(os.path.join(RAW, anim, direction, "*.png")))
    ims = [Image.open(f).convert("RGBA") for f in files]
    if not ims:
        raise FileNotFoundError(f"no frames for {anim}/{direction}")
    # Pad/truncate to exactly FRAMES (PixelLab occasionally yields 3 or 5).
    while len(ims) < FRAMES:
        ims.append(ims[-1].copy())
    return ims[:FRAMES]


def build():
    # Gather every frame first so the crop window is shared across the whole sheet.
    blocks = {
        "walk": [(_load("walk", d), d) for d in DIRS8],
        "idle": [(_load("idle", d), d) for d in DIRS8],
        "attack": [(_load("attack", d), d) for d in DIRS8],
        "sleep": [(_load("sleep", "south"), "south")],
    }
    all_frames = [im for rows in blocks.values() for ims, _ in rows for im in ims]
    cw, ch = all_frames[0].size

    # One shared vertical crop: keep the full width (body stays centred through the
    # asymmetric attack swing) but drop the transparent padding below the feet so
    # billboarding bottom-centre grounds every pose. Bottom = lowest opaque row over
    # ALL frames (the standing feet / the seated base), top stays at 0 for headroom.
    bottom = 0
    for im in all_frames:
        px = im.load()
        for y in range(ch - 1, -1, -1):
            if any(px[x, y][3] > 20 for x in range(cw)):
                bottom = max(bottom, y)
                break
    fh = bottom + 1
    fw = cw

    order = ["walk", "idle", "attack", "sleep"]
    total_rows = 8 + 8 + 8 + 1
    sheet = Image.new("RGBA", (fw * FRAMES, fh * total_rows), (0, 0, 0, 0))

    geometry = {}
    row = 0
    for anim in order:
        rows = {}
        for ims, direction in blocks[anim]:
            for c, im in enumerate(ims):
                sheet.alpha_composite(im.crop((0, 0, fw, fh)), (c * fw, row * fh))
            rows[direction] = row * fh
            row += 1
        geometry[anim] = {
            "frameW": fw,
            "frameH": fh,
            "cols": [c * fw for c in range(FRAMES)],
            "rows": rows,
        }

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print(f"OK iso avatar: sheet={sheet.size} frame={fw}x{fh} rows={total_rows}")
    print("GEOMETRY " + json.dumps(geometry))


if __name__ == "__main__":
    build()
