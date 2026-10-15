# Space sprite tooling

Each virtual-space map ships one composed sprite sheet, written straight into
`apps/retro_hex_chat_web/priv/static/images/space/`, plus a thin Elixir map
module that declares its tile vocabulary: `end_of_time` (`endoftime.webp`, by
`author_scene.py`), the scene every channel and DM renders, and `construct`
(`construct.webp`, by `author_construct.py`), the buildable room behind its
gate (`SCENES.md` §10), and `office` (by `author_office.py`), the furnished
room behind the wooden door, drawn from the Construct's sheets (§11). The
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

Trimming the transparent padding of a scene sheet is **not** worth doing: it
compresses to almost nothing already, and repacking measured *larger*. The
character creator's pieces are the one exception to WebP: they are indexed
PNGs because recolouring them is a palette rewrite (see
[`../CHARACTERS.md`](../CHARACTERS.md) §4).

## Where things live

- **Runtime sheets** — `apps/retro_hex_chat_web/priv/static/images/space/`
  (`endoftime.webp` for the scene; `creator/` for the character creator's
  pieces and catalog).
  `author_scene.py` writes the scene sheet here.
- **Tile vocabulary** — the map module (`RetroHexChat.VirtualSpace.Maps.EndOfTime`)
  owns its vocab: semantic tile names → `{col, row, w, h, frames?, period_ms?,
  flip_x?}` on the sheet. Tiles are referenced by name; there is no shared
  cross-map tile catalog.
- **Characters** — made in the Space's character creator from layered pieces
  (a body wearing an outfit, hair, headwear, face items), each premium
  **8-direction** art at **native scale 1**. The sources, the PixelLab
  pipeline and the "add a piece" recipe are in
  [`../CHARACTERS.md`](../CHARACTERS.md). Raw frames live under
  `characters/creator/raw/`.

## The scripts

- **`author_scene.py`** — the End of Time scene. Reads the raw art (the native
  iso floor variations, the railing strip + post, the lamp) from
  `../scenes/end_of_time/` and emits the sheet `endoftime.webp` plus the layout
  `priv/maps/end_of_time.json` (including the iso `slabs`/`railings` geometry).
  Its only animated strip today is the script-drawn `iso_star` (see the status
  note atop [`../ANIMATIONS.md`](../ANIMATIONS.md)); the iso build is in
  [`../ISOMETRIC.md`](../ISOMETRIC.md).
- **`author_construct.py`** — the Construct: its floor, its gate and the catalog
  of every piece people can place, packed into `construct.webp` and
  `priv/maps/construct.json` from `../scenes/construct/` (a still piece is
  `<kind>.png`, a moving one `anim/<kind>/<i>.png`). See
  [`../SCENES.md`](../SCENES.md) §10.
- **`author_office.py`** — the Office: the Construct's platform with a floor
  plan and the furniture it comes with (`fixed_items`), written to
  `priv/maps/office.json` from the Construct's own catalog and sheets, so it
  packs no sheet. It reads `construct.json`, which reads the End of Time's
  vocab: run `author_scene.py`, then `author_construct.py`, then this. See
  [`../SCENES.md`](../SCENES.md) §11.
- **`fetch_pixellab_objects.py`** — downloads the Construct pieces named in
  `../scenes/construct/pixellab.json` from the PixelLab account, still or
  animated, into that layout. Run it when a piece is added; it keeps art
  already on disk unless `--force`.
- **`creator_generate.py`** — brings every piece of the character creator up
  to its clips in all eight facings on PixelLab (`plan`, `run --budget N`) and
  downloads the frames (`fetch`). See [`../CHARACTERS.md`](../CHARACTERS.md).
- **`build_creator.py`** — turns those frames into the creator's indexed
  sheets, masks, portrait crops, its two catalogs and the swatch CSS
  (`creator_art.py` holds the pixel work, `creator_pose.py` the seated pose).
- **`creator_contact_sheet.py`** — composes recipes from the built catalog the
  way the game does, for review and for the portrait golden images.
- **`author_ui.py`** — the space's pixel-art UI kit: cuts the frames, icons and
  canvas pieces out of the PixelLab generations under `../ui/pixellab/`, derives
  their states, and writes the images, the CSS tokens and the canvas geometry
  (`make space.ui`; `make space.ui.check` is part of `make lint.css`). See
  [`../UI.md`](../UI.md).
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
