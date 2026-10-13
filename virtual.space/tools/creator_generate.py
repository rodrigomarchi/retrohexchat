#!/usr/bin/env python3
"""Generate and download the animation frames of the Space character creator.

Every piece in ``virtual.space/characters/creator/catalog_src.json`` (a body
wearing an outfit, a hairstyle, a hat, a face item) is a PixelLab character: a
state of the master mannequin. This tool brings each one up to the catalog's
clips in all eight facings, then downloads the frames to
``virtual.space/characters/creator/raw/<layer>/<anim>/<dir>/<i>.png`` (and its
rotations to ``raw/<layer>/rotations/<dir>.png``), which is what
``build_creator.py`` reads. The frames are committed: this runs when a piece is
added, never in a build.

Clips with a template are posed with ``animate-character`` in ``skeleton-v3``
mode, the one that keeps the piece's own look. The seated clip has no template:
it is posed from skeletons (``creator_pose.py``) with ``animate-with-skeleton-v3``,
whose frames come back in the job instead of on the character, so they are
written straight to ``raw/`` when the job ends.

Which animation group holds which clip is kept in ``pixellab.json`` beside the
catalog, so a re-run adds missing facings to the same group instead of starting
another. The token is read from ``PIXELLAB_TOKEN``.

    python3 virtual.space/tools/creator_generate.py plan            # what is missing
    python3 virtual.space/tools/creator_generate.py run --budget 300 # queue it
    python3 virtual.space/tools/creator_generate.py fetch            # download frames
"""
from __future__ import annotations

import argparse
import base64
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)

import creator_pose  # noqa: E402

REPO = os.path.abspath(os.path.join(TOOLS, "..", ".."))
CREATOR = os.path.join(REPO, "virtual.space", "characters", "creator")
CATALOG = os.path.join(CREATOR, "catalog_src.json")
REGISTRY = os.path.join(CREATOR, "pixellab.json")
RAW = os.path.join(CREATOR, "raw")
API = "https://api.pixellab.ai/v2"
USER_AGENT = "retrohexchat-character-creator/1"
# Generations a job is assumed to cost before it reports, for the budget.
ESTIMATE = {"template": 3, "pose": 2}


def layers(catalog):
    """[(layer name, PixelLab character id)] for every piece of the catalog."""
    out = [(f"base-{key.replace('/', '-')}", cid) for key, cid in sorted(catalog["bases"].items())]
    for kind, prefix in (("hair", "hair"), ("headwear", "hat"), ("face", "face")):
        for item in catalog[kind]:
            out.append((f"{prefix}-{item['id']}", item["character"]))
    return out


def clip_name(anim):
    return f"cc_{anim}"


def done_directions(character, group_id, anim):
    """Facings a character already has for a clip: in the registered group, or
    in any group carrying the clip's display name."""
    done = set()
    for animation in character.get("animations", []):
        if animation.get("animation_group_id") == group_id or animation.get("display_name") == clip_name(anim):
            for d in animation.get("directions", []):
                if d.get("frame_count", len(d.get("frames", []))) > 0:
                    done.add(d["direction"])
    return done


def plan(catalog, registry, characters, raw_exists):
    """The jobs still to run: [(layer, character id, clip, direction)].

    `characters` maps a character id to its PixelLab JSON; `raw_exists(layer,
    anim, dir)` says whether a posed clip's frames are already on disk."""
    jobs = []
    for layer, cid in layers(catalog):
        character = characters[cid]
        groups = registry.get("characters", {}).get(cid, {}).get("groups", {})
        for clip in catalog["clips"]:
            anim = clip["anim"]
            if "template" in clip:
                have = done_directions(character, groups.get(anim), anim)
            else:
                have = {d for d in catalog["dirs"] if raw_exists(layer, anim, d)}
            for d in catalog["dirs"]:
                if d not in have:
                    jobs.append((layer, cid, clip, d))
    return jobs


def frame_downloads(catalog, registry, layer, cid, character):
    """(url, path relative to raw/) of every frame and rotation of a layer."""
    out = [(url, os.path.join(layer, "rotations", f"{d}.png"))
           for d, url in sorted(character["rotation_urls"].items())]
    groups = registry.get("characters", {}).get(cid, {}).get("groups", {})
    for clip in catalog["clips"]:
        if "template" not in clip:
            continue
        anim = clip["anim"]
        wanted = groups.get(anim)
        for animation in character.get("animations", []):
            if animation.get("animation_group_id") != wanted and animation.get("display_name") != clip_name(anim):
                continue
            for d in animation.get("directions", []):
                for i, url in enumerate(d.get("frames", [])):
                    out.append((url, os.path.join(layer, anim, d["direction"], f"{i}.png")))
    return out


# ---------------------------------------------------------------- transport

def _token():
    token = os.environ.get("PIXELLAB_TOKEN")
    if not token:
        raise SystemExit("PIXELLAB_TOKEN is not set")
    return token


def transient(error):
    """Whether a failed call is worth trying again: the service's own errors
    (PixelLab answers 5xx under load) and the network's, never a refusal."""
    if isinstance(error, urllib.error.HTTPError):
        return error.code >= 500
    return isinstance(error, (urllib.error.URLError, TimeoutError, ConnectionError))


def _retrying(call, attempts=5, wait=5.0, sleep=time.sleep):
    for attempt in range(attempts):
        try:
            return call()
        except Exception as error:  # noqa: BLE001 -- re-raised unless transient
            if attempt == attempts - 1 or not transient(error):
                raise
            print(f"  retrying after {error}")
            sleep(wait * (2 ** attempt))


def _request(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None

    def call():
        request = urllib.request.Request(f"{API}{path}", data=data, method=method, headers={
            "User-Agent": USER_AGENT, "Authorization": f"Bearer {_token()}", "Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.loads(response.read())

    # A submission is not retried: a 5xx after the job was queued would queue it twice.
    return call() if method == "POST" else _retrying(call)


def _download(url):
    def call():
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=120) as response:
            return response.read()

    body = _retrying(call)
    if not body.startswith(b"\x89PNG"):
        raise ValueError(f"{url}: not a PNG")
    return body


def _load(path, default):
    if not os.path.exists(path):
        return default
    with open(path) as handle:
        return json.load(handle)


def _save_registry(registry):
    with open(REGISTRY, "w") as handle:
        json.dump(registry, handle, indent=2, sort_keys=True)
        handle.write("\n")


def _raw_exists(layer, anim, d):
    return os.path.exists(os.path.join(RAW, layer, anim, d, "0.png"))


def _balance():
    return float(_request("GET", "/balance")["subscription"]["generations"])


def _submit(catalog, registry, layer, cid, clip, d, characters):
    anim = clip["anim"]
    if "template" in clip:
        entry = registry.setdefault("characters", {}).setdefault(cid, {"layer": layer, "groups": {}})
        body = {"character_id": cid, "template_animation_id": clip["template"], "mode": "skeleton-v3",
                "directions": [d], "animation_name": clip_name(anim)}
        if entry["groups"].get(anim):
            body["animation_group_id"] = entry["groups"][anim]
        response = _request("POST", "/animate-character", body)
        if response.get("animation_group_id"):
            entry["groups"][anim] = response["animation_group_id"]
            _save_registry(registry)
        return response["background_job_ids"][0]
    # A posed clip: the piece's rotation, centred on the clips' canvas.
    from PIL import Image
    character = characters[cid]
    rotation = Image.open(io.BytesIO(_download(character["rotation_urls"][d]))).convert("RGBA")
    size = catalog["canvas"]
    pad = (size - rotation.width) // 2
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(rotation, (pad, pad))
    buffer = io.BytesIO()
    canvas.save(buffer, format="PNG")
    master = characters[catalog["master"]]
    first, frames = creator_pose.sit_clip(master["skeletons"], d, clip["steps"],
                                          rotation.width / size, pad / size)
    own = character.get("skeletons", {}).get("2d_references", {}).get(d)
    if own:  # the piece's own skeleton of its first frame, when it has one
        first = [{"label": l, "x": own["keypoints"][l]["x"] * rotation.width / size + pad / size,
                  "y": own["keypoints"][l]["y"] * rotation.width / size + pad / size}
                 for l in sorted(own["keypoints"])]
    body = {"description": character.get("prompt", "a person")[:300],
            "action": "sitting down, alone, with no chair, no table and no furniture drawn",
            "direction": d, "view": "low top-down",
            "first_frame": {"type": "base64", "base64": base64.b64encode(buffer.getvalue()).decode()},
            "first_frame_keypoints": first, "keypoints": frames, "template_id": "mannequin",
            "no_background": True}
    return _request("POST", "/animate-with-skeleton-v3", body)["background_job_id"]


def _write_posed(layer, anim, d, job):
    images = (job.get("last_response") or {}).get("images") or []
    folder = os.path.join(RAW, layer, anim, d)
    os.makedirs(folder, exist_ok=True)
    for i, image in enumerate(images):
        data = image["base64"] if isinstance(image, dict) else image
        with open(os.path.join(folder, f"{i}.png"), "wb") as handle:
            handle.write(base64.b64decode(data))


def _characters(catalog):
    ids = {cid for _layer, cid in layers(catalog)} | {catalog["master"]}
    return {cid: _request("GET", f"/characters/{cid}") for cid in sorted(ids)}


def cost_of(clip):
    return ESTIMATE["template" if "template" in clip else "pose"]


def within_budget(spent, active_costs, cost, budget):
    """Whether one more job fits: the balance has not been charged for jobs
    still running yet, so they are counted at their estimate."""
    return spent + sum(active_costs) + cost <= budget


def run(catalog, registry, budget, slots, retries=3):
    characters = _characters(catalog)
    queue = plan(catalog, registry, characters, _raw_exists)
    start = _balance()
    print(f"{len(queue)} jobs to run, {start:.1f} generations available, budget {budget}")
    active, attempts = {}, {}

    def again(task, why):
        layer, _cid, clip, d = task
        key = (layer, clip["anim"], d)
        attempts[key] = attempts.get(key, 0) + 1
        print(f"  FAILED {layer} {clip['anim']} {d} ({why}, attempt {attempts[key]})")
        if attempts[key] < retries:
            queue.append(task)

    while queue or active:
        while queue and len(active) < slots:
            task = queue[0]
            layer, cid, clip, d = task
            spent = start - _balance()
            if not within_budget(spent, [cost_of(t[2]) for t in active.values()], cost_of(clip), budget):
                print(f"budget reached ({spent:.1f} spent, {len(active)} running); {len(queue)} jobs left")
                queue = []
                break
            queue.pop(0)
            try:
                job_id = _submit(catalog, registry, layer, cid, clip, d, characters)
            except urllib.error.HTTPError as error:
                if error.code == 409:  # the group already has this facing
                    continue
                if error.code == 429:
                    queue.insert(0, task)
                    time.sleep(30)
                    break
                # Anything else is this job's problem, not the run's: the jobs
                # already running are paid for, and a posed one's frames exist
                # only in its answer.
                again(task, f"HTTP {error.code}")
                continue
            except Exception as error:  # noqa: BLE001 -- logged and retried below
                again(task, repr(error))
                continue
            active[job_id] = task
            print(f"  queued {layer} {clip['anim']} {d}")
            time.sleep(2.5)  # the API asks for >2 s between submissions
        time.sleep(10)
        for job_id, task in list(active.items()):
            try:
                job = _request("GET", f"/background-jobs/{job_id}")
            except Exception as error:  # noqa: BLE001 -- the job is asked again next round
                print(f"  could not read job {job_id}: {error!r}")
                continue
            if job["status"] not in ("completed", "failed"):
                continue
            del active[job_id]
            layer, _cid, clip, d = task
            if job["status"] == "completed":
                if "template" not in clip:
                    _write_posed(layer, clip["anim"], d, job)
                print(f"  done {layer} {clip['anim']} {d}")
            else:
                again(task, "job failed")
    print(f"finished; spent {start - _balance():.1f} generations")


def fetch(catalog, registry, force=False):
    characters = _characters(catalog)
    fetched = kept = 0
    for layer, cid in layers(catalog):
        downloads = frame_downloads(catalog, registry, layer, cid, characters[cid])
        if force:
            # A regenerated clip may have fewer frames: none of the old stay.
            import shutil
            for folder in sorted({os.path.dirname(os.path.join(RAW, rel)) for _url, rel in downloads}):
                if os.path.basename(os.path.dirname(folder)) != layer:
                    shutil.rmtree(folder, ignore_errors=True)
        for url, rel in downloads:
            path = os.path.join(RAW, rel)
            if os.path.exists(path) and not force:
                kept += 1
                continue
            body = _download(url)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as handle:
                handle.write(body)
            fetched += 1
    print(f"OK creator frames: fetched={fetched} kept={kept}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("command", choices=["plan", "run", "fetch"])
    parser.add_argument("--budget", type=float, default=0, help="most generations to spend (run)")
    parser.add_argument("--slots", type=int, default=8, help="jobs running at once (run)")
    parser.add_argument("--force", action="store_true", help="re-download frames already on disk (fetch)")
    args = parser.parse_args(argv)
    catalog = _load(CATALOG, None)
    registry = _load(REGISTRY, {"characters": {}})
    if args.command == "plan":
        characters = _characters(catalog)
        for layer, _cid, clip, d in plan(catalog, registry, characters, _raw_exists):
            print(layer, clip["anim"], d)
    elif args.command == "run":
        if args.budget <= 0:
            raise SystemExit("give --budget, the most generations this run may spend")
        run(catalog, registry, args.budget, args.slots)
    else:
        fetch(catalog, registry, args.force)
    return 0


if __name__ == "__main__":
    sys.exit(main())
