# Virtual-space characters — pipeline & playbook

How the selectable player characters are made, from AI generation to the
in-game sprite. Read this before adding, regenerating, or debugging an avatar.
The knowledge here is hard-won and mostly empirical — the PixelLab service is
powerful but flaky, and the engine has a few non-obvious contracts.

Every avatar is a **premium 8-direction isometric** character, authored at
**native scale 1** (1:1, no scaling in code) to match the iso diamond floor
(see [`ISOMETRIC.md`](ISOMETRIC.md)). There is no legacy top-down / 4-direction
avatar anymore.

---

## 1. What exists

Players choose a character when they enter a Space — channel or DM (a 4×2 picker).
The roster is **8 iso avatars**, all built by this pipeline:

| id | role | sheet |
|---|---|---|
| `hero` | default (assigned before a pick) | `avatars/iso_hero.png` |
| `knight` | armoured melee | `avatars/iso_knight.png` |
| `sorceress` | mage | `avatars/iso_sorceress.png` |
| `archer` | ranged | `avatars/iso_archer.png` |
| `barbarian` | heavy melee | `avatars/iso_barbarian.png` |
| `rogue` | daggers | `avatars/iso_rogue.png` |
| `cleric` | support | `avatars/iso_cleric.png` |
| `monk` | martial artist | `avatars/iso_monk.png` |

The clean id (`hero`) is what the server and picker use; the sheet/geometry are
named `iso_<id>` (`iso_hero.png`, `iso_hero.geo.json`). `hero` is `hd(@avatars)`
— the **default** everyone spawns as until they pick.

Runtime sheets + their geometry are served from
`apps/retro_hex_chat_web/priv/static/images/space/avatars/iso_<id>.png` (+
`iso_<id>.geo.json`). Raw generation exports (per-frame PNGs) are kept in
`virtual.space/characters/iso_<id>/pixellab/` so a sheet can always be recomposed
without re-spending generations.

### Animations & facings

Each character carries **walk + idle + attack + sleep** in all **8 iso
facings** (sleep's south row is the 4-frame seated doze from the class's
"sitting on the ground" sibling state; the other seven facings hold that state's
static sitting rotations). Knight, rogue and sorceress additionally carry
**idle2** — the second idle stance generated for them (breathing-idle; their
`idle` block is calm-idle). The eight facings, in the row order every sheet is
packed:

```
south, south-east, east, north-east, north, north-west, west, south-west
```

The game's `sword` action maps to the **attack** block (each class swings its
own weapon — the weapon comes for free from the base sprite). `idle` and `sleep`
are the resting states — the renderer alternates `idle`/`idle2` on a slow,
per-participant-offset cycle where `idle2` exists, and `sleep` faces the
avatar's own direction; an avatar missing any animation falls back to `walk`.

### Sheet layout (per character)

`compose_iso_avatar.py` packs one sheet per character: **4 frames** per
animation per direction, laid out **direction-major** in the fixed animation
order `walk, idle, idle2, attack, sleep`, skipping any animation not yet
generated.
Every frame is cropped to **one shared vertical window** (feet flush to the
bottom, full width kept so the body stays centred through the attack swing).

Geometry lives beside the sheet in `iso_<id>.geo.json`:

```json
{"frameW": 188, "frameH": 142, "cols": [0, 188, 376, 564],
 "anims": {"walk": {"south": 0, "south-east": 142, ...},
           "idle": {...}, "attack": {...},
           "sleep": {"south": 3408, "south-east": 3550, ...}}}
```

`frameW/frameH` is the cell size, `cols` are the four frame x-offsets, and each
anim maps a direction → its **row y-offset**. The atlas is generated from this
data (§4) — no per-avatar code.

---

## 2. Generating a character (PixelLab MCP)

The [PixelLab](https://pixellab.ai) MCP server does the art. Add it once:

```bash
claude mcp add pixellab https://api.pixellab.ai/mcp -t http \
  -H "Authorization: Bearer <PIXELLAB_TOKEN>"
```

Check `mcp__pixellab__get_balance` first. Budget generously: an 8-direction
character with walk + idle + attack + sleep is **many** generations (1 create +
8 walk + 8 idle + 8 attack + 1 sleep, plus retries) — a paid tier (Tier 1, 2000
generations) is required, not a trial.

> ⚠️ PixelLab has **no reference-image input** for `create_character`. Style
> consistency comes ONLY from using identical parameters across every
> character. Do not change them between characters.

> **Premium art, not the easiest.** Always use the premium **v3 / 8-direction**
> path — never `standard`. Credits are not the constraint; class-A art is.
> (See the memory `premium-art-not-easiest`.)

### 2a. Create (the 8 directional rotations)

`mcp__pixellab__create_character` — the premium 8-direction rotation set.
Locked params (identical across every character):

```
description: "RPG overworld <role>, <specifics>"
n_directions: 8                  # the eight iso facings
view:        "isometric"         # matches the 2:1 diamond floor
outline:     "single color black outline"
shading:     "basic shading"
detail:      "medium detail"
```

The art is authored at its **native size** and rendered at **scale 1** — never
scale it up or down in code. If a size looks wrong, **regenerate** it in
PixelLab at the right size; do not scale/crop in the engine (memory
`pixellab-art-authority-scale-1`).

### 2b. Walk & idle animations

`mcp__pixellab__animate_character` — **1 generation per direction (8 total)** per
animation. Walk and idle are full 8-direction cycles (4 frames each):

```
animation_name: "walk"    # then "idle"
directions:     ["south","south-east","east","north-east",
                 "north","north-west","west","south-west"]
```

### 2c. Attack animation

`mcp__pixellab__animate_character`, **v3** mode — **1 gen/direction (8 total)**:

```
mode:               "v3"
frame_count:        4
keep_first_frame:   false          # false => exactly 4 frames (true => 5)
animation_name:     "attack"
action_description: "swinging their weapon forward in a quick attack"
directions:         ["south","south-east","east","north-east",
                     "north","north-west","west","south-west"]   # v3 defaults to south only!
```

### 2d. Sleep (south-only seated pose)

Sleep is a single **south-facing** seated/resting pose — one direction, not
eight. Generate it for `south` only; the atlas reuses it for any facing.

### 2e. Job limits & flakiness (the empirical part)

- **Max 8 concurrent jobs.** An 8-direction animation = 8 jobs, so only **one
  character animates at a time**. Batch accordingly; excess calls return
  `need N job slots but only M available`.
- PixelLab **fails intermittently**, especially under load:
  - `Generation failed due to heavy load. Please try again.`
  - spurious `404: Character rotation image not found for direction: <dir>`
    (the rotation PNG is actually fine — verify with `curl` on the public
    backblaze URL; just retry).
- **Retry failed directions individually.** Partial successes survive: an
  8-direction call that dies on direction 5 keeps directions 1–4.
- Some directions occasionally generate **3 or 5 frames instead of 4** — the
  compose script pads/truncates to exactly 4 (see §3).
- After generating, **always verify coverage** before composing: every
  direction of walk/idle/attack should have frames, plus the full `sleep` block
  (4 doze frames in `sleep/south`, one static sitting rotation per other facing).

### 2f. Download the export

The per-character endpoint returns a zip (raw, reliable):

```bash
curl -L "https://api.pixellab.ai/mcp/characters/<id>/download" \
  -H "Authorization: Bearer <PIXELLAB_TOKEN>" -o char.zip
# HTTP 423 => jobs still pending. Structure:
#   <Name>/rotations/<dir>.png
#   <Name>/animations/<anim>/<dir>/frame_00X.png
#   metadata.json
```

Unzip so the raw frames land under
`virtual.space/characters/iso_<id>/pixellab/animations/<anim>/<dir>/*.png`.

---

## 3. Composing the sheet

```bash
python3 virtual.space/tools/compose_iso_avatar.py           # default iso_knight
python3 virtual.space/tools/compose_iso_avatar.py iso_hero  # one character
```

`compose_iso_avatar.py` reads the raw frames, crops every frame to **one shared
vertical window**, stacks them in direction-major blocks (`walk, idle, attack,
sleep`, skipping absent ones), and writes `avatars/iso_<id>.png` plus the sibling
`iso_<id>.geo.json`. It is **deterministic** (same frames → identical bytes) and
defensively handles the flakiness:

- **Pads/truncates** to exactly 4 frames per direction (a 3-frame direction
  repeats its last frame; a 5-frame one drops the extra — imperceptible in a
  fast cycle).
- **Skips** any animation with no frames yet (the roster is built up
  incrementally as animations land).

Inspect the result visually before trusting it — render the walk/idle/attack
blocks scaled up on a checkerboard (that is how every calibration in this
project was reviewed).

---

## 4. Engine integration

The renderer (`assets/js/lib/space/renderer.js`) is **size-agnostic**: it draws
`sprite.sw × sprite.sh × avatarScale` and anchors the sprite's feet to the iso
diamond foot, so the frame size is pure data — no renderer change per character.

### The atlas

`assets/js/lib/space/sprite_atlas.js` builds every avatar from data:

- `DIRECTIONS` — the eight iso facings, in packed row order.
- `ROSTER` — the 8 clean ids; `DEFAULT_AVATAR_ID = "hero"`.
- `ISO_GEO` — per-avatar geometry (`frameW/frameH`, `cols`, per-anim/-direction
  row offsets), **generated** by `tools/gen_iso_atlas.py` from every
  `iso_<id>.geo.json`.
- `AVATAR_SHEETS` — self-loaded `av_iso_<id>` image list, loaded **independent of
  the active map** so every avatar resolves on any scene.
- `isoAvatar(id)` builds each descriptor from `ISO_GEO` (`scale: 1`, `attack` →
  the `sword` action); a **single native iso geometry** — no special-cased legacy
  hero. `avatar(id, dir, frame, action)` resolves the rect, falling back to the
  default avatar and to `walk` / the first facing when an id/action/direction is
  absent (so a partially-generated block still serves every facing).

`gen_iso_atlas.py` prints both the `AVATAR_SHEETS` entries and the `ISO_GEO`
literal, so adding or regenerating a character is a **data change** you paste in.

### The select_avatar round-trip

```
picker click (phx-click "space_select_avatar")
  -> ChatLive assigns space_avatar, mounts SpaceCanvasHook with data-avatar
  -> hook pushes CLIENT_EVENTS.SELECT_AVATAR after channel join
  -> SpaceChannel handle_in("space_select_avatar")
  -> VirtualSpace.select_avatar -> ChannelSpaceServer.apply_select_avatar
  -> broadcast_delta (participant_view carries `avatar`)
  -> every client's engine applies the delta; sprite swaps live
```

Two JS gaps that had to be fixed (keep them in mind if avatars ever stop
updating live): `engine.js _reconcileSelf` must carry `avatar` on a **self**
delta, and `protocol.js normalizeUpdates` must coerce `avatar`.

### The picker component — location matters

`components/ui/space_character_select.ex`. It **must** live under
`components/ui/` (a Tailwind-path that `mix lint.css_consistency` skips). A
component under `live/chat_live/components/` is scanned, and raw Tailwind
utilities there fail the check as "missing CSS". The animated previews are CSS
sprites (`.rh-charsel-*` in `retrohex.css`, allowlisted under
`rh-charsel-sprite--*` because a Tailwind-path component isn't scanned).

In-game, the attack fires on the **Space** key (`ACTION_MAP` in `input.js`).

---

## 5. Add a new character — checklist

1. **Generate** (§2): create (8-dir) + walk + idle + attack (8 dirs each),
   plus the "sitting on the ground" sibling state (8-dir rotations + a south
   breathing doze) that fills the `sleep` block, using the locked params.
2. **Download & verify** coverage (§2e–2f), retrying flaky directions.
3. **Compose** the sheet (§3); eyeball the blocks.
4. **Regenerate the atlas data**: `python3 tools/gen_iso_atlas.py` and paste the
   printed `AVATAR_SHEETS` entry + `ISO_GEO` block into `sprite_atlas.js`.
5. **Sync the two source-of-truth roster lists** (they must match, order
   included):
   - JS: add id to `ROSTER` in `sprite_atlas.js`.
   - Elixir: add id to `@avatars` in `channel_space_server.ex`.
6. **CSS**: add `.rh-charsel-sprite--<id>` in `retrohex.css` (covered by the
   `rh-charsel-sprite--*` allowlist entry).
7. **Label**: add to `@labels` in `components/ui/space_character_select.ex`.
8. **Help**: extend the roster wording in the `feature-choose-character` topic
   (`chat/help_topics/features.ex`) and its content
   (`help_content/feature_choose_character.html.heex`).
9. **Tests**: update `AVATAR_IDS` in `sprite_atlas.test.js` and the `@avatars`
   assertion in `avatar_test.exs`.
10. **Validate**: `make ci` (9/9), then verify in a browser — the picker grid,
   the avatar rendering in-world, and the attack (Space) — via the
   `e2e/tests/space-character-select.spec.ts` Playwright spec.

Grid tip: keep the roster a multiple of 4 so the picker stays a clean grid.

---

## 6. Gotchas, distilled

- **Style consistency = identical create params.** No reference image exists.
- **Premium v3 / 8-direction, always.** Never `standard`; the eight iso facings
  must match the diamond.
- **Native scale 1.** Art is authored 1:1 and rendered at scale 1 — fix a wrong
  size by regenerating in PixelLab, never by scaling/cropping in code.
- **8-job ceiling** → animate one character at a time (8 dirs = 8 jobs).
- **Retry per direction.** Heavy-load and phantom-404 failures are common;
  partials survive, so re-run only the missing directions.
- **keep_first_frame:false** for exactly 4 v3 frames; **v3 defaults to south
  only** — always pass all eight `directions`.
- **Sleep is south-only** — one seated pose the atlas reuses for any facing.
- **Picker lives in `components/ui/`**, never `chat_live/components/`.
- **Renderer is size-agnostic**; don't special-case a frame size there.
- **Self deltas drop non-position fields** unless explicitly carried.

## 7. Avatar rendering on every map

- **Auto-load every iso sheet, don't rely on the map.** `AVATAR_SHEETS` in
  `sprite_atlas.js` loads all eight `av_iso_<id>` sheets **independent of the
  active map**, so an avatar resolves on any scene. A nickname with no sprite
  means its sheet isn't loaded (or its `avatar` id has no sheet): the atlas
  returns the rect as soon as the sheet is *registered*, and the label draws from
  `nickname` alone, so a missing/late sheet shows as a floating name.
- **Bots (and anyone who never picked) use the default avatar.** The server
  seeds them via `avatar_for/2 = hd(@avatars) = "hero"`; nothing bot-specific is
  needed on the client beyond that sheet already being in `AVATAR_SHEETS` (it is
  — it's the first roster entry). Every bot renders the `hero` sprite on any map.
