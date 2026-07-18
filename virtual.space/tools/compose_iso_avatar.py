#!/usr/bin/env python3
"""Compose an 8-direction isometric avatar sheet from a PixelLab export.

Packs a premium 8-direction character's animations into one sheet the engine
addresses via an iso avatar atlas entry. Handles whichever of walk/idle/idle2/
attack/sleep actually exist (the roster is built up incrementally as animations
land).

Usage:
    python3 tools/compose_iso_avatar.py <name>     # default: iso_knight

Input (raw PixelLab frames, kept in the repo so sheets recompose without
re-spending generations):
    virtual.space/characters/<name>/pixellab/animations/<anim>/<dir>/*.png
    (walk/idle/attack carry all 8 directions; idle2 is an optional second idle
    variant; sleep is a seated pose — south holds the 4-frame doze, the other
    facings a single static sitting rotation each)

Layout: every frame is cropped to ONE shared vertical window (feet flush to the
bottom, full width kept so the body stays centred through the attack swing), then
stacked in direction-major blocks in the fixed order walk, idle, idle2, attack,
sleep — skipping any animation that has not been generated yet.

Deterministic: same frames in → identical bytes out. Writes the sheet PNG and a
sibling ``<name>.geo.json`` (frame size + per-anim/-direction row offsets) so the
atlas can be generated from data, and prints the same geometry.
"""
import glob
import json
import os
import sys

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIRS8 = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
ANIM_ORDER = ["walk", "idle", "idle2", "attack", "sleep"]
FRAMES = 4  # per animation, per direction


def _load(raw, anim, direction):
    files = sorted(glob.glob(os.path.join(raw, anim, direction, "*.png")))
    ims = [Image.open(f).convert("RGBA") for f in files]
    if not ims:
        return None
    while len(ims) < FRAMES:  # PixelLab occasionally yields 3 or 5 frames.
        ims.append(ims[-1].copy())
    return ims[:FRAMES]


def build(name):
    raw = os.path.join(REPO, "virtual.space/characters", name, "pixellab/animations")
    out = os.path.join(
        REPO, "apps/retro_hex_chat_web/priv/static/images/space/avatars", name + ".png"
    )
    geo_out = os.path.join(os.path.dirname(out), name + ".geo.json")

    # Gather whichever animations and directions exist for each block.
    blocks = {}
    for anim in ANIM_ORDER:
        rows = [(ims, d) for d in DIRS8 if (ims := _load(raw, anim, d)) is not None]
        if rows:
            blocks[anim] = rows
    if not blocks:
        raise SystemExit(f"no animations found under {raw}")

    all_frames = [im for rows in blocks.values() for ims, _ in rows for im in ims]
    cw, ch = all_frames[0].size

    # One shared vertical crop for the whole sheet: keep full width (body stays
    # centred through the asymmetric attack swing), drop the transparent padding
    # below the feet so billboarding bottom-centre grounds every pose.
    bottom = 0
    for im in all_frames:
        px = im.load()
        for y in range(ch - 1, -1, -1):
            if any(px[x, y][3] > 20 for x in range(cw)):
                bottom = max(bottom, y)
                break
    fh, fw = bottom + 1, cw

    present = [a for a in ANIM_ORDER if a in blocks]
    total_rows = sum(len(blocks[a]) for a in present)
    sheet = Image.new("RGBA", (fw * FRAMES, fh * total_rows), (0, 0, 0, 0))

    geometry = {"frameW": fw, "frameH": fh, "cols": [c * fw for c in range(FRAMES)], "anims": {}}
    row = 0
    for anim in present:
        rows = {}
        for ims, direction in blocks[anim]:
            for c, im in enumerate(ims):
                sheet.alpha_composite(im.crop((0, 0, fw, fh)), (c * fw, row * fh))
            rows[direction] = row * fh
            row += 1
        geometry["anims"][anim] = rows

    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    json.dump(geometry, open(geo_out, "w"))
    print(f"OK {name}: sheet={sheet.size} frame={fw}x{fh} anims={present}")
    print("GEOMETRY " + json.dumps(geometry))


if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else "iso_knight")
