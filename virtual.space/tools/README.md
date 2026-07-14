# Space sprite tooling

The single virtual-space map (`end_of_time`, isometric) ships one composed
sprite sheet (`endoftime.png`, written by `author_scene.py` straight into
`apps/retro_hex_chat_web/priv/static/images/space/`) plus a thin Elixir map
module that declares its tile vocabulary. Both channels and DMs render it. The
client sprite atlas slices the sheet with `drawImage`; no pixel data is traced
into JS or into the map payload.

The map art is **generated with PixelLab** (native flat iso floor diamonds —
shipped at 48×20 — + map-object props as iso billboards) and packed into its
sheet by `author_scene.py`. The script is deterministic and re-reads the tracked
raw art, so the sheet is always reproducible from source.

## Where things live

- **Runtime sheets** — `apps/retro_hex_chat_web/priv/static/images/space/`
  (`endoftime.png` for the scene; `avatars/iso_<id>.png` for the 8 avatars).
  `author_scene.py` writes the scene sheet here.
- **Tile vocabulary** — the map module (`RetroHexChat.VirtualSpace.Maps.EndOfTime`)
  owns its vocab: semantic tile names → `{col, row, w, h, frames?, period_ms?,
  flip_x?}` on the sheet. Tiles are referenced by name; there is no shared
  cross-map tile catalog.
- **Avatars** — eight premium **8-direction isometric** characters (`hero`,
  `knight`, `sorceress`, `archer`, `barbarian`, `rogue`, `cleric`, `monk`),
  authored at **native scale 1**, each with walk + idle + attack (8 facings) and
  a south seated sleep. Runtime sheets are `avatars/iso_<id>.png` with sibling
  `iso_<id>.geo.json` geometry. The generation → composition → integration
  pipeline and the "add a new character" recipe are in
  [`../CHARACTERS.md`](../CHARACTERS.md). Raw exports live under
  `characters/iso_<id>/pixellab/`.

## The scripts

- **`author_scene.py`** — the End of Time scene. Reads the raw art (the native
  iso floor variations, the railing strip + post, the lamp) from
  `../scenes/end_of_time/` and emits the sheet `endoftime.png` plus the layout
  `priv/maps/end_of_time.json` (including the iso `slabs`/`railings` geometry).
  Its only animated strip today is the script-drawn `iso_star` (see the status
  note atop [`../ANIMATIONS.md`](../ANIMATIONS.md)); the iso build is in
  [`../ISOMETRIC.md`](../ISOMETRIC.md).
- **`compose_iso_avatar.py`** — composes one 8-direction iso avatar sheet from a
  PixelLab export. Crops every frame to one shared window, stacks them in
  direction-major blocks (`walk, idle, attack, sleep`), and writes
  `avatars/iso_<id>.png` plus `iso_<id>.geo.json` (see
  [`../CHARACTERS.md`](../CHARACTERS.md)).
- **`gen_iso_atlas.py`** — reads every `iso_<id>.geo.json` and prints the JS
  atlas data (`AVATAR_SHEETS` entries + the `ISO_GEO` literal) to paste into
  `sprite_atlas.js`, so adding a character is a data change.

## Authoring the scene

The full pipeline for building a virtual-space scene — the iso floor + map-object
props, cohesive art curation, sheet packing, the map module and its integration —
is in [`../SCENES.md`](../SCENES.md) and [`../ISOMETRIC.md`](../ISOMETRIC.md).
The registry currently holds the single `Maps.EndOfTime` module
(`RetroHexChat.VirtualSpace.Map`); a new scene copies `author_scene.py`, generates
its art with PixelLab, packs it, and registers its `Maps.<Name>` module.
