#!/usr/bin/env python3
"""Compose PixelLab character exports into engine-ready avatar sprite sheets.

Each avatar's raw PixelLab export lives under
``docs/virtual.space.tiles/characters/<id>/pixellab/<Name>/`` (unzipped from the
per-character download endpoint). This script slices the 36x36 frames of two
animations and lays them out in the fixed grid the runtime atlas expects:

    rows 0-3 (walk):   down, up, left, right  x  4 walk frames
    rows 4-7 (attack): down, up, left, right  x  4 attack frames

producing ``apps/retro_hex_chat_web/priv/static/images/space/avatars/<id>.png``
(144x288, transparent background). If an avatar has no attack animation yet, the
attack rows are left transparent (the atlas simply keeps falling back to walk).
Deterministic: same export -> same sheet.
"""

import glob
import os
import sys

from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SRC = os.path.join(REPO, "docs", "virtual.space.tiles", "characters")
OUT = os.path.join(
    REPO, "apps", "retro_hex_chat_web", "priv", "static", "images", "space", "avatars"
)

FRAME = 36
FRAMES = 4
# Engine direction order (rows) mapped to PixelLab facing names (folders).
ROW_DIRS = [("down", "south"), ("up", "north"), ("left", "west"), ("right", "east")]
# Animation blocks: (folder-name-substring, base row index).
BLOCKS = [("animating", 0), ("attack", 4)]

AVATARS = ["sorceress", "knight", "archer", "barbarian", "rogue", "cleric", "monk"]


def dir_frames(avatar, folder_key, facing):
    """Best frame list for one facing across every folder matching folder_key.

    Retries can spread an attack across sibling folders (attack, attack-<hash>),
    each holding different directions — so for each facing we pick the folder
    that has the most frames. The list is then padded to FRAMES by repeating the
    last frame (covers a direction that generated 3 frames instead of 4).
    """
    base = os.path.join(SRC, avatar, "pixellab")
    best = []
    for root in sorted(glob.glob(os.path.join(base, "*", "animations", "*"))):
        if folder_key not in os.path.basename(root).lower():
            continue
        frames = sorted(glob.glob(os.path.join(root, facing, "frame_*.png")))
        if len(frames) > len(best):
            best = frames
    if not best:
        return []
    while len(best) < FRAMES:
        best.append(best[-1])
    return best[:FRAMES]


def paste_block(sheet, avatar, folder_key, base_row):
    """Paste one animation block; return True if any frame was found."""
    found = False
    for i, (_engine_dir, facing) in enumerate(ROW_DIRS):
        frames = dir_frames(avatar, folder_key, facing)
        for col, p in enumerate(frames):
            cell = Image.open(p).convert("RGBA")
            if cell.size != (FRAME, FRAME):
                cell = cell.resize((FRAME, FRAME), Image.NEAREST)
            sheet.alpha_composite(cell, (col * FRAME, (base_row + i) * FRAME))
            found = True
    return found


def compose(avatar):
    sheet = Image.new("RGBA", (FRAME * FRAMES, FRAME * 8), (0, 0, 0, 0))
    if not paste_block(sheet, avatar, "animating", 0):
        raise FileNotFoundError(f"{avatar}: no walk animation found")
    has_attack = paste_block(sheet, avatar, "attack", 4)
    os.makedirs(OUT, exist_ok=True)
    dest = os.path.join(OUT, f"{avatar}.png")
    sheet.save(dest)
    return dest, has_attack


def main(argv):
    targets = argv[1:] or AVATARS
    for avatar in targets:
        try:
            dest, has_attack = compose(avatar)
            tag = "walk+attack" if has_attack else "walk only"
            print(f"OK   {avatar} ({tag}) -> {os.path.relpath(dest, REPO)}")
        except FileNotFoundError as exc:
            print(f"SKIP {exc}")


if __name__ == "__main__":
    main(sys.argv)
