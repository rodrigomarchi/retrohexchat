# Animating virtual-space maps — pipeline & playbook

How a scene's tiles and props are brought to life with **real, generated pixel
art** — no runtime procedural animation. Read this before animating anything in a
space. Like [`SCENES.md`](SCENES.md) and [`CHARACTERS.md`](CHARACTERS.md), most of
this is hard-won empirical knowledge.

The worked example throughout is the **End of Time** DM scene: flickering fire
braziers, a swirling portal, flame-lit lamps, an off-air-static CRT, a breathing
Nu, and an infinite twinkling starfield — every one a PixelLab animation the
engine cycles.

> **Platform rule: zero procedural animation.** Motion is always real generated
> frames cycled on a clock — never runtime-drawn twinkle/glow/noise. The early
> procedural POC (canvas-drawn stars, a baked radial lamp-glow) was removed. Even
> the "background sky" twinkle uses shrunk real star art, not drawn dots.

---

## 1. The animated-tile model

A tile is animated purely by two extra vocab keys — everything else is a normal
tile, so animated and static tiles coexist and the change is backward-compatible:

| Key | Meaning |
|---|---|
| `frames` | Number of frames, **packed horizontally** from `col` (frame *i* at `col + i*w`). |
| `period_ms` | Full-cycle duration. Frame duration is `period_ms / frames`. |

The client atlas (`sprite_atlas.js tile(name, now, seed)`) resolves the current
frame on a **global clock** and offsets each tile's phase by a **per-position
seed** so repeated tiles never pulse in lockstep:

```js
if (frames > 1) {
  const period = spec.period_ms ?? 800;
  const phase  = ((seed >>> 0) * 2654435761) % period;   // per-position offset
  const idx    = Math.floor((now + phase) / (period / frames)) % frames;
  col = spec.col + idx * w;                                // slide across the strip
}
```

`now` is `performance.now()`; `seed` is `seedAt(x,y)` (a spatial hash in
`renderer.js`). A static tile (`frames` unset ⇒ 1) ignores both — same code path.

**Why this works out of the box:** the engine already runs a continuous RAF loop
(`engine.js _frame → renderer.draw({…, now})`), so animation is a *localized*
change — vocab keys + a few lines in the atlas/renderer — with no new loop.

---

## 2. Engine wiring (already in place)

Three small hooks, all done — you only touch these when extending the mechanism:

- **`sprite_atlas.js`** — `tile(name, now = 0, seed = 0)` cycles animated frames
  (above). Returns the same `{img, sx, sy, sw, sh, flipX}` rect as a static tile.
- **`renderer.js`** — `seedAt(x, y)` (a `73856093 / 19349663` xor-hash);
  `draw()` threads `now`; `_drawFloor`/`_drawDecor` call
  `atlas.tile(id, now, seedAt(x, y))`. So **both floor tiles and decor props
  animate**, each desynced by its grid position.
- **`Maps.<Name>` (Elixir)** — `tiles/1` must pass the optional keys through to
  the client. Keep it flat (credo: max nesting 2) via a helper, not a nested
  `case`:

  ```elixir
  @optional_tile_keys ~w(flip_x frames period_ms)
  defp put_optional(rect, key, v) do
    case v[key] do
      nil -> rect
      value -> Map.put(rect, String.to_atom(key), value)
    end
  end
  ```

---

## 3. Generating an animation (PixelLab MCP)

Object animations work **directly on map objects** — no heavyweight review flow.
Check `mcp__pixellab__get_balance` first. The reliable recipe:

1. **`create_map_object`** — transparent-bg object. Generate **generously large**
   (e.g. 96px) for detail; it's scaled down at pack time (§4). `view: "side"` for
   furniture (TV), `"high top-down"` for creatures/props (Nu, star).
2. **`animate_object`** — `mode: "v3"` (default; higher quality **and** cheaper
   than `pro`), `frame_count: 6` (any even 4–16), `keep_first_frame: false` (drop
   the reference frame so you get exactly N generated frames). For a 1-direction
   object, **omit `directions`** — it animates the single `unknown` direction.
   Write the animation prompt to move only what should move ("*the body stays
   still*", "*base fixed*").
3. **`get_object`** — once complete, returns the animation group + frame URLs
   `…/animations/<group>/unknown/{i}.png (i=0..N-1)`.
4. **Download** each frame into `virtual.space/scenes/<scene>/anim/<name>/{i}.png`
   with `curl -sf`. These raw frames are the tracked source art — commit them.

Under load a generation can take 5–7 min instead of 30–90 s; poll `get_object`.

---

## 4. Packing frames into the sheet — `author_scene.py`

Animated props are declared in `ANIM_PROPS` (`name → (folder, col, row, w, h,
period_ms)`) and packed as a **horizontal frame strip** from `(col,row)`. The
sheet grows taller to hold the strips; each entry emits
`vocab[name] = {col,row,w,h,frames,period_ms}`. Two rules are non-negotiable:

### 4a. Union-bbox packing — the wobble killer

Crop **every frame to ONE shared window** — the *union* of all frames' bboxes —
never a per-frame `getbbox()`. Per-frame crop + recenter shifts the static parts
frame-to-frame, so a "still" post/body **visibly wobbles**. The union window
pins the base; only the moving pixels (flame, vortex, static, bob) change.

```python
boxes = [im.getbbox() or (0,0,im.width,im.height) for im in ims]
union = (min(b[0] for b in boxes), min(b[1] for b in boxes),
         max(b[2] for b in boxes), max(b[3] for b in boxes))
crop = im.crop(union)   # same window for every frame
```

### 4b. Scale-to-fit, never crop content

If the union is bigger than the `w×h` block (a 96px object in a 48px tile),
**scale it down preserving aspect** — do *not* center-crop, or you slice off a
fragment (a 96px Nu became a flat teal rectangle). Then bottom-anchor like a
standing prop:

```python
bw, bh = w*T, h*T
uw, uh = union[2]-union[0], union[3]-union[1]
scale  = fit/max(uw,uh) if fit else min(1.0, bw/uw, bh/uh)   # fit = tiny pinpoint
```

This is backward-compatible: fire/lamp/portal/star already fit (scale = 1), so
their packing is unchanged.

### 4c. Reuse one animation at multiple sizes

`SCALE_TO_FIT` shrinks the same art to a tiny centred pinpoint. The twinkle star
packs as a bright **2×2 near star** *and* a ~5px **far star** from the identical
frames. Hash-scatter the far star across the void cells
(`floor[y][x] == "void" and _hash(x,y) % N == 0`) and the per-position seed
desyncs each one → an endless, shimmering, real-image starfield. Layer a few
bright near stars over the dense far field for depth ("infinite sky").

---

## 5. Tuning & the End of Time inventory

`period_ms` sets the mood — fast crackle vs. slow breath:

| Prop | frames | period_ms | feel |
|---|---|---|---|
| `eot_fire` (brazier) | 6 | 660 | lively flicker |
| `eot_lamp` | 6 | 780 | flame-lit flutter |
| `eot_portal` | 6 | 700 | swirling vortex |
| `eot_tv` (off-air static) | 6 | 420 | fast snow crackle |
| `eot_nu` (breathing) | 6 | 1800 | slow squish/bob |
| `eot_star` (near) | 4 | 1400 | bright twinkle |
| `eot_star_far` (deep sky) | 4 | 1600 | faint distant blink |

Interpretation of a design note matters: "animate the water/fire" meant **only
what already exists**, on a global clock with a per-position offset — not adding
new procedural systems.

---

## 6. Verify motion in a real browser

`map_test.exs` covers the layout; **motion needs a canvas check**. The E2E spec
(`e2e/tests/space-end-of-time.spec.ts`) hashes `getImageData` into a
`canvasSignature`, then asserts it **changes over ~1300 ms with nobody moving** —
proof the tiles/props are advancing frames, not just static art:

```js
const before = await canvasSignature(canvas);
await page.waitForTimeout(1300);
expect(await canvasSignature(canvas)).not.toBe(before);   // frames advanced
```

Also eyeball `scene_preview.png` (one frame) for placement, then the E2E
screenshot for the live look. Finish with `make ci` (9/9).

---

## 7. Add an animated prop — checklist

1. **Generate** (§3): `create_map_object` → `animate_object` (v3, 6 frames,
   `keep_first_frame:false`) → download frames to `scenes/<scene>/anim/<name>/`.
2. **Inspect the frames** — print each frame's `size`/`getbbox()`. Drop any
   **junk frame** (a fully-opaque `alpha 255` frame renders as a solid square —
   PixelLab occasionally emits these); keep the clean subset (§8).
3. **Declare** it in `ANIM_PROPS` with a sheet slot + `period_ms`; if it should
   be a shrunk pinpoint, add it to `SCALE_TO_FIT`. Bump the sheet height if the
   new strip doesn't fit. Remove the prop's static entry if you're replacing one.
4. **Place** it in `DECOR` (and its footprint in `SOLID`); re-run
   `author_scene.py`; eyeball `scene_preview.png`.
5. **Verify**: `map_test.exs`, the E2E motion assertion + screenshot, `make ci`.

---

## 8. Gotchas, distilled

- **The engine is already animation-ready** — RAF passes `now`; animated tiles
  are vocab keys + atlas/renderer lines, not a new loop. Static tiles unaffected.
- **Union-bbox packing, always** — per-frame auto-crop makes a "still" base
  wobble. One shared window; only the moving pixels change.
- **Scale to fit, never crop** — content bigger than its tile must be scaled
  (aspect-preserving), or you slice a fragment (the flattened-Nu bug).
- **Reuse art at sizes** — one twinkle → near star + hash-scattered far field;
  the per-position seed makes the whole sky shimmer out of phase.
- **PixelLab emits junk frames** — a fully-opaque frame (all `alpha 255`) draws
  as a solid square. Inspect bboxes/alpha and drop the bad ones.
- **`mode: "v3"`, `keep_first_frame: false`** — the dependable animation recipe;
  cheaper and better than `pro`. Omit `directions` for 1-direction objects.
- **Elixir must pass `frames`/`period_ms`/`flip_x` through** — via a flat
  `put_optional` helper (credo max-nesting is 2), not a nested `case`.
- **Motion needs a browser assert** — `canvasSignature` before/after with nobody
  moving; layout tests can't see animation.
- **Commit the raw frames** — `scenes/<scene>/anim/<name>/*.png` is tracked
  source art; `author_scene.py` is deterministic and re-reads them.

## 9. More gotchas — from the Millennial Fair (flat 16-bit) pass

- **Sheet must fit the widest strip, or frames flicker.** An animated tile packs
  `frames` cells horizontally, so its strip is `w × frames` tiles wide. If that
  exceeds `SHEET_COLS` the trailing frames land off the sheet and render **empty
  → the prop blinks** on those frames. A 4-tile prop × 6 frames = 24 tiles wide.
  Set `SHEET_COLS` accordingly **and keep a guard** that raises if any
  `w*frames > SHEET_COLS` (it fails loudly instead of silently flickering).
- **Verify every frame cell is non-empty** after packing (crop each frame rect
  from the sheet, assert `getbbox()` is not None) — the cheapest blink check.
- **"Floating" = the art has no base.** A hanging-lantern sprite with no post
  reads as floating in mid-air. Generate the *whole* object (a lamppost = post +
  base + lamp head), not just the glowing part.
- **Blinking ≠ animating.** If the animation frames disagree on the object's
  fixed parts (a lantern whose post appears/vanishes frame to frame), it reads as
  a strobe. Animate ONLY the moving element and keep the base identical across
  frames (union-bbox handles alignment; the *prompt* must say "the post stays
  perfectly still").
- **Subtle beats spectacular.** An over-strong effect prompt ("electricity arcs
  crackle") gave the telepod huge white bursts that read as a *mortar & pestle*.
  Prompt for a **faint/small** effect ("a few faint blue sparks flicker at the
  tip; the body stays perfectly still") and a **clean readable base shape**.
- **Cohesive flat animations.** Generate the animated object itself in the flat
  16-bit register (`detail: "low detail"`, `shading: "flat shading"`, native
  size) — an animation only looks as coherent as the object it animates
  (see `SCENES.md` §8).
- **Animating a map-object directly works.** `animate_object` takes a
  `create_map_object` id (not just character ids); the frames come back under
  `.../objects/<id>/animations/<group>/unknown/{i}.png`.
- **To animate an existing static prop, regenerate it as an object.** Map
  objects auto-delete after 8h, so the original id is usually gone. Recreate the
  prop with `create_map_object` (same flat-16-bit params to stay cohesive), then
  `animate_object`; frame 0 becomes the new static. Judge the regen against the
  current sprite before accepting — swap the `PROPS` source from `foo.png` to
  `anim/foo` and delete the orphaned static PNG.
- **One coherent breeze beats scattered effects.** When several outdoor props
  animate at once (flags, tent pennants, foliage), tie them to a *single* wind:
  scale `period_ms` by the material's weight — light fabric ripples faster
  (~850–1000 ms), heavy foliage sways slower (~1500–1600 ms). Same physical
  cause, so the whole scene reads alive instead of twitchy. The per-position
  seed already desyncs repeated props (every tree/bush out of phase).
