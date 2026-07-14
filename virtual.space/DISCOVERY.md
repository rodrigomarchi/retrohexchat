# Discovery log — archaeology of the source material

Durable record of the **reference material** the virtual-space scenes are built
to match, and what we learned by studying it. When a scene chases a real game's
look, the ground-truth reference is a *finding* — capture it here (image saved in
the repo + its source + the anatomy we extracted) so no future session has to
rediscover it. This is archaeology: the artifact and its reading, preserved.

> Convention: save the reference image under
> `scenes/<scene>/reference/` (git-tracked) and add a section below with the
> source URL, the date found, and the distilled anatomy. Never rely on a link
> alone — links rot; commit the pixels.

---

## End of Time (Chrono Trigger) — the DM scene ground truth

- **Artifact:** [`scenes/end_of_time/reference/end_of_time_snes_map.png`](scenes/end_of_time/reference/end_of_time_snes_map.png)
  (full SNES area map, 1024×768).
- **Source:** SNESMaps.com map rip by Rick N. Bruns, v1.0 © 2011 —
  `https://www.vgmaps.com/Atlas/SuperNES/ChronoTrigger-EndOfTime.png`.
- **Found:** 2026-07-11, while judging how close our iso scene got to "full CT".

### Anatomy of the real End of Time (what we're matching)
The real area is **three square platforms floating in a dark rippling sea,
joined by stone bridges** — not one platform:

1. **Pillars-of-light platform** (top-left): a grid of glowing **blue light
   pillars** (the numbered era portals 1–9) on the cobble floor.
2. **Spekkio's room** (right): a lit cobble circle with Spekkio centred, a
   **wooden door/gate** on the left edge.
3. **Central hub** (bottom-centre): the iconic **lamppost** + the **Old Man
   (Gaspar)** standing in a warm **light pool**, a **wooden door** at the top
   edge, and a **stone staircase** descending off the lower-right corner. This
   is the platform our DM scene is modelled on.

Key visual facts (the ones that decide fidelity):
- **Floor = warm brown cobblestone in concentric radial rings**, with the light
  pool glowing *through* the stone at each platform's centre. (Our biggest gap:
  ours reads cold-grey and flat.)
- **Railing = tall, ornate wrought-iron** (brass/gold), Victorian park style, on
  every edge — taller and more decorative than a plain fence.
- **Block undersides = dark, flat-bottomed, reddish** (a solid prism), NOT a
  tapered diamond. Our diamond apex is a deliberate stylisation (user-requested).
- **Sea = dark navy with horizontal rippling wave bands** — our procedural sea
  matches this well.
- **Props:** lamppost, bucket, wooden door, stone stairs, the light pillars.

### Fidelity gaps (ranked — first judged 2026-07-11 at ~75%)
1. ✅ **Floor** (was 🔴, closed 2026-07-11): the cold-grey tile is **warmed to CT
   brown/tan** (`floor_0.png` recoloured via a luminance→warm ramp — the diamond
   already tessellated, only the palette was cold). The amber light pool now glows
   *through* warm stone, reading like CT's lit plaza. The literal concentric
   mortar rings are a platform-level feature we approximate with the radial glow.
2. ✅ **Railing** (was 🟡; reworked 2026-07-13): the code-drawn fence was replaced
   by **generated iso edge tiles** — a straight PixelLab wrought-iron strip tiled
   per cell and **sheared onto the 2:1 edge**, with tall **ornate spear-tip posts**
   (their own billboard) every 3 cells + on the corners. All real pixel art, seam-
   free around the platform (`_drawRailingTile`/`_drawRailingPost`, authored by
   `_rail_tiles`). Matches the CT game screenshots; the fan-art S-scroll is still
   open (ISOMETRIC §7).
3. ❌ **Wooden door** (tried 2026-07-11, **reverted** same day): a door set into a
   gap in the back rail read as awkward clutter in the round DM room — removed at
   the user's call. **Stone staircase also omitted** — CT's stairs bridge
   platforms; our single floating room has nowhere to go. Lesson: not every CT
   prop transplants to a one-platform DM scene; the fence + lamp carry the read.
4. ✅ **Railing height** (2026-07-11): raised (h 27 → 38) — CT's iron fence is tall;
   the shorter version read as a low garden edge.
5. ✅ **Lamp light** (2026-07-11): two fixes. (a) The pool anchored at the sprite
   box top-left (`floorAnchor`) → landed ½ tile up-left of the lamp; re-anchored to
   the tile ground centre (`footAnchor`). (b) A single ground pool centred on the
   base read as "light from the base" — the emitter is the lantern *head*. So the
   lamp now casts **two stacked additive glows**: a soft ground pool + a tight
   bright halo `lift`ed ~106px up to the lantern head (new `light.lift` field, px).
   Reads as source-on-top, light-on-ground.
6. 🟢 One platform vs three (+ bridges) — acceptable simplification for a 1:1 DM room.
7. 🟢 Diamond underside vs flat reddish block — intentional stylisation, keep.

**Scene reads ~93–95% CT** (2026-07-11): warm lit cobble plaza, tall ornate iron
railing on all four sides, lamp casting an aligned amber pool + the holographic
nameplate, adrift in the rippling sea of time. (The bucket prop was cut
2026-07-13 — the fence + lamp carry the read.)

See [`ISOMETRIC.md`](ISOMETRIC.md) for how the scene is built and
[`SCENES.md`](SCENES.md) for the scene catalogue.
