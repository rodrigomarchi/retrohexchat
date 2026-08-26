# Combat impact effects (fx)

PixelLab one-shot burst animations for the Space combat feedback layer, packed
into `apps/retro_hex_chat_web/priv/static/images/space/fx.webp` as horizontal
strips (frame *i* at `x = i * size`):

| Effect | Size | Frames | Row y | Played on |
|---|---|---|---|---|
| `hit_spark` | 64×64 | 6 | 0 | every landed hit (`FX_SPARK_MS`) |
| `ko_burst` | 96×96 | 6 | 64 | knockout (`FX_BURST_MS`) |

Source: `create_map_object` (side view, lineless, transparent bg) +
`animate_object` v3, 6 frames, `keep_first_frame: false`. The raw frames in
`hit_spark/` and `ko_burst/` are the committed ground truth — the sheet can be
repacked from them without re-spending generations (map objects auto-delete
from PixelLab after 8 hours, so these directories are the only durable copy).

Unlike the scene and the avatars, this sheet has no packer of its own — it was
assembled by hand. Repacking it is a matter of writing one, but re-encoding it
is not: like every runtime sheet it goes through `tools/sheet_io.save_sheet()`,
so from the packed RGBA image it is

```python
from sheet_io import save_sheet, assert_identical
save_sheet(sheet, ".../priv/static/images/space/fx.webp")
assert_identical(sheet, ".../priv/static/images/space/fx.webp")
```

Geometry lives in `FX` in `sprite_atlas.js` (`fx(name, frame)` resolves the
rect); the renderer drives lifetimes and draws them centred on the victim's
chest anchor.
