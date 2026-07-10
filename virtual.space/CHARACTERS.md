# Virtual-space characters — pipeline & playbook

How the selectable player characters are made, from AI generation to the
in-game sprite. Read this before adding, regenerating, or debugging an avatar.
The knowledge here is hard-won and mostly empirical — the PixelLab service is
powerful but flaky, and the engine has a few non-obvious contracts.

---

## 1. What exists

Players choose a character when they enter a channel's Space (a 4×2 picker).

| Roster | id | sheet | source |
|---|---|---|---|
| Hero (legacy) | `redtunic_hero` | `character.png` (16×32 frames) | hand-authored, pre-existing |
| 7 classes | `sorceress`, `knight`, `archer`, `barbarian`, `rogue`, `cleric`, `monk` | `avatars/<id>.png` (36×36 frames) | PixelLab, this pipeline |

Runtime sheets are served from
`apps/retro_hex_chat_web/priv/static/images/space/avatars/<id>.png`.
Raw generation exports (per-frame PNGs + `metadata.json`) are kept in
`virtual.space/characters/<id>/pixellab/` so a sheet can always be recomposed
without re-spending generations.

### Sheet layout (class avatars — 144×288)

36px cells, 8 rows × 4 columns:

```
        col0    col1    col2    col3      <- animation frames 0..3
row 0   walk  down / south
row 1   walk  up   / north
row 2   walk  left / west
row 3   walk  right/ east
row 4   attack down / south
row 5   attack up   / north
row 6   attack left / west
row 7   attack right/ east
```

The game's `sword` action maps to the **attack** block (each class swings its
own weapon — the weapon comes for free from the base sprite).

---

## 2. Generating a character (PixelLab MCP)

The [PixelLab](https://pixellab.ai) MCP server does the art. Add it once:

```bash
claude mcp add pixellab https://api.pixellab.ai/mcp -t http \
  -H "Authorization: Bearer <PIXELLAB_TOKEN>"
```

Check `mcp__pixellab__get_balance` first. A **trial** has ~40 generations; a
paid tier (Tier 1) has 2000. Budget: **~13 generations per fully-animated
character** (1 create + 4 walk + 4 attack, plus retries).

> ⚠️ PixelLab has **no reference-image input** for `create_character`. Style
> consistency comes ONLY from using identical parameters across every
> character. Do not change them between characters.

### 2a. Create (the 4 directional rotations)

`mcp__pixellab__create_character` — **1 generation**. Locked params:

```
description: "chibi RPG overworld <role>, big round head, small body, <specifics>"
mode:        "standard"          # standard is REQUIRED — pro/v3 ignore proportions
body_type:   "humanoid"
n_directions: 4
size:        24                  # renders on a ~36px canvas
view:        "low top-down"      # the JRPG 3/4 angle that matches character.png
outline:     "single color black outline"
shading:     "basic shading"
detail:      "low detail"
proportions: {"type":"custom","head_size":1.8,"arms_length":0.7,
              "legs_length":0.65,"shoulder_width":0.7,"hip_width":0.75}
```

Why these exact values (calibration history):
- `size: 32` + `proportions: chibi` preset came out **tall and lanky** — wrong.
  `size: 24` + the **custom** chibi proportions above gives the squat, big-head
  look that matches the hero and the 16px tile world.
- `view: "low top-down"` matches; `"high top-down"` is too steep.
- The world is built from **16px tiles**, so the character must stay small. A
  48px sprite towers over the houses — do not scale up.

### 2b. Walk animation

`mcp__pixellab__animate_character`, template mode — **1 gen/direction (4 total)**:

```
template_animation_id: "walking-4-frames"   # exactly 4 frames, matches the hero
animation_name:        "walk"                # export folder is named "animating"
```

### 2c. Attack animation

`mcp__pixellab__animate_character`, **v3** mode — **1 gen/direction (4 total)**:

```
mode:               "v3"
frame_count:        4
keep_first_frame:   false          # false => exactly 4 frames (true => 5)
animation_name:     "attack"        # export folder is named "attack"
action_description: "swinging their weapon forward in a quick attack"
directions:         ["south","north","east","west"]   # v3 defaults to south only!
```

### 2d. Job limits & flakiness (the empirical part)

- **Max 8 concurrent jobs.** A 4-direction animation = 4 jobs, so only **2
  characters animate at a time**. Batch accordingly; excess calls return
  `need N job slots but only M available`.
- PixelLab **fails intermittently**, especially under load:
  - `Generation failed due to heavy load. Please try again.`
  - spurious `404: Character rotation image not found for direction: <dir>`
    (the rotation PNG is actually fine — verify with `curl` on the public
    backblaze URL; just retry).
- **Retry failed directions individually.** Partial successes survive: a
  4-direction call that dies on direction 3 keeps directions 1–2. Retried
  single directions land in **sibling folders** named `attack-<hash>` — the
  compose script merges them (see §3).
- Some directions occasionally generate **3 frames instead of 4** — the compose
  script pads them (see §3).
- After generating, **always verify coverage** before composing: every
  direction of every animation should have 4 frames.

### 2e. Download the export

The per-character endpoint returns a zip (raw, reliable):

```bash
curl -L "https://api.pixellab.ai/mcp/characters/<id>/download" \
  -H "Authorization: Bearer <PIXELLAB_TOKEN>" -o char.zip
# HTTP 423 => jobs still pending. Structure:
#   <Name>/rotations/<dir>.png
#   <Name>/animations/<anim>/<dir>/frame_00X.png
#   metadata.json
```

Unzip into `virtual.space/characters/<id>/pixellab/`.

---

## 3. Composing the sheet

```bash
python3 virtual.space/tools/compose_avatars.py            # all avatars
python3 virtual.space/tools/compose_avatars.py knight     # just one
```

`compose_avatars.py` slices the 36px frames into the fixed 144×288 grid and
writes `priv/static/images/space/avatars/<id>.png`. It is **deterministic**
(same export → identical bytes) and defensively handles the flakiness:
- **Merges** every folder matching `attack*`, picking the version with the most
  frames per direction (recovers a retry-split attack).
- **Pads** a direction that generated 3 frames by repeating the last frame
  (imperceptible in a fast swing).

Inspect the result visually before trusting it — render the walk and attack
blocks scaled up on a checkerboard (that is how every calibration in this
project was reviewed).

---

## 4. Engine integration

The renderer (`assets/js/lib/space/renderer.js`) is **size-agnostic**: it draws
`sprite.sw × sprite.sh × camera.scale` and anchors the sprite's feet to the
tile, so 36px frames needed **no renderer change**. Everything else is data.

### The atlas

`assets/js/lib/space/sprite_atlas.js` holds per-avatar **pixel** geometry:
- `AVATAR_SHEETS` — self-loaded `av_<id>` image list (global, not per-map).
- `AVATARS` — each id → `{ sheet, walk, sword }` blocks with `frameW/frameH`,
  `cols` (x offsets) and `rows` (y per facing). `classAvatar(sheet)` builds the
  standard 36px walk+attack blocks; the hero is expressed in its own 16×32 /
  32×32 geometry so it stays pixel-identical.

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

1. **Generate** (§2): create + walk + attack, using the locked params.
2. **Download & verify** coverage (§2d–2e), retrying flaky directions.
3. **Compose** the sheet (§3); eyeball walk + attack blocks.
4. **Sync the two source-of-truth lists** (they must match, order included):
   - JS: add id to `AVATARS` (via `classAvatar("av_<id>")`) and a sheet to
     `AVATAR_SHEETS` in `sprite_atlas.js`.
   - Elixir: add id to `@avatars` in `channel_space_server.ex`.
5. **CSS**: add `.rh-charsel-sprite--<id>` in `retrohex.css` (covered by the
   `rh-charsel-sprite--*` allowlist entry).
6. **Label**: add to `@labels` in `components/ui/space_character_select.ex`.
7. **Help**: extend the roster wording in the `feature-choose-character` topic
   (`chat/help_topics/features.ex`) and its content
   (`help_content/feature_choose_character.html.heex`).
8. **Tests**: update `AVATAR_IDS` in `sprite_atlas.test.js` and the `@avatars`
   assertion in `avatar_test.exs`.
9. **Validate**: `make ci` (9/9), then verify in a browser — the picker grid,
   the avatar rendering in-world, and the attack (Space) — via the
   `e2e/tests/space-character-select.spec.ts` Playwright spec.

Grid tip: keep the roster a multiple of 4 so the picker stays a clean grid.

---

## 6. Gotchas, distilled

- **Style consistency = identical create params.** No reference image exists.
- **standard mode** is the only one that honours `proportions`.
- **Small on purpose.** 24px create / 36px frames fit the 16px tile world.
- **8-job ceiling** → animate 2 characters at a time.
- **Retry per direction.** Heavy-load and phantom-404 failures are common;
  partials survive into `attack-<hash>` sibling folders that compose merges.
- **keep_first_frame:false** for exactly 4 v3 frames.
- **v3 defaults to south only** — always pass all four `directions`.
- **Picker lives in `components/ui/`**, never `chat_live/components/`.
- **Renderer is size-agnostic**; don't special-case 36px there.
- **Self deltas drop non-position fields** unless explicitly carried.

## 7. Avatar rendering across maps (the bot regression)

- **Auto-load the character sheet, don't rely on the map.** The default red-tunic
  hero lives on `/images/space/character.png`; the 7 class avatars on their own
  `avatars/*.png`. The atlas (`sprite_atlas.js`) loads `AVATAR_SHEETS`
  **independent of the active map** — and `character.png` MUST be in that list.
  It wasn't: the hero sheet used to arrive only because the old channel map
  (Overworld/ElficForest) happened to declare a `character` tileset. When the new
  channel scene didn't, **bots** (and anyone who never picked a class, who all
  fall back to `redtunic_hero`) rendered a **nickname with no sprite**. Fix: put
  `{ id: "character", src: "/images/space/character.png" }` in `AVATAR_SHEETS` so
  the default avatar resolves on **every** map.
- **Bots use the default avatar.** They never open the picker; the server seeds
  them via `avatar_for/2 = hd(@avatars) = "redtunic_hero"`. Nothing bot-specific
  is needed on the client beyond the default sheet being loaded.
- **A nickname with no avatar = the sheet isn't loaded** (or the participant's
  `avatar` id has no sheet). `atlas.avatar` returns the rect as soon as the sheet
  is *registered*; the label draws from `nickname` alone, so a missing/late sheet
  shows as a floating name. Auto-loading the needed sheets is the durable fix.
