#!/usr/bin/env python3
"""Emit the JS atlas data for the isometric avatar roster.

Reads every ``<name>.geo.json`` produced by ``compose_iso_avatar.py`` and prints
the two literals the sprite atlas needs: the sheet list and an ``ISO_GEO`` object
(per-avatar frame size, columns, and per-animation/-direction row offsets). The
atlas builds each avatar descriptor from this data, so adding/regenerating a
character is a data change — no bespoke per-avatar code.
"""
import glob
import json
import os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AV = os.path.join(REPO, "apps/retro_hex_chat_web/priv/static/images/space/avatars")

names = sorted(os.path.basename(p)[:-9] for p in glob.glob(os.path.join(AV, "*.geo.json")))

print("// AVATAR_SHEETS iso entries:")
for n in names:
    print(f'  {{ id: "av_{n}", src: "/images/space/avatars/{n}.png" }},')

print("\n// ISO_GEO:")
geo = {}
for n in names:
    g = json.load(open(os.path.join(AV, n + ".geo.json")))
    geo[n] = g
print("const ISO_GEO = " + json.dumps(geo, separators=(",", ":")) + ";")
print("\n// AVATARS iso ids:", names)
