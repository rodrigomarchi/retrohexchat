# Space tile catalog

218 named, ready-to-use tiles across the human-made sheets, exposed in code by `RetroHexChat.VirtualSpace.Maps.Catalog` (data in `priv/maps/tile_catalog.json`, baked at compile time). Each tile is a source rectangle on a sheet, sliced at runtime by the client.

Every entry carries metadata so a map author — human or AI — can place it without seeing the art:

- **layer**: `floor` (walkable ground), `decor` (object over the floor), `above` (roof/canopy drawn over avatars)
- **solid**: whether it blocks movement (seed collision from this)
- **review**: `true` when the sheet crop is imperfect (spills into a neighbour / is a fragment) — prefer another tile or trim before use

## Usage (Elixir)

```elixir
alias RetroHexChat.VirtualSpace.Maps.Catalog

%{
  id: "my_map", tile_size: 16,
  tilesets: Catalog.tilesets(),
  tiles: Catalog.tiles(~w(grass_plain tree_foliage house_large pond_grass_edge)),
  ground: "grass_plain", layers: %{floor: [...], decor: [...]}
}
# Catalog.info("tree_foliage") -> full metadata (category/layer/solid/desc)
# Catalog.solid?("tree_foliage") -> true
```

## Sheets

| sheet | tiles | image |
|-------|-------|-------|
| overworld | 92 | `/images/space/overworld.png` (40 cols) |
| inner | 48 | `/images/space/inner.png` (40 cols) |
| cave | 29 | `/images/space/cave.png` (40 cols) |
| objects | 37 | `/images/space/objects.png` (33 cols) |
| character | 6 | `/images/space/character.png` (17 cols) |
| log | 6 | `/images/space/log.png` (12 cols) |


## overworld (92)


### terrain

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `cobblestone_path` ⚠️ | 13,14 | 3×3 | floor | no | Brown/tan cobbled paving with a lighter L-shaped stone edging. Courtyard/road surface; edge reads as a low kerb. |
| `dirt_field_tilled` | 1,30 | 1×1 | floor | no | Ploughed brown soil in even rows. Tile into rectangles for farm plots; pair with crops_field. |
| `dirt_patch` | 1,0 | 1×1 | floor | no | Bare brown earth with a few green sprigs. Walkable ground for clearings, campsites, grass/path borders. |
| `grass_dark` | 0,29 | 1×1 | floor | no | Darker shadowed green grass with faint lighter blades. Walkable variant for forest floors/shade. |
| `grass_flower_yellow` | 0,3 | 2×2 | floor | no | Green grass threaded with wavy pale-yellow patches (flowering meadow / worn trail). Breaks up plain grass, hints at paths. |
| `grass_plain` | 0,0 | 1×1 | floor | no | Flat mid-green grass with subtle darker speckle. Default walkable ground; fill open fields and lay decor on top. |
| `gravel_light` | 14,11 | 2×2 | floor | no | Pale grey gravel/rubble ground with darker speckle. Walkable for quarries, cave floors, stone yards. |

### vegetation

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `bush_dead_grey` ⚠️ | 18,17 | 3×3 | decor | yes | Sparse grey-green dead shrub by a small rock. Withered/wintry undergrowth; crop overlaps adjacent rock. |
| `bush_round` | 0,16 | 1×1 | decor | yes | Single small round green bush. Scatter along paths, garden edges, undergrowth; blocks movement. |
| `crops_field` | 0,34 | 2×2 | floor | no | Tilled dirt studded with small red/green crop plants. Growing field; walkable so avatars wander the rows. |
| `flowers_white` | 0,8 | 1×1 | decor | no | Scatter of tiny white four-petal flowers (transparent bg). Sprinkle over grass for meadow detail; non-blocking. |
| `hedge_block` | 0,14 | 2×2 | decor | yes | Chunky rectangular block of green hedge. Tile in rows for hedgerows, maze walls, garden borders; solid. |
| `plant_leafy_green` | 32,1 | 1×1 | decor | yes | Bushy bright-green leafy plant (highlight dots read almost like eyes). Ornamental shrub/houseplant; no pot visible. |
| `tree_foliage` | 5,16 | 3×3 | decor | yes | Dense round clump of bright/dark green leaves — a full tree canopy. Main forest tree; cluster many for woods. Solid. |
| `tree_stumps` | 4,2 | 2×1 | decor | yes | Pair of low cut brown tree stumps with grass tufts. Clearings/logging sites; solid obstacles. |
| `water_lilies_cluster` | 4,0 | 2×1 | decor | no | Cluster of overlapping green lily pads on water. Dress pond surfaces and slow river bends. |
| `water_lily` | 2,0 | 1×1 | decor | no | Single round green lily pad on blue water. Pond accent; stepping-stone-sized detail. |

### water

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `pond_grass_edge` | 2,9 | 2×2 | floor | yes | Blue pond framed by a white-foam grassy edge. Prefab pond with green bank; interior blocks movement. |
| `pond_sand_edge` | 3,6 | 2×3 | floor | yes | Blue pond bordered by a pale sandy rim. Prefab small water body with shoreline; place on grass. |
| `shore_grass_water` | 16,6 | 2×3 | floor | yes | Diagonal shoreline where grass meets water along a foam line (L-shaped coast). Land/lake corner transition; water half impassable. |
| `water_deep` | 3,3 | 1×1 | floor | yes | Darker blue open water with a shaded ring (deeper). Centre of large lakes or sea; impassable. |
| `water_fill` | 0,1 | 1×1 | floor | yes | Solid mid-blue water with small white foam caps. Base water body for lakes/moats/rivers; blocks movement. |
| `water_ripple` | 16,0 | 1×1 | floor | yes | Blue water with a curved white ripple/current line. Scatter among water_fill for surface movement; blocks. |

### cliff

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `boulder_pile` ⚠️ | 11,7 | 5×6 | decor | yes | Large heap of rounded foam-outlined boulders. Big 5x6 crop spills into cave-mouth/shore/gravel at edges — trim before use. Rock formation for cliff bases/blockers. |
| `cave_hole` | 14,25 | 2×2 | decor | yes | Dark round opening in rocky ground (cave hole/pit). Burrow/entrance detail on cliffs/hillsides; blocks. |
| `cliff_rock_fill` | 10,10 | 1×1 | decor | yes | Brown rocky cliff-face fill with a green grassy lip on top. Tile as the vertical body of a plateau/cliff wall; blocks. |

### prop

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `banner_skull_purple` | 5,28 | 1×2 | decor | yes | Purple pennant with a white skull emblem on a post. Faction/warning banner at gates/camps; solid at post. |
| `barrel_wood` | 33,0 | 1×1 | decor | yes | Banded wooden barrel. Cellars, docks, markets; solid storage. |
| `bone` | 29,2 | 1×1 | decor | no | Pair of small white bones on the ground. Grim scenery with the skull; non-blocking. |
| `chain_hanging` | 26,1 | 1×2 | decor | no | Vertical segmented grey/brown chain or rope. Dangle from beams/wells/gates as detail; non-blocking. |
| `coal_rocks` | 12,22 | 2×2 | decor | yes | Scatter of dark grey rocks flecked with black (coal/ore). Mine/cave mineral deposit; solid. |
| `crate_open` | 18,20 | 2×2 | decor | yes | Open-topped wooden crate showing plank interior. Emptied/loot container; solid. |
| `crate_wood` | 30,0 | 1×1 | decor | yes | Closed square wooden crate with plank slats. Cargo/storage for warehouses/stalls; solid. |
| `crate_x` | 36,8 | 1×2 | decor | yes | Tall wooden crate braced with an X-frame. Shipping crate for storerooms/docks; solid. |
| `flag_blue` | 4,29 | 2×2 | decor | yes | Blue draped banner/flag with a white heraldic emblem. Territory marker on walls/squares; solid at mount. |
| `flowerpot_sprout` | 35,0 | 1×1 | decor | yes | Brown pot with a green sprout topped by a small white flower. Windowsills, stalls, porches; solid. |
| `haystack` ⚠️ | 32,3 | 2×2 | decor | yes | Mound of golden hay beside a framed wooden panel — the 2x2 crop captures two objects. Use hay for barnyards; trim the framed panel. |
| `log_horizontal` | 3,5 | 3×1 | decor | yes | Felled brown log on its side with bark rings. Solid low obstacle for forest paths/campsites. |
| `panel_wood_slats` ⚠️ | 6,6 | 3×3 | decor | yes | Vertical tan slatted wooden panel with rounded ends beside a small log — upright twin of counter_wood (woven mat/pallet). Wall backboard. |
| `planks_wood_stacked` ⚠️ | 26,4 | 2×4 | decor | yes | Two horizontal slatted wooden panels stacked (benches / stacked planks). Shares origin with bench_wood — a taller crop of the same art. |
| `produce_crate_banana` | 26,20 | 1×1 | decor | yes | Wooden market crate heaped with yellow bananas. Grocer stalls/market rows; solid. |
| `produce_crate_greens` | 27,20 | 1×1 | decor | yes | Wooden market crate of leafy greens. Markets/kitchens; solid. |
| `produce_crate_lemon` | 29,20 | 1×1 | decor | yes | Wooden market crate of yellow lemons/citrus. Market displays; solid. |
| `produce_crate_tomato` | 28,20 | 1×1 | decor | yes | Wooden market crate of red tomatoes. Greengrocer stalls; solid. |
| `rock_small` | 6,5 | 1×1 | decor | yes | Single small rounded brown rock on grass. Solid decoration for fields/paths/boundaries. |
| `rocks_row` | 7,5 | 4×1 | decor | no | Horizontal line of little brown pebbles. Low ground detail for gravel edges/trails; walkable. |
| `sack_flour` | 32,0 | 1×1 | decor | yes | Bulging pale cloth sack tied at the top (flour/grain). Mills, bakeries, stalls; solid. |
| `skull` | 28,2 | 1×1 | decor | no | Small white human skull on the ground. Macabre accent for dungeons/graveyards/battlefields; walkable detail. |
| `stone_slab_round` | 35,5 | 1×1 | decor | yes | Smooth rounded grey stone slab/boulder. Lone rock, stepping stone, rubble accent; solid. |

### structure

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `arch_stone` | 24,32 | 4×2 | decor | yes | Low grey stone archway / open wall opening. Freestanding gate arch or ruin fragment to frame passages; solid at piers. |
| `barn_large` | 11,0 | 5×5 | decor | yes | Wide barn with a broad gambrel roof and big front doors. Farm outbuilding/stable; solid. |
| `beam_wood_corner` ⚠️ | 32,10 | 2×4 | decor | yes | Tall tan wooden beam bent into an L with a horizontal top arm (crane/gibbet/support post). Structural timber/hoist prop; solid. |
| `bridge_stone` | 19,28 | 5×6 | floor | no | Light grey paved stone deck with low battlemented side edges — bridge or plaza surface. Walkable; span water or use as courtyard floor. |
| `castle_gate` | 26,22 | 5×6 | decor | yes | Grey stone castle gatehouse: crenellated wall with a central arched gateway between towers. Fortress entrance/wall; solid. |
| `cave_entrance` | 11,31 | 3×3 | decor | yes | Stone archway framing a black cave opening. Dungeon/mine doorway; set into a cliff wall as a level exit/entrance. |
| `cellar_door_dark` | 16,4 | 3×2 | decor | yes | Brown wall face with two dark arched doorways/cellar openings. Building base with entries; solid. |
| `chimney_stone` | 6,23 | 2×2 | decor | yes | Grey stone chimney/hearth stack with a dark opening. Attach to roofs or use as an oven/forge stack; solid. |
| `door_arch_stone` | 25,2 | 1×2 | decor | yes | Stone-arched doorway with an iron grille. Fortified arched entrance for towers/keeps; solid. |
| `door_barred` | 25,0 | 1×2 | decor | yes | Grey iron-barred door/gate (jail/portcullis grille). Cells, dungeons, fortified doorways; solid. |
| `door_wood` | 25,8 | 1×1 | decor | yes | Single plank wooden door with a small window. Building entrance; solid. |
| `fence_wood` | 0,17 | 4×1 | decor | yes | Thin run of low wooden fence rails/posts. Paths, paddocks, garden edges; solid barrier. |
| `fountain_basin` | 16,28 | 2×1 | decor | yes | Low grey stone basin/trough (dry or drinking basin). Water trough or fountain base; solid. |
| `fountain_stone` | 22,9 | 3×3 | decor | yes | Round grey stone fountain basin with blue water and a central spray. Town-square centrepiece; solid. |
| `gate_arch_wood` | 4,31 | 4×3 | decor | yes | Stone archway fitted with a wooden double gate. Walled entrance for keeps/gardens; solid. |
| `hearth_stone` ⚠️ | 7,28 | 2×2 | decor | yes | Grey stone mantel over a draped purple cloth with a pale-blue flame emblem — a hearth or curtained shop doorway (not stairs); solid. |
| `house_large` | 7,0 | 4×5 | decor | yes | Large timber-framed house, multiple windows, central door, gabled roof. Primary village building; solid footprint. |
| `lamp_post` | 4,28 | 1×1 | decor | yes | Brown wooden post topped by a pale lantern head. Street/plaza lighting; solid. |
| `log_wall` | 4,14 | 4×2 | decor | yes | Wall of stacked horizontal log ends (log-cabin). Cabin walls and stockades; solid. |
| `market_stall_awning` | 17,22 | 6×5 | decor | yes | Market stall with a blue-and-white striped awning over a counter of goods. Marketplace anchor; solid. |
| `market_table` | 23,20 | 2×4 | decor | yes | Wooden market table of colourful wares under a little roof. Single vendor stand; solid. |
| `palisade_log` | 0,20 | 3×1 | decor | yes | Pointed tops of a log palisade fence. Enclose forts/camps; solid barrier. |
| `roof_round_orange` | 3,22 | 3×5 | above | yes | Tall orange conical tower roof with a finial. Drawn over avatars; caps tower_stone_round. |
| `roof_tile_fill` | 32,17 | 1×1 | above | yes | Repeatable horizontal strip of orange roof tiles. Extend roof_tile_large across wide roofs; above avatars. |
| `roof_tile_large` | 21,14 | 6×3 | above | yes | Large angled orange clay-tile roof with ridge and eaves. Covers big buildings; 'above' layer over characters. |
| `shingle_wall` | 22,17 | 2×3 | decor | yes | Wall clad in overlapping wooden shingles/planks. Exterior siding of wooden buildings; solid. |
| `shrine_stone` ⚠️ | 26,0 | 1×1 | decor | yes | Small grey stone portico/shrine — columns supporting a pediment (not a lantern). Wayside altar/mini-temple; solid. |
| `statue_pawn` | 10,22 | 2×4 | decor | yes | Grey carved stone statue with a bulbous chess-pawn head on a pedestal. Monument for plazas/shrines; solid. |
| `statue_relief` | 8,31 | 2×3 | decor | yes | Pale stone figure set in a niche — a wall statue/relief. Mount on castle/temple walls; solid. |
| `stone_wall_arch` | 22,3 | 3×3 | decor | yes | Grey ashlar stone wall pierced by arched openings. Building/courtyard wall segment; solid. |
| `table_stone` ⚠️ | 27,0 | 1×1 | decor | yes | Grey stone table/bench: flat slab on stubby legs (not a plank pile). Stone table/altar slab in ruins/temples; solid. |
| `tent_wood` | 13,5 | 2×3 | decor | yes | Small wooden A-frame hut with steep peaked roof and dark doorway. Outposts, huts, market dwellings; solid. |
| `tower_stone_round` | 0,21 | 3×6 | decor | yes | Tall cylindrical grey stone tower shaft with banding. Cap with roof_round_orange for a turret; solid. |
| `trapdoor_closed` | 33,3 | 2×2 | floor | no | Closed square wooden trapdoor with an iron ring, flush with the floor. Cellar/hatch cover; walkable. |
| `trapdoor_open` ⚠️ | 35,3 | 2×3 | decor | yes | Brown wooden hatch in a grey frame over a rounded stone dome — an opened trapdoor/hatch. Opening blocks movement. |
| `well_stone` | 32,5 | 2×2 | decor | yes | Round stone well with a wooden shingled roof. Classic village-square prop; solid. |
| `window_wood` | 22,7 | 3×2 | decor | yes | Wide wooden-framed window with panes. House facade detail; solid. |

### furniture

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `anvil_forge` | 24,17 | 2×3 | decor | yes | Blacksmith setup: grey iron anvil and stone forge with tools. Smithy centrepiece; solid. |
| `bench_wood` | 28,4 | 3×2 | decor | yes | Wooden bench with a slatted seat and low back. Seating for gardens/plazas/taverns; solid. |
| `counter_wood` | 9,6 | 2×2 | decor | yes | Horizontal tan wooden counter/board with slatted grain and knobs. Market/tavern counter; solid. |
| `planter_box` | 34,2 | 2×1 | decor | yes | Long low brown wooden planter with green shoots. Garden beds and shopfronts; solid furniture. |
| `stool_wood` | 37,8 | 1×1 | decor | yes | Small round wooden stool/seat. Taverns and workshops; solid. |
| `stump_table` | 35,10 | 2×3 | decor | yes | Round wooden tabletop on a short pedestal (stump/round table). Taverns, market corners, yards; solid. |

## inner (48)


### floor

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `floor_checker` ⚠️ | 0,0 | 1×1 | floor | no | Checkerboard floor tile in cream/pink and warm brown squares (marble/tiled). Tile seamlessly to pave indoor rooms and kitchens. |

### wall

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `wall_brick_brown` | 0,1 | 1×1 | decor | yes | Brown brick wall with offset courses and mortar lines. Repeat to build interior walls; blocks movement. |
| `wall_brick_tan` | 0,2 | 1×1 | decor | yes | Pale tan brick wall with offset courses. Tiles seamlessly for lighter interior walls; solid. |

### rug

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `rug_beige` | 0,3 | 4×3 | floor | no | Large woven beige area rug with plain border, repeating dark cross motif and fringed bottom. Lay over floor to define a seating area; walkable. |
| `rug_dark_medallion` | 6,3 | 4×3 | floor | no | Large dark rug with decorative border and central medallion. Grand centerpiece carpet; walkable. |
| `rug_dark_ornate` ⚠️ | 1,0 | 4×3 | floor | no | Large dark rug with light braided border around a near-black field. Anchors a formal room; walkable. |
| `rug_green` | 0,7 | 3×3 | floor | no | Green rug with ornate golden border and solid green field. Adds color to a room; walkable. |
| `rug_green_fragment` ⚠️ | 1,11 | 1×1 | floor | no | Green rug edge/corner tile (lighter beige corner). Walkable; use as green-rug fill. Mislabeled 'painting_medallion'. |

### door

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `door_arch_wood` | 4,2 | 1×2 | decor | yes | Single arched wooden door in a frame, closed. Place in a wall gap as a room entrance; solid when closed. |
| `door_double_arch` | 7,4 | 2×2 | decor | yes | Arched wooden double doors, closed, central seam. Grand entrances/hall doorways; blocks when shut. |
| `doorway_arch_open` | 7,6 | 2×2 | decor | no | Open stone archway with grey masonry surround and dark passage. Walk-through opening between rooms; passable. |

### prop

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `bush_potted` | 11,11 | 1×1 | decor | no | Small terracotta pot with a rounded green bush. Compact indoor greenery; non-blocking. |
| `candle_lit` | 4,15 | 1×2 | decor | no | Lit candle on a round tan holder with a glowing flame. Floor/table light-source accent; non-blocking. |
| `dishes_platters` | 12,6 | 2×1 | decor | no | Two grey serving platters holding food. Dress a dining table/kitchen counter; non-blocking. |
| `painting_landscape` | 9,0 | 1×1 | decor | no | Small framed landscape (blue sky, yellow foreground) in a dark frame. Wall decoration; non-blocking. |
| `painting_landscape_wide` | 16,0 | 3×1 | decor | no | Wide framed green-landscape painting. Statement wall art above beds/sofas/fireplaces; non-blocking. |
| `painting_night` | 14,0 | 2×1 | decor | no | Wide framed night-sky painting with moon and stars. Wall art for bedrooms/studies; non-blocking. |
| `painting_river` | 11,4 | 1×2 | decor | no | Tall framed river/forest landscape. Vertical wall art for hallways; non-blocking. |
| `painting_scene` | 2,11 | 2×1 | decor | no | Two small framed pictures in wooden frames. Paired wall art in rooms/corridors; non-blocking. |
| `plant_potted` | 11,10 | 1×1 | decor | no | Small terracotta pot with a white flowering plant. Windowsill/table accent; non-blocking. |
| `plant_tall` | 8,12 | 1×2 | decor | no | Tall leafy green plant in a terracotta pot. Standing greenery in corners/doorways; non-blocking. |
| `plate_stack` ⚠️ | 9,8 | 1×1 | decor | no | Small cluster of white plates or folded napkins on a surface. Tabletop clutter; non-blocking (low confidence). |
| `props_cluster_pots` ⚠️ | 10,10 | 2×2 | decor | no | Bad multi-prop crop: two white plates, a potted flower, an empty barrel and a leafy plant — not one object. Pick individual props from the raw sheet. |
| `props_wood_small` ⚠️ | 16,7 | 1×3 | decor | no | Bad multi-prop crop: a paddle/board with a hang hole and a small latched crate — not one desk. |
| `table_cloth` ⚠️ | 13,10 | 1×2 | decor | no | Narrow crop of a cloth-draped table corner. Partial/ambiguous; usable as a cloth-covered table fragment. |

### furniture

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `bed_purple` | 19,1 | 3×3 | decor | yes | Full bed with purple blanket and wooden frame. Bedroom/dorm color variant; solid. |
| `bed_yellow` | 16,1 | 3×3 | decor | yes | Full bed with yellow blanket, white pillows, wooden frame (foot view). Bedrooms/inns; blocks movement. |
| `bench_indoor` ⚠️ | 0,14 | 3×2 | decor | yes | Low wooden bench/shelf, three sections, plank top on legs. Seating/display along walls; solid. |
| `cabinet_red_tall` | 6,14 | 2×2 | decor | yes | Reddish-brown two-door wooden cabinet with handles. Bedroom/study wall storage; blocks movement. |
| `cabinet_three_door` ⚠️ | 6,10 | 3×3 | decor | yes | Wide brown three-door cabinet/sideboard with handles. Solid wall storage. Crop bottom catches a second cabinet and a small frog sprite. |
| `cabinet_wood` | 14,4 | 2×2 | decor | yes | Wooden storage cabinet with a door and knob. Wall storage for bedroom/kitchen; solid. |
| `chair_wood` | 16,4 | 1×3 | decor | yes | Wooden chair with tall slatted back, side-facing. Pair with tables/desks; blocks movement. |
| `counter_indoor` | 0,12 | 3×2 | decor | yes | Wooden counter/workbench, flat top over paneled drawers. Kitchen/shop/tavern service counter; solid. |
| `fireplace_lit` | 10,12 | 2×1 | decor | yes | Fireplace hearth with orange flames in a stone/wood surround. Warm animated focal point; solid. |
| `fireplace_stone` | 5,6 | 3×4 | decor | yes | Tall grey stone fireplace with dark hearth and mantel (unlit). Room focal point against a wall; solid. |
| `nightstand_wood` ⚠️ | 12,4 | 2×2 | decor | yes | Small wooden nightstand with a drawer, beside a bed. Crop also catches a thin chair frame on its left. |
| `oven_stone` | 12,12 | 2×2 | decor | yes | Grey stone oven/hearth with an arched opening. Kitchen/bakery wall; blocks movement. |
| `pool_table` | 11,0 | 3×1 | decor | yes | Billiard table: green felt top, wooden rails, balls. Games-room/tavern centerpiece; blocks movement. |
| `shelf_bottles` | 3,12 | 3×2 | decor | yes | Wooden shelving stocked with colorful bottles, jars and books. Shop/kitchen/study walls; blocks movement. |
| `sideboard_wood` | 10,7 | 3×3 | decor | yes | Long wooden sideboard/dresser with a row of drawers and handles. Dining-room/hall storage; solid. |
| `stool_round` | 17,4 | 1×3 | decor | yes | Small round-topped wooden stool. Extra seating at counters/bedsides; solid. |
| `table_round_white` | 13,1 | 3×3 | decor | yes | Large round table with white draped top and wooden legs. Dining/meeting table; blocks movement. |
| `table_round_wood` | 14,7 | 2×2 | decor | yes | Round wooden table with plain grained top. Small dining/side table; blocks movement. |
| `wardrobe_dark` | 0,15 | 2×3 | decor | yes | Tall dark wooden cabinet with louvered slats in a frame. Wardrobe/shuttered cupboard; solid. |
| `wardrobe_wood` | 10,1 | 2×3 | decor | yes | Tall plain wooden wardrobe/cabinet with grey plinth base. Storage piece against a wall; solid. |

### window

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `window_4pane` | 9,4 | 2×2 | decor | no | Wooden-framed four-pane window showing daylight. Mount in interior walls; decorative, non-blocking. |
| `window_dark` ⚠️ | 3,14 | 2×3 | decor | no | Dark wooden window with near-black interior. Dim interior/exterior walls; decorative. Crop overlaps a candle-disc sprite lower-left. |

### stairs

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `stairs_wood` | 2,15 | 2×3 | decor | no | Wooden staircase, side view, ascending. Level connector/vertical accent; typically walkable as a transition. |

## cave (29)


### floor

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `cave_floor_rock` | 0,1 | 1×1 | floor | no | Dark mottled brown cave floor with rocky, dirt-flecked texture. Default walkable cave ground; tile edge-to-edge, then scatter rocks/totems/pools on top. |
| `cave_floor_sand` | 0,2 | 1×1 | floor | no | Lighter tan/sandy cave floor variant. Walkable ground for dry caverns; mix with cave_floor_rock to break up floors. |

### wall

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `cave_dark_hollow` | 1,0 | 2×2 | above | yes | Large near-black hollow rimmed by rough rock (deep wall recess). Impassable dark background pocket behind rock formations. |
| `cave_entrance_alt` | 14,4 | 2×3 | above | yes | Narrower 2x3 dark cave passage with a rock cluster inside. Tighter/gloomier tunnel mouth; solid. |
| `cave_mouth_ring` | 11,4 | 3×3 | above | yes | 3x3 cave mouth: black opening ringed by boulders. Doorway/tunnel entrance; boulder ring solid, dark center is the passage. |
| `cave_wall_base` | 1,5 | 1×1 | decor | yes | Dark chunky rock rubble — base/foot of a cave wall. Line beneath cave_wall_face or use as a low boulder skirt; solid. |
| `cave_wall_face` | 1,3 | 1×2 | above | yes | Tall vertical brown rock wall face (2 tiles), faint cracks. Northern room edge; pair with cave_wall_base at its foot; impassable. |

### misc

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `cave_pit_hole` | 0,4 | 1×1 | floor | yes | Dark oval hole sunk into the floor. Hazard/pit set flush in the ground; blocks movement (a fall). |

### prop

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `cave_rock_small` | 6,3 | 1×1 | decor | yes | Single small brown rock with a lighter top. Floor decoration; solid single-tile obstacle. |
| `rock_boulder` | 5,4 | 1×1 | decor | yes | Rounded single boulder filling most of a tile, with shadow. Solid one-tile obstacle for paths/floors. |
| `rock_boulder_huge` | 8,5 | 2×2 | decor | yes | Massive 2x2 boulder cluster with a central cleft. Major solid landmark; block passages or anchor a chamber. |
| `rock_islet` | 9,7 | 2×2 | decor | yes | Large rounded boulder island in water with a foam ring (2x2). Solid landmark within a pool; unreachable centerpiece. |
| `rock_pebbles` | 5,3 | 1×1 | decor | yes | Pair of small rounded brown rocks. Minor floor decor; scatter for texture. Treated as solid. |
| `rock_pebbles_scatter` | 5,6 | 1×1 | decor | yes | Loose scatter of small dark pebbles. Lightest rock decor; sprinkle near boulders/walls. Solid. |
| `rock_pile` | 5,5 | 1×1 | decor | yes | Flat-topped mound of piled rock with a small stone. Solid rubble decor; cluster for a rockslide. |
| `torch_lit` | 0,6 | 1×1 | decor | yes | Small standing torch, bright flame and warm light halo. Cave light source; place along walls/paths to illuminate and guide. |
| `totem_mask` | 9,0 | 1×3 | decor | yes | Ornate idol totem (3 tiles) with a ceremonial mask and headdress. Shrine centerpiece / focal idol; solid. |
| `totem_skull` | 8,0 | 1×3 | decor | yes | Tall stone totem (3 tiles) carved with a hollow-eyed skull. Ominous idol for burial/cult chambers; solid landmark. |
| `totem_stone_a` | 6,0 | 1×3 | decor | yes | Tall tribal stone totem (3 tiles): banded carved pillar with a blocky head. Ceremonial statue; flank entrances; solid. |
| `totem_stone_b` | 7,0 | 1×3 | decor | yes | Second banded stone totem variant (3 tiles). Pair with totem_stone_a to line ritual corridors without repetition; solid. |

### cliff

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `cliff_rock_top` | 7,3 | 4×1 | above | yes | Jagged upper rim/peaks of a rock cliff (4 wide, pointed top edge). Caps cliff_rock_wall where the crest meets floor above; impassable. |
| `cliff_rock_wall` | 7,4 | 4×2 | above | yes | Broad rocky cliff face (4x2) of layered brown stone. Main cliff body; place beneath cliff_rock_top for a tall barrier. |

### water

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `cave_water_ripple` | 5,7 | 4×2 | floor | yes | Open deep-water surface (4x2) with crescent ripple marks (animation frames). Fill lake/pool interiors; blocks movement. |
| `stepping_stone` | 10,9 | 1×1 | floor | no | Single tile with a small pair of stepping stones ringed by foam. One-tile crossing to bridge short water gaps; walkable. |
| `stepping_stones` | 7,9 | 3×1 | floor | no | Row of three flat stepping stones with water foam (3 wide). Walkable crossing laid over water; chain across a pool. |
| `water_edge_corner` | 4,8 | 1×1 | floor | yes | Diagonal water-to-shore corner: rock top-left, foam edge, deep water lower-right. Pool boundary corner; water side impassable. |
| `water_edge_shore` | 3,9 | 2×1 | floor | yes | 2-wide water shoreline: deep water above a foam border meeting rocky ground. Bank of a pool; water side impassable. |
| `water_pool` | 0,7 | 3×3 | floor | yes | Full 3x3 deep-blue pool framed by rocky shore with foam edge and drip highlights. Self-contained impassable water feature. |
| `water_rock_deep` | 3,7 | 2×2 | floor | yes | Brown rock jutting from a 2x2 patch of deep water with a foam ring. Mid-pool obstacle/accent; impassable. |

## objects (37)


### decor

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `painting_fragment_a` ⚠️ | 12,1 | 1×1 | decor | no | Partial crop: lower-right corner of a framed painting. Not a standalone object. |
| `painting_fragment_b` ⚠️ | 14,1 | 1×1 | decor | no | Fragment of a framed painting (L-shaped corner bands). Bad crop. |
| `painting_framed_dark` | 11,0 | 1×1 | decor | yes | Framed painting, dark interior with a brown band, cream frame and maroon mat. Interior wall/floor decor. |
| `painting_framed_gold` | 10,0 | 1×1 | decor | yes | Framed painting, bright gold canvas in cream frame with maroon mat. Hung or leaning artwork in furnished rooms. |
| `painting_framed_landscape` | 0,0 | 1×1 | decor | yes | Framed picture on the floor: cream frame, maroon mat, warm gold/tan landscape. Lean against walls in houses/shops/galleries. |
| `painting_framed_portrait` | 1,0 | 1×1 | decor | yes | Framed picture, cream frame and maroon mat with a dark interior and a brown horizon stripe (somber scene). Interior wall/floor decor. |
| `pebble_stone` | 16,1 | 1×1 | decor | no | Small round brown pebble. Ground detail; sprinkle along paths/riverbanks/rocky patches. |
| `rug_ornate` | 26,0 | 2×2 | floor | no | Square grey ornamental rug with central diamond and fringed corners. Flat floor covering for interiors/thrones/shrines; walkable. |

### prop

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `barrel_corner_fragment` ⚠️ | 1,6 | 1×1 | decor | no | Bottom-left quarter of the round wooden barrel/avatar frame. Crop fragment, not complete. |
| `barrel_top_partial` ⚠️ | 0,6 | 1×2 | decor | yes | Upper rim of a large round hooped wooden barrel. Partial crop; full object is bigger. |
| `boulder_mossy` | 20,0 | 2×2 | decor | yes | Large brown boulder with moss and grass tufts at base. Movement-blocking obstacle for trails/cliffs/clearings. |
| `grave_stone_a` | 0,8 | 1×1 | decor | yes | Grey arched tombstone with a dark niche. Graveyards, ruins, haunted areas. |
| `grave_stone_b` | 1,8 | 1×1 | decor | yes | Weathered arched gravestone, variant of grave_stone_a. Mix for natural grave rows. |
| `pan_silver` | 2,9 | 1×1 | decor | yes | Silvery cookware: rounded pan/pot with upright handle (covered skillet/ladle). Dress kitchens, hearths, camp fires. |

### misc

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `fragment_light` ⚠️ | 4,7 | 1×1 | decor | no | Small tan corner fragment (box/book corner). Mostly empty, not usable standalone. |
| `frame_avatar_round` ⚠️ | 0,14 | 2×2 | decor | no | Round wooden HUD avatar frame (maroon/gold hoops, peg legs), sits above an EXP bar in the sheet. UI element, not a map prop; could double as a round wooden table-head. |
| `speech_bubble` | 2,7 | 1×1 | decor | no | White rounded speech bubble with a tail (family includes dots/!/? variants). Floating dialogue marker over NPCs; never blocks. |

### container

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `pot_clay_a` | 13,0 | 1×1 | decor | yes | Wide-mouthed tan ceramic pot/cauldron with dark rim. Storage/cooking vessel for kitchens, markets, camps. |
| `pot_clay_b` | 14,0 | 1×1 | decor | yes | Second wide clay pot, slight shading variant of pot_clay_a. Use in clusters. |

### item

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `book_closed_orange` | 15,0 | 1×1 | decor | no | Closed orange hardcover book with a heart emblem. Spellbook/quest item; shelves, desks, altars. |
| `book_open_pages` | 18,0 | 1×1 | decor | no | Open book lying flat, fanned pages, gold edge. Decorative on desks/reading tables. |
| `book_open_quill` | 16,0 | 1×1 | decor | no | Open book upright: white pages, orange spine, yellow bookmark. Lecterns, study desks, libraries. |
| `coin_gold` | 0,5 | 1×1 | decor | no | Gold oval coin with faint star face. Currency pickup; scatter singly or in trails/piles. |
| `coin_gold_counter` ⚠️ | 5,18 | 1×1 | decor | no | HUD currency-counter crop (coin + parchment bar edge), not a clean map coin. |
| `gem_amber` | 3,4 | 1×1 | decor | no | Round faceted amber gem with glowing core. Valuable collectible; mines, chests, caches. |
| `gold_bar` | 1,5 | 1×1 | decor | no | Thin gold ingot/bar with rounded ends. High-value treasure for vaults/chests. |
| `heart_full` | 4,0 | 1×1 | decor | no | Full bright-red heart with highlight. Health/life pickup; paths, chests, reward drops. |
| `heart_red` | 4,8 | 1×1 | decor | no | Deep-red heart with white outline and shadow (health pickup). Art is a heart despite old 'meat_steak' label. |
| `heart_small` | 0,3 | 1×1 | decor | no | Small red heart, minor health pickup or UI life icon. |
| `meat_raw` | 2,5 | 1×1 | decor | no | Pink raw meat/ham chunk. Food pickup for kitchens/larders/enemy drops. |
| `sausage` | 3,5 | 1×1 | decor | no | Salmon-pink sausage/bacon strips. Food pickup or counter dressing for taverns/butchers. |
| `star_gold` | 11,3 | 1×1 | decor | no | Golden four-pointed star in a rounded gold square. Collectible/power-up or objective marker. |

### light

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `flame_fire` | 8,3 | 1×1 | decor | no | Bright orange/yellow campfire flame with white-hot core. Light/heat for fire pits, torches, braziers; animated. |

### plant

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `bush_clover` | 2,0 | 1×1 | decor | yes | Small round-leafed green shrub in a clover cluster. Low cover on grass/gardens/forest edges. |
| `bush_dry` | 8,13 | 1×1 | decor | yes | Brown dry/brambly thicket with a few shoots. Dead undergrowth, autumn scenes, neglected wilds. |
| `bush_teal` | 16,13 | 1×1 | decor | yes | Round mint/teal bush on a dirt mound with grass at base. Exotic/magical shrub for enchanted biomes. |
| `plant_sprout` | 0,10 | 1×1 | decor | no | Seedling on a soil mound (yellow leaves, green shoot). Ground greenery for gardens/farm rows/dirt. |

## character (6)


### character

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `char_redtunic_hero_sword_a` | 0,8 | 4×8 | decor | no | Red-tunic hero sword-attack block: 4 frames x 4 facings, white blade. Player melee-attack sprite. |
| `char_redtunic_hero_sword_b` | 4,8 | 4×8 | decor | no | Red-tunic hero sword-attack block (second variant), 4 frames x 4 facings. |
| `char_redtunic_hero_walk` | 0,0 | 4×8 | decor | no | Hero in red tunic, brown hair (16x32 avatar). Full walk-cycle block: 4 frames x 4 facings (down/right/up/left stacked). Canonical player walk sprite. |
| `char_redtunic_hero_walk_b` | 4,0 | 4×8 | decor | no | Same red-tunic hero walk-cycle block, frames in columns 1-3 (first frame column empty). |
| `char_redtunic_hero_walk_c` | 8,0 | 4×8 | decor | no | Same red-tunic hero walk-cycle block, frames in columns 1-3 (first frame column empty). |
| `char_redtunic_hero_walk_d` | 12,0 | 4×8 | decor | no | Same red-tunic hero, partial walk block (down facing has 3 frames, other facings 1). |

## log (6)


### stump

| name | col,row | size | layer | solid | description |
|------|---------|------|-------|-------|-------------|
| `stump_creature_angry` | 0,6 | 2×2 | decor | yes | Tree-stump creature with a scowling angry face. Aggressive-state stump prop; blocks movement. |
| `stump_creature_back` | 0,2 | 2×2 | decor | yes | Tree-stump creature seen from the back, hollow rim facing away. Back-facing stump prop; blocks movement. |
| `stump_creature_front` | 0,0 | 2×2 | decor | yes | Hollow wooden tree-stump creature with green leaf sprigs and a small face, front idle. Decorative animated stump prop; blocks movement. |
| `stump_creature_leaf_right` | 10,0 | 2×2 | decor | yes | Tree-stump creature with a prominent leaf sprig to its right. Idle variant stump prop; blocks movement. |
| `stump_creature_sleep` | 8,0 | 2×2 | decor | yes | Tree-stump creature, eyes closed with floating 'Z' snooze marks. Sleeping-state stump prop; blocks movement. |
| `stump_plain` | 0,4 | 2×2 | decor | yes | Plain hollow log stump, light-topped rim, no face. Static decorative stump prop; blocks movement. |

---
⚠️ = `review: true` (imperfect crop). 29 tiles flagged.

