#!/usr/bin/env python3
"""Download the Construct's PixelLab art named in ``scenes/construct/pixellab.json``.

Each entry names the PixelLab object a piece was drawn as, and, for a piece
that moves, the animation it moves with. A still piece lands as
``scenes/construct/<kind>.png`` (the object's one rotation); an animated one as
``scenes/construct/anim/<kind>/<i>.png``, one file per frame — the layout
``author_construct.py`` reads. The art is committed: this runs when a piece is
added, never in a build.

A file already on disk is left alone unless ``--force``, so a piece whose art
was touched up by hand is not overwritten by a re-run.

    python3 virtual.space/tools/fetch_pixellab_objects.py [--force] [kind ...]
"""
import argparse
import json
import os
import sys
import urllib.request

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(TOOLS, "..", ".."))
CONSTRUCT = os.path.join(REPO, "virtual.space", "scenes", "construct")
REGISTRY = os.path.join(CONSTRUCT, "pixellab.json")


def downloads(registry, kinds=None):
    """Every (url, path relative to the construct directory) the registry asks
    for, in kind order; only `kinds` when given. An unknown kind is an error."""
    objects = registry["objects"]
    wanted = sorted(objects) if not kinds else list(kinds)
    unknown = [kind for kind in wanted if kind not in objects]
    if unknown:
        raise KeyError(f"not in pixellab.json: {', '.join(unknown)}")
    base = registry["base"].rstrip("/")
    out = []
    for kind in wanted:
        entry = objects[kind]
        root = f"{base}/{entry['object']}"
        if "animation" in entry:
            for i in range(entry["frames"]):
                url = f"{root}/animations/{entry['animation']}/unknown/{i}.png"
                out.append((url, os.path.join("anim", kind, f"{i}.png")))
        else:
            out.append((f"{root}/rotations/unknown.png", f"{kind}.png"))
    return out


# The file host refuses Python's default client name.
USER_AGENT = "retrohexchat-construct-art/1"


def _fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        body = response.read()
    if not body.startswith(b"\x89PNG"):
        raise ValueError(f"{url}: not a PNG")
    return body


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("kinds", nargs="*")
    parser.add_argument("--force", action="store_true", help="overwrite art already on disk")
    args = parser.parse_args(argv)
    with open(REGISTRY) as handle:
        registry = json.load(handle)
    fetched = kept = 0
    for url, rel in downloads(registry, args.kinds):
        path = os.path.join(CONSTRUCT, rel)
        if os.path.exists(path) and not args.force:
            kept += 1
            continue
        # Fetched before the file is opened: a failed download leaves no
        # empty PNG behind for the next run to keep.
        body = _fetch(url)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as handle:
            handle.write(body)
        fetched += 1
    print(f"OK pixellab: fetched={fetched} kept={kept}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
