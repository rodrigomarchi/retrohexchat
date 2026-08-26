#!/usr/bin/env python3
"""Runtime sprite-sheet encoding, in one place.

Every sheet the client downloads is written through :func:`save_sheet`, so the
encoder settings live at a single address instead of being spelled out at each
call site.

WebP, lossless. The art is high-colour PixelLab output — a single 188x146 frame
carries ~1600 distinct colours across ~2900 opaque pixels, which is noise as far
as PNG's filters are concerned. Lossless WebP reads the same pixels back byte for
byte and lands ~40% smaller. Lossy WebP is not an option: these are sprite sheets
sliced by exact source rectangles, and a resampled edge shows as a seam.

``exact=True`` keeps the RGB values under fully transparent pixels, so a sheet
round-trips unchanged and the output stays reproducible from the same input.
"""
import os

from PIL import Image

# `method=6` is libwebp's slowest, smallest setting; sheets are built rarely and
# downloaded often, so the encode time is the right thing to spend.
_WEBP = {"format": "WEBP", "lossless": True, "quality": 100, "method": 6, "exact": True}

SHEET_SUFFIX = ".webp"


def save_sheet(image, path):
    """Write a runtime sprite sheet, creating its directory.

    :param image: the composed RGBA sheet
    :param path: destination, expected to end in ``.webp``
    """
    if not path.endswith(SHEET_SUFFIX):
        raise ValueError(f"runtime sheets are {SHEET_SUFFIX}, got {path}")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, **_WEBP)


def assert_identical(image, path):
    """Prove a written sheet reads back pixel for pixel. Raises on mismatch."""
    written = Image.open(path).convert("RGBA")
    if list(written.getdata()) != list(image.convert("RGBA").getdata()):
        raise AssertionError(f"{path} did not round-trip losslessly")
