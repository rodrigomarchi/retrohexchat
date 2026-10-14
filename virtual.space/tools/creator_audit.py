#!/usr/bin/env python3
"""Audit the character creator's raw frames before anyone looks at them.

Every piece is a state of one master mannequin animated on the same skeleton,
so two numbers say a lot about a generated facing without an eye on it:

  * **body** -- how well the figure's silhouette below the head lies on the
    master's same frame (intersection over union). A wrong facing, a wrong
    clip or a broken pose falls well below the rest.
  * **piece** -- for hair, headwear and face items, how many pixels the
    build's own extractor takes as the piece in a frame, against the same
    piece standing idle in the same facing. A hat that vanished, or a hair
    drawn bald, falls towards 0.

It prints the facings below the thresholds and writes, with `--redo`, the
facings whose piece fell away as a list in `redo.json`'s shape, for a person
to read through before `creator_generate.py run` spends anything on it.
Review sheets are still for the eye: these numbers find what is missing or
misplaced, not what is ugly.

    python3 virtual.space/tools/creator_audit.py
    python3 virtual.space/tools/creator_audit.py --redo candidates.json
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from concurrent.futures import ProcessPoolExecutor

from PIL import Image, ImageChops

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)

import build_creator as build  # noqa: E402
import creator_art as art  # noqa: E402

CREATOR = build.CREATOR
RAW = os.path.join(CREATOR, "raw")
CATALOG = os.path.join(CREATOR, "catalog_src.json")
# A body below this against the master's frame is worth a look.
BODY_MIN = 0.45
# A piece keeping less than this share of its idle size has fallen away. In
# a posed clip the head stays up as in the idle, so the piece must stay
# whole; in a template clip a turn of the head hides some of it, and lying
# down (the clips below) may hide it all, so there only the body is judged.
PIECE_MIN = {"posed": 0.75, "template": 0.25}
LYING = {"ko", "getup"}
# A piece showing fewer pixels than this idle in a facing (glasses seen from
# behind) is barely there; its few pixels come and go and say nothing.
MIN_VISIBLE = 30
# The body is compared from this far down the master's figure: the head, where
# the pieces go, is left out.
BODY_FROM = 0.30


def silhouette(image):
    """The opaque pixels of an RGBA image, as a 1-bit mask."""
    return image.getchannel("A").point(lambda a: 255 if a >= 128 else 0).convert("1")


def area(mask):
    return mask.convert("L").histogram()[255]


def body_match(mask, master):
    """IoU of two silhouettes below the head of the master's figure."""
    box = master.getbbox()
    if box is None:
        return 1.0
    cut = box[1] + int((box[3] - box[1]) * BODY_FROM)
    a, b = mask.copy(), master.copy()
    a.paste(0, (0, 0, a.width, cut))
    b.paste(0, (0, 0, b.width, cut))
    union = area(ImageChops.logical_or(a, b))
    return area(ImageChops.logical_and(a, b)) / union if union else 1.0


def piece_shares(counts, idle):
    """Each frame's piece size as a share of the idle frames' median size; all
    1.0 where the piece is barely seen idle (MIN_VISIBLE)."""
    ordered = sorted(idle)
    ref = ordered[len(ordered) // 2] if ordered else 0
    return [c / ref if ref >= MIN_VISIBLE else 1.0 for c in counts]


def _measure(job):
    """One layer's numbers: {anim|facing: {"body": [..], "piece": [..]}}."""
    spec, master, catalog = job
    canvas, out = catalog["canvas"], {}
    for clip in catalog["clips"]:
        for d in catalog["dirs"]:
            frames = build.load_frames(RAW, spec["name"], clip["anim"], [d], canvas)[d]
            ref = build.load_frames(RAW, master, clip["anim"], [d], canvas)[d]
            images = [Image.frombytes("RGBA", (f.w, f.h), bytes(c for p in f.px for c in p)) for f in frames]
            refs = [Image.frombytes("RGBA", (f.w, f.h), bytes(c for p in f.px for c in p)) for f in ref]
            row = {"body": [round(body_match(silhouette(im), silhouette(refs[min(i, len(refs) - 1)])), 3)
                            for i, im in enumerate(images)]}
            if spec["kind"] != "base":
                row["piece"] = [sum(1 for label in art.overlay(f, spec["keys"]) if label is not art.TRANSPARENT)
                                for f in frames]
            out[f"{clip['anim']}|{d}"] = row
    return spec["name"], out


def measure(catalog):
    specs = build.layer_specs(catalog)
    master = next(s["name"] for s in specs if s["kind"] == "base"
                  and catalog["bases"][f"{s['body']}/{s['outfit']}"] == catalog["master"])
    with ProcessPoolExecutor() as pool:
        return dict(pool.map(_measure, [(s, master, catalog) for s in specs]))


def piece_min(clip):
    """The least share of its idle size a piece may keep in this clip, or None."""
    if clip["anim"] in LYING:
        return None
    return PIECE_MIN["template" if "template" in clip else "posed"]


def findings(catalog, numbers):
    """[(layer, anim, facing, what, values)] below the thresholds."""
    out = []
    for layer, per in sorted(numbers.items()):
        for clip in catalog["clips"]:
            for d in catalog["dirs"]:
                row = per[f"{clip['anim']}|{d}"]
                if min(row["body"]) < BODY_MIN:
                    out.append((layer, clip["anim"], d, "body", row["body"]))
                least = piece_min(clip)
                if "piece" in row and least is not None:
                    shares = piece_shares(row["piece"], per[f"idle|{d}"]["piece"])
                    if min(shares) < least:
                        out.append((layer, clip["anim"], d, "piece", [round(s, 2) for s in shares]))
    return out


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--redo", help="write the facings whose piece fell away to this file")
    parser.add_argument("--json", help="write every number to this file")
    args = parser.parse_args(argv)
    with open(CATALOG) as handle:
        catalog = json.load(handle)
    numbers = measure(catalog)
    found = findings(catalog, numbers)
    for layer, anim, d, what, values in found:
        print(f"{layer:12} {anim:6} {d:10} {what:5} {values}")
    print(f"{len(found)} facings to look at")
    if args.json:
        with open(args.json, "w") as handle:
            json.dump(numbers, handle, indent=1, sort_keys=True)
    if args.redo:
        items = [{"layer": l, "anim": a, "dir": d, "why": "the piece falls away (creator_audit)"}
                 for l, a, d, what, _v in found if what == "piece"]
        with open(args.redo, "w") as handle:
            json.dump(items, handle, indent=1)
            handle.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
