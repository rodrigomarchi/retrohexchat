#!/usr/bin/env python3
"""Pack the character-picker preview strip.

The picker shows a small walking loop per class. It used to point at the full
runtime sheets — eight multi-megabyte downloads to fill eight thumbnails, each
scaled to a fraction of native size and so drawn blurred. This packs the four
south-facing walk frames of every class into one sheet the picker can show 1:1.

Layout: one row per class in roster order, four frames across, every cell the
same size — the tightest box that fits every class's walk content. Each frame is
centred horizontally and flush to the bottom of its cell, so the characters share
a ground line and the CSS needs one offset per row.

Usage:
    python3 virtual.space/tools/gen_charsel_sheet.py

Reads the runtime avatar sheets and their `.geo.json` siblings, so it always
reflects whatever `compose_iso_avatar.py` last wrote. Prints the geometry the
stylesheet needs.
"""
import json
import os

from PIL import Image

from sheet_io import save_sheet, assert_identical

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(TOOLS, "..", ".."))
SPACE = os.path.join(REPO, "apps/retro_hex_chat_web/priv/static/images/space")
AV = os.path.join(SPACE, "avatars")
OUT = os.path.join(SPACE, "charsel.webp")

# Roster order, matching `RetroHexChat.VirtualSpace.avatars/0` and the atlas
# ROSTER. The row index is the contract with the picker stylesheet.
ROSTER = ["hero", "knight", "sorceress", "archer", "barbarian", "rogue", "cleric", "monk"]
FRAMES = 4


def walk_frames(avatar_id):
    """The four south-facing walk frames of one class, cropped to their content."""
    geo = json.load(open(os.path.join(AV, f"iso_{avatar_id}.geo.json")))
    sheet = Image.open(os.path.join(AV, f"iso_{avatar_id}.webp")).convert("RGBA")
    row = geo["anims"]["walk"]["south"]
    fw, fh = geo["frameW"], geo["frameH"]
    frames = [sheet.crop((c, row, c + fw, row + fh)) for c in geo["cols"][:FRAMES]]

    # One crop window for the whole class, so the character does not jitter
    # between frames the way a per-frame bbox would make it.
    boxes = [f.getbbox() for f in frames]
    x0 = min(b[0] for b in boxes)
    y0 = min(b[1] for b in boxes)
    x1 = max(b[2] for b in boxes)
    y1 = max(b[3] for b in boxes)
    return [f.crop((x0, y0, x1, y1)) for f in frames]


def build():
    per_class = {avatar_id: walk_frames(avatar_id) for avatar_id in ROSTER}
    cell_w = max(f.width for frames in per_class.values() for f in frames)
    cell_h = max(f.height for frames in per_class.values() for f in frames)

    sheet = Image.new("RGBA", (cell_w * FRAMES, cell_h * len(ROSTER)), (0, 0, 0, 0))
    for row, avatar_id in enumerate(ROSTER):
        for col, frame in enumerate(per_class[avatar_id]):
            x = col * cell_w + (cell_w - frame.width) // 2
            y = row * cell_h + (cell_h - frame.height)
            sheet.paste(frame, (x, y))

    save_sheet(sheet, OUT)
    assert_identical(sheet, OUT)

    print(f"OK charsel: sheet={sheet.size} cell={cell_w}x{cell_h} rows={len(ROSTER)}")
    print(f"CSS cell: width {cell_w}px; height {cell_h}px;")
    print(f"CSS strip: background-position-x cycles 0 to -{cell_w * FRAMES}px")
    for row, avatar_id in enumerate(ROSTER):
        print(f"CSS row  {avatar_id}: background-position-y: -{row * cell_h}px;")


if __name__ == "__main__":
    build()
