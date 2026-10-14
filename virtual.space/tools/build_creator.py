#!/usr/bin/env python3
"""Build the Space character creator from its PixelLab frames.

Reads ``virtual.space/characters/creator/catalog_src.json`` and the frames
``creator_generate.py`` downloaded to ``raw/``, and writes:

* ``priv/static/images/space/creator/<layer>_<anim>.png`` -- one indexed PNG
  per piece and clip: the eight facings as rows, the frames as columns, each
  cell the piece's box for that clip. Index 0 is transparent; each recolourable
  channel's shades sit at known indices, so a colour change is a palette swap.
  A hat that hides the hair under it also gets ``<layer>_<anim>_mask.png``.
* ``priv/static/images/space/creator/portrait_<layer>.png`` -- the piece's
  head crop, for the portraits the chat shows; ``figure_<layer>.png``, the
  whole figure, and ``head_<layer>.png``, everything worn on the head, for
  the creator's pictures of its pieces.
* ``priv/static/images/space/creator/catalog.json`` -- the web catalog: geometry,
  sheet URLs, palette indices, colour ramps, head offsets.
* ``apps/retro_hex_chat/priv/virtual_space/character_catalog.json`` -- what the
  server validates a recipe against.
* ``assets/css/retrohex/features/space-creator-swatches.generated.css`` -- the
  colour swatches of the creator.

How the pieces line up: every piece is a state of the master mannequin with
the master's skeleton, so a hair frame fits the master frame of the same clip,
facing and index. A body other than the master's moves the head a pixel or
two; that shift is measured per frame (``creator_art.head_offset``) and stored
as the base's ``delta``, which the compositor adds to every overlay.

Deterministic: the same frames give the same bytes, on any machine -- the PNGs
are written here with the standard library's zlib (`creator_art.encode_png8`),
not by whichever zlib Pillow was built with.

    python3 virtual.space/tools/build_creator.py [--check]
"""
from __future__ import annotations

import argparse
import colorsys
import hashlib
import json
import os
import sys
from concurrent.futures import ProcessPoolExecutor

from PIL import Image

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)

import creator_art as art  # noqa: E402

REPO = os.path.abspath(os.path.join(TOOLS, "..", ".."))
CREATOR = os.path.join(REPO, "virtual.space", "characters", "creator")
WEB = os.path.join(REPO, "apps", "retro_hex_chat_web")
OUT = os.path.join(WEB, "priv", "static", "images", "space", "creator")
URL = "/images/space/creator"
DOMAIN_OUT = os.path.join(REPO, "apps", "retro_hex_chat", "priv", "virtual_space", "character_catalog.json")
CSS_OUT = os.path.join(WEB, "assets", "css", "retrohex", "features", "space-creator-swatches.generated.css")

# Which colour list dyes which channel.
CHANNEL_PALETTE = {"skin": "skin", "hair": "hair", "primary": "fabric", "secondary": "fabric"}
# Side of the square a chat portrait is cut to, in pixels.
PORTRAIT = 24
# Clear pixels round a figure: an overlay moved by a base's head offset stays in.
FIGURE_PAD = 2


# ------------------------------------------------------------------ catalog

def layer_specs(catalog):
    """Every layer: (name, kind, keys, skin?, extra) in drawing order of kind."""
    keys = catalog["keys"]
    outfits = {o["id"]: o for o in catalog["outfits"]}
    specs = []
    for key in sorted(catalog["bases"]):
        body, outfit = key.split("/")
        channels = outfits[outfit]["channels"]
        specs.append({"name": f"base-{body}-{outfit}", "kind": "base", "body": body, "outfit": outfit,
                      "keys": {c: keys[c] for c in channels}, "skin": True})
    for item in catalog["hair"]:
        specs.append({"name": f"hair-{item['id']}", "kind": "hair", "id": item["id"],
                      "keys": {"hair": item["key"]}, "skin": False})
    for item in catalog["headwear"]:
        specs.append({"name": f"hat-{item['id']}", "kind": "hat", "id": item["id"],
                      "keys": {c: keys[c] for c in item["channels"]}, "skin": False, "hair": item["hair"]})
    for item in catalog["face"]:
        specs.append({"name": f"face-{item['id']}", "kind": "face", "id": item["id"],
                      "keys": {item["channel"]: item["key"]}, "skin": False})
    return specs


def ramp(rgb, shades):
    """A shade ramp, dark to light, around a swatch colour: shadows lean cool
    and saturated, highlights warm and pale -- the pixel-art way of shading."""
    h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
    out = []
    for j in range(shades):
        t = j / (shades - 1) if shades > 1 else 1
        hh = h * 360
        warm = 60 if (hh - 60) % 360 < 180 else 60 + 360
        cool = 240
        shift = (1 - t) * -12 + t * 10
        target = cool if shift < 0 else warm
        direction = 1 if ((target - hh) % 360) < 180 else -1
        hh = (hh + direction * abs(shift)) % 360
        vv = min(1.0, v * (0.42 + 0.78 * t) + 0.04 * t)
        ss = max(0.0, min(1.0, s * (1.18 - 0.5 * t)))
        r, g, b = colorsys.hsv_to_rgb(hh / 360, ss, vv)
        out.append([round(r * 255), round(g * 255), round(b * 255)])
    return out


def palettes(catalog):
    shades = catalog["shades"]
    out = {}
    for name, entries in catalog["palettes"].items():
        k = {"skin": shades["skin"], "hair": shades["hair"], "fabric": shades["primary"]}[name]
        out[name] = [ramp(e["rgb"], k) for e in entries]
    return out


# ------------------------------------------------------------------- frames

def load_frames(raw, layer, anim, dirs, canvas):
    """{dir: [Frame]} on the canvas, frames in index order."""
    out = {}
    for d in dirs:
        folder = os.path.join(raw, layer, anim, d)
        if not os.path.isdir(folder):
            raise FileNotFoundError(f"{layer}: no {anim} frames facing {d}")
        names = sorted((n for n in os.listdir(folder) if n.endswith(".png")), key=lambda n: int(n[:-4]))
        frames = []
        for n in names:
            image = Image.open(os.path.join(folder, n)).convert("RGBA")
            if image.size != (canvas, canvas):
                padded = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
                padded.paste(image, ((canvas - image.width) // 2, (canvas - image.height) // 2))
                image = padded
            frames.append(art.Frame(image))
        out[d] = frames
    return out


def load_sources(raw, layer):
    """What `creator_generate.py fetch` wrote of where a layer's clips came
    from: {anim: {facing: {"template", "group"}}}."""
    path = os.path.join(raw, layer, "sources.json")
    if not os.path.exists(path):
        raise FileNotFoundError(f"{layer}: no sources.json; fetch the frames with creator_generate.py")
    with open(path) as handle:
        return json.load(handle)


def check_sources(catalog, layer, sources):
    """Refuse a template clip with a facing missing, or made from another
    template than the catalog names."""
    for clip in catalog["clips"]:
        if "template" not in clip:
            continue
        got = sources.get(clip["anim"], {})
        for d in catalog["dirs"]:
            if d not in got:
                raise ValueError(f"{layer} {clip['anim']} {d}: no source recorded")
            if got[d]["template"] != clip["template"]:
                raise ValueError(f"{layer} {clip['anim']} {d}: made from {got[d]['template']}, "
                                 f"the catalog says {clip['template']}")


def label_frames(spec, frames):
    if spec["kind"] == "base":
        labels = [art.classify(f, spec["keys"], skin=True) for f in frames]
    else:
        labels = [art.overlay(f, spec["keys"]) for f in frames]
    if spec["kind"] == "face":
        # A face item is one small piece, its pale parts its own (a lens inside
        # a frame): only its largest part and what lies against it are kept, so
        # a speck of the skin's red shadow on a shoulder is not the item.
        return [art.keep_near_main(f, l, share=1.01) for f, l in zip(frames, labels)]
    return [art.fill_enclosed(f, l, list(spec["keys"])) for f, l in zip(frames, labels)]


# How far past the hair and headwear drawn in the same frame a face item may
# reach. Measured over every face frame: never past them, so 2 px is slack.
FACE_REACH = 2


def face_box(boxes):
    """The region a face item is kept in, from the boxes of the hair and
    headwear of the same frame; None when there are none to go by."""
    box = art.union(boxes)
    if box is None:
        return None
    return (box[0] - FACE_REACH, box[1] - FACE_REACH, box[2] + FACE_REACH, box[3] + FACE_REACH)


# --------------------------------------------------------------------- build

def _label_clip(job):
    """{facing: (frames, labels)} of one layer's clip (a process pool's task)."""
    spec, anim, raw, dirs, canvas = job
    frames = load_frames(raw, spec["name"], anim, dirs, canvas)
    return {d: (frames[d], label_frames(spec, frames[d])) for d in dirs}


def build(catalog, raw, out_dir, write=True):
    """Build everything; returns {path: bytes} of what would be written."""
    dirs, canvas = catalog["dirs"], catalog["canvas"]
    specs = layer_specs(catalog)
    clips = catalog["clips"]
    master_layer = next(s["name"] for s in specs if s["kind"] == "base"
                        and catalog["bases"][f"{s['body']}/{s['outfit']}"] == catalog["master"])

    # Every template clip's frames must have come from that template: a walk
    # fetched into the idle folder would otherwise build without a complaint.
    for spec in specs:
        check_sources(catalog, spec["name"], load_sources(raw, spec["name"]))

    # Frames and labels for every layer, clip and facing: each (layer, clip)
    # labelled in a process of its own, gathered back in a fixed order.
    data = {}
    work = [(spec, clip["anim"], raw, dirs, canvas) for spec in specs for clip in clips]
    with ProcessPoolExecutor() as pool:
        for (spec, anim, *_rest), labelled in zip(work, pool.map(_label_clip, work)):
            for d in dirs:
                data[(spec["name"], anim, d)] = labelled[d]

    # A face item is small, and the skin's red shadows can fall in its key:
    # what it draws away from the head (a speck on an arm) is not the item.
    heads = [s for s in specs if s["kind"] in ("hair", "hat")]
    for spec in specs:
        if spec["kind"] != "face":
            continue
        for clip in clips:
            for d in dirs:
                frames, labels = data[(spec["name"], clip["anim"], d)]
                kept = []
                for i, (f, l) in enumerate(zip(frames, labels)):
                    box = face_box([art.bbox(*[data[(h["name"], clip["anim"], d)][k][i] for k in (0, 1)])
                                    for h in heads if i < len(data[(h["name"], clip["anim"], d)][0])])
                    kept.append(art.keep_within(f, l, box) if box else l)
                data[(spec["name"], clip["anim"], d)] = (frames, kept)

    # One frame count per clip, the master's; every piece must match it.
    counts = {}
    for clip in clips:
        anim = clip["anim"]
        counts[anim] = len(data[(master_layer, anim, dirs[0])][0])
        for spec in specs:
            for d in dirs:
                n = len(data[(spec["name"], anim, d)][0])
                if n != counts[anim]:
                    raise ValueError(f"{spec['name']} {anim} {d}: {n} frames, the master has {counts[anim]}")

    overlays = [s for s in specs if s["kind"] != "base"]

    # Where the head is, per frame: the union of every overlay drawn there.
    def head_box(anim, d, i):
        box = art.union([art.bbox(data[(o["name"], anim, d)][0][i], data[(o["name"], anim, d)][1][i])
                         for o in overlays])
        if box is None:
            return None
        return (box[0] - 3, box[1] - 3, box[2] + 3, box[3] + 3)

    # Head offsets of each base against the master.
    deltas = {}
    for spec in specs:
        if spec["kind"] != "base":
            continue
        per_anim = {}
        for clip in clips:
            anim = clip["anim"]
            rows = []
            for d in dirs:
                mf, ml = data[(master_layer, anim, d)]
                of, ol = data[(spec["name"], anim, d)]
                rows.append([list(art.head_offset(mf[i], ml[i], of[i], ol[i], head_box(anim, d, i)))
                             if spec["name"] != master_layer else [0, 0] for i in range(counts[anim])])
            per_anim[anim] = rows
        deltas[spec["name"]] = per_anim

    # The box every composed frame is cut to: everything any piece draws.
    box = art.union([art.bbox(f, l) for (frames, labels) in data.values() for f, l in zip(frames, labels)])
    box = (box[0] - 2, box[1] - 2, box[2] + 2, box[3] + 2)

    files = {}
    web_layers = {}
    for spec in specs:
        frames_labels = [(f, l) for clip in clips for d in dirs
                         for f, l in zip(*data[(spec["name"], clip["anim"], d)])]
        shades = {c: catalog["shades"][c] for c in spec["keys"]}
        if spec["skin"]:
            shades["skin"] = catalog["shades"]["skin"]
        if spec["kind"] == "hair":
            shades = {"hair": catalog["shades"]["hair"]}
        palette = art.build_palette(frames_labels, shades)
        entry = {"channels": {c: palette.channels[c] for c in sorted(palette.channels)}, "anims": {}}
        for clip in clips:
            anim = clip["anim"]
            sheet, cell, origin = pack(data, spec["name"], anim, dirs, counts[anim], palette)
            name = f"{spec['name']}_{anim}.png"
            files[name] = png_bytes(sheet)
            entry["anims"][anim] = {"file": name, "cell": cell, "origin": origin}
            if spec.get("hair") == "clip":
                mask, mcell, morigin = pack_mask(data, spec["name"], anim, dirs, counts[anim])
                mname = f"{spec['name']}_{anim}_mask.png"
                files[mname] = png_bytes(mask)
                entry.setdefault("mask", {})[anim] = {"file": mname, "cell": mcell, "origin": morigin}
        if spec["kind"] == "base":
            entry["delta"] = deltas[spec["name"]]
        web_layers[spec["name"]] = (entry, palette)

    # Portraits: each layer's south-facing first idle frame, cropped to a square
    # on the master's face -- from just above the crown, so a hat shows its
    # brim and the face stays whole.
    mf, ml = data[(master_layer, "idle", "south")][0][0], data[(master_layer, "idle", "south")][1][0]
    mbox = art.bbox(mf, ml)
    head_cols = [i % mf.w for i, l in enumerate(ml) if l is not art.TRANSPARENT and i // mf.w < mbox[1] + 16]
    cx = (min(head_cols) + max(head_cols) + 1) // 2
    rect = [cx - PORTRAIT // 2, mbox[1] - 3, PORTRAIT, PORTRAIT]
    # Figures: the same frame, cut to everything any piece draws in it, with
    # room for the overlays' head offsets.
    fbox = art.union([art.bbox(*[data[(s["name"], "idle", "south")][k][0] for k in (0, 1)]) for s in specs])
    figure_rect = [fbox[0] - FIGURE_PAD, fbox[1] - FIGURE_PAD,
                   fbox[2] - fbox[0] + 2 * FIGURE_PAD, fbox[3] - fbox[1] + 2 * FIGURE_PAD]
    # Heads: a bust as wide as everything worn on the head in that frame, from
    # the tip of the tallest hat down past the beard; a long fall of hair or a
    # hood's cape goes on below it. The creator pictures hair, headwear and
    # face items in it, where the chat's portrait would cut them.
    hbox = art.union([art.bbox(*[data[(s["name"], "idle", "south")][k][0] for k in (0, 1)])
                      for s in specs if s["kind"] != "base"])
    side = hbox[2] - hbox[0] + 2 * FIGURE_PAD
    head_rect = [hbox[0] - FIGURE_PAD, hbox[1] - FIGURE_PAD, side, side]
    for view, view_rect in (("portrait", rect), ("figure", figure_rect), ("head", head_rect)):
        for spec in specs:
            entry, palette = web_layers[spec["name"]]
            f, l = data[(spec["name"], "idle", "south")][0][0], data[(spec["name"], "idle", "south")][1][0]
            name = f"{view}_{spec['name']}.png"
            files[name] = png_bytes(crop_indexed(f, l, palette, view_rect))
            entry[view] = {"file": name}
            if spec.get("hair") == "clip":
                cover = art.cover_mask(f, l)
                files[f"{view}_{spec['name']}_mask.png"] = png_bytes(crop_mask(f, cover, view_rect))
                entry[f"{view}Mask"] = {"file": f"{view}_{spec['name']}_mask.png"}

    # Bounds of each body: where its head and feet are inside the box.
    bodies = {}
    for spec in specs:
        if spec["kind"] == "base" and spec["body"] not in bodies:
            f, l = data[(spec["name"], "idle", "south")][0][0], data[(spec["name"], "idle", "south")][1][0]
            b = art.bbox(f, l)
            bodies[spec["body"]] = {"top": b[1] - box[1], "foot": b[3] - 1 - box[1]}

    versions = {name: hashlib.sha1(body).hexdigest()[:10] for name, body in files.items()}

    def url(name):
        return f"{URL}/{name}?vsn={versions[name]}"

    layers_json = {}
    for name, (entry, _palette) in sorted(web_layers.items()):
        for anim, a in entry["anims"].items():
            a["url"] = url(a.pop("file"))
        for anim, a in entry.get("mask", {}).items():
            a["url"] = url(a.pop("file"))
        for key in ("portrait", "portraitMask", "figure", "figureMask", "head", "headMask"):
            if key in entry:
                entry[key]["url"] = url(entry[key].pop("file"))
        layers_json[name] = entry

    items = {
        "bodies": [b["id"] for b in catalog["bodies"]],
        "outfits": {o["id"]: {"channels": o["channels"]} for o in catalog["outfits"]},
        "bases": sorted(catalog["bases"]),
        "hair": [h["id"] for h in catalog["hair"]],
        "headwear": {h["id"]: {"channels": h["channels"], "hair": h["hair"]} for h in catalog["headwear"]},
        "face": {f["id"]: {"channel": f["channel"]} for f in catalog["face"]},
    }
    ramps = palettes(catalog)
    web = {
        "canvas": canvas,
        "box": [box[0], box[1], box[2] - box[0], box[3] - box[1]],
        "dirs": dirs,
        "anims": {c["anim"]: {"frames": counts[c["anim"]], "ms": c["ms"]} for c in clips},
        "bodies": bodies,
        "channelPalette": CHANNEL_PALETTE,
        "palettes": ramps,
        "portrait": {"rect": rect},
        "figure": {"rect": figure_rect},
        "head": {"rect": head_rect},
        "items": items,
        "layers": layers_json,
        "default": catalog["default"],
    }
    web["v"] = hashlib.sha1(json.dumps(web, sort_keys=True).encode()).hexdigest()[:10]
    files["catalog.json"] = (json.dumps(web, sort_keys=True, separators=(",", ":")) + "\n").encode()

    domain = {
        "version": catalog["version"],
        "bodies": items["bodies"],
        "outfits": {o: len(v["channels"]) for o, v in items["outfits"].items()},
        "bases": items["bases"],
        "hair": items["hair"],
        "headwear": {h: len(v["channels"]) for h, v in items["headwear"].items()},
        "face": {f["id"]: CHANNEL_PALETTE[f["channel"]] for f in catalog["face"]},
        "palettes": {name: len(r) for name, r in ramps.items()},
        "default": catalog["default"],
        "portrait_version": web["v"],
    }
    outputs = {os.path.join(out_dir, name): body for name, body in files.items()}
    outputs[DOMAIN_OUT] = (json.dumps(domain, indent=2, sort_keys=True) + "\n").encode()
    outputs[CSS_OUT] = swatch_css(catalog, ramps).encode()
    if write:
        # The folder holds this build's sheets and nothing else: a piece taken
        # out of the catalog takes its sheets with it.
        if os.path.isdir(out_dir):
            for name in os.listdir(out_dir):
                if os.path.join(out_dir, name) not in outputs:
                    os.remove(os.path.join(out_dir, name))
        for path, body in outputs.items():
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as handle:
                handle.write(body)
    return outputs


def pack(data, layer, anim, dirs, count, palette):
    """One indexed sheet: rows the facings, columns the frames, each cell the
    union of the layer's pixels for the clip. Returns (image, cell, origin)."""
    cell_box = art.union([art.bbox(f, l) for d in dirs for f, l in zip(*data[(layer, anim, d)])])
    if cell_box is None:
        cell_box = (0, 0, 1, 1)
    x0, y0, x1, y1 = cell_box
    cw, ch = x1 - x0, y1 - y0
    sheet = [0] * (cw * count * ch * len(dirs))
    width = cw * count
    for row, d in enumerate(dirs):
        frames, labels = data[(layer, anim, d)]
        for col, (f, l) in enumerate(zip(frames, labels)):
            idx = art.indices(f, l, palette)
            for y in range(ch):
                src = (y0 + y) * f.w + x0
                dst = (row * ch + y) * width + col * cw
                sheet[dst:dst + cw] = idx[src:src + cw]
    return art.indexed_image((width, ch * len(dirs)), sheet, palette), [cw, ch], [x0, y0]


def mask_palette():
    p = art.Palette({}, [(0, 0, 0)])
    return p


def pack_mask(data, layer, anim, dirs, count):
    masks = {}
    for d in dirs:
        frames, labels = data[(layer, anim, d)]
        masks[d] = [art.cover_mask(f, l) for f, l in zip(frames, labels)]
    w = data[(layer, anim, dirs[0])][0][0].w
    boxes = []
    for d in dirs:
        for m in masks[d]:
            pts = [i for i, on in enumerate(m) if on]
            if pts:
                xs = [i % w for i in pts]
                ys = [i // w for i in pts]
                boxes.append((min(xs), min(ys), max(xs) + 1, max(ys) + 1))
    cell_box = art.union(boxes) or (0, 0, 1, 1)
    x0, y0, x1, y1 = cell_box
    cw, ch = x1 - x0, y1 - y0
    width = cw * count
    sheet = [0] * (width * ch * len(dirs))
    for row, d in enumerate(dirs):
        for col, m in enumerate(masks[d]):
            for y in range(ch):
                for x in range(cw):
                    if m[(y0 + y) * w + x0 + x]:
                        sheet[(row * ch + y) * width + col * cw + x] = 1
    return art.indexed_image((width, ch * len(dirs)), sheet, mask_palette()), [cw, ch], [x0, y0]


def crop_indexed(frame, labels, palette, rect):
    x, y, w, h = rect
    idx = art.indices(frame, labels, palette)
    out = [0] * (w * h)
    for yy in range(h):
        for xx in range(w):
            sx, sy = x + xx, y + yy
            if 0 <= sx < frame.w and 0 <= sy < frame.h:
                out[yy * w + xx] = idx[sy * frame.w + sx]
    return art.indexed_image((w, h), out, palette)


def crop_mask(frame, cover, rect):
    x, y, w, h = rect
    out = [0] * (w * h)
    for yy in range(h):
        for xx in range(w):
            sx, sy = x + xx, y + yy
            if 0 <= sx < frame.w and 0 <= sy < frame.h and cover[sy * frame.w + sx]:
                out[yy * w + xx] = 1
    return art.indexed_image((w, h), out, mask_palette())


def png_bytes(image):
    return art.encode_png8(image)


def swatch_css(catalog, ramps):
    lines = ["/* Generated by virtual.space/tools/build_creator.py -- do not edit.",
             "   One class per colour the character creator offers: the swatch shows the",
             "   colour's middle shade. */", ""]
    for name, entries in sorted(ramps.items()):
        for i, shades in enumerate(entries):
            mid = shades[len(shades) // 2]
            lines.append(f".rh-creator-swatch--{name}-{i} {{ background-color: rgb({mid[0]} {mid[1]} {mid[2]}); }}")
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail if the built files are out of date")
    args = parser.parse_args(argv)
    with open(os.path.join(CREATOR, "catalog_src.json")) as handle:
        catalog = json.load(handle)
    outputs = build(catalog, os.path.join(CREATOR, "raw"), OUT, write=not args.check)
    if args.check:
        stale = []
        for path, body in outputs.items():
            if not os.path.exists(path):
                stale.append(path)
                continue
            with open(path, "rb") as handle:
                if handle.read() != body:
                    stale.append(path)
        extra = [os.path.join(OUT, n) for n in os.listdir(OUT) if os.path.join(OUT, n) not in outputs]
        import creator_contact_sheet
        with open(os.path.join(OUT, "catalog.json")) as handle:
            goldens = creator_contact_sheet.stale_goldens(json.load(handle))
        if stale or extra or goldens:
            for label, paths in (("stale", stale), ("not built", extra), ("golden portrait out of date", goldens)):
                for path in paths:
                    print(f"{label}: {os.path.relpath(path, REPO)}")
            print("run python3 virtual.space/tools/build_creator.py")
            return 1
    if not args.check:
        # The portraits the server must draw byte for byte the same.
        import creator_contact_sheet
        with open(os.path.join(OUT, "catalog.json")) as handle:
            creator_contact_sheet.write_goldens(json.load(handle))
    print(f"OK creator: {len(outputs)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
