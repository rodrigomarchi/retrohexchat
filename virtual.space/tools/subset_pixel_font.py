#!/usr/bin/env python3
"""Build the Virtual Space's pixel font ("RH Pixel") from Fusion Pixel 12px.

Fusion Pixel (https://github.com/TakWolf/fusion-pixel-font, SIL OFL 1.1, no
Reserved Font Name) ships one ~670 KB woff2 per region, each carrying Latin,
Greek, Cyrillic, kana and ~19k Han glyphs. A page needs a sliver of that, so this
script cuts it into files a browser fetches only when a character asks for one:

* ``rh_pixel_base.woff2`` — Latin (with every accent the catalogs use), Greek,
  Cyrillic, punctuation, symbols. Family ``RH Pixel``; everyone loads it.
* per region (``jp``, ``sc``, ``tc``, from the ja / zh_hans / zh_hant builds,
  whose Han glyphs follow that region's forms):

  * ``rh_pixel_<r>_core.woff2`` — CJK punctuation, kana, fullwidth forms, and
    exactly the Han characters that locale's catalogs (gettext ``.po`` and the JS
    catalog) use. Family ``RH Pixel <R>``.
  * ``rh_pixel_<r>_ext_NN.woff2`` — the remaining Han glyphs in contiguous
    slices. Family ``RH Pixel <R> Ext``.

  The core face declares the whole CJK range, so a character it does not carry
  falls through, per character, to the ``Ext`` family next in the stack, and
  only the slice holding it is fetched. The CSS stays a few dozen lines instead
  of spelling out a thousand code points per region.

Every face is renamed to its RH Pixel family (subsetting is a modification under
the OFL; the name keeps it from posing as the upstream font). The upstream files
are downloaded from the pinned release and checked against their SHA-256, so a
run is reproducible; outputs are deterministic for the same inputs and catalogs.

Outputs (``--check`` rebuilds in memory and fails if a committed file differs):

* ``apps/retro_hex_chat_web/priv/static/fonts/pixel/*.woff2`` + the licences;
* ``apps/retro_hex_chat_web/assets/css/retrohex/features/space-ui-font.generated.css``.

Run with the pinned tools in ``virtual.space/tools/requirements-font.txt``:

    python3 -m venv /tmp/rh_font_venv
    /tmp/rh_font_venv/bin/pip install -r virtual.space/tools/requirements-font.txt
    /tmp/rh_font_venv/bin/python virtual.space/tools/subset_pixel_font.py
"""
import argparse
import glob
import hashlib
import io
import os
import re
import sys
import urllib.request
import zipfile

from fontTools import subset
from fontTools.ttLib import TTFont

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WEB = os.path.join(REPO, "apps/retro_hex_chat_web")
OUT_DIR = os.path.join(WEB, "priv/static/fonts/pixel")
CSS_OUT = os.path.join(WEB, "assets/css/retrohex/features/space-ui-font.generated.css")
CACHE = os.environ.get("RH_FONT_CACHE", "/tmp/rh_pixel_font_cache")

VERSION = "2026.09.25"
ZIP_NAME = f"fusion-pixel-font-12px-proportional-otf.woff2-v{VERSION}.zip"
ZIP_URL = f"https://github.com/TakWolf/fusion-pixel-font/releases/download/{VERSION}/{ZIP_NAME}"
ZIP_SHA256 = "44b456f6f920d700f98d5865e03152d6a7357ed0a8ee388376ac0530d2d57072"
UPSTREAM = "fusion-pixel-12px-proportional-{build}.otf.woff2"
LICENCES = ["OFL.txt", "LICENSES/ark-pixel/OFL.txt", "LICENSES/cubic-11/OFL.txt",
            "LICENSES/galmuri/LICENSE.txt"]

HAN = (0x4E00, 0x9FFF)
EXT_SLICES = 12

# Everything but Han that the space can show: Latin with its extensions (pl, de,
# fr, pt, nl, it, id, es accents), combining marks, Greek, Cyrillic, general
# punctuation, currency, letterlike, arrows, box drawing and geometric shapes.
BASE_RANGES = [(0x0020, 0x024F), (0x0300, 0x036F), (0x0370, 0x03FF), (0x0400, 0x052F),
               (0x1E00, 0x1EFF), (0x2000, 0x206F), (0x20A0, 0x20CF), (0x2100, 0x218F),
               (0x2190, 0x21FF), (0x2500, 0x25FF)]
# CJK symbols and punctuation, hiragana, katakana, halfwidth and fullwidth forms.
CJK_EXTRA = [(0x3000, 0x30FF), (0xFF00, 0xFFEF)]

REGIONS = [
    # (slug, family suffix, upstream build, catalog locale)
    ("jp", "JP", "ja", "ja"),
    ("sc", "SC", "zh_hans", "zh_hans"),
    ("tc", "TC", "zh_hant", "zh_hant"),
]


def fetch_upstream():
    """The release zip, from the cache or the network, verified by SHA-256."""
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, ZIP_NAME)
    if not os.path.exists(path):
        urllib.request.urlretrieve(ZIP_URL, path)
    with open(path, "rb") as f:
        digest = hashlib.sha256(f.read()).hexdigest()
    if digest != ZIP_SHA256:
        sys.exit(f"{ZIP_NAME}: sha256 {digest} does not match the pinned {ZIP_SHA256}")
    return zipfile.ZipFile(path)


def catalog_han(locale):
    """Every Han code point the locale's catalogs use, sorted."""
    text = []
    for po in sorted(glob.glob(os.path.join(WEB, f"priv/gettext/{locale}/LC_MESSAGES/*.po"))):
        with open(po, encoding="utf-8") as f:
            text.append(f.read())
    with open(os.path.join(WEB, f"assets/js/lib/i18n_catalogs/{locale}.js"), encoding="utf-8") as f:
        text.append(f.read())
    return sorted({ord(c) for c in "".join(text) if HAN[0] <= ord(c) <= HAN[1]})


def expand(ranges):
    return [cp for lo, hi in ranges for cp in range(lo, hi + 1)]


def build_face(source_bytes, unicodes, family):
    """One woff2: `unicodes` cut from the upstream font, renamed to `family`."""
    # recalcTimestamp=False keeps head.modified as upstream wrote it, so the
    # same inputs give the same bytes.
    font = TTFont(io.BytesIO(source_bytes), recalcTimestamp=False)
    options = subset.Options()
    options.flavor = "woff2"
    options.layout_features = ["*"]
    options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
    options.notdef_outline = True
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)
    rename(font, family)
    out = io.BytesIO()
    font.flavor = "woff2"
    font.save(out, reorderTables=True)
    return out.getvalue()


def rename(font, family):
    postscript = family.replace(" ", "") + "-Regular"
    names = {1: family, 2: "Regular", 3: f"{postscript};{VERSION}", 4: f"{family} Regular",
             6: postscript, 16: family, 17: "Regular"}
    table = font["name"]
    for record in list(table.names):
        if record.nameID in names:
            table.setName(names[record.nameID], record.nameID, record.platformID,
                          record.platEncID, record.langID)
    for record in [r for r in table.names if r.nameID in (16, 17)]:
        table.removeNames(nameID=record.nameID)


def unicode_range(ranges):
    return ", ".join(f"U+{lo:04X}" if lo == hi else f"U+{lo:04X}-{hi:04X}" for lo, hi in ranges)


def face_css(family, file, ranges):
    return (
        "@font-face {\n"
        f'  font-family: "{family}";\n'
        f'  src: url("/fonts/pixel/{file}") format("woff2");\n'
        "  font-weight: 400;\n"
        "  font-style: normal;\n"
        "  font-display: swap;\n"
        f"  unicode-range: {unicode_range(ranges)};\n"
        "}\n"
    )


def ext_slices(rest):
    """Contiguous Han slices of about equal glyph count, as (lo, hi, cps)."""
    size = -(-len(rest) // EXT_SLICES)
    chunks = [rest[i:i + size] for i in range(0, len(rest), size)]
    slices = []
    for n, chunk in enumerate(chunks):
        lo = HAN[0] if n == 0 else chunk[0]
        hi = HAN[1] if n == len(chunks) - 1 else chunks[n + 1][0] - 1
        slices.append((lo, hi, chunk))
    return slices


def build():
    """Every output as {path: bytes}."""
    archive = fetch_upstream()
    files = {}
    css = [
        "/* Generated by virtual.space/tools/subset_pixel_font.py — do not edit. */\n",
        f"/* RH Pixel: Fusion Pixel 12px proportional v{VERSION}, SIL OFL 1.1 — see /fonts/pixel/OFL.txt. */\n\n",
    ]

    latin = archive.read(UPSTREAM.format(build="latin"))
    files["rh_pixel_base.woff2"] = build_face(latin, expand(BASE_RANGES), "RH Pixel")
    css.append(face_css("RH Pixel", "rh_pixel_base.woff2", BASE_RANGES))

    for slug, suffix, upstream_build, locale in REGIONS:
        source = archive.read(UPSTREAM.format(build=upstream_build))
        cmap = TTFont(io.BytesIO(source)).getBestCmap()
        used = [cp for cp in catalog_han(locale) if cp in cmap]
        family = f"RH Pixel {suffix}"
        core = f"rh_pixel_{slug}_core.woff2"
        files[core] = build_face(source, expand(CJK_EXTRA) + used, family)
        css.append(face_css(family, core, CJK_EXTRA + [HAN]))

        taken = set(used)
        rest = [cp for cp in range(HAN[0], HAN[1] + 1) if cp in cmap and cp not in taken]
        for n, (lo, hi, cps) in enumerate(ext_slices(rest)):
            name = f"rh_pixel_{slug}_ext_{n:02d}.woff2"
            files[name] = build_face(source, cps, f"{family} Ext")
            css.append(face_css(f"{family} Ext", name, [(lo, hi)]))

    for licence in LICENCES:
        target = licence if licence == "OFL.txt" else licence.replace("/", "_").replace("-", "_")
        files[target] = archive.read(licence)

    # `.gitignore` drops `priv/static/**/*-[0-9a-f]*.*` as digest output: a
    # name that looks like one would never be committed.
    for name in files:
        if re.search(r"-[0-9a-f]", name):
            sys.exit(f"{name} looks like digest output and would be gitignored")
    outputs = {os.path.join(OUT_DIR, name): data for name, data in files.items()}
    outputs[CSS_OUT] = "\n".join(css).encode("utf-8")
    return outputs


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail if a committed output differs")
    args = parser.parse_args()
    outputs = build()

    if args.check:
        stale = [p for p, data in outputs.items()
                 if not os.path.exists(p) or open(p, "rb").read() != data]
        extra = sorted(set(glob.glob(os.path.join(OUT_DIR, "*"))) - set(outputs))
        for path in stale + extra:
            print(f"stale: {os.path.relpath(path, REPO)}")
        sys.exit(1 if stale or extra else 0)

    for path in glob.glob(os.path.join(OUT_DIR, "*")):
        if path not in outputs:
            os.remove(path)
    for path, data in outputs.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)
    total = sum(len(d) for p, d in outputs.items() if p.endswith(".woff2"))
    print(f"wrote {len(outputs)} files, {total // 1024} KiB of woff2")


if __name__ == "__main__":
    main()
