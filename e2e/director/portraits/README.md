# Director portraits

What a person's camera shows on film: a pixel-art webcam portrait, drawn by
PixelLab and animated by `media.ts` (`installCharacterCamera`). A nick with a
folder here is drawn from it; anyone else gets the look drawn in code.

## Shape of a folder

| File            | Size                 | What it is                                                      |
| --------------- | -------------------- | --------------------------------------------------------------- |
| `room.png`      | 160x120, opaque      | the room behind the person, edge to edge                        |
| `talk-0.png`    | 96x96, transparent   | the still bust; `talk-1…8` the mouth moving                     |
| `blink-0…4.png` | 96x96, transparent   | one blink, open → closed → open                                 |
| `wave-0…8.png`  | 160x120, transparent | raising a hand and waving; room-sized, the hand needs the width |

The bust sits at (32, 24) on the room, so its bottom edge meets the frame's.
The camera paints everything at 4x with no smoothing: 640x480, each art pixel a
4x4 block. Art is never resized or stretched to fit — a wrong size is
regenerated.

## How they were made (2026-10-10, for EP04)

All PixelLab, Pro models, highest quality:

1. **Room** — `create_image_pro`, 160x120, `no_background=false`, a prompt
   naming the person's room seen straight on with the centre left plain; one of
   four candidates picked. The Pro model draws a grey frame around a scene, so
   the border (8 px) was regenerated with `inpaint_image` and a border mask —
   the inside is pixel-identical to the candidate.
2. **Bust** — `create_image_pro`, 96x96, transparent, "bust portrait facing
   the camera straight on, as seen on a webcam"; lumen's first, then every
   other bust with lumen's as `style_image` (outline, detail, shading) so the
   band reads as one cast. One of four candidates picked.
3. **Frames** — `animate_image` from the bust: talking (8 frames, "only the
   mouth moves"), a blink (4), and a wave (8, from the bust placed on a
   transparent room-sized canvas).

| Nick     | Who                  | Room                                              | Bust                                                 | talk       | blink      | wave       |
| -------- | -------------------- | ------------------------------------------------- | ---------------------------------------------------- | ---------- | ---------- | ---------- |
| lumen    | synth, runs the call | bedroom studio, neon strip, synth                 | teal bob, round glasses, headphones, lavender hoodie | `7dbdfaad` | `a1aea07b` | `0f0b2207` |
| nova     | vocals               | pink bedroom, fairy lights, vanity mirror, mic    | long pink hair, freckles, denim jacket               | `1c2d5d41` | `17ae708e` | `628cb5fc` |
| bytebard | guitar               | garage, guitars on pegboard, amps                 | yellow beanie, stubble, plaid flannel                | `23143ec0` | `29fd8909` | `5665fbff` |
| kestrel  | bass                 | living room, bass on the wall, vinyl, jazz poster | locs tied up, bomber jacket, bass strap              | `92dca6ee` | `6f7d43ac` | `be9ab910` |
| pixel    | drums                | basement, drum kit, neon drumsticks               | spiky red hair, sweatband, glasses, tank top         | `43237d01` | `c52fa159` | `89988f01` |
| m0dem    | manager              | city bus at night                                 | slicked grey-temple hair, moustache, earbud, blazer  | `7febc9ee` | `b39ff9a2` | `0561c339` |
| honk     | the uninvited guest  | party mess, balloons, clown posters               | rainbow clown wig, red nose, star glasses            | `09a53622` | `6749e985` | `b888d45c` |

The ids are the first block of each PixelLab job id; the generations are in
the account's gallery under the same ids.
