# The Virtual Space's interface — a pixel-art UI kit

A space is a pixel-art world, so everything a person handles inside it is drawn
the way the world is: dark wood, grey stone, gold corners, parchment faces, a
pixel font. This covers the space page's window and status bar, the say bar, the
character creator, the loading card, the gate's question, a Construct piece's
panel, the build palette, the pad and the fullscreen key — and, on the canvas,
the nameplates, speech bubbles, the focus prompt and the HP bar. The rest of the
platform stays Win98.

| Piece | Where |
|---|---|
| The kit's definition: every piece, its slice, its states | `ui/kit.json` |
| Raw PixelLab art, one file per generation, and where each came from | `ui/pixellab/`, `ui/manifest.json` |
| The style reference every later generation was given | `ui/reference/master.png` |
| The tool that slices, derives states and writes the outputs | `tools/author_ui.py` (`make space.ui`) |
| Frames (one webp per piece × state), icons, the canvas sheet | `priv/static/images/space/ui/` |
| CSS tokens per piece, one rule per icon (generated) | `assets/css/retrohex/features/space-ui-kit.generated.css` |
| The kit's look, by hand: which control wears which piece | `assets/css/retrohex/features/space-ui.css` |
| Canvas geometry (generated) | `assets/js/lib/space/ui_kit_geometry.js` |
| The font, subset per script (generated) | `virtual.space/tools/subset_pixel_font.py` → `priv/static/fonts/pixel/`, `space-ui-font.generated.css` |

## How the art was made

1. **One master panel first.** `create_ui_asset` at 384×384, and the candidate
   judged on a board beside an avatar frame and the End of Time floor, at 1:1.
   The chosen one (oak frame, stone inner rim, gold corner caps, parchment) is
   `reference/master.png`; its top-left 192×192 is the `style_image_base64` of
   every later generation.
2. **Controls as one sheet, at exact sizes.** `create_ui_asset` at 512×512 with a
   `pieces` template: on a 512 canvas the virtual 0–512 grid is the pixel grid,
   so a 96×28 piece comes back 97×29, near enough to cut. Pieces from one
   generation share their density and palette, which matters more than any one of
   them. Two sheets: parchment faces (`controls_a`) and dark wood faces
   (`controls_wood`), each with its own seed.
3. **States are derived, never generated.** Hover, pressed, disabled, selected,
   active, focus, inactive and danger are palette recipes over the normal art
   (`STATES` in `author_ui.py`), so every state keeps the slice of the normal one
   to the pixel. Two separate generations never line up.
4. **Pieces too small to generate are drawn in `kit.json`**, row by row in the
   kit's palette: the bubble's tail, the HP bar's fills, the four title-bar
   glyphs.
5. **Icons** come from `create_image_pro` at their native size (16 or 24 px gives
   64 candidates per call), the master as style (palette, outline, shading). The
   chosen candidate is kept; the others are not. A quarter turn (`rotate`) or a
   quadrant flip (`quadrants: flip`) makes an icon from another without
   resampling: the pad's four arrows are one, the two fullscreen glyphs are one.

**What went wrong the first time** — and what to ask for instead:

- A "wide" plank panel came back with inner bars and a second frame inside; its
  middle cannot repeat. A piece whose face is not uniform is not a frame.
- A rotate icon came back with no outline and a vague arrowhead: say "solid 1px
  dark brown outline all around" and "a big clear arrowhead".
- A trash bin came back as a wooden bucket: name the material ("grey iron trash
  can with a lid").
- A "fullscreen exit" came back identical to "enter": generate one, derive the
  other.
- An icon asked for "two people" came back as mud at 16 px: pick a subject with a
  silhouette (the space's icon is a stone tower).

## The rules the tool enforces

`author_ui.py` fails instead of fixing, because the fix belongs in the art or in
the kit:

- the `rect` is the piece's exact opaque bounding box in its sheet;
- the art is native (no run of equal pixels shared by a factor of 2+);
- the edges between the corners repeat cleanly — a corner ornament reaching past
  the slice is reported, and the fix is a wider slice in `kit.json`;
- every state has the normal piece's geometry.

`--check` (in `make lint.css`) rebuilds in memory and fails on any committed
output that differs; two runs give the same bytes.

## Rendering

- **1:1, never scaled.** One art pixel per CSS pixel, as the avatars render.
  Edges `repeat`; a tile that does not fit is cut short, not stretched — in CSS
  (`border-image-repeat: repeat`) and on the canvas (`nine_slice.js`).
- **CSS:** `border-image` with `border-image-width` from the kit and a zero
  border, so the frame can be thicker than the layout's border; padding keeps the
  content off the frame. A narrow screen (≤ 480 px) gives a panel the slim frame.
- **Canvas:** the renderer draws from `canvas.webp` through `atlas.uiPiece(name)`,
  reads the kit's colours and font from the CSS once (`ui_theme.js`), and asks the
  font for the glyphs of each new line (`ui_font.js`) — `fillText` never fetches a
  face on its own, and a script nobody has typed yet would otherwise stay in the
  fallback.

**Contrast**, measured on the kit's own colours: ink on parchment and muted ink
on parchment both read at WCAG AA for body text, the danger red on parchment
too, and gold on dark wood well above it. A new text colour is measured the same
way before it ships.

**Fractional device-pixel ratios** (125 %, 150 % zoom) resample 1:1 pixel art and
the 12px font slightly; integer scaling cannot be forced from CSS. It is
accepted, and it is the same for the world's own sprites.

**What stays the platform's.** A dialog or toast raised over the space — sharing
the address, "Copied!" — is the platform's own window and keeps its Win98 chrome
and type (`space-ui.css` resets them under `[role=dialog]` and `.toast-container`).
On the map the window has no status bar: `← Chat`, "Change character" and the
count sit on the say bar as parchment chips (`space-ui-chip`), one line under
the map. Before walking in (the picker, a refusal) there is no say bar, and the
window's own status line carries the way back. On a phone the send key, "Change
character" and the count show a glyph, your face and the tower with a number,
their words kept for a screen reader, and the chips step aside while the field
is typed in.

**The pad is held like a handheld:** the use and sword keys under the left thumb,
staggered like A and B; the D-pad under the right. The strip between them lets
presses through to the map.

**The Construct's build controls** stay off the room until wanted. A Build key
opens a drawer, a side panel on a desktop and a sheet from the bottom on a phone.
A card next to the Build key shows what is in hand, with turn, remove and drop:
a touch screen has no Esc and no right-click, so letting go needs a button. A
refusal is said over the room, outside the drawer, so it is seen even with the
drawer shut.

**A large face is plain parchment.** The slim frame (`button_parch`) is a
button's: repeated across a panel, its own face shows stripes. So a drawer, and
a panel on a phone, take the frame without `fill`, with a flat parchment
background inset under it.

## The font

RH Pixel is Fusion Pixel 12px proportional (TakWolf, SIL OFL 1.1, no Reserved
Font Name), subset and renamed by `virtual.space/tools/subset_pixel_font.py` from the
pinned release (checked by SHA-256). It is drawn at 12px — its design size — or
24px. Japanese and Traditional Chinese readers get their region's Han forms
(`:lang()` in `space-ui.css`); a region's core face carries exactly the Han its
catalogs use, and the rest of the block is in slices fetched only when a line
needs one. Its `@font-face` rules live in the global stylesheet: they compress
to almost nothing, and no face is fetched until a glyph on the page needs it, so
a page outside the space pays nothing for them. Rebuild it after a catalog
change adds characters:

    python3 -m venv /tmp/rh_font_venv
    /tmp/rh_font_venv/bin/pip install -r virtual.space/tools/requirements-font.txt
    /tmp/rh_font_venv/bin/python virtual.space/tools/subset_pixel_font.py

## The arcade kit (the Retro Games' stage)

The Retro Games are played on a stage of their own (`Games.GameStage`), drawn in a second kit
built the same way: `virtual.space/ui-arcade/` (`kit.json`, `manifest.json`, `pixellab/`,
`reference/master.png`), `python3 virtual.space/tools/author_ui.py --kit arcade`
(`make arcade.ui`, checked by `make arcade.ui.check` in `make lint.css`). Its outputs are
`priv/static/images/arcade/ui/`, `arcade-ui-kit.generated.css` (tokens `--arcade-ui-*` on
`.arcade-ui`, icons `.arcade-icon--*`) and, by hand, `arcade-ui.css`. It has no canvas pieces,
so no geometry file. Black chrome lit by a cyan and a magenta line, in the canvas's own neon.

What it taught:

- **A dark kit needs its own state recipes.** Lightening toward white does nothing to navy:
  `glow`, `lit`, `lit_pressed`, `alarm` light the face toward cyan or turn the cyan line red,
  and touch only the face's navy — not the black outline, which otherwise grows a halo.
- **Measure the slice; the seam check is not enough.** A slice thinner than the frame put the
  inner neon line in the fill, and `fill` repeats it as stripes across the panel; a slice cut
  through a rounded corner repeats the corner as "joints" along the edge. Widen the slice to
  where every column of the edge is the same.
- **A large face is flat under the frame.** The master's face is shaded toward its edges; tiled
  across a bigger panel the shading shows tile seams. The panel takes the frame without `fill`
  and a flat navy inset under it, as the space's drawer does with parchment.
- **Icons at 16 px with a silhouette.** A "two players" icon came back as blobs at 16 px; the
  gamepad was drawn in `kit.json` instead, and so was the exit-fullscreen glyph: the quadrant
  flip of art cropped to its brackets meets in the middle as a plus.

The pad is the space's pad: the same component and script, worn in the arcade kit by its root
class, with neon arrows (`pad_cross skin="arcade"`). It lies over the game on a touch screen
only, and steps aside while the menu is open.

## Adding a control

1. Find a piece that fits in `kit.json` — the same frame at another size is the
   same piece. Add a state to its `states` if it needs one.
2. Only if nothing fits, generate it: `create_ui_asset` with the master's crop as
   style, as a labelled piece at its exact size, and add it to `kit.json` with
   its `rect` and a first `slice`. Run `make space.ui` and widen the slice until
   the seam check passes. Log the job in `manifest.json`.
3. Style the control in `space-ui.css` from the piece's tokens
   (`--space-ui-<piece>`, `-slice`, `-width`), and use a primitive's `pixel`
   variant where one exists.
4. Screenshot it at 1280×800 and 390×844 (`make e2e.shots`) and look at it.
