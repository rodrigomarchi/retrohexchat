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

A scene about two people films both at once: `filmCrew({ Pixel: page, lumen:
page }, shot, action, { kind, cameras })` puts a camera on each person's own
browser, all on one clock, and writes `cams/<name>/frames/` plus a `take.json`
with `cameras` and `layouts`. `layout("full" | "split" | "pip", ...names)`
tells the edit which screens to show from that moment; `follow` and `focus`
act on the camera whose browser the page belongs to; `talk("words")` waits
for a line one of them says (a cue with `who` and `seconds`) and makes their
character talk for as long as it is on screen; `wave(name)` waves.

`DIRECTOR_REHEARSAL=1` reports late cues and overruns instead of failing, and
prints how long each scene acted: one run measures how much narration every
beat needs.

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
  own, never filmed. Their cameras are characters too: on a call, people are
  people, never a test card.
- `cursor.ts` — a drawn Windows-98 pointer: headless Chrome has no system
  cursor, so without it clicks and pointing are invisible on film.
- `media.ts` — cameras for people on film, devices named like a laptop's.
  `installTestCard`: a broadcast test card captioned with the nickname.
  `installCharacterCamera`: a pixel-art webcam portrait, from `portraits/<nick>/`
  (PixelLab art — see that folder's README) or, for a nick with no folder, a
  character drawn in code. It talks, waves and flashes on the director's word
  (`window.__directorCamera`, passed to every tab of the context by a
  BroadcastChannel), and while it talks its microphone carries a voice-like
  tone, so the call lights the speaker up; sharing the screen shows that
  person's own screen (a music tracker, or honk's honks). The suite's synthetic
  media ("p2p media", "Mock Camera") reads as a test on screen.
- `filmCrew(…, voices)` — people on a call who are not filmed but are seen on
  someone's screen: their lines make their own portrait talk.
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
- **A cast member's command acts on the channel they have open.** `/voice`,
  `/invite` or `/mode` sent while their screen shows #lobby lands on #lobby.
  `castIn(nick, channel)` before each one, and wait for the `sets mode` line
  before the next step: a mode sent while the join is still landing acts on
  the previous channel.
- **A window under the chat cannot take a click.** After typing in the chat,
  the chat window is on top; raise a window from its taskbar button
  (`[data-window-taskbar="…"]`) before using it, and close it by its close
  control — Escape or emptying it leaves it on the taskbar of every later
  scene.
- **A landing page opens its Connect window on top.** Bring the window the
  scene is about to the front from the taskbar, off camera.
- **The Status tab has its own pane** (`statusMessageList`), not the
  conversation's message list — focus and assertions aim there.
- **Set up off camera what an earlier scene does on camera.** A scene that
  shows a topic coming back must set that topic itself: filmed alone, the
  scene that set it never ran.
- **The cold open is filmed last.** Run first, its session is already
  history in the next scene's private chat; ep01 and ep03 put scene 0 at the
  end of the file.
- **A queued file needs the first one still travelling.** On loopback a
  transfer runs at about 45 MB/s; the song in ep03 is near the 500 MB limit
  so it is still going when the second file is picked.
- **The e2e server allows two new sessions every ten seconds.** A director
  that opens one per scene waits between them (`sessionAllowed`).
- **An ended session is a grey page.** Hold on it for a beat, then cut back to
  the chat, where the private conversation keeps what happened.
- **Write a director from the specs the script cites.** Each beat names an
  e2e spec; copy its steps and its assertions, then add the camera.
