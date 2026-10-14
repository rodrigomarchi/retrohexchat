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
mode, the one that keeps the piece's own look. The clips with no template (sit,
wave, dance) are posed from skeletons (``creator_pose.py``) with ``animate-with-skeleton-v3``,
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
import contextlib
import io
import json
import os
import socket
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
# Jobs sent and not yet seen to end, and the lock that keeps one run at a time.
PENDING = os.path.join(CREATOR, "pending.json")
LOCK = os.path.join(CREATOR, ".generate.lock")
# Facings a review sent back: generated again, the new take replacing the old.
REDO = os.path.join(CREATOR, "redo.json")
RAW = os.path.join(CREATOR, "raw")
API = "https://api.pixellab.ai/v2"
USER_AGENT = "retrohexchat-character-creator/1"
# What a job costs, measured: a skeleton-v3 template facing is 3 generations,
# a posed facing 2 up to three frames and 3 beyond.
ESTIMATE = {"template": 3, "pose": 2, "long pose": 3}


def layers(catalog):
    """[(layer name, PixelLab character id)] for every piece of the catalog."""
    out = [(f"base-{key.replace('/', '-')}", cid) for key, cid in sorted(catalog["bases"].items())]
    for kind, prefix in (("hair", "hair"), ("headwear", "hat"), ("face", "face")):
        for item in catalog[kind]:
            out.append((f"{prefix}-{item['id']}", item["character"]))
    return out


def clip_name(anim):
    return f"cc_{anim}"


def clip_sources(character, group_id, clip, redone=None):
    """{facing: (animation, direction entry)} of a template clip, as PixelLab
    holds it.

    What a clip is comes from PixelLab, not from a file here: every animation
    names the template it was made from (`animation_type`), so a walk can
    never be taken for an idle. A facing comes from the registered group when
    that group has it -- a piece made before may also carry leftovers of the
    same template from an experiment -- and otherwise from the group of the
    clip's template holding the most facings, the same one every time. A
    facing a review sent back (`redone`: {facing: group}) comes from its new
    group once that group has its frames."""
    template = clip["template"]
    own = [a for a in character.get("animations", []) if a.get("animation_type") == template]
    registered = [a for a in own if group_id and a.get("animation_group_id") == group_id]
    others = sorted((a for a in own if a not in registered),
                    key=lambda a: (-len(a.get("directions", [])), a.get("animation_group_id") or ""))
    out = {}
    for facing, group in sorted((redone or {}).items()):
        for animation in own:
            if animation.get("animation_group_id") != group:
                continue
            for d in animation.get("directions", []):
                if d["direction"] == facing and d.get("frame_count", len(d.get("frames", []))) > 0:
                    out.setdefault(facing, (animation, d))
    for animation in registered + others:
        for d in animation.get("directions", []):
            if d.get("frame_count", len(d.get("frames", []))) > 0:
                out.setdefault(d["direction"], (animation, d))
    return out


def redone_groups(registry, cid, anim):
    """{facing: group} of a template clip's facings generated again."""
    entry = registry.get("characters", {}).get(cid, {}).get("redone", {}).get(anim, {})
    return {d: v["group"] for d, v in entry.items() if v.get("group")}


def redo_jobs(catalog, registry, redo):
    """The facings of `redo` ([{layer, anim, dir, round?}]) not yet generated
    again in their round: [(layer, character id, clip, direction, round)]."""
    cids = dict(layers(catalog))
    clips = {c["anim"]: c for c in catalog["clips"]}
    out = []
    for item in redo:
        layer, anim, d, rnd = item["layer"], item["anim"], item["dir"], item.get("round", 1)
        if layer not in cids or anim not in clips or d not in catalog["dirs"]:
            raise ValueError(f"redo: no {layer} {anim} {d} in the catalog")
        done = registry.get("characters", {}).get(cids[layer], {}).get("redone", {}).get(anim, {}).get(d, {})
        if done.get("round", 0) < rnd:
            out.append((layer, cids[layer], clips[anim], d, rnd))
    return out


def record_redo(registry, layer, cid, anim, d, rnd, group):
    """Note a facing generated again: its round, and its new group if a template's."""
    entry = registry.setdefault("characters", {}).setdefault(cid, {"layer": layer, "groups": {}})
    entry.setdefault("redone", {}).setdefault(anim, {})[d] = {"round": rnd, "group": group}


def changed_facings(old, new):
    """(anim, facing) whose frames now come from another group than the
    sources.json written with them said: their files on disk are stale."""
    return sorted((anim, d) for anim, per in new.items() for d, src in per.items()
                  if anim in old and d in old[anim] and old[anim][d].get("group") != src.get("group"))


def done_directions(character, group_id, clip, redone=None):
    """Facings a character already has for a template clip (see clip_sources)."""
    return set(clip_sources(character, group_id, clip, redone))


def append_group(character, group_id, clip):
    """The group a new facing of a template clip joins: the registered one, or
    the one already holding most of the clip, so a clip stays one group."""
    if group_id:
        return group_id
    sources = clip_sources(character, None, clip)
    if not sources:
        return None
    counts = {}
    for animation, _d in sources.values():
        counts[animation["animation_group_id"]] = counts.get(animation["animation_group_id"], 0) + 1
    return max(sorted(counts), key=lambda g: counts[g])


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
                have = done_directions(character, groups.get(anim), clip, redone_groups(registry, cid, anim))
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
        sources = clip_sources(character, groups.get(anim), clip, redone_groups(registry, cid, anim))
        for direction, (_animation, d) in sorted(sources.items()):
            for i, url in enumerate(d.get("frames", [])):
                out.append((url, os.path.join(layer, anim, direction, f"{i}.png")))
    return out


def frame_sources(catalog, registry, cid, character):
    """{anim: {facing: {"template", "group"}}}: where each fetched template
    clip came from, written beside the frames so the build can check it."""
    groups = registry.get("characters", {}).get(cid, {}).get("groups", {})
    out = {}
    for clip in catalog["clips"]:
        if "template" in clip:
            out[clip["anim"]] = {
                direction: {"template": animation.get("animation_type"), "group": animation.get("animation_group_id")}
                for direction, (animation, _d) in sorted(clip_sources(
                    character, groups.get(clip["anim"]), clip, redone_groups(registry, cid, clip["anim"])).items())}
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


def ipv4_first(addresses):
    """getaddrinfo's answer with the IPv4 addresses first. The frames' CDN
    answers over IPv6 with addresses some networks cannot reach, and every
    one of them is waited out to its timeout before IPv4 is tried."""
    return sorted(addresses, key=lambda info: info[0] != socket.AF_INET)


def _prefer_ipv4():
    resolve = socket.getaddrinfo
    if getattr(resolve, "ipv4_first", False):
        return

    def getaddrinfo(*args, **kwargs):
        return ipv4_first(resolve(*args, **kwargs))

    getaddrinfo.ipv4_first = True
    socket.getaddrinfo = getaddrinfo


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


def merge_registry(on_disk, mine):
    """`mine` laid over `on_disk`, group by group: another run adding pieces at
    the same time keeps the groups it wrote. Facings generated again merge
    the same way, the later round winning."""
    out = {"characters": {}}
    for cid, e in on_disk.get("characters", {}).items():
        out["characters"][cid] = {"layer": e.get("layer"), "groups": dict(e.get("groups", {}))}
        if e.get("redone"):
            out["characters"][cid]["redone"] = {a: dict(per) for a, per in e["redone"].items()}
    for cid, entry in mine.get("characters", {}).items():
        target = out["characters"].setdefault(cid, {"layer": entry.get("layer"), "groups": {}})
        target["layer"] = entry.get("layer", target.get("layer"))
        target["groups"].update(entry.get("groups", {}))
        for anim, per in entry.get("redone", {}).items():
            have = target.setdefault("redone", {}).setdefault(anim, {})
            for d, v in per.items():
                if v.get("round", 0) >= have.get(d, {}).get("round", 0):
                    have[d] = dict(v)
    return out


def _save_registry(registry):
    merged = merge_registry(_load(REGISTRY, {"characters": {}}), registry)
    registry["characters"] = merged["characters"]
    with open(REGISTRY, "w") as handle:
        json.dump(merged, handle, indent=2, sort_keys=True)
        handle.write("\n")


def _raw_exists(layer, anim, d):
    return os.path.exists(os.path.join(RAW, layer, anim, d, "0.png"))


def _balance():
    return float(_request("GET", "/balance")["subscription"]["generations"])


def _submit(catalog, registry, layer, cid, clip, d, characters, redo=False):
    """Send one facing's job: (job id, the template group it lands in or None).
    A facing generated again goes to a group of its own, so the old take stays
    until the new one is there."""
    anim = clip["anim"]
    if "template" in clip:
        entry = registry.setdefault("characters", {}).setdefault(cid, {"layer": layer, "groups": {}})
        body = {"character_id": cid, "template_animation_id": clip["template"], "mode": "skeleton-v3",
                "directions": [d], "animation_name": clip_name(anim)}
        group = None if redo else append_group(characters[cid], entry["groups"].get(anim), clip)
        if group:
            body["animation_group_id"] = group
        response = _request("POST", "/animate-character", body)
        if response.get("animation_group_id") and not redo:
            entry["groups"][anim] = response["animation_group_id"]
            _save_registry(registry)
        return response["background_job_ids"][0], response.get("animation_group_id")
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
    first, frames = creator_pose.posed_clip(master["skeletons"], d, clip["pose"], clip["steps"],
                                            rotation.width / size, pad / size)
    own = character.get("skeletons", {}).get("2d_references", {}).get(d)
    if own:  # the piece's own skeleton of its first frame, when it has one
        first = [{"label": l, "x": own["keypoints"][l]["x"] * rotation.width / size + pad / size,
                  "y": own["keypoints"][l]["y"] * rotation.width / size + pad / size}
                 for l in sorted(own["keypoints"])]
    body = {"description": posed_description(character, layer),
            "action": creator_pose.POSES[clip["pose"]][1],
            "direction": d, "view": "low top-down",
            "first_frame": {"type": "base64", "base64": base64.b64encode(buffer.getvalue()).decode()},
            "first_frame_keypoints": first, "keypoints": frames, "template_id": "mannequin",
            "no_background": True}
    return _request("POST", "/animate-with-skeleton-v3", body)["background_job_id"], None


POSED_PERSON = "pixel art RPG character, an adult person of average build"


def posed_description(character, layer):
    """What a posed job is told the character looks like. A state keeps the
    master's prompt -- a bald mannequin, no accessories -- and PixelLab
    follows the words over the first frame: a hair or a hat told that way
    comes out bald. So the piece is described by its own state edit, its
    first clause, and an outfit keeps the bald head the overlays go on."""
    edit = ((character.get("style_settings") or {}).get("state_source") or {}).get("edit_description")
    if not edit:
        return character.get("prompt", "a person")[:300]
    piece = edit.split(";")[0].strip()
    if piece.startswith("add only "):
        piece = piece[len("add only "):]
    bald = ", with a completely bald head" if layer.startswith("base-") else ""
    text = f"{POSED_PERSON} {piece}{bald}"
    if len(text) > 300:
        text = text[:300].rsplit(" ", 1)[0]
    return text


def _write_posed(layer, anim, d, job):
    images = (job.get("last_response") or {}).get("images") or []
    if not images:
        return 0
    folder = os.path.join(RAW, layer, anim, d)
    os.makedirs(folder, exist_ok=True)
    for name in os.listdir(folder):  # a take generated again replaces the old one whole
        if name.endswith(".png"):
            os.remove(os.path.join(folder, name))
    for i, image in enumerate(images):
        data = image["base64"] if isinstance(image, dict) else image
        with open(os.path.join(folder, f"{i}.png"), "wb") as handle:
            handle.write(base64.b64decode(data))
    return len(images)


def _characters(catalog):
    ids = {cid for _layer, cid in layers(catalog)} | {catalog["master"]}
    return {cid: _request("GET", f"/characters/{cid}") for cid in sorted(ids)}


def cost_of(clip):
    if "template" in clip:
        return ESTIMATE["template"]
    return ESTIMATE["pose" if len(clip["steps"]) <= 3 else "long pose"]


def within_budget(submitted, cost, budget):
    """Whether one more job fits in this run's budget. The run counts what it
    sent, each job at its cost, and not the account's balance: another run
    spending beside it, or a job not charged yet, would make that lie."""
    return submitted + cost <= budget


class Locked(SystemExit):
    pass


def acquire_lock(path, pid=None, alive=None, others=None):
    """Make this the only run: two runs side by side each plan from what they
    saw at their start, so both pay for the same facing. Refuses while the pid
    in `path` is alive, or while any other `creator_generate.py run` process
    is (one started without the lock counts too); a lock left by a run that
    died is taken over."""
    pid = pid or os.getpid()
    alive = alive or _alive
    running = (others or _other_runs)(pid)
    if running:
        raise Locked(f"another run is generating (pid {', '.join(map(str, running))}); wait for it to end")
    if os.path.exists(path):
        with open(path) as handle:
            text = handle.read().strip()
        if text.isdigit() and int(text) != pid and alive(int(text)):
            raise Locked(f"another run (pid {text}) is generating; wait for it to end")
    with open(path, "w") as handle:
        handle.write(str(pid))


def _other_runs(pid):
    """Pids of other `creator_generate.py run` processes on this machine."""
    import subprocess
    out = subprocess.run(["ps", "-axo", "pid=,ppid=,command="], capture_output=True, text=True).stdout
    return other_runs(out, pid)


def other_runs(ps_output, pid):
    """From `ps -axo pid=,ppid=,command=`: the python processes running
    `creator_generate.py run`, but not this one nor the shells that started
    it (their command line names the run too)."""
    procs = {}
    for line in ps_output.splitlines():
        fields = line.split(None, 2)
        if len(fields) == 3 and fields[0].isdigit() and fields[1].isdigit():
            procs[int(fields[0])] = (int(fields[1]), fields[2])
    mine, cur = set(), pid
    while cur in procs and cur not in mine:
        mine.add(cur)
        cur = procs[cur][0]
    mine.add(pid)
    return [p for p, (_pp, command) in sorted(procs.items())
            if p not in mine and "creator_generate.py run" in command
            and "python" in os.path.basename(command.split()[0]).lower()]


def _alive(pid):
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def load_pending(path):
    """{job id: {layer, cid, anim, dir}}: every job sent and not yet seen to
    end. Written before a job is waited on, so a run that stops loses nothing
    it paid for: the next one finishes reading it."""
    return _load(path, {})


def save_pending(path, pending):
    if not pending:
        if os.path.exists(path):
            os.remove(path)
        return
    with open(path, "w") as handle:
        json.dump(pending, handle, indent=2, sort_keys=True)
        handle.write("\n")


def run(catalog, registry, budget, slots, retries=3, only=None, redo=()):
    acquire_lock(LOCK)
    try:
        _run(catalog, registry, budget, slots, retries, only, redo)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.remove(LOCK)


def _run(catalog, registry, budget, slots, retries, only, redo=()):
    characters = _characters(catalog)
    clips = {c["anim"]: c for c in catalog["clips"]}
    pending = load_pending(PENDING)
    # Jobs a run before this one sent and never saw end are waited on first.
    for job_id, p in list(pending.items()):
        if p["anim"] not in clips:  # a clip taken out of the catalog since
            print(f"  dropping job {job_id}: no clip {p['anim']} in the catalog now")
            pending.pop(job_id)
    active = {job_id: (p["layer"], p["cid"], clips[p["anim"]], p["dir"]) for job_id, p in pending.items()}
    in_flight = {(t[0], t[2]["anim"], t[3]) for t in active.values()}
    queue = [job for job in plan(catalog, registry, characters, _raw_exists)
             if (not only or job[0] in only) and (job[0], job[2]["anim"], job[3]) not in in_flight]
    # Facings a review sent back, after what is missing. Their round is kept
    # with the job, so a run stopped halfway still records them right.
    rounds = {(p["layer"], p["anim"], p["dir"]): p["redo"] for p in pending.values() if p.get("redo")}
    planned = {(job[0], job[2]["anim"], job[3]) for job in queue}
    for layer, cid, clip, d, rnd in redo_jobs(catalog, registry, redo):
        key = (layer, clip["anim"], d)
        if (not only or layer in only) and key not in in_flight and key not in planned:
            queue.append((layer, cid, clip, d))
            rounds[key] = rnd
    cost = sum(cost_of(job[2]) for job in queue)
    start = _balance()
    print(f"{len(queue)} jobs to run (~{cost} generations), {len(active)} still running from before, "
          f"{start:.1f} generations available, budget {budget}")
    if cost > budget:
        print(f"  the budget covers part of the plan: about {budget} of {cost}")
    attempts = {}
    submitted = 0

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
            if not within_budget(submitted, cost_of(clip), budget):
                print(f"budget reached ({submitted} sent, {len(active)} running); {len(queue)} jobs left")
                queue = []
                break
            queue.pop(0)
            again_round = rounds.get((layer, clip["anim"], d))
            if "template" in clip and not again_round:
                # Asked again right before paying: whatever PixelLab holds now
                # is the truth, not what was planned an hour ago.
                characters[cid] = _request("GET", f"/characters/{cid}")
                group = registry.get("characters", {}).get(cid, {}).get("groups", {}).get(clip["anim"])
                if d in done_directions(characters[cid], group, clip):
                    print(f"  already there: {layer} {clip['anim']} {d}")
                    continue
            try:
                job_id, group = _submit(catalog, registry, layer, cid, clip, d, characters,
                                        redo=bool(again_round))
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
            pending[job_id] = {"layer": layer, "cid": cid, "anim": clip["anim"], "dir": d}
            if again_round:
                pending[job_id].update({"redo": again_round, "group": group})
            save_pending(PENDING, pending)
            submitted += cost_of(clip)
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
            layer, cid, clip, d = task
            if job["status"] == "completed" and ("template" in clip or _write_posed(layer, clip["anim"], d, job)):
                sent = pending.get(job_id, {})
                if sent.get("redo") and "template" in clip and not sent.get("group"):
                    # Without its group the new take cannot be told from the
                    # old: left unrecorded, so the plan lists it again.
                    print(f"  WARNING {layer} {clip['anim']} {d}: done, but PixelLab named no group;"
                          f" job {job_id} is not recorded as redone")
                elif sent.get("redo"):
                    record_redo(registry, layer, cid, clip["anim"], d, sent["redo"], sent.get("group"))
                    _save_registry(registry)
                print(f"  done {layer} {clip['anim']} {d}" + (" (again)" if sent.get("redo") else ""))
            else:
                again(task, "job failed" if job["status"] == "failed" else "no frames in the answer")
            del active[job_id]
            pending.pop(job_id, None)
            save_pending(PENDING, pending)
    print(f"finished; sent {submitted}, the balance moved {start - _balance():.1f}")


def fetch(catalog, registry, force=False):
    characters = _characters(catalog)
    fetched = kept = 0
    for layer, cid in layers(catalog):
        downloads = frame_downloads(catalog, registry, layer, cid, characters[cid])
        sources = frame_sources(catalog, registry, cid, characters[cid])
        old = os.path.join(RAW, layer, "sources.json")
        if os.path.exists(old) and not force:
            # A facing generated again: its old frames go, the new ones come.
            with open(old) as handle:
                for anim, d in changed_facings(json.load(handle), sources):
                    folder = os.path.join(RAW, layer, anim, d)
                    for name in os.listdir(folder) if os.path.isdir(folder) else []:
                        os.remove(os.path.join(folder, name))
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
        # Which template and group every clip's frames came from, for the
        # build to check against the catalog.
        with open(os.path.join(RAW, layer, "sources.json"), "w") as handle:
            json.dump(sources, handle, indent=1, sort_keys=True)
            handle.write("\n")
    print(f"OK creator frames: fetched={fetched} kept={kept}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("command", choices=["plan", "run", "fetch"])
    parser.add_argument("--budget", type=float, default=0, help="most generations to spend (run)")
    parser.add_argument("--slots", type=int, default=8, help="jobs running at once (run)")
    parser.add_argument("--force", action="store_true", help="re-download frames already on disk (fetch)")
    parser.add_argument("--only", nargs="+", metavar="LAYER",
                        help="run only these layers (run)")
    args = parser.parse_args(argv)
    _prefer_ipv4()
    catalog = _load(CATALOG, None)
    registry = _load(REGISTRY, {"characters": {}})
    if args.command == "plan":
        characters = _characters(catalog)
        jobs = plan(catalog, registry, characters, _raw_exists)
        planned = {(j[0], j[2]["anim"], j[3]) for j in jobs}
        jobs += [j[:4] for j in redo_jobs(catalog, registry, _load(REDO, []))
                 if (j[0], j[2]["anim"], j[3]) not in planned]
        for layer, _cid, clip, d in jobs:
            print(layer, clip["anim"], d)
        print(f"{len(jobs)} jobs, ~{sum(cost_of(j[2]) for j in jobs)} generations", file=sys.stderr)
    elif args.command == "run":
        if args.budget <= 0:
            raise SystemExit("give --budget, the most generations this run may spend")
        run(catalog, registry, args.budget, args.slots, only=set(args.only or ()), redo=_load(REDO, []))
    else:
        fetch(catalog, registry, args.force)
    return 0


if __name__ == "__main__":
    sys.exit(main())
