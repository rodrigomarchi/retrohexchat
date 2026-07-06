# Space sprite tooling

Mechanical pipeline that turns the public-domain reference sheets in
`docs/plans/espaco.virtual/gfx/*.png` into **authorial traced-pixel JS modules**
under `apps/retro_hex_chat_web/assets/js/lib/space/sprites/`. No PNG ships at
runtime — the sprite atlas decodes the pixel data.

## Requirements

Python 3 + Pillow:

```bash
python3 -m venv .venv && .venv/bin/pip install Pillow
```

Run everything with that interpreter (`\.venv/bin/python3 <script>`).

## Pipeline

1. **`slice.py`** — cuts every reference sheet into individual per-tile PNGs
   under `gfx/sliced/<sheet>/cCC_rRR.png` (the full browsable library) plus a
   labeled `_contact_<sheet>.png` to locate coordinates. Run once (or after the
   source sheets change).

2. **`manifest.json`** — the single source of truth mapping **semantic names**
   (`grass`, `log_m`, `cliff_face`…) to `{sheet, col, row}`. Never reference raw
   coordinates in game code — add a semantic entry here instead.

3. **`migrate.py`** — reads `manifest.json`, mirrors each named tile into
   `sprites/tiles/<name>.js`, regenerates `sprites/index.js`, and writes
   `_verify_tiles.png` (a labeled montage to eyeball the name→art mapping).

   ```bash
   .venv/bin/python3 migrate.py
   ```

4. **`png2js.py`** — the converter used by `migrate.py`; also runnable standalone
   for a single tile.

## Adding a tile

1. Find it in `gfx/sliced/_contact_<sheet>.png` (col,row).
2. Add `"<semantic_name>": { "sheet": "...", "col": C, "row": R }` to
   `manifest.json`.
3. Run `migrate.py`. The new `sprites/tiles/<semantic_name>.js` + the updated
   registry are ready to use by tile id in a map definition.

The sliced PNGs are derived artifacts (regenerate with `slice.py`); they are not
required at runtime and can be left out of the bundle.
