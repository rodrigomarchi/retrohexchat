"""Pixel work behind the Space character creator: split PixelLab frames into
recolourable paper-doll layers.

Every piece of the creator is a PixelLab *state* of one master mannequin,
animated with the same skeleton, so a piece lines up with the master frame by
frame. Pieces do not differ from the master by a clean pixel diff -- each
generation redraws the whole figure a little -- so a piece says what is its own
by colour instead: hair and headwear are drawn in a key colour (vivid magenta),
an outfit's dyeable cloth in two (magenta for the main colour, cyan for the
trim). This module finds those keys, assigns every pixel of a frame to a
*channel* (skin, a key, or a fixed neutral such as the outline), and quantizes
each channel to a fixed number of shades, so that recolouring is swapping one
shade ramp for another in the PNG palette.

Pure PIL and stdlib: the tests run on the system python3.
"""
from __future__ import annotations

import colorsys
import zlib

from PIL import Image

TRANSPARENT = None
NEUTRAL = "neutral"

# What a key looks like: a hue (degrees) and how far a pixel may stray from it.
KEY_TOLERANCE = 38
KEY_MIN_SAT = 0.30
KEY_MIN_VAL = 0.14
# Skin: warm hues of the master's complexion, never grey.
SKIN_HUES = ((0, 52), (338, 360))
SKIN_SAT = (0.16, 0.88)
SKIN_MIN_VAL = 0.26
# The black outline PixelLab draws round every figure stays as drawn.
OUTLINE_VAL = 0.20
# A state tints the whole figure's outline towards its key, so a dark pixel of
# the key's hue is often the body's outline, not the piece: an overlay is grown
# only from key pixels at least this bright.
OVERLAY_SEED_VAL = 0.32


def hsv(rgb):
    """(hue degrees, saturation, value) of an (r, g, b) in 0-255."""
    h, s, v = colorsys.rgb_to_hsv(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255)
    return h * 360, s, v


def hue_distance(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


def luminance(rgb):
    return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]


def is_key(rgb, hue):
    h, s, v = hsv(rgb)
    return s >= KEY_MIN_SAT and v >= KEY_MIN_VAL and hue_distance(h, hue) <= KEY_TOLERANCE


def is_skin(rgb):
    h, s, v = hsv(rgb)
    if v < SKIN_MIN_VAL or not (SKIN_SAT[0] <= s <= SKIN_SAT[1]):
        return False
    return any(lo <= h <= hi for lo, hi in SKIN_HUES)


class Frame:
    """An RGBA frame as a flat pixel list, with its size."""

    def __init__(self, image):
        image = image.convert("RGBA")
        self.w, self.h = image.size
        flat = getattr(image, "get_flattened_data", None) or image.getdata
        self.px = [tuple(p) for p in flat()]

    def opaque(self, i):
        return self.px[i][3] >= 128

    def neighbours(self, i, diagonal=False):
        x, y = i % self.w, i // self.w
        steps = ((1, 0), (-1, 0), (0, 1), (0, -1))
        if diagonal:
            steps += ((1, 1), (1, -1), (-1, 1), (-1, -1))
        for dx, dy in steps:
            nx, ny = x + dx, y + dy
            if 0 <= nx < self.w and 0 <= ny < self.h:
                yield ny * self.w + nx


def classify(frame, keys, skin=True):
    """Assign each pixel of a *base* frame (a whole figure) to a channel.

    `keys` maps a channel name to its key hue, e.g. {"primary": 310,
    "secondary": 185}. Skin is found by its warm hue when `skin` is set.
    Anything else opaque is NEUTRAL; transparent pixels are TRANSPARENT.
    Shadows too dark or grey to show their key are claimed afterwards by the
    channel they sit inside (`_claim_shadows`).
    """
    out = []
    for i, p in enumerate(frame.px):
        if p[3] < 128:
            out.append(TRANSPARENT)
            continue
        rgb = p[:3]
        channel = next((name for name, hue in keys.items() if is_key(rgb, hue)), None)
        if channel is None and skin and is_skin(rgb):
            channel = "skin"
        out.append(channel or NEUTRAL)
    return _claim_shadows(frame, out, keys)


def _claim_shadows(frame, labels, keys, passes=2):
    """A dark or washed-out pixel inside a channel belongs to it.

    PixelLab shades a magenta cloth with near-black purples that no longer read
    as magenta; left NEUTRAL they would keep their colour while the cloth around
    them is dyed. A neutral pixel joins channel C when at least two of its four
    neighbours are C, it is not the black outline, and its hue (if it has one
    worth the name) is near C's key.
    """
    labels = list(labels)
    for _ in range(passes):
        changed = []
        for i, label in enumerate(labels):
            if label != NEUTRAL:
                continue
            h, s, v = hsv(frame.px[i][:3])
            if v < OUTLINE_VAL:
                continue
            counts = {}
            for n in frame.neighbours(i):
                c = labels[n]
                if c not in (NEUTRAL, TRANSPARENT):
                    counts[c] = counts.get(c, 0) + 1
            if not counts:
                continue
            best, count = max(counts.items(), key=lambda kv: (kv[1], kv[0]))
            if count < 2:
                continue
            if best in keys and s >= 0.10 and hue_distance(h, keys[best]) > 60:
                continue
            if best == "skin" and s >= 0.10 and not any(lo - 20 <= h <= hi + 20 for lo, hi in SKIN_HUES):
                continue
            changed.append((i, best))
        if not changed:
            break
        for i, c in changed:
            labels[i] = c
    return labels


def overlay(frame, keys):
    """Labels for an *overlay* (hair, headwear, a face item) drawn on the master.

    `keys` maps each of the piece's channels to its key hue. Only key-coloured
    pixels are the piece's own, plus the shadows and highlights inside them and
    the dark outline rimming them; the rest of the frame is the mannequin under
    it and becomes TRANSPARENT. Specks are removed.
    """
    labels = []
    for p in frame.px:
        channel = None
        if p[3] >= 128 and hsv(p[:3])[2] >= OVERLAY_SEED_VAL:
            channel = next((name for name, hue in sorted(keys.items()) if is_key(p[:3], hue)), None)
        labels.append(channel if channel else TRANSPARENT)
    # Shadows and highlights inside a key: grown from the key outwards.
    for _ in range(2):
        grown = []
        for i, label in enumerate(labels):
            if label is not TRANSPARENT or not frame.opaque(i):
                continue
            h, s, v = hsv(frame.px[i][:3])
            if v < OUTLINE_VAL:
                continue
            counts = {}
            for n in frame.neighbours(i):
                if labels[n] not in (TRANSPARENT, NEUTRAL):
                    counts[labels[n]] = counts.get(labels[n], 0) + 1
            if not counts:
                continue
            best, near = max(counts.items(), key=lambda kv: (kv[1], kv[0]))
            if near >= 2 and (s < 0.10 or hue_distance(h, keys[best]) <= 45):
                grown.append((i, best))
        for i, best in grown:
            labels[i] = best
    # Holes: a pixel of the mannequin showing through the piece, almost walled
    # in by it, is the piece's (PixelLab leaves a few in a long fall of hair).
    for _ in range(2):
        filled = []
        for i, label in enumerate(labels):
            if label is not TRANSPARENT or not frame.opaque(i):
                continue
            counts = {}
            for n in frame.neighbours(i, diagonal=True):
                if labels[n] not in (TRANSPARENT, NEUTRAL):
                    counts[labels[n]] = counts.get(labels[n], 0) + 1
            if counts:
                best, near = max(counts.items(), key=lambda kv: (kv[1], kv[0]))
                if near >= 6:
                    filled.append((i, best))
        for i, best in filled:
            labels[i] = best
    # The outline that rims the piece. Where PixelLab tinted it with the key
    # it is dyed with the piece (its darkest shade), or a recoloured hair
    # would keep a magenta edge; a plain dark outline stays as drawn.
    rim = []
    for i, label in enumerate(labels):
        if label is TRANSPARENT and frame.opaque(i) and hsv(frame.px[i][:3])[2] < OUTLINE_VAL + 0.12:
            near = [labels[n] for n in frame.neighbours(i, diagonal=True)
                    if labels[n] not in (TRANSPARENT, NEUTRAL)]
            if near:
                rim.append((i, max(set(near), key=lambda c: (near.count(c), c))))
    for i, channel in rim:
        h, sat, v = hsv(frame.px[i][:3])
        tinted = sat >= 0.35 and v >= 0.12 and hue_distance(h, keys[channel]) <= 45
        labels[i] = channel if tinted else NEUTRAL
    return keep_near_main(frame, despeckle(frame, labels))


def components(frame, member):
    """8-connected components of the pixels where member(i) is true."""
    seen = [False] * len(frame.px)
    out = []
    for start in range(len(frame.px)):
        if seen[start] or not member(start):
            continue
        seen[start] = True
        stack, comp = [start], []
        while stack:
            i = stack.pop()
            comp.append(i)
            for n in frame.neighbours(i, diagonal=True):
                if not seen[n] and member(n):
                    seen[n] = True
                    stack.append(n)
        out.append(comp)
    return out


def despeckle(frame, labels, min_area=6, share=0.04):
    """Drop the small islands a key match leaves behind (a pink lip, a stray rim)."""
    comps = components(frame, lambda i: labels[i] is not TRANSPARENT)
    if not comps:
        return labels
    largest = max(len(c) for c in comps)
    keep = max(min_area, int(largest * share))
    labels = list(labels)
    for comp in comps:
        if len(comp) < keep:
            for i in comp:
                labels[i] = TRANSPARENT
    return labels


def keep_near_main(frame, labels, share=0.15, reach=3):
    """An overlay is one piece: keep its largest part, the parts big enough to
    be a piece of their own (a lock of hair falling apart from the rest), and
    whatever lies right against the largest part; drop strays further off."""
    comps = components(frame, lambda i: labels[i] is not TRANSPARENT)
    if len(comps) < 2:
        return labels
    comps.sort(key=len, reverse=True)
    main = comps[0]
    xs = [i % frame.w for i in main]
    ys = [i // frame.w for i in main]
    x0, x1, y0, y1 = min(xs) - reach, max(xs) + reach, min(ys) - reach, max(ys) + reach
    labels = list(labels)
    for comp in comps[1:]:
        if len(comp) >= share * len(main):
            continue
        if any(x0 <= i % frame.w <= x1 and y0 <= i // frame.w <= y1 for i in comp):
            continue
        for i in comp:
            labels[i] = TRANSPARENT
    return labels


def fill_enclosed(frame, labels, channels, max_area=120, share=0.8):
    """Pale patches inside a piece become the piece: the highlights PixelLab
    paints on cloth and hair in near-white, which carry no key and would stay
    grey through a recolour, and the mannequin's scalp showing through hair.

    An island of opaque pixels that are not of the piece, not skin and not
    outline-dark is filled with the channel round it when, of the pixels on
    its rim (the dark outline aside), at least `share` are that one channel.
    An island touching the background is an edge, not a patch, and stays; so
    does one larger than `max_area` (trousers under a tunic). An island
    touching the skin stays too: a white shirt between a jacket and the neck,
    or a trouser leg between a hem and a knee."""
    channels = set(channels)

    def candidate(i):
        if labels[i] in channels or not frame.opaque(i):
            return False
        rgb = frame.px[i][:3]
        return hsv(rgb)[2] >= OUTLINE_VAL and not is_skin(rgb)

    labels = list(labels)
    for comp in components(frame, candidate):
        if len(comp) > max_area:
            continue
        inside = set(comp)
        counts, open_edge = {}, False
        for i in comp:
            for n in frame.neighbours(i):
                if n in inside:
                    continue
                if not frame.opaque(n):
                    open_edge = True
                    break
                if hsv(frame.px[n][:3])[2] < OUTLINE_VAL:
                    continue
                counts[labels[n]] = counts.get(labels[n], 0) + 1
            if open_edge:
                break
        if open_edge or not counts:
            continue
        best, n_best = max(counts.items(), key=lambda kv: (kv[1], str(kv[0])))
        if best in channels and n_best >= share * sum(counts.values()):
            for i in comp:
                labels[i] = best
    return labels


def keep_within(frame, labels, box):
    """Labels outside `box` (x0, y0, x1, y1) dropped to TRANSPARENT."""
    x0, y0, x1, y1 = box
    return [l if x0 <= i % frame.w < x1 and y0 <= i // frame.w < y1 else TRANSPARENT
            for i, l in enumerate(labels)]


def kmeans_1d(values, k, iterations=30):
    """Deterministic 1-D k-means: `k` ascending centres for `values`."""
    vals = sorted(values)
    if not vals:
        return []
    k = max(1, min(k, len(set(vals))))
    centres = [vals[min(len(vals) - 1, int((j + 0.5) * len(vals) / k))] for j in range(k)]
    for _ in range(iterations):
        buckets = [[] for _ in centres]
        for v in vals:
            j = min(range(len(centres)), key=lambda c: (abs(v - centres[c]), c))
            buckets[j].append(v)
        new = [sum(b) / len(b) if b else centres[j] for j, b in enumerate(buckets)]
        if new == centres:
            break
        centres = new
    return sorted(centres)


def shade_of(value, centres):
    return min(range(len(centres)), key=lambda c: (abs(value - centres[c]), c))


class Palette:
    """A layer's indexed palette: index 0 transparent, then each channel's
    shades dark to light, then the fixed neutral colours."""

    def __init__(self, shades, neutrals):
        # shades: {channel: [(centre luminance, (r,g,b) default colour), ...]}
        self.entries = [(0, 0, 0)]
        self.channels = {}
        for channel in sorted(shades):
            idx = []
            for _lum, rgb in shades[channel]:
                idx.append(len(self.entries))
                self.entries.append(tuple(rgb))
            self.channels[channel] = idx
        self.neutral_index = {}
        for rgb in neutrals:
            self.neutral_index[rgb] = len(self.entries)
            self.entries.append(rgb)
        if len(self.entries) > 256:
            raise ValueError(f"palette has {len(self.entries)} colours, over 256")


def build_palette(frames_labels, shades_per_channel, neutral_budget=None):
    """One palette for every frame of a layer.

    `frames_labels` is [(Frame, labels)]. Each channel is quantized to its
    shade count by luminance across all frames, so frame 3 and frame 0 use the
    same index for the same shade. Neutrals are kept exact when they fit.
    """
    per_channel = {}
    neutral_counts = {}
    for frame, labels in frames_labels:
        for p, label in zip(frame.px, labels):
            if label is TRANSPARENT:
                continue
            if label == NEUTRAL:
                neutral_counts[p[:3]] = neutral_counts.get(p[:3], 0) + 1
            else:
                per_channel.setdefault(label, []).append(p[:3])
    shades = {}
    for channel, pixels in per_channel.items():
        k = shades_per_channel[channel]
        centres = kmeans_1d([luminance(rgb) for rgb in pixels], k)
        while len(centres) < k:  # a channel too flat for k shades: repeat its lightest
            centres.append(centres[-1] + 0.001 * len(centres))
        sums = [[0, 0, 0, 0] for _ in centres]
        for rgb in pixels:
            j = shade_of(luminance(rgb), centres)
            for c in range(3):
                sums[j][c] += rgb[c]
            sums[j][3] += 1
        shades[channel] = [(centres[j], tuple(round(s[c] / s[3]) if s[3] else 0 for c in range(3)))
                           for j, s in enumerate(sums)]
    budget = 255 - sum(len(v) for v in shades.values()) if neutral_budget is None else neutral_budget
    neutrals = sorted(neutral_counts, key=lambda rgb: (-neutral_counts[rgb], rgb))
    mapping = {rgb: rgb for rgb in neutrals}
    if len(neutrals) > budget:
        kept = sorted(neutrals[:budget])
        for rgb in neutrals[budget:]:
            mapping[rgb] = min(kept, key=lambda k: (sum((a - b) ** 2 for a, b in zip(rgb, k)), k))
        neutrals = kept
    else:
        neutrals = sorted(neutrals)
    palette = Palette(shades, neutrals)
    palette.neutral_map = mapping
    palette.centres = {ch: [c for c, _ in v] for ch, v in shades.items()}
    return palette


def indices(frame, labels, palette):
    """The palette index of every pixel of a frame."""
    out = []
    for p, label in zip(frame.px, labels):
        if label is TRANSPARENT:
            out.append(0)
        elif label == NEUTRAL:
            out.append(palette.neutral_index[palette.neutral_map[p[:3]]])
        else:
            j = shade_of(luminance(p[:3]), palette.centres[label])
            out.append(palette.channels[label][j])
    return out


def indexed_image(size, data, palette):
    """A mode-P image whose index 0 is transparent."""
    image = Image.new("P", size)
    flat = []
    for rgb in palette.entries:
        flat.extend(rgb)
    flat.extend([0] * (768 - len(flat)))
    image.putpalette(flat)
    image.putdata(data)
    image.info["transparency"] = 0
    return image


def save_png8(image, path):
    """Write an indexed PNG; deterministic (no time chunk), index 0 transparent."""
    image.save(path, format="PNG", optimize=False, transparency=0)


def bbox(frame, labels):
    xs, ys = [], []
    for i, label in enumerate(labels):
        if label is not TRANSPARENT:
            xs.append(i % frame.w)
            ys.append(i // frame.w)
    if not xs:
        return None
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def union(boxes):
    boxes = [b for b in boxes if b]
    if not boxes:
        return None
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def cover_mask(frame, labels):
    """Where a hat hides the hair under it: in every column the hat reaches,
    everything from the top of the canvas down to the hat's lowest pixel."""
    w = frame.w
    lowest = {}
    for i, label in enumerate(labels):
        if label is not TRANSPARENT:
            x, y = i % w, i // w
            lowest[x] = max(lowest.get(x, -1), y)
    return [i // w <= lowest.get(i % w, -1) for i in range(len(labels))]


def head_offset(master, master_labels, other, other_labels, box, reach=3):
    """The shift that lays `other`'s head on the master's, inside `box`.

    Both frames are reduced to their skin pixels within the box (where the
    overlays go); the shift is the one that makes them agree most. Ties go to
    the smallest shift, so identical frames give (0, 0).
    """
    if box is None:
        return (0, 0)
    x0, y0, x1, y1 = box
    w = master.w

    def skin_set(labels, frame):
        return {(i % w, i // w) for i, l in enumerate(labels)
                if l == "skin" and x0 <= i % w < x1 and y0 <= i // w < y1}

    ref = skin_set(master_labels, master)
    mine = skin_set(other_labels, other)
    if not ref or not mine:
        return (0, 0)
    best = None
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            hit = sum(1 for (x, y) in mine if (x + dx, y + dy) in ref)
            score = (-hit, abs(dx) + abs(dy), dx, dy)
            if best is None or score < best[0]:
                best = (score, (dx, dy))
    # The shift moves the overlay (drawn for the master) onto `other`: the
    # opposite of moving `other` onto the master.
    dx, dy = best[1]
    return (-dx, -dy)


def encode_png8(image):
    """An indexed image as PNG bytes, written here rather than by Pillow.

    The bytes are hashed into the URLs every client caches, so they must not
    depend on which zlib the machine's Pillow was built with (zlib-ng and
    stdlib zlib compress differently): rows unfiltered, deflated by the
    standard library at level 9, the whole 256-entry palette, index 0 the one
    transparent entry.
    """
    import struct

    width, height = image.size
    palette = (image.getpalette() or [])[:768]
    palette += [0] * (768 - len(palette))
    flat = getattr(image, "get_flattened_data", None) or image.getdata
    pixels = bytes(flat())
    raw = b"".join(b"\x00" + pixels[y * width:(y + 1) * width] for y in range(height))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 3, 0, 0, 0))
            + chunk(b"PLTE", bytes(palette))
            + chunk(b"tRNS", b"\x00")
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))
