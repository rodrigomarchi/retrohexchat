# Video director

Films scenes for the RetroHexChat YouTube channel. **Not a test category**:
nothing here guards a behaviour. It lives outside `tests/`, so the catalog, the
batches and the sweep never see it, and its Playwright project exists only when
`E2E_DIRECTOR=1` — a plain `playwright test` cannot pick it up.

```bash
make e2e.director SHOTS=/abs/shots.json OUT=/abs/takes [FRESH=1]
```

It is driven by the video project (`../retro_hex_chat_videos`, `make capture`),
which writes the shot list from the measured narration: each scene lasts as
long as the voice over it, each action waits for its sentence (`cue`), and a
take that falls behind its narration fails. Defects found while filming go in
a `TODO.md` at the repository root, not here: create it when the first one is
found, and delete it once every item is fixed.

`focus(locator | null)` records in the take what the scene is about from that
moment — nothing changes on screen; the edit (`retro_hex_chat_videos/compose`)
zooms towards it. Following a new tab resets it to the whole frame.

## Files

- `epNN-*.director.ts` — one file per episode, one `test` per scene.
- `shots.ts` — the shot list, `film()` (pace, cue, follow, focus) and the on-camera
  helpers (`typeOnCamera`, `pointAt`, `restCursor`).
- `camera.ts` — 1280x720 CSS at 1.5x → 1920x1080 frames. The scale comes from
  launch flags; the screencast ignores an emulated `deviceScaleFactor`.
- `recorder.ts` — CDP screencast to JPEG frames + `take.json` (when each frame
  was painted); `follow()` moves the camera to another tab on one timeline.
  Playwright's own video is VP8 at 1 Mbit/s.
- `cast.ts` — the people already in the room, each in a browser context of its
  own, never filmed.
- `cursor.ts` — a drawn Windows-98 pointer: headless Chrome has no system
  cursor, so without it clicks and pointing are invisible on film.
- `media.ts` — a camera for people on film: a broadcast test card captioned
  with the nickname, devices named like a laptop's. The suite's synthetic
  media ("p2p media", "Mock Camera") reads as a test on screen.
- `calls.ts`, `space.ts`, `arcade.ts` — sessions and conferences, Spaces, and
  the Arcade with DOOM, the way a scene needs them.

Scene 1 registers its nickname on camera, so a retake of it needs a fresh
database (`FRESH=1`) or another `DIRECTOR_NICK`.

## Pitfalls the director already hit

- **The screencast ignores emulated scale.** A context with
  `deviceScaleFactor: 1.5` still paints 1280x720 frames. The scale comes from
  `CAMERA_LAUNCH_ARGS` with `viewport: null`, and the director project must not
  spread `devices[...]`: a device preset injects `deviceScaleFactor` into every
  context, which Playwright refuses alongside a null viewport. `Recorder.stop`
  fails a take whose frames are not the size asked for.
- **`playwright.config.ts` must not import a module that imports `test`.** The
  camera constants live in `camera.ts`, which imports nothing from Playwright.
- **A pointer left where it clicked keeps that spot's hover state on screen** —
  a message's reaction bar, a highlighted button. `restCursor()` after clicks
  that end a beat; `pointAt()` to direct the eye on purpose.
- **Hover cards leak the filming machine.** Pointing at a user in the list
  opened their profile card, showing the OS, browser and the machine's time
  zone. Every context the director creates sets its own `locale` and
  `timezoneId` (the cast gets zones from around the world), and `pointAt()`
  aims at a panel's header, never at a row inside it.
- **Headless has no cursor.** The screencast showed clicks with nothing to
  follow; `cameraContext` installs `drawCursor`.
- **Close what a scene opens.** The formatting toolbar left open sat over the
  command autocomplete in the next beat.
- **Act on cues, not on guessed waits.** `cue("words")` waits for the sentence
  of narration that contains them and fails the take if the action before it
  ran late; hand-tuned `pace()` alone left scene 2 frozen for its last 9 s.
- **An empty channel reads as a dead product.** Assemble the cast first. On a
  fresh database the first member to join founds the channel and owns it —
  the order of `CAST` is casting. Every line is checked on its speaker's screen,
  so one refused by flood control fails the take instead of leaving a hole.
- **Offer a call in the private chat.** `/p2p` from a channel follows the
  newest card on screen — in a channel with a conference running, that is the
  conference's.
- **The Arcade cannot see the game's tab.** Closing it leaves the session
  "in progress", and the next visit opens on that state with no Play button.
  End it (`solo-session-end`, which also closes the window); `resetArcade()`
  makes sure before a scene. Warm DOOM's cache with `warmDoom()` — straight to
  the static host, no session.
- **DOOM ignores keys for a few seconds after loading.** Press Play early in
  the scene, `readyDoom()` waits for the engine, then play. It also scales the
  game's small canvas to the window's height.
- **Remote video in a conference lands ~3 s after Join.** Leave that time
  before the scene ends.
- **A green take is not a good take.** Pull stills from the encoded video and
  look at them before calling a scene done.
