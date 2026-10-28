#!/usr/bin/env python3
"""Author a pixel-art UI kit from its PixelLab generations.

Two kits are built the same way (``--kit``): the Virtual Space's
(``virtual.space/ui``) and the arcade's, the Retro Games' stage
(``virtual.space/ui-arcade``, outputs under ``images/arcade/ui`` and
``arcade-ui-kit.generated.css``, its tokens on ``.arcade-ui``; no canvas
pieces, so no geometry file). The space's kit reads ``virtual.space/ui/kit.json``
and the raw art it names, and writes:

* ``priv/static/images/space/ui/<piece>__<state>.webp`` — one image per state of
  every ``css`` piece. CSS ``border-image`` cannot address part of an image, so
  a sliced frame is a file of its own.
* ``priv/static/images/space/ui/<image>.webp`` — whole images (the d-pad base).
* ``priv/static/images/space/ui/icons.webp`` — every icon, packed in a row.
* ``priv/static/images/space/ui/canvas.webp`` — the pieces the canvas renderer
  slices itself (bubble, nameplate, signs, HP bar) and its fixed sprites.
* ``assets/css/retrohex/features/space-ui-kit.generated.css`` — custom
  properties on ``.space-ui`` for each piece (image per state, slice, width),
  a preload of every state image, and one ``.space-icon--<name>`` rule per icon.
* ``assets/js/lib/space/ui_kit_geometry.js`` — where each canvas piece sits in
  ``canvas.webp`` and how it is sliced.

The art renders 1:1 (one art pixel per CSS pixel), so nothing is scaled. The
tool fails instead of fixing what it finds wrong, because the fix belongs in the
art (regenerate it in PixelLab) or in the kit (the slice):

* the piece's ``rect`` must be its exact opaque bounding box in the source;
* the art must not be upscaled (every run of equal pixels a multiple of 2+);
* the edges between corners must repeat cleanly (no ornament left inside
  them), since ``border-image`` tiles them;
* every state keeps the geometry of the normal one.

States are derived from the normal art by fixed palette recipes (see
``STATES``), never generated, so their slices line up pixel for pixel.

``--check`` builds everything in memory and fails if a committed output differs.
"""
import argparse
import colorsys
import io
import json
import math
import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sheet_io import _WEBP  # noqa: E402  (the one place encoder settings live)

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WEB = os.path.join(REPO, "apps/retro_hex_chat_web")


class Kit:
    """Where one kit's definition lives and where its outputs go. The space's
    kit draws the virtual space; the arcade's draws the Retro Games' stage."""

    def __init__(self, name, ui, img, css, js=None):
        self.name = name
        self.ui = os.path.join(REPO, ui)
        self.ui_rel = ui
        self.img_dir = os.path.join(WEB, "priv/static", img)
        self.img_url = "/" + img
        self.css_out = os.path.join(WEB, css)
        self.js_out = os.path.join(WEB, js) if js else None


KITS = {
    "space": Kit("space", "virtual.space/ui", "images/space/ui",
                 "assets/css/retrohex/features/space-ui-kit.generated.css",
                 "assets/js/lib/space/ui_kit_geometry.js"),
    "arcade": Kit("arcade", "virtual.space/ui-arcade", "images/arcade/ui",
                  "assets/css/retrohex/features/arcade-ui-kit.generated.css"),
}
SPACE = KITS["space"]

# An edge column may differ from the edge's median column by this much (mean
# per-channel difference over its pixels) before it counts as a seam.
SEAM_TOLERANCE = 28
# Share of an edge's columns allowed over the tolerance (grain and noise).
SEAM_SHARE = 0.12


class KitError(Exception):
    """The art or the kit is wrong; the message says which and where."""


# `.gitignore` drops `priv/static/**/*-[0-9a-f]*.*` as digest output, so a file
# named `button-disabled.webp` would never be committed. No output may look like
# one.
DIGEST_LOOKALIKE = re.compile(r"-[0-9a-f]")


def _check_name(path):
    if DIGEST_LOOKALIKE.search(os.path.basename(path)):
        raise KitError(f"{os.path.basename(path)} looks like digest output and would be gitignored")


# ---------------------------------------------------------------- recipes ----

def _map(image, fn):
    out = image.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (*fn(r, g, b), a)
    return out


def _clamp(v):
    return max(0, min(255, int(round(v))))


def _scale(k):
    return lambda r, g, b: (_clamp(r * k), _clamp(g * k), _clamp(b * k))


def _lighten(k):
    # Toward white, so the outline stays dark while the faces lift.
    def fn(r, g, b):
        lum = (r + g + b) / 765
        t = k * lum
        return (_clamp(r + (255 - r) * t), _clamp(g + (255 - g) * t), _clamp(b + (255 - b) * t))
    return fn


def _stone(r, g, b):
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    v = _clamp(lum * 0.75 + 40)
    return (v, v, _clamp(v + 4))


def _desaturate(k):
    def fn(r, g, b):
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        rr, gg, bb = colorsys.hls_to_rgb(h, l * 0.92, s * k)
        return (_clamp(rr * 255), _clamp(gg * 255), _clamp(bb * 255))
    return fn


def _gild(r, g, b):
    # The grey stone rim turns gold: the mark of the chosen one.
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if s < 0.14 and 0.3 < l < 0.8:
        rr, gg, bb = colorsys.hls_to_rgb(0.105, min(0.85, l * 1.05 + 0.08), 0.75)
        return (_clamp(rr * 255), _clamp(gg * 255), _clamp(bb * 255))
    return (r, g, b)


def _redden(r, g, b):
    # Warm browns turn blood red; outlines and greys stay.
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if s > 0.18 and (h < 0.12 or h > 0.95):
        rr, gg, bb = colorsys.hls_to_rgb(0.99, l, min(1.0, s * 1.5 + 0.1))
        return (_clamp(rr * 255), _clamp(gg * 255), _clamp(bb * 255))
    return (r, g, b)


def _then(*fns):
    def fn(r, g, b):
        for f in fns:
            r, g, b = f(r, g, b)
        return (r, g, b)
    return fn


# The arcade's art is dark chrome around a navy face, lit by neon lines: a
# recipe that lifts toward white does nothing there. Its states light the face
# and the lines instead, or turn the cyan line red.

def _neon_lit(k):
    # The navy face glows toward cyan by `k`; the neon lines brighten.
    def fn(r, g, b):
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        if s > 0.45 and l > 0.3:
            rr, gg, bb = colorsys.hls_to_rgb(h, min(0.82, l + 0.12), s)
            return (_clamp(rr * 255), _clamp(gg * 255), _clamp(bb * 255))
        # The face's navy only: not the black outline, nor the chrome's violet.
        if 0.08 < l < 0.21 and 0.6 < h < 0.8:
            return (_clamp(r + (0 - r) * k), _clamp(g + (190 - g) * k), _clamp(b + (160 - b) * k))
        return (r, g, b)
    return fn


def _alarm(r, g, b):
    # The cyan line and the amber corners turn red; the magenta line stays.
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if s > 0.45 and (0.38 < h < 0.56 or 0.06 < h < 0.16):
        rr, gg, bb = colorsys.hls_to_rgb(0.99, l, s)
        return (_clamp(rr * 255), _clamp(gg * 255), _clamp(bb * 255))
    return (r, g, b)


STATES = {
    "normal": None,
    "hover": _lighten(0.16),
    "pressed": _scale(0.82),
    "disabled": _stone,
    "selected": _gild,
    "active": _then(_gild, _scale(0.92)),
    "focus": _gild,
    "inactive": _desaturate(0.35),
    "danger": _redden,
    "danger_pressed": _then(_redden, _scale(0.82)),
    "glow": _neon_lit(0.12),
    "lit": _neon_lit(0.3),
    "lit_pressed": _then(_neon_lit(0.3), _scale(0.85)),
    "alarm": _alarm,
    "alarm_pressed": _then(_alarm, _neon_lit(0.2), _scale(0.85)),
}


# ----------------------------------------------------------------- checks ----

def _check_rect(name, source, rect):
    piece = source.crop(rect)
    box = piece.getbbox()
    if box != (0, 0, piece.width, piece.height):
        raise KitError(f"{name}: rect {rect} is not the piece's opaque bounding box (inside it: {box})")
    return piece


def _runs(seq):
    out, run = [], 1
    for a, b in zip(seq, seq[1:]):
        if a == b:
            run += 1
        else:
            out.append(run)
            run = 1
    out.append(run)
    return out


def _check_native(name, image):
    """Fail on art drawn at 2x or more: every run a multiple of the same k > 1."""
    px = image.load()
    g = 0
    for y in range(image.height):
        for r in _runs([px[x, y] for x in range(image.width)]):
            g = math.gcd(g, r)
    for x in range(image.width):
        for r in _runs([px[x, y] for y in range(image.height)]):
            g = math.gcd(g, r)
    if g > 1:
        raise KitError(f"{name}: art is upscaled {g}x; regenerate it at native size")


def _column(px, x, y0, y1):
    return [px[x, y] for y in range(y0, y1)]


def _seam_share(cols):
    if not cols:
        return 0.0
    n = len(cols[0])
    median = [tuple(sorted(c[i][k] for c in cols)[len(cols) // 2] for k in range(4)) for i in range(n)]
    bad = 0
    for c in cols:
        diff = sum(abs(p[k] - q[k]) for p, q in zip(c, median) for k in range(4)) / (n * 4)
        bad += diff > SEAM_TOLERANCE
    return bad / len(cols)


def _check_slice(name, image, slice_):
    t, r, b, l = slice_
    w, h = image.size
    if l + r >= w or t + b >= h:
        raise KitError(f"{name}: slice {slice_} leaves no edge to repeat in {w}x{h}")
    px = image.load()
    edges = {
        "top": [_column(px, x, 0, t) for x in range(l, w - r)],
        "bottom": [_column(px, x, h - b, h) for x in range(l, w - r)],
        "left": [[px[x, y] for x in range(0, l)] for y in range(t, h - b)],
        "right": [[px[x, y] for x in range(w - r, w)] for y in range(t, h - b)],
    }
    for edge, cols in edges.items():
        share = _seam_share(cols)
        if share > SEAM_SHARE:
            raise KitError(
                f"{name}: {edge} edge does not repeat cleanly ({share:.0%} of it differs); "
                "a corner ornament reaches past the slice — widen the slice")


# ----------------------------------------------------------------- output ----

def _webp(image):
    out = io.BytesIO()
    image.save(out, **_WEBP)
    return out.getvalue()


def _drawn(kit, name):
    rows = kit["drawn"][name]
    keys = kit["drawn"]["keys"]
    palette = kit["palette"]
    image = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    px = image.load()
    for y, row in enumerate(rows):
        if len(row) != image.width:
            raise KitError(f"drawn {name}: row {y} is {len(row)} wide, not {image.width}")
        for x, ch in enumerate(row):
            if ch != ".":
                px[x, y] = (*palette[keys[ch]], 255)
    return image


def _icon(kit, name, spec, done, ui):
    if "drawn" in spec:
        return _drawn(kit, spec["drawn"])
    if "rotate" in spec:
        if spec["rotate"] % 90:
            raise KitError(f"icon {name}: only quarter turns are lossless")
        return done[spec["from"]].rotate(spec["rotate"], expand=True)
    if spec.get("quadrants") == "flip":
        return _flip_quadrants(name, done[spec["from"]])
    image = Image.open(os.path.join(ui, spec["src"])).convert("RGBA")
    _check_native(f"icon {name}", image)
    return image


def _flip_quadrants(name, image):
    """Mirror each quarter in place: corner marks pointing out now point in."""
    w, h = image.size
    if w % 2 or h % 2:
        raise KitError(f"icon {name}: quadrants need an even size, got {w}x{h}")
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    for x0 in (0, w // 2):
        for y0 in (0, h // 2):
            box = (x0, y0, x0 + w // 2, y0 + h // 2)
            quarter = image.crop(box).transpose(Image.Transpose.ROTATE_180)
            out.paste(quarter, box[:2])
    return out


def _pack_row(images, gap=1):
    """Pack images left to right; returns the sheet and {name: (x, y, w, h)}."""
    width = sum(i.width for i in images.values()) + gap * max(0, len(images) - 1)
    height = max(i.height for i in images.values())
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    where, x = {}, 0
    for name, image in images.items():
        sheet.paste(image, (x, 0))
        where[name] = (x, 0, image.width, image.height)
        x += image.width + gap
    return sheet, where


def build(k=SPACE):
    with open(os.path.join(k.ui, "kit.json")) as f:
        kit = json.load(f)
    sources = {n: Image.open(os.path.join(k.ui, v)).convert("RGBA") for n, v in kit["sources"].items()}
    img_dir, img_url, p = k.img_dir, k.img_url, k.name
    files = {}
    css = [
        f"/* Generated by virtual.space/tools/author_ui.py from {k.ui_rel}/kit.json — do not edit. */\n",
        f"/* Each piece: --{p}-ui-<piece>[--<state>] (its image), -slice (border-image-slice)\n",
        "   and -width (border-image-width). */\n",
        f".{p}-ui {{\n",
    ]
    canvas_pieces, canvas_geo = {}, {}

    for name, spec in kit["pieces"].items():
        piece = _check_rect(name, sources[spec["src"]], tuple(spec["rect"]))
        _check_native(name, piece)
        _check_slice(name, piece, spec["slice"])
        t, r, b, l = spec["slice"]
        if "css" in spec["targets"]:
            css_name = name.replace("_", "-")
            for state in spec["states"]:
                css_state = state.replace("_", "-")
                recipe = STATES[state]
                image = piece if recipe is None else _map(piece, recipe)
                if image.size != piece.size:
                    raise KitError(f"{name}--{state}: geometry differs from normal")
                # `__`, never `-` (the digest gitignore) or `.` (read as a class by
                # the CSS lint).
                file = f"{name}__{state}.webp"
                files[os.path.join(img_dir, file)] = _webp(image)
                var = f"--{p}-ui-{css_name}" + ("" if state == "normal" else f"--{css_state}")
                css.append(f'  {var}: url("{img_url}/{file}");\n')
            css.append(f"  --{p}-ui-{css_name}-slice: {t} {r} {b} {l};\n")
            css.append(f"  --{p}-ui-{css_name}-width: {t}px {r}px {b}px {l}px;\n")
        if "canvas" in spec["targets"]:
            canvas_pieces[name] = piece
            canvas_geo[name] = {"t": t, "r": r, "b": b, "l": l}

    for name, spec in kit.get("images", {}).items():
        image = _check_rect(name, sources[spec["src"]], tuple(spec["rect"]))
        _check_native(name, image)
        files[os.path.join(img_dir, f"{name}.webp")] = _webp(image)
        css.append(f'  --{p}-ui-{name}: url("{img_url}/{name}.webp");\n')
        css.append(f"  --{p}-ui-{name}-size: {image.width}px {image.height}px;\n")
    css.append("}\n\n")

    # Every state image but the normal ones, fetched with the page, so the first
    # hover or press does not flash an empty frame while its image loads.
    states = [f for f in files if f.startswith(img_dir) and "__" in f
              and "__normal." not in f]
    if states:
        css.append(f".{p}-ui::after {{\n  content: \"\";\n  position: absolute;\n"
                   "  width: 0;\n  height: 0;\n  overflow: hidden;\n  background-image:\n")
        css.append(",\n".join(f'    url("{img_url}/{os.path.basename(f)}")' for f in sorted(states)))
        css.append(";\n}\n\n")

    for name, spec in kit.get("canvas_sprites", {}).items():
        if name.startswith("_"):
            continue
        canvas_pieces[name] = _drawn(kit, spec["drawn"])
        canvas_geo[name] = {}
    # A kit without canvas pieces (the arcade's) has no sheet and no geometry.
    if canvas_pieces:
        sheet, where = _pack_row(canvas_pieces)
        files[os.path.join(img_dir, "canvas.webp")] = _webp(sheet)

    icons = {}
    for name, spec in kit.get("icons", {}).items():
        if not name.startswith("_"):
            icons[name] = _icon(kit, name, spec, icons, k.ui)
    if icons:
        icon_sheet, icon_where = _pack_row(icons)
        files[os.path.join(img_dir, "icons.webp")] = _webp(icon_sheet)
        # `display` under `:where()`, so a utility (`hidden`) still wins over it.
        css.append(f":where(.{p}-icon) {{\n  display: inline-block;\n}}\n")
        css.append(
            f".{p}-icon {{\n"
            "  flex-shrink: 0;\n"
            f'  background-image: url("{img_url}/icons.webp");\n'
            "  background-repeat: no-repeat;\n"
            "  image-rendering: pixelated;\n"
            "}\n")
        for name, (x, y, w, h) in icon_where.items():
            css.append(
                f".{p}-icon--{name.replace('_', '-')} {{\n"
                f"  width: {w}px;\n  height: {h}px;\n"
                f"  background-position: {-x}px {-y}px;\n}}\n")

    files[k.css_out] = "".join(css).encode()
    if k.js_out:
        if not canvas_pieces:
            raise KitError(f"{k.name}: a geometry file is asked for, but no piece targets the canvas")
        geo_lines = [
            f"// Generated by virtual.space/tools/author_ui.py from {k.ui_rel}/kit.json — do not edit.\n",
            f"// Where each canvas UI piece sits in {img_url}/canvas.webp (x, y, w, h) and,\n",
            "// for a sliced piece, its slice in native pixels (t, r, b, l).\n",
            "export const UI_KIT_GEOMETRY = Object.freeze({\n",
        ]
        for name, (x, y, w, h) in where.items():
            fields = {"x": x, "y": y, "w": w, "h": h, **canvas_geo[name]}
            body = ", ".join(f"{key}: {v}" for key, v in fields.items())
            geo_lines.append(f"  {name}: Object.freeze({{ {body} }}),\n")
        geo_lines.append("});\n")
        files[k.js_out] = "".join(geo_lines).encode()
    for path in files:
        if path.startswith(img_dir):
            _check_name(path)
    return files


def same_output(path, data):
    """Whether the committed file is this output. An image is compared by its
    pixels, not its bytes: another libwebp encodes the same pixels differently."""
    if not os.path.exists(path):
        return False
    with open(path, "rb") as f:
        committed = f.read()
    if committed == data or not path.endswith(".webp"):
        return committed == data
    a = Image.open(io.BytesIO(committed)).convert("RGBA")
    b = Image.open(io.BytesIO(data)).convert("RGBA")
    return a.size == b.size and a.tobytes() == b.tobytes()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail if a committed output differs")
    parser.add_argument("--kit", choices=sorted(KITS), default="space", help="which kit to build")
    args = parser.parse_args()
    k = KITS[args.kit]
    try:
        files = build(k)
    except KitError as e:
        sys.exit(f"author_ui: {e}")

    img_dir = k.img_dir
    owned = {os.path.join(img_dir, f) for f in os.listdir(img_dir)} if os.path.isdir(img_dir) else set()
    if args.check:
        stale = [p for p, d in files.items() if not same_output(p, d)]
        stale += sorted(owned - set(files))
        for p in stale:
            print(f"stale: {os.path.relpath(p, REPO)}")
        sys.exit(1 if stale else 0)

    for p in owned - set(files):
        os.remove(p)
    for p, d in files.items():
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "wb") as f:
            f.write(d)
    size = sum(len(d) for p, d in files.items() if p.endswith(".webp"))
    print(f"wrote {len(files)} files ({size // 1024} KiB of webp)")


if __name__ == "__main__":
    main()
