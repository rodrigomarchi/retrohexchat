#!/usr/bin/env python3
"""Emit the JS atlas data for the isometric avatar roster.

Reads every ``<name>.geo.json`` produced by ``compose_iso_avatar.py`` and prints
the compact ``ISO_GEO`` object the sprite atlas needs: per avatar, the frame size
and the animation names in row order. The atlas derives every rectangle from
those, because ``compose_iso_avatar.py`` packs every sheet the same way:

* column ``i`` starts at ``i * frameW`` (``FRAMES`` columns);
* animation ``a`` (its index in ``anims``), direction ``d`` (its index in the
  atlas's ``DIRECTIONS``) starts at row ``(a * 8 + d) * frameH``.

This script **asserts** that layout for every sheet and fails on one that breaks
it, so the compact form can never silently disagree with the pixels; the
offsets themselves carry no information the layout does not.

Sheet URLs are not printed: the atlas derives them from the roster, and at runtime
the server hands it digested ones.
"""
import glob
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AV = os.path.join(REPO, "apps/retro_hex_chat_web/priv/static/images/space/avatars")

# The atlas's `DIRECTIONS`, in sheet row order.
DIRECTIONS = [
    "south",
    "south-east",
    "east",
    "north-east",
    "north",
    "north-west",
    "west",
    "south-west",
]
FRAMES = 4


def compact(name, geo):
    """The compact geometry of one avatar, or a SystemExit naming the break."""
    w, h = geo["frameW"], geo["frameH"]
    if geo["cols"] != [i * w for i in range(FRAMES)]:
        sys.exit(f"{name}: columns are not {FRAMES} x frameW")
    anims = list(geo["anims"])
    for a, anim in enumerate(anims):
        rows = geo["anims"][anim]
        if list(rows) != DIRECTIONS:
            sys.exit(f"{name}.{anim}: directions are not in DIRECTIONS order")
        for d, direction in enumerate(DIRECTIONS):
            if rows[direction] != (a * 8 + d) * h:
                sys.exit(f"{name}.{anim}.{direction}: row is not (anim*8+dir)*frameH")
    return {"frameW": w, "frameH": h, "anims": anims}


def main():
    names = sorted(os.path.basename(p)[:-9] for p in glob.glob(os.path.join(AV, "*.geo.json")))
    geo = {}
    for n in names:
        with open(os.path.join(AV, n + ".geo.json")) as f:
            geo[n] = compact(n, json.load(f))
    print("// ISO_GEO:")
    print("const ISO_GEO = " + json.dumps(geo, separators=(",", ":")) + ";")
    print("\n// AVATARS iso ids:", names)


if __name__ == "__main__":
    main()
