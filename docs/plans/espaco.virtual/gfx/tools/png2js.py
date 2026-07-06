"""Mirror one PNG into a tiny JS module of traced pixel data.

A traced tile is emitted as `export default { w, h, p: [hex...], d: "<indices>" }`
where `d` is one character per pixel (row-major); `.` marks a transparent pixel
and every other char indexes the palette `p` through `ALPHA`. The virtual-space
sprite atlas decodes this back into a canvas — no PNG ships at runtime.

Usage:
    python3 png2js.py <input.png> <output.js> <export_name>
"""

import os
import sys

from PIL import Image

# Palette-index alphabet. Excludes . " \ ` (JS string / transparency) and #
# (keeps `d` clear of the JS hex-color audit). Kept in sync with sprite_atlas.js.
ALPHA = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!$%&()*+,-/:;<=>?@[]^_{|}~"


def convert(src, dst, name):
    """Trace `src` PNG into a JS module at `dst`. Returns (bytes, colors)."""
    return convert_image(Image.open(src), dst, name)


def convert_image(im, dst, name):
    """Trace an RGBA PIL image into a JS module at `dst`. Returns (bytes, colors)."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    palette = []
    index = {}
    out = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                out.append(".")
                continue
            hx = f"{r:02x}{g:02x}{b:02x}"
            if hx not in index:
                index[hx] = len(palette)
                palette.append(hx)
            out.append(ALPHA[index[hx]])
    if len(palette) > len(ALPHA):
        raise SystemExit(f"{name}: palette too large ({len(palette)} colors)")
    data = "".join(out)
    pal = ",".join(f'"{c}"' for c in palette)
    js = (
        f"// {name}: {w}x{h} sprite. p = palette (hex), "
        f"d = row-major palette indices ('.' = transparent).\n"
        f"export default {{ w: {w}, h: {h}, p: [{pal}], d: \"{data}\" }};\n"
    )
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "w") as f:
        f.write(js)
    return len(js), len(palette)


if __name__ == "__main__":
    src, dst, name = sys.argv[1], sys.argv[2], sys.argv[3]
    size, colors = convert(src, dst, name)
    print(f"{name}: {size} bytes, {colors} colors -> {dst}")
