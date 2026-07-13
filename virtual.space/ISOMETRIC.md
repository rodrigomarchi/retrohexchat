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
hw = tile_w*scale/2 ; hh = tile_h*scale/2 ; zs = z_step*scale     # tile_w:tile_h = 2:1 (e.g. 64:32)
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
| `slab:{thickness,taper,hull}` | the 3D block: side height, taper 0..1 to a bottom apex, `hull=[minX,maxX,minY,maxY]` of solid cells |
| `sea:{top,bottom,band,bands,amp}` | procedural deep-blue rippling void |
| `vignette:{color,alpha,inner}` | screen-space radial multiply framing the void |
| `railings:[{x,y,edge}]` + `railing_style:{height,color,hi,base,posts}` | the geometric fence (§3) |
| `lights`,`ambient` | color-math atmosphere (additive light pools + multiply ambient wash) |
| `labels` (`hologram` + `lift`) | the DM nameplate floats `lift` px above its tile |
| `layers.decor` (`sort:"flat"\|"stand"`) | stars (flat, void) / props (stand, billboarded, depth-sorted) |

**Keep the floor matrix a square H×W grid.** The platform shape is a straight-edged
rectangle/octagon in tile space (see §3) — never an organic super-ellipse.

---

## 2. The floating 3D slab (`renderer._drawSlabUnderside`)

The platform is a solid block, drawn as ONE shape (not per-tile) before the floor
tiles so the top surface seats over its rim. From the `slab.hull` corners it projects
the four platform vertices, then draws the **two camera-facing front faces**
(front-left, front-right) extruded down by `thickness*z_step` and pulled toward a
centre **apex** by `taper` (0..1). `taper≈0.8` → the block narrows to a **diamond
point below** — a floating gem, not a flat prism. Only the two front faces are
visible; top/back are hidden. A `vignette` + the `sea` complete the "floating in the
abyss" read.

**The void is procedural** (`renderer._drawSea`): a deep-blue vertical gradient +
slowly drifting, gently rippling horizontal bands (wavy filled paths). Map objects
can't make seamless textures — procedural is the reliable win, and it animates
(covers the e2e liveness check). Faint twinkling stars (`sort:"flat"`) scatter the
void.

**Stars are void background:** flat decor draws **before** the floor so the solid
slab **occludes** any star behind it. A solid island can't have stars showing
through it.

---

## 3. The railing — GEOMETRY, not sprites (the crux)

Billboard fence *sprites* can never form a clean continuous rim on iso edges: a
sprite's baked slope never exactly matches the 2:1 edge, so they gap (spaced) or
stack into a mess (dense). **The platform is a square 3D block; its railing is ONE
continuous contour wrapping the four top edges, meeting at corners.** So draw it
**geometrically**, not from art:

1. Make the platform a **straight-edged** rectangle (or bevelled octagon) in tile
   space (`author_scene.py` `RECT`, `bevel:0`) → in iso it projects to a clean
   diamond with **straight** diagonal screen edges. A wobbly super-ellipse is what
   makes a fence staircase — never use one for an iso scene with edge decor.
2. The author emits **edge cells** `railings:[{x,y,edge}]`: each solid cell bordering
   the void contributes a fence segment on that shared diamond edge
   (`edge ∈ tr,tl,bl,br`; a corner cell emits two → the fence wraps the corner).
3. `renderer._drawRailingSegment` draws each on the cell's **exact** diamond-edge
   endpoints (`_railingEdge`): a dark base rail on the lip + evenly spaced gold posts
   + a top and mid rail + finial caps. Adjacent segments **share endpoints →
   seamless**. It participates in `_drawDepthSorted` (baseline `depthKey(x,y)`) so
   back-edge railings draw **behind** avatars, front-edge **in front**.

**General iso lesson:** any edge-aligned decor that must be *continuous* (railings,
walls, kerbs) = **geometry following the edge**, not tiled/billboarded sprites. Only
free-standing upright props (lamp, bucket) are billboards.

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
- **Floor diamond (2:1)**: `create_map_object` at an **exact 64×32** with "diamond
  … fills the entire rhombus" → transparent corners + filled centre that
  **tessellates seam-free**. `create_tiles_pro` isometric only yields ~1:1 (steep,
  wrong for CT's flat 2:1) and ignores `tile_height`. "Bigger cobbles" prompts often
  draw a smaller non-filling patch — keep the plain "round cobbles" one that fills.
- **Upright props (lamp, bucket, gate)**: draw as iso **billboards** — an upright
  object reads correctly in any projection (bottom-centre on the diamond foot). No
  iso-specific art needed; regenerate only for cohesion.
- **Railings**: DON'T generate — they're geometric (§3). Generated fence sprites
  fought the edge slope endlessly.
- Author packs the floor at its **native** size (`author_scene.py` must NOT crop the
  floor tile — the exact 64×32 must survive or tessellation seams appear).

---

## 5. Build & validate loop
- **Regenerate** (deterministic, no PixelLab): `python3 tools/author_scene.py` →
  `endoftime.png` + `end_of_time.json`.
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
- Never deform aspect ratio; regenerate native (2:1 floor via `create_map_object` 64×32).
- Avatars are native **8-direction iso** sprites (feet on `footAnchor`), authored at
  scale 1 — the eight iso facings match the diamond (see [`CHARACTERS.md`](CHARACTERS.md)).
- `make ci` "compile" flakiness = a stale dev-server `_build` lock; kill it.
- Commit: stage exact paths, never a foreign `catalog.ex`; repo commits direct to main.

## 7. Still open / future
- Bigger cobbles (tool-limited via `create_map_object` — needs a real iso tileset
  tool or hand-edit). Wooden door + stone stairs in the fence (CT has them). More
  ornate railing scrollwork.
