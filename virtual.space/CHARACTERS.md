# Virtual-space characters — the character creator

How the Space's characters are made, from PixelLab generations to the figure
people compose in the creator. Read this before adding a piece (an outfit, a
body, a hairstyle, a hat, a face item), regenerating one, or debugging how a
character draws. Almost everything below was learned by spending generations;
the cost table at the end is what a piece really takes.

Characters are **paper dolls**: a person picks a body, a skin colour, an
outfit and its two colours, a hairstyle and its colour, a hat and its two
colours, and a face item, from pieces generated beforehand. Nothing calls
PixelLab while somebody makes a character. Every piece is premium
**8-direction** art at **native scale 1**, with every clip drawn for every
facing — no mirroring, no reversed clips.

---

## 1. What a character is

A **recipe**, one short string (`RetroHexChat.VirtualSpace.CharacterRecipe`):

```
c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0
   body skin outfit+2 dyes  hair+dye  hat+2 dyes  face
```

`h-0`, `w-0`, `f-0` mean none. A colour is one base-36 digit, an index into a
palette. The recipe travels everywhere: the wire (`space_select_avatar`, join
params), the portal URL (`?avatar=`), the nickname's row
(`registered_nicks.avatar`). Every client composes the same figure from it.

The pieces, as layers drawn in this order:

| Layer | What it is | Made per |
|---|---|---|
| **base** | a body wearing an outfit: the whole figure, skin included | body × outfit |
| **face** | a face item (glasses, beard…) | once, on the master |
| **hair** | a hairstyle | once, on the master |
| **hat** | headwear; `hair: clip` cuts the hair it covers | once, on the master |

Overlays are made **once, on the master mannequin**, and fit every body: the
bodies are states of the master too, so they share its skeleton and their heads
stand where the master's does. The build measures any pixel of drift per frame
(each base's `delta` in the catalog) and the compositor moves the overlays by it.

## 2. The master and its states

Everything is a **PixelLab character state** (`create_character_state`) of one
master mannequin, `CreatorBaseAverage` (`catalog_src.json` → `master`): v3,
104 px canvas, ~95 px tall, bald, plain grey undershirt and shorts, barefoot.
A state keeps the master's identity, proportions and **skeleton** — that is
what makes the layers line up. Never make a piece with `create_character`: a
new character has its own skeleton and nothing will fit on it.

### Key colours (how a piece says what is its own)

A state is **not** a clean diff of the master: every generation redraws the
whole figure a little, so `state − master` is noise all over the body. A piece
marks its own pixels by colour instead:

- **Overlays** (hair, hat, face item): drawn in **vivid saturated magenta**
  (hue ~310). A hat's band or trim in **vivid saturated cyan** (hue ~185).
- **Outfits**: the dyeable cloth in **magenta** (main colour) and **cyan**
  (trim). Anything not meant to be dyed in **neutrals** — greys, black, white,
  metal. **No browns or warm tans on an outfit**: they read as skin and get
  recoloured with it.
- The final colours come from palettes at runtime, so the key colours are
  never seen.

Prompts that worked (pass `state_name`, keep the rest of the figure "exactly
unchanged"):

```
outfit: wearing a knee-length cloth tunic dyed vivid saturated magenta pink,
        with vivid saturated cyan trim along the collar, sleeves and hem, a
        plain cyan sash belt, light grey trousers and dark grey leather boots;
        keep the exact same bald head, face, skin, body proportions and pose unchanged
hair:   with long straight hair falling down to the shoulders, the hair is a
        vivid saturated magenta pink colour; everything else exactly unchanged:
        same face, same grey undershirt and shorts, same pose
hat:    wearing a wide-brimmed adventurer hat made of leather dyed vivid
        saturated magenta pink, with a vivid saturated cyan band around the
        crown; everything else exactly unchanged: …
body:   with a much broader, stockier, heavier and more muscular build with
        wide shoulders and a thick torso; keep the exact same bald head and
        face unchanged, same grey undershirt and shorts, same pose
```

Lessons:
- A **grey** key is useless: grey hair over the grey undershirt left holes
  where the two matched. Always a key no other part of the figure has.
- Say where a hat **sits**: the adventurer hat came out worn low over the eyes,
  and its portrait shows a brim and a chin. Ask for "worn high on the head, the
  face fully visible".
- A body type must keep the **height and the head**: a shorter body moves the
  head and every overlay would need its own version.

## 3. Animations

The clips are in `catalog_src.json` → `clips`. Each is generated for every
piece and every facing:

| Clip | How |
|---|---|
| walk, idle, attack, hit, ko, getup | `animate_character` `mode="skeleton-v3"` with the template the source names |
| sit | **posed**: `animate-with-skeleton-v3` with keypoints from `creator_pose.py` (its `steps`) |

The frames of a clip are whatever its template gives; the build reads the
count off the master and refuses a piece that differs.

- **Only `skeleton-v3` keeps the piece's look.** `mode="template"` redraws the
  character from its *original description* — the master's — so a tunic state
  walked barefoot in grey shorts. `mode="v3"` (custom) kept the look but the
  south walk barely moved.
- skeleton-v3 frames come on a **144 px canvas** with the figure centred; the
  poses of different states match frame for frame.
- **There is no sit template** (`crouching` ends squatting), so the seated clip
  is posed: `creator_pose.py` takes the master's 3-D skeleton (PixelLab keeps
  it with the character), bends it into a chair, projects it into each facing
  with an affine map fitted to the facing's 2-D skeleton (within ~1.5 px), and
  sends the same keypoints for every piece. Say there is **no furniture** in
  the `action` — "sitting down on a chair" drew chairs and a table.
- `/estimate-skeleton` cannot read lying poses (it gave −21° for a body lying
  flat), so nothing tracks heads; every overlay is animated itself.

## 4. The pipeline

All committed; nothing here runs in a build.

1. **Add the piece to `virtual.space/characters/creator/catalog_src.json`**
   with a new short id (never reuse one — stored recipes name ids) and its
   PixelLab state id. A base goes under `bases` as `"<body>/<outfit>"`.
2. **Generate its clips**: `python3 virtual.space/tools/creator_generate.py plan`
   lists what is missing; `… run --budget N` queues it (8 jobs at a time,
   retries failures, stops at the budget, writes posed frames to `raw/` as jobs
   end); the animation groups are kept in `characters/creator/pixellab.json`.
   Token in `PIXELLAB_TOKEN`.
3. **Download the frames**: `… creator_generate.py fetch` →
   `characters/creator/raw/<layer>/<clip>/<dir>/<i>.png`.
4. **Build**: `make space.creator` (`build_creator.py`) writes the indexed
   sheets `apps/retro_hex_chat_web/priv/static/images/space/creator/<layer>_<clip>.png`
   (rows the eight facings, columns the frames), the hat masks, the portrait
   crops, both catalogs (`…/creator/catalog.json` for the web,
   `apps/retro_hex_chat/priv/virtual_space/character_catalog.json` for the
   server), the swatch CSS and the golden portraits the server is tested
   against. `make space.creator.check` (part of `make lint.css`) fails when
   any of it is not what the frames build.
5. **Look at it**: `python3 virtual.space/tools/creator_contact_sheet.py out.png --random 20`
   composes random recipes in every clip and facing, the way the game does.
6. **Name it**: a label in `components/ui/space_character_creator.ex` and a
   row in `scripts/i18n/glossary.py` (with its context).
7. `make ci`.

### Colour

Each layer is an **indexed PNG**. The build sorts every pixel into a channel —
`skin` (warm hues), `primary`/`secondary`/`hair` (the keys), or a fixed neutral
(outline, eyes, metal) — and claims dark shadows for the channel they sit in.
Each channel is quantized to a fixed number of shades (`shades` in the source)
at known palette indices, listed per layer in the catalog. A palette colour is a **ramp** of that many shades, built from one
swatch colour (shadows cooler, highlights warmer). Recolouring is writing the
ramp into those indices of the PNG's `PLTE` chunk — the browser
(`png_palette.js`) and the server (`CharacterPortrait.patch_plte/2`) patch the
same bytes, and no pixel is read back off a canvas.

## 5. In the app

- **Server**: `CharacterCatalog` (compile-time catalog), `CharacterRecipe`
  (`parse/1` strict on the wire, `coerce/1` for anything stored, `put/3` for the
  creator's clicks, `random/1` for a seat nobody dressed), `Accounts.Avatars`
  (the nickname's character).
- **Creator**: `components/ui/space_character_creator.ex` and
  `SpaceCreatorPreviewHook` (`lib/space/creator_preview.js`).
- **Game**: `character_compositor.js` composes a strip per recipe, clip and
  facing (LRU-cached, bounded in bytes) that `sprite_atlas.js` hands the
  renderer like any sprite.
- **Chat portraits**: `/character-portrait/<version>/<recipe>`, composed by
  `RetroHexChatWeb.CharacterPortrait` from the head crops the build cuts.

## 6. Costs (Tier 1, measured)

| Job | Generations |
|---|---|
| a state (`create_character_state`, 104 px) | ~25 |
| a template clip, skeleton-v3, one facing | 3 |
| the seated clip, one facing (3 frames) | 2 |
| **one piece: state + 6 clips × 8 + sit × 8** | **~185** |

PixelLab runs 8 jobs at a time on Tier 1 and, under load, a skeleton-v3 job
takes 8–14 minutes: a piece takes about an hour of wall time. The group zip
download answers `423` while any job of the group is running; `creator_generate.py`
reads frames from the character JSON instead.
