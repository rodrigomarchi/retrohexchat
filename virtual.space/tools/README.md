# Space sprite tooling

The single virtual-space map (`end_of_time`, isometric) ships one composed
sprite sheet (`endoftime.webp`, written by `author_scene.py` straight into
`apps/retro_hex_chat_web/priv/static/images/space/`) plus a thin Elixir map
module that declares its tile vocabulary. Both channels and DMs render it. The
client sprite atlas slices the sheet with `drawImage`; no pixel data is traced
into JS or into the map payload.

The map art is **generated with PixelLab** (native flat iso floor diamonds —
shipped at 48×20 — + map-object props as iso billboards) and packed into its
sheet by `author_scene.py`. The script is deterministic and re-reads the tracked
raw art, so the sheet is always reproducible from source.

## Why WebP

Every runtime sheet is written through `sheet_io.save_sheet()` as **lossless**
WebP. The art is high-colour: a single 188×146 avatar frame carries ~1600
distinct colours over ~2900 opaque pixels, which is noise to PNG's filters. Over
the ten sheets, lossless WebP reads back byte for byte and lands 39% smaller
(13.81 MB → 8.41 MB). Lossy WebP is not an option — the atlas slices these by
exact source rectangles, and a resampled edge shows as a seam.

There is no PNG fallback, on the same reasoning as
`RetroHexChatWeb.Wallpaper`. Unlike the wallpaper there is no colour underneath:
a browser that cannot decode WebP draws no world. That is every browser shipped
since 2020 having to be wrong.

Trimming the transparent padding is **not** worth doing — 91% of an avatar sheet
is transparent, but that compresses to almost nothing already, and repacking
measured *larger*. Quantising to a 256-colour palette buys 78% and costs up to
52/255 of error on 8.6% of pixels; the roster is premium art and does not pay
that.

## Where things live

- **Runtime sheets** — `apps/retro_hex_chat_web/priv/static/images/space/`
  (`endoftime.webp` for the scene; `avatars/iso_<id>.webp` for the 8 avatars).
  `author_scene.py` writes the scene sheet here.
- **Tile vocabulary** — the map module (`RetroHexChat.VirtualSpace.Maps.EndOfTime`)
  owns its vocab: semantic tile names → `{col, row, w, h, frames?, period_ms?,
  flip_x?}` on the sheet. Tiles are referenced by name; there is no shared
  cross-map tile catalog.
- **Avatars** — eight premium **8-direction isometric** characters (`hero`,
  `knight`, `sorceress`, `archer`, `barbarian`, `rogue`, `cleric`, `monk`),
  authored at **native scale 1**, each with walk + idle + attack (8 facings) and
  a south seated sleep. Runtime sheets are `avatars/iso_<id>.webp` with sibling
  `iso_<id>.geo.json` geometry. The generation → composition → integration
  pipeline and the "add a new character" recipe are in
  [`../CHARACTERS.md`](../CHARACTERS.md). Raw exports live under
  `characters/iso_<id>/pixellab/`.

## The scripts

- **`author_scene.py`** — the End of Time scene. Reads the raw art (the native
  iso floor variations, the railing strip + post, the lamp) from
  `../scenes/end_of_time/` and emits the sheet `endoftime.webp` plus the layout
  `priv/maps/end_of_time.json` (including the iso `slabs`/`railings` geometry).
  Its only animated strip today is the script-drawn `iso_star` (see the status
  note atop [`../ANIMATIONS.md`](../ANIMATIONS.md)); the iso build is in
  [`../ISOMETRIC.md`](../ISOMETRIC.md).
- **`compose_iso_avatar.py`** — composes one 8-direction iso avatar sheet from a
  PixelLab export. Crops every frame to one shared window, stacks them in
  direction-major blocks (`walk, idle, attack, sleep`), and writes
  `avatars/iso_<id>.webp` plus `iso_<id>.geo.json` (see
  [`../CHARACTERS.md`](../CHARACTERS.md)).
- **`gen_iso_atlas.py`** — reads every `iso_<id>.geo.json` and prints the JS
  atlas data (the `ISO_GEO` literal) to paste into `sprite_atlas.js`, so adding a
  character is a data change. It prints no sheet URLs: the atlas derives them
  from its roster, and at runtime the server hands it digested ones.
- **`gen_charsel_sheet.py`** — packs the south-facing walk loop of all eight
  classes into `charsel.webp` (80×95 cells, one row per class in roster order)
  for the character picker, and prints the offsets
  `css/retrohex/features/space-character-picker.css` needs. The picker shows this
  sheet 1:1; it must never point at the runtime sheets, which cost megabytes to
  fill a thumbnail.
- **`sheet_io.py`** — not a script: `save_sheet()`, the single place that knows
  how a runtime sheet is encoded. Lossless WebP, `exact=True`, `method=6`. See
  "Why WebP" below.

## Authoring the scene

The full pipeline for building a virtual-space scene — the iso floor + map-object
props, cohesive art curation, sheet packing, the map module and its integration —
is in [`../SCENES.md`](../SCENES.md) and [`../ISOMETRIC.md`](../ISOMETRIC.md).
The registry currently holds the single `Maps.EndOfTime` module
(`RetroHexChat.VirtualSpace.Map`); a new scene copies `author_scene.py`, generates
its art with PixelLab, packs it, and registers its `Maps.<Name>` module.
