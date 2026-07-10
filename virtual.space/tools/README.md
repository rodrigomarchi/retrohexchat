# Space sprite tooling

Each virtual-space map ships one composed sprite sheet
(`virtual.space/*.png`, copied into
`apps/retro_hex_chat_web/priv/static/images/space/`) plus a thin Elixir map
module that declares its tile vocabulary. The client sprite atlas slices the
sheet with `drawImage`; no pixel data is traced into JS or into the map payload.

Every map's art is **generated with PixelLab** (Wang tilesets + map-object
props, in a cohesive flat 16-bit register) and packed into its sheet by a
per-map `author_*.py` script. The scripts are deterministic and re-read the
tracked raw art, so a sheet is always reproducible from source.

## Where things live

- **Runtime sheets** — `apps/retro_hex_chat_web/priv/static/images/space/`
  (`character.png` for the default hero, `endoftime.png`, `millennialfair.png`).
  A map's `author_*.py` writes its sheet here.
- **Tile vocabulary** — each map module (`RetroHexChat.VirtualSpace.Maps.*`)
  owns its own vocab: semantic tile names → `{col, row, w, h, frames?,
  period_ms?, flip_x?}` on that map's sheet. Maps reference tiles by name; there
  is no shared cross-map tile catalog.
- **Avatars** — the red-tunic hero (sliced from `character.png`, 16×32) plus
  seven PixelLab-authored classes (`avatars/<id>.png`, 36×36), each with a
  4-direction walk and attack. The generation → composition → integration
  pipeline and the "add a new character" recipe are in
  [`../CHARACTERS.md`](../CHARACTERS.md). Raw generation exports live under
  `characters/<id>/pixellab/`; `compose_avatars.py` builds the runtime sheets.

## The author scripts

- **`author_scene.py`** — the End of Time DM scene. Reads the raw art (tileset +
  animated map-object frames) from `../scenes/end_of_time/` and emits the sheet
  `endoftime.png` plus the layout `priv/maps/end_of_time.json`. The animation
  pipeline it exercises is documented in [`../ANIMATIONS.md`](../ANIMATIONS.md).
- **`author_fair.py`** — the Millennial Fair channel scene. Builds the plaza
  floor, packs the flat 16-bit props (union-bbox, scale-to-fit, off-sheet guard)
  and emits `millennialfair.png` plus `priv/maps/millennial_fair.json`.
- **`compose_avatars.py`** — assembles the class-avatar runtime sheets from the
  PixelLab exports (see [`../CHARACTERS.md`](../CHARACTERS.md)).

## Authoring a new map

The full pipeline for authoring a virtual-space scene — PixelLab Wang-tileset
floors + map-object props, cohesive flat-art curation, sheet packing, the map
module and its integration — is in [`../SCENES.md`](../SCENES.md). Copy an
existing `author_*.py` as the starting point, generate the art with PixelLab,
pack it, and add the `Maps.<Name>` module to the registry
(`RetroHexChat.VirtualSpace.Map`).
