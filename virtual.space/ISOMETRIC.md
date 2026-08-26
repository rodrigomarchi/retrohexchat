# Isometric 3D scenes — the playbook

How to build a **true isometric, 3D-reading** virtual-space scene in this engine —
a floating platform with thickness, edge railings, depth, and atmosphere — the way
the **End of Time** scene does it (a Chrono-Trigger floating island). Like
[`SCENES.md`](SCENES.md), almost all of this is hard-won empirical knowledge. Read
this before building or reworking any scene.

The worked example throughout is **End of Time** (`maps/end_of_time.ex`,
authored by `tools/author_scene.py`) — the single registered map, rendered by
both channels and DMs. Isometric is the only projection.

The **ground-truth reference** for End of Time (the real SNES area map + its
distilled anatomy and ranked fidelity gaps) lives in
[`DISCOVERY.md`](DISCOVERY.md) — read it before reworking the scene's art.

---

## 0. The one idea: a projection seam

The engine renders in two stages, and only the second was ever abstracted:

- **Stage A — `tile → worldPixel`**: where a diamond differs from a square. Anchors,
  depth order, the inverse (screen→tile), the input remap all live here.
- **Stage B — `worldPixel → screen`**: `Camera.worldToScreen = wx − camX`. A bare
  translation. **Projection-agnostic. Never touch it.**

So isometric = Stage A lives in an injectable **`Projection`**
(`assets/js/lib/space/projection.js`): the single `IsoProjection` maps the square
(x,y) grid onto a 2:1 diamond. `createProjection` always returns it; the camera gets
one from the map and injects it into the renderer/engine. There is no other
projection — iso is the only one the engine knows.

**Movement, collision, spawns, zones and the server stay a square (x,y) grid.** The
diamond is *purely* a rendering projection of that grid.

### The iso math (2:1 diamond, `IsoProjection`)
```
hw = tile_w*scale/2 ; hh = tile_h*scale/2 ; zs = z_step*scale     # tile_w:tile_h from the art's native size (currently 48:20)
footAnchor(tx,ty,h) = { x:(tx−ty)*hw + originX,  y:(tx+ty)*hh + originY − h*zs }   # diamond CENTRE (feet)
floorAnchor(tx,ty)  = footAnchor − (hw,hh)                        # top-left of the TW×TH sprite box
worldToTile(wx,wy)  : X=wx−originX, Y=wy−originY → tx=(X/hw+Y/hh)/2, ty=(Y/hh−X/hw)/2   # inverse, for hit/click
depthKey(x,y,h)     = x+y + h*EPS                                 # far→near; height only breaks ties
```
`worldBounds` bounds the projected diamond for the camera clamp. There is one
resolution: `tile_size` is always **32**, world `scale` is always **1** and
`avatar_scale` is always **1** (`space_channel.ex` sends them; `engine.js` reads
them; the renderer draws avatars at `avatarScale`, tiles at `camera.scale`). No
derived scaling, no dual-resolution system.

---

## 1. Map schema (iso fields)

`maps/<name>.ex` passes these from the JSON; `map.js` exposes them; the renderer
consumes them.

| Field | Meaning |
|---|---|
| `iso:{tile_w,tile_h,z_step,headroom}` | diamond footprint (2:1) + elevation px + top clearance |
| `slabs:[{thickness,taper,hull}]` | one 3D block per platform/bridge: side height, taper 0..1 to a bottom apex (0 = straight prism, the bridge look), `hull=[minX,maxX,minY,maxY]` of that block's cells |
| `sea:{top,bottom,band,bands,amp}` | procedural deep-blue rippling void |
| `vignette:{color,alpha,inner}` | screen-space radial multiply framing the void |
| `railings:[{x,y,edge}]` + `railing_style:{height,color,hi,base,posts}` | the geometric fence (§3) |
| `lights`,`ambient` | color-math atmosphere (additive light pools + multiply ambient wash) |
| `labels` (`hologram` + `lift`) | the DM nameplate floats `lift` px above its tile |
| `layers.decor` (`sort:"flat"\|"stand"`) | stars (flat, void) / props (stand, billboarded, depth-sorted) |

**Keep the floor matrix a square H×W grid.** The platform shape is a straight-edged
rectangle/octagon in tile space (see §3) — never an organic super-ellipse.

---

## 2. The floating 3D slabs (`renderer._drawSlabUnderside`)

Each platform/bridge is a solid block, drawn as ONE shape per block (not
per-tile) before the floor tiles so every top surface seats over its own rim.
The map carries a `slabs` list; the renderer sorts it **far→near by each hull's
front corner** (`hull[1]+hull[3]`) so a nearer block's faces paint over a
farther block's. Per block, from the `hull` corners it projects the four
vertices, then draws the **two camera-facing front faces** (front-left,
front-right) extruded down by `thickness*z_step` and pulled toward a centre
**apex** by `taper` (0..1). `taper≈0.8` → the block narrows to a **diamond
point below** — a floating gem; `taper 0` → a straight thin prism (the stone
bridges). Only the two front faces are visible; top/back are hidden. A
`vignette` + the `sea` complete the "floating in the abyss" read.

**The void is procedural** (`renderer._drawSea`): a deep-blue vertical gradient +
slowly drifting, gently rippling horizontal bands (wavy filled paths). Map objects
can't make seamless textures — procedural is the reliable win, and it animates
(covers the e2e liveness check). Faint twinkling stars (`sort:"flat"`) scatter the
void.

**Stars are void background:** flat decor draws **before** the floor so the solid
slab **occludes** any star behind it. A solid island can't have stars showing
through it.

---

## 3. The railing — ISO EDGE TILES (generated art, sheared to the slope)

A continuous fence on an iso edge has **two dead ends**: an **upright billboard**
sprite staircases (its top rail stays horizontal while the diamond edge descends
at 2:1), and **code-drawn geometry** (the fence this scene shipped with first)
reads as flat line-art up close — "código deixa a arte feia". The fix is what CT
itself does: the fence is an **edge-aligned TILE** whose base follows the 2:1
slope, anchored on the diamond foot exactly like the floor, so neighbours share
vertices and tessellate **seam-free**.

The pipeline (all real PixelLab art — no code-drawn fence):

1. Keep the platform a **straight-edged** rectangle/octagon in tile space
   (`author_scene.py` `RECT`, `bevel:0`) → a clean diamond with **straight**
   screen edges; a super-ellipse would staircase the tiles.
2. **Generate** a straight **front-elevation** fence strip (PixelLab is good at
   this — but prompt "uniform repeating, no arch, no gate, no central post" or it
   composes a *gate*). Generate the ornate **spear-tip post** as its own tall
   billboard. Both are isolated transparent objects — PixelLab's strength.
3. `author_scene.py._rail_tiles`: crop to content, pick the picket's repeat
   **period** (snapped to a divisor of the cell width `tile_w/2` so cells abut
   with identical spacing), tile ONE period across a cell, and `_shear` it onto
   each edge slope (column `x` drops `x*tile_h/tile_w` → the base traces the edge
   while every bar stays vertical). Two mirror tiles `iso_rail_dr`/`iso_rail_dl`
   wrap all four sides. `_extend_bars` lengthens the picket by **splicing real bar
   pixels** (never a vertical stretch) when a taller fence is wanted.
4. Each solid edge cell emits `railings:[{x,y,edge}]`; `renderer._drawRailingTile`
   blits the matching sheared tile at the cell's near vertex (offset by `edge`),
   depth-sorted so **back** edges (tr/tl) draw behind avatars, **front** (bl/br)
   in front.
5. Ornate posts punctuate the run: `railing_posts:[{x,y,corner}]` — one every N
   cells along each edge **+ the four corners** — billboarded on the diamond
   vertex (`renderer._drawRailingPost`). The tall posts carry the ornament
   PixelLab won't draw at fence scale.

**General iso lesson:** edge-continuous decor (railings, walls, kerbs) = a **tile
drawn along the diamond edge slope** (base on the foot), tessellated per cell —
NOT an upright billboard (staircases) and NOT code-drawn geometry (flat line-art).
Free-standing upright props (lamp, corner post) stay billboards.

**Validate at REAL scale — a zoomed offline preview LIES.** A 3× zoom on a tiny
6×6 platform flatters a short/plain fence; on the real platform at game scale it
reads tiny. Render the ACTUAL scene at the game scale (scale 1 — tiles and
avatar both native) with an avatar in frame for proportion, or check in-app —
height and ornament only read honestly against the avatar and the full floor.

### Depth sorting (`renderer._drawDepthSorted`)
Iso merges standing props, avatars and railings into one list keyed by
`projection.depthKey`: props/railings by their base tile `x+y`, avatars `x+y+0.5`,
height only a tie-break (`h*EPS`) so a tall thing never reorders its neighbours.
Multi-tile props sort by their **front** corner. The iso floor itself paints far→near
(cached `x+y` order), **skipping the ground/void tile** so the platform floats.

---

## 4. The art pipeline for iso (and the ONE inviolable rule)

**Never deform aspect ratio to fit a slot — regenerate at the native ratio.**
Squashing a 1:1 tile to 2:1 flattens the pixels and reads as junk up close. See the
memory `no-aspect-ratio-deform`.

What the PixelLab tools actually give (empirical):
- **Floor diamond (flat)**: `create_map_object` at an **exact flat canvas** with
  "diamond … fills the entire rhombus" → transparent corners + filled centre that
  **tessellates seam-free**. The shipped floors are **48×20 native** (the 64×32
  calibration also worked); the projection reads `iso.tile_w/tile_h` from the
  art's own size. `create_tiles_pro` isometric only yields ~1:1 (steep, wrong for
  CT's flat look) and ignores `tile_height`. "Bigger cobbles" prompts often
  draw a smaller non-filling patch — keep the plain "round cobbles" one that fills.
- **Upright props (e.g. the lamp)**: draw as iso **billboards** — an upright
  object reads correctly in any projection (bottom-centre on the diamond foot). No
  iso-specific art needed; regenerate only for cohesion.
- **Railings**: DO generate, but as a **straight front-elevation strip + a post**
  (isolated objects), then the author tiles + shears them onto the edge (§3). Do
  NOT ask PixelLab for the whole iso-sloped fence — it can't tile a baked slope,
  and "fence" prompts drift into centred *gates*.
- Author packs the floor at its **native** size (`author_scene.py` must NOT crop the
  floor tile — the exact native canvas (48×20 today) must survive or tessellation
  seams appear).

---

## 5. Build & validate loop
- **Regenerate** (deterministic, no PixelLab): `python3 tools/author_scene.py` →
  `endoftime.webp` + `end_of_time.json`.
- **See it** (the only way to judge iso): run the Playwright spec
  `e2e/tests/space-end-of-time.spec.ts` (kill `:4003` first; a stale `mix phx.server`
  holding the `_build` lock makes `make ci` "compile" hang — `pkill` it) → Read
  `e2e/test-results/end-of-time.png`.
- **Validate**: `make ci` (9/9). CSS Lint runs `mix audit.styles --strict` — no
  hardcoded hex in JS (use named top-level colour consts + the `#`-via-`HASH` trick)
  and **no Elixir function named `*style*`** (it flags them as CSS builders; we used
  `railing_look`). Must be 0 LOW/MEDIUM/HIGH.
- **map_test** requires `tile_size` to be `32`; `ground` must be in `tiles`; spawns
  off-collision.

## 6. Gotchas, distilled
- Straight platform edges (rect/octagon), never a super-ellipse — else railings step.
- Railing = geometric contour; free props = billboards.
- Stars/flat-decor draw BEFORE the floor in iso (solid slab occludes them).
- Never deform aspect ratio; regenerate native (flat floor via `create_map_object`
  at an exact flat canvas — shipped floors are 48×20; the projection reads the
  ratio from the art).
- Avatars are native **8-direction iso** sprites (feet on `footAnchor`), authored at
  scale 1 — the eight iso facings match the diamond (see [`CHARACTERS.md`](CHARACTERS.md)).
- `make ci` "compile" flakiness = a stale dev-server `_build` lock; kill it.
- Commit: stage exact paths, never a foreign `catalog.ex`; repo commits direct to main.

## 7. Still open / future
- Bigger cobbles (tool-limited via `create_map_object` — needs a real iso tileset
  tool or hand-edit). The wooden door was tried and **reverted** at the user's
  call, and the stone stairs deliberately omitted ([`DISCOVERY.md`](DISCOVERY.md)
  gap 3) — don't revisit either without an explicit ask.
- **S-scroll filigree between posts**: PixelLab won't draw the scroll at fence
  scale (it returns a plain picket), so the ornament currently rides on the tall
  posts. A dedicated scroll-panel motif spliced into the picket would push closer
  to the fan-art look (image 2); the game screenshots (1/3) are picket-dominant.
