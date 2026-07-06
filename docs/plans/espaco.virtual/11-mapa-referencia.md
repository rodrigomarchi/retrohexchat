# Reference map — deep analysis (Elfic Forest target)

Purpose: fully understand the reference forest map **before** building ours, so
we stop guessing. This document describes what the reference *is* as terrain —
its elevation logic, paths, density and props — plus the exact tile/autotile
inventory it needs. No implementation here; this is the spec we build against.

Source image: a single screenshot, `~/Desktop/…08.43.11.png` (1616×1172),
shown **zoomed out** — it is the *whole level at once*, not a viewport. So the
real map is large; tiles look small. Tileset is the same public-domain
`Overworld.png` we already extract from.

---

## 1. The one-sentence idea

A **natural forest basin**: an open grass **valley** in the middle where players
walk, ringed and terraced by **forested higher ground**, with the height change
drawn as **rock cliffs** that snake and step down into the valley. Two focal
landmarks sit at opposite corners — a **cabin** (upper-left) and a **pond**
(lower-center, the lowest point). It reads as a *place with depth and routes*,
not a flat field with props scattered on it.

This is the core thing our current map gets wrong: we have flat grass with
isolated brown bars. The reference is **layered terrain**.

---

## 2. Macro composition (whole-level schematic)

Rough thirds (zoomed-out overview):

```
 ┌──────────────────────────────────────────────────────────┐
 │ CABIN▓         dense treeline / high ground ▒▒▒▒▒▒▒▒▒▒▒▒  │
 │ ░stump  ░rocks      ▒cliff────┐   ▒rock-on-cliff          │
 │        ══cliff══ gap ══cliff════╗  ▒▒  cliff steps down    │
 │   ░log        │path│            ║        diagonally ▒▒     │
 │                                 ╚═╗ (staircase of ledges)  │
 │        O P E N   V A L L E Y      ║                        │
 │        (sparse: few trees,        ╚══╗   ░log-on-ledge     │
 │         clover + dark-grass        ░stump ░log-on-ledge    │
 │         patches, a stump)             ║                    │
 │  ▒dark-forest        ══cliff══════════╝    ░log-on-ledge   │
 │  mass          ~~POND~~ (at base of cliff) ▒dense forest▒  │
 └──────────────────────────────────────────────────────────┘
   ▓ cabin  ▒ trees/forest  ══ cliff face  ░ prop  ~ water
```

Read it as elevation, not a flat picture:

- **Outer ring = high ground**, thickly forested (dense tree canopies + bushes).
- **Cliffs** step *down* from that ring into the valley, mostly as a **diagonal
  staircase** on the right half and horizontal ledges on the top/left.
- **Center = the low valley**, open grass, sparse — this is the play space.
- The **pond** is the lowest pocket, tucked against the base of a cliff.

---

## 3. Elevation & cliff system — THE core (what we keep failing)

The cliffs are a **full autotile**, not a horizontal bar. Observed pieces:

- **Top lip**: grass tile with a dark shadow strip on the side that faces the
  drop (the top of the cliff, walkable, at the *higher* level).
- **Face**: rocky brown, vertical striations, 1–3 tiles tall depending on the
  height of the drop.
- **Base**: rock face bottom with rounded pebbles where it meets the *lower*
  grass.
- **Corners** — REQUIRED and currently missing:
  - **Outer corners** (convex): where a ledge turns and the face wraps around a
    protruding nose of high ground.
  - **Inner corners** (concave): where the face tucks into a notch.
- **Vertical / side faces**: the cliff also runs *vertically* (e.g. the whole
  left border is a cliff seen edge-on; the right side is a descending
  staircase). Vertical runs need side-face + corner tiles, not just the
  front-facing horizontal face.

Behaviour / layout rules seen:

- Cliffs **snake and step**: a run of horizontal ledge, then a 1-tile drop to a
  lower ledge, repeated — a **staircase** descending toward the valley.
- **Gaps / ramps**: the cliff line is broken by openings where players move
  between levels (e.g. below the cabin there's a break used as a path; our
  cave-mouth idea is one legit way to render a passage).
- **Small isolated raised platforms** exist inside the valley — a ~2×2 patch of
  high ground fully ringed by cliff, often with a log on top.
- Trees and props sit **on the high ledges** (above the face), reinforcing "this
  is raised".

Engineering implication: to reproduce this we must (a) extract the **complete
cliff autotile set** (edge L/M/R, face, base, the 4 outer + 4 inner corners,
vertical L/R side faces), and (b) add a small **autotiler**: given a boolean
"high-ground" mask over the grid, pick the correct cliff tile per cell from its
neighbours. Horizontal-only bars can never look like this.

---

## 4. Walkability, paths, routes

- **Valley floor** (low, open grass) = the main walkable area / spawn.
- **Higher terraces** are also walkable (grass on top of the cliffs); you reach
  them through the **gaps/ramps** in the cliff line.
- **Worn-grass / dirt paths**: subtle lighter, trodden strips connect features —
  notably a vertical path dropping from the cabin toward the cliff gap. Paths
  guide the eye and the feet; they are a distinct ground treatment (dirt patch
  with grass edges = its own small autotile).
- **Choke points**: the cliff gaps are deliberate pinch points between levels.
- The pond is an **obstacle** (water = blocked) tucked at a cliff base, not a
  place you cross.

---

## 5. Ground texture (the richness we lack)

The grass is **not uniform**. Layers, from base up:

1. **Base grass** — medium green with faint blade specks.
2. **Dark-grass patches** — soft, irregular, rounded **darker-green blobs**,
   scattered densely across the whole floor. This is the single biggest texture
   element and we don't have it yet. Likely a semi-transparent overlay/decal
   tile (or a dark-grass autotile blob), *not* the light-edged patch we tried
   (that one has a hard bright rim and looks wrong).
3. **Clover / flower clusters** — small groups of white 4-petal specks (`✦✦`),
   sprinkled as accents (we have this as `flowers`).
4. **Dirt / worn ground** — brown earth patches with grass edges, used for
   paths and bare spots.

Distribution: patches and clover are *everywhere but sparse*, breaking up the
green; density of decals is higher near paths and features.

---

## 6. Vegetation

- **Round tree canopies** — the dominant sprite; big soft round tops. Come in a
  couple of sizes; frequently **overlap in clumps** of 2–4 to make bigger
  masses.
- **Treeline** — the map border and high ground are a **thick, dense** band of
  overlapping canopies + bushes (a wall of green), not a thin single-tile ring.
- **Density gradient** — very dense at the edges/high ground → sparse in the
  open valley (a few lone trees only). This gradient is what makes the valley
  read as a clearing.
- **Bushes / hedges** — smaller round greenery filling between trees and along
  cliff tops.
- Trees sit **on the higher ledges**, their bases near the cliff lip.

---

## 7. Water

- A single **pond**, lower-center, **at the base of a cliff** (water pools at
  the lowest point below a ledge).
- Blue fill with a **wavy surface** (`~` ripples) and a **light/white shore**
  rim; grass and bushes crowd its edges.
- It is a small, self-contained body (roughly 4–6 tiles wide), not a river.

---

## 8. Landmarks & props

| Prop | Where / how | Have it? |
|------|-------------|----------|
| **Cabin** | upper-left, on an upper terrace, facing down (door + 2 windows) | ✅ `house` |
| **Pond** | lower-center, base of a cliff | ✅ `pond_*` (small) |
| **Tree stumps** | round cut-tree tops with rings; a few, in the open | ❌ need `stump` |
| **Fallen logs** | horizontal; placed **on cliff ledges / terraces** as benches, and a couple in the valley | ✅ `log_*` (placement wrong) |
| **Rocks / pebbles** | tiny rock specks scattered on grass | ✅ `rock_s` (under-used) |
| **Boulder** | one bigger rock, sitting **on top of a cliff** | ✅ `boulder` |
| **Dark-grass patches** | see §5 | ❌ need `grass_dark*` |
| **Dirt path** | see §4/§5 | ❌ need `dirt*` |

Placement principle: props are **motivated** — logs on ledges, boulder on a
clifftop, stump in a clearing, rocks trailing along edges — never a uniform
sprinkle.

---

## 9. Tile / sprite inventory (build checklist)

Already extracted & good: `grass`, `bush`, `tree` (2×2 round), `house`,
`boulder`, `log_l/m/r`, `flowers`, `rock`/`rock_s`, `pond_*` (9), `cave`,
`cliff_edge/face/mid/base` (horizontal only).

Still needed for reference fidelity:

- **Cliff autotile — full set**: outer corners (NE/NW/SE/SW), inner corners,
  vertical L/R side faces, edge L/M/R variants. (Locate the complete block in
  `Overworld.png`; it exists — the reference uses it.)
- **Dark-grass patch** — the soft darker blob overlay (find the decal; it is not
  the light-rimmed patch at Overworld (0,6)).
- **Dirt / worn-path** autotile (center + grass edges) — Overworld (1,30) is the
  dirt center; needs its edge tiles.
- **Stump** — round cut-tree top (locate in sheet).
- Optional: a **larger tree** variant and a **bush cluster** fill for denser
  masses.

---

## 10. Design principles (the "why", to reuse when composing)

1. **Terrain first, props second** — lay out elevation (valley vs high ground)
   and the cliff lines, *then* drop props on the resulting shelves.
2. **Density gradient** — thick forest at edges, open middle; the emptiness of
   the valley is intentional and defines the play space.
3. **Framing & focal points** — cliffs and treeline frame the valley; cabin and
   pond anchor opposite corners and give orientation.
4. **Motivated placement** — every log/boulder/stump sits *because of* a shelf,
   edge or clearing, never on a grid.
5. **Routes & choke points** — cliff gaps and worn paths steer movement; the
   layout implies where you go.
6. **Texture breaks the green** — dark-grass blobs + clover + dirt keep the
   floor from being a flat mat; they are sparse but everywhere.

---

## 11. Gap analysis vs our current `elfic_forest`

What we have right: valley concept, round tree decor, tall readable horizontal
cliff faces, a cave passage, pond at a cliff base, forest border, dense-ish tree
ring.

What is still wrong / missing (in priority order):

1. **Cliffs don't turn** — only horizontal bars; no corners/vertical runs, so no
   staircase and no real terracing. → needs the full cliff autotile + a small
   autotiler driven by a high-ground mask. **(biggest gap)**
2. **No dark-grass patches** — floor is a flat green mat. → find the dark-grass
   decal; scatter sparsely everywhere.
3. **No stumps, no dirt paths** — missing texture/landmarks. → extract + place.
4. **Prop placement is grid-ish** — logs/rocks not motivated by shelves/edges. →
   place logs on ledges, rocks trailing edges, boulder on a clifftop.
5. **Treeline not thick/dense enough** and the density gradient is weak. →
   thicker overlapping canopies at edges, emptier center.

Recommended build order once we implement: (a) high-ground mask + cliff
autotiler + full cliff tiles → real terraced terrain; (b) dark-grass +
dirt-path decals for floor richness; (c) stumps + motivated prop placement;
(d) density-gradient pass on the treeline.
