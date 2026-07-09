# Space sprite tooling

The virtual space renders the human-made reference sheets in
`virtual.space/*.png` **directly at runtime**: the sheets are
copied into `apps/retro_hex_chat_web/priv/static/images/space/` and the client
sprite atlas slices them with `drawImage`. No pixel data is traced into JS or
into the map payload anymore.

## Where things live

- **Runtime sheets** — `apps/retro_hex_chat_web/priv/static/images/space/`
  (`overworld.png`, `character.png`, plus `objects.png`/`inner.png`/`cave.png`
  for future maps). Copy a sheet here to make it available to the client.
- **Tile vocabulary** — `RetroHexChat.VirtualSpace.Maps.Overworld` (Elixir) maps
  semantic tile names (`grass`, `tree`, `pond_c`, `cliff_face`…) to a source
  rectangle `{ts, col, row, w, h}` on a sheet. Maps reference tiles by name.
- **Avatar** — sliced from `character.png` by the client atlas
  (`js/lib/space/sprite_atlas.js`): one red-tunic hero, 16×32 sprites, four
  facings, four walk frames per facing, and two four-frame sword variants.

## `manifest.json`

The single source of truth for **which Overworld tiles the vocabulary uses**
(semantic name → `{sheet, col, row, w, h}`). It is the reference the Elixir
`Overworld` module mirrors; when you add a tile, add it here and to that module.

## `slice.py`

Cuts every reference sheet into individual per-tile PNGs under
`sliced/<sheet>/cCC_rRR.png` plus a labeled `_contact_<sheet>.png` to locate
`(col, row)` coordinates while authoring. These are browsing aids only — nothing
here ships at runtime.

```bash
python3 -m venv .venv && .venv/bin/pip install Pillow
.venv/bin/python3 slice.py
```

## Adding a tile to a map

1. Find it in `sliced/_contact_<sheet>.png` (col, row).
2. Add a semantic entry to `manifest.json` and to
   `RetroHexChat.VirtualSpace.Maps.Overworld`.
3. Reference it by name in a map module's floor/decor.

## `derive_map.py` — Elfic Forest from the reference

`derive_map.py` reproduces the reference forest map faithfully instead of
hand-authoring it. It classifies the reference screenshot
(`~/Desktop/Captura de Tela 2026-07-06 …08.43.11.png`) into a semantic grid
(grass / tree / cliff / water), denoises it, then autotiles it into our sheet
tiles — tree clumps where the reference has forest, the cliff autotile along the
brown contour, a pond autotile on the water, the cabin sprite on its blob. It
writes **layout only** (tile names, prop positions, blocked cells — no pixels)
to `apps/retro_hex_chat/priv/maps/elfic_forest.json`, which
`RetroHexChat.VirtualSpace.Maps.ElficForest` loads.

```bash
.venv/bin/python3 derive_map.py
```

The reference lives outside the repo, so the derived JSON is committed; rerun the
script only to regenerate it after tuning the classifier/autotiler.
