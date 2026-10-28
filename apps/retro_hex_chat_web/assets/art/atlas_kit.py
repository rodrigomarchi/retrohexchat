"""What every game's atlas builder shares: its pictures packed into one sheet,
and the sheet published beside the game with a version in each address.

A builder draws its pictures and hands them here:

    sheet, regions = atlas_kit.pack(pieces, width)
    return atlas_kit.main(argv, doc, build_atlas, output=..., protocol_js=..., tiles_url_re=...)

`main` writes `tiles.png` and `tiles.json` (the picture's `?vsn=` in the
description) into `output`, rewrites the description's `?vsn=` in the game's
`TILES_URL`, and with `--preview X.png` saves the sheet 4x on a teal ground.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import sys

from PIL import Image

CLEAR = (0, 0, 0, 0)


def pack(pieces, width):
    """The pictures, by name, in rows across a sheet `width` wide, a pixel apart: the sheet and each region."""
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
    return sheet, regions


def version(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()[:12]


def main(argv, doc, build_atlas, *, output, protocol_js, tiles_url_re):
    parser = argparse.ArgumentParser(description=doc.splitlines()[0])
    parser.add_argument("--preview", metavar="PNG")
    args = parser.parse_args(argv)
    sheet, description = build_atlas()
    os.makedirs(output, exist_ok=True)
    out = io.BytesIO()
    sheet.save(out, format="PNG", optimize=True)
    picture = out.getvalue()
    with open(os.path.join(output, "tiles.png"), "wb") as f:
        f.write(picture)
    description["image"] += f"?vsn={version(picture)}"
    text = (json.dumps(description, indent=1) + "\n").encode()
    with open(os.path.join(output, "tiles.json"), "wb") as f:
        f.write(text)
    with open(protocol_js, encoding="utf-8") as f:
        module = f.read()
    module, found = tiles_url_re.subn(rf"\g<1>{version(text)}\g<2>", module)
    if found != 1:
        print(f"TILES_URL not found once in {protocol_js}", file=sys.stderr)
        return 1
    with open(protocol_js, "w", encoding="utf-8") as f:
        f.write(module)
    if args.preview:
        back = Image.new("RGBA", sheet.size, (8, 120, 108, 255))
        back.alpha_composite(sheet)
        back.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(args.preview)
    return 0


def load(path, name):
    """A builder module by its path: every builder is a `build_tiles`."""
    import importlib.util

    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module
