# The browser games

Read when adding a game, changing one, or touching the shared game core.

Part of the [Agent Guide](../AGENT-GUIDE.md) (§15, §20). Section numbers there are stable.

---

A game is a **definition**: it says what is its own — its inputs, its wire, its state, its
phases, its picture, its sounds, its AI — and `js/lib/games/core/` supplies everything else:
the match lifecycle, the ready handshake, the clock, the countdown, the end, the disconnect,
the guest's interpolation, the sounds' synthesis and the seeded randomness. Every game in
`js/lib/games/<dir>/` is built this way, and ESLint refuses the shortcuts that would start
another copy of the core (§G.5).

## G.1 The core

| Need | Module |
|---|---|
| The engine class from a definition | `core/define_game.js` — `defineGame(def)`; its header lists every field and hook. `ARROWS_WASD_SPACE` is the usual `captureKeys`; nothing is rendered before `theme` has given the colours |
| Phases and their timing | `core/flow.js` — states with `tick`, `enter`, `after: { ticks }`, `every`, `next`, `final` |
| A match played in rounds | `core/rounds.js` — `roundsFlow({ … })`: countdown, bell, round, round-over pause, match end; `countdownState({ from, every, next, capture })` for the spoken countdown alone; `tallyRound` counts a round's win |
| The wire | `core/codec.js` — `schema(type, fields)` with `u8`, `i16`, `flags`, `struct`, `list`, … |
| Message types and dispatch | `core/messages.js`; a `protocol.js` re-exports `core/protocol_base.js` (`MSG_TYPE`, `encodeGameReady`, `getMessageType`) |
| Randomness | `core/rng.js` — `createRng(seed)`; a game gets `game.random` (simulation), `game.fxRandom` (effects) and its AI a stream of its own |
| Sounds | `core/synth.js` — a sound is data (`blip`, `sweep`, `notes`, voices); `createGameAudio` turns a table into `playX()` methods |
| What the guest hears | `core/events.js` — `cues` (phase, change, rise, flags, when) and `playFlags` for the host |
| The result the server is told, and the end | `core/result.js` — `matchResult(p1, p2, winner)`; `drawOnDisconnect((s) => [p1, p2])` for `disconnectResult`; `guestEnd({ phase, fields, sound })` for `onEnd`; `playOutcome(game, winner, win, lose)` for the ending sound |
| Drawing chrome | `core/render.js` — background, scanlines, vignette, grid, digits, centred and glitched text, the closing banner, countdown, waiting, particles |
| A ball off a paddle | `core/paddle.js` — `paddleBounce`: the angle from where it hit, the speed up to a ceiling; `moveBall` |
| The neon bat-and-ball look | `core/neon.js` — `neonColors`, `drawNeonPaddle`, `drawNeonBall` (Pong and Block Breakers); a module of its own, so the other games do not load it |
| A person on platforms | `core/platform.js` — `jumpStep` (a jump read from a table of lines a tick), `fall`, `ladderGrab`, `climbStep`, `overlaps`, `edgeExit`, `cadence`; a module of its own, so the other games do not load it |
| A mouse or a finger | `pointer: true` + `onPointer(game, { type, x, y })` in the definition: the canvas's presses, moves, releases and cancels, in canvas pixels, handed over at the next tick in order. `core/pointer.js` — `toCanvasPoint` (undoes the `object-contain` scale and bands) and `createGesture({ slop })` (tap, drag, drop); a module of its own |
| Playing cards | `core/cards.js` — `DECK` (ids 0–51, suit by suit, ace to king), `suitOf`, `rankOf`, `isRed`, `shuffle(cards, random)` with the match's generator; `createCardAtlasLoader({ fetchJson, loadImage })` reads an art atlas once and refuses an incomplete one; `drawCard(ctx, atlas, card, x, y, { faceUp, back, size })` cuts a face or a back from it, full or `"mini"`; `faceOf` and `spiderDeck(suits)` for two-deck games; `CARD_ATLAS_URL` carries the atlas's version (`assets/art/cards/build_deck.py` rewrites it); a module of its own |
| A card table | `core/card_table/` — the match every one-player card game shares: `table.js` `defineCardTable({ init, act, step, finalScore, interpret, hitTest, effects, render, … })` (phases with the cascade before the result, clock, back kept by the browser, table standing up on a phone, frames only while something moves); `gestures.js` `createInterpreter(rules)` (tap, drag, drop on the pile covered most); `effects.js` (deal, flight, flip, shake, sparks, cascade, in ticks); `render.js` (felt, slots, HUD, cards resting and moving); `piles.js` (places, the squeezed fan); `clock.js` (the clock, ten seconds' penalty, the hour, the win's time bonus); `sounds.js`. A table laid with `size: "mini"` deals the 44×62 minis. A game keeps its rules, scoring, layout and state |
| Motion over ticks | `core/tween.js` — `progress(start, ticks, now)`, `easeOutCubic`, `easeOutBack`, `bounce`, `lerp`, `tweenPoint` (whole pixels); a module of its own |
| A board that hardly changes | `core/layers.js` — `createLayer(width, height, resolution)`: a canvas off the screen drawn once and copied each frame; one never cleared keeps a trail |
| Crisp pixel art, more pixels | `pixelArt: true` (unsmoothed, `game-canvas--pixel-art`) and `resolution: 2` (the canvas has twice the pixels, the game still draws and reads presses in `game.view`) in the definition |
| Pixel-art sprites | `core/render.js` — `drawPixelSprite(ctx, rows, palette, x, y, sx, sy, { flip })`: a sprite as rows of characters, coloured by a palette |
| AI pieces | `core/ai.js` — `aiRequest`, `normalizeDifficulty`, `interceptAt`/`reflect`, `toward`, `dutyFrame`, `createReaction`, `aiRng`, `rotationDelta`, `finiteMotion`, `edgeAware` |

The engine underneath is `js/lib/game_engine.js`; a game never imports it.

## G.2 A game's folder

| File | Holds |
|---|---|
| `index.js` | `export default defineGame({ … })` — the only file the loader imports |
| `protocol.js` | `PHASE`, the snapshot and end schemas (`core/codec.js`), the game's constants on the wire |
| `physics.js` | The simulation as pure functions of the state. Anything random takes a trailing `random = Math.random` parameter, and the definition passes `game.random` |
| `renderer.js` | `render(ctx, state, colors, time)` from `core/render.js` pieces |
| `sounds.js` | `SOUNDS`, a table of sound data; `extend` for held tones (an engine's drone) |
| `ai.js` | The solo opponent: `create<Game>AI({ difficulty, rng })` with `nextInputs(request)`; draws only from `rng` |

## G.3 Registering a game

1. **Server:** add it to `RetroHexChat.Games.Catalog` (`@games`, and `@solo_game_ids` when it
   plays solo). A mode of a game is its own id with `mode_of`.
2. **Browser:** add every id to `js/lib/games/registry.json` (`{ "dir": …, "solo": … }`) and the
   folder's literal import to `DEFINITION_LOADERS` in `engine_loader.js` — esbuild splits a
   chunk only for an import path it can read. An AI kept out of the game's chunk (downloaded
   only for solo) goes in `SOLO_AI_LOADERS` there; any other AI is the definition's `ai.create`.

`test/lib/games/registry.test.js` and `apps/retro_hex_chat_web/test/retro_hex_chat_web/games/registry_test.exs`
fail until the two sides, the folder and its pins agree.

**A game for one player** (`players: 1` in its definition) is `"soloOnly": true` in
`registry.json` and in `@solo_only_game_ids` of `Games.Catalog` (always also solo and ranked by
score). It has no `ai.js`, no snapshot or end schema and no guest: the lifecycle tests that need a
channel between two players skip it (`TWO_PLAYER_ENGINE_GAME_IDS` in `test/support/games/engines.js`),
and its pins are `pinGame(id, { soloOnly: true, script, endScript })` — the solo match on its key
script, one played to the end, and the same match twice. Its result is `soloResult(points)`, and
the server records it with origin `"solo"`.

The rest of what a new game needs, and what stops you when it is missing:

| Step | Where | Caught by |
|---|---|---|
| Ranking: versus, score or co-op | `@versus_game_ids` / `@score_game_ids` / `@coop_game_ids` in `Games.Catalog` | compilation stops |
| Goal and keys in the library panel | `goal_label/1` and `control_rows/1` in `RetroGamesPanel` | `retro_games_panel_test.exs` |
| Box art | an `icon_game_*` in `components/icons/games.ex`, its line in `icons/registry.ex`, and the catalog entry's `icon:` naming it | `icons_test.exs`, `icons_registry_test.exs` |
| Help topic | `HelpTopics` features list + topic, `controllers/help_content/feature_<id>.html.heex` | `games_catalog_test.exs`, `help_content_coverage_test.exs` |
| Translations | `make i18n.gettext.merge`, then every locale | `make i18n.gettext.check`, `i18n.catalog.check` |
| Screenshot and share card | `make games.shots ONLY=<slug>` | `games_catalog_test.exs` |
| Pins and the key script | `test/lib/games/pins/<dir>.pin.test.js`, `test/support/games/scripts/` | `registry.test.js` |
| Endings heard and spelled | `end_sounds.test.js`, `result_spelling.test.js` tables | their "every game folder" test |
| Game channel and its bots | production, by hand: `docs/provisioning/en.md` | nothing — a runbook step |

The lifecycle tests (determinism, disconnect, match, keymap) read the engines from the registry
and pick a new folder up by themselves.

## G.4 Rules a game keeps

- **Time is ticks.** The simulation steps at a fixed 60 Hz; a pause is `after: { ticks: n }`, a
  repeat is `every`. No `setTimeout`, no `setInterval`, no milliseconds.
- **One seed plays one match.** The host's simulation draws only from `game.random`, so a seed
  replays the same match; decoration draws from `game.fxRandom`, the AI from its own `rng`.
  A renderer may use `Math.random()` for sparkle no replay depends on.
- **The host simulates, the guest shows.** The guest takes snapshots (`applySnapshot` when a
  field needs more than copying) and hears its sounds from `cues`, never from a simulation of
  its own.
- **Sounds are data.** A new sound is an entry in `SOUNDS`; nothing builds oscillators by hand.
- **End mid-match ends it as it stands.** `quit()` (the page's End button) reports the score
  the game holds now — `standing`, or for a two-player game the score `disconnectResult` reads
  — with `ended_early: true`. The server decides the rest: a versus match keeps who led but is
  written unranked (no win, no announcement — a lead of one and End is no victory), a score or
  co-op game keeps its points, ranked, best included. So `disconnectResult` must read the score at
  any moment of play; `test/lib/games/quit.test.js` holds every game to it.
- **A definition uses the public surface** listed in `define_game.js`: `gameState`,
  `localInputs`, `remoteInputs`, `audio`, `broadcast()`, `invalidate()`, `updateOpponent()`,
  `finish()`, `flow.go()`, `keyInput(event)`, `sendInputEdge(code)` — no `_`-prefixed member.

## G.5 What ESLint refuses in a game's folder

`eslint.config.mjs` blocks, under `js/lib/games/*/**` (the core excepted): `new DataView`
(use a schema), `createOscillator` (use the sound table), `setTimeout`/`setInterval` (count
ticks), `Math.random()` outside `renderer.js` (draw from `game.random`), `extends GameEngine`
and importing `game_engine.js` (write a definition). `test/lint/games_rules.test.js` proves
each rule fires.

## G.6 Tests

- **Pins** (`test/lib/games/pins/<dir>.pin.test.js`, with its key script in
  `test/support/games/scripts/<dir>.js`) record a game from outside: solo, P2P, lossy,
  disconnect and every mode played to the end. They run by hand — `make test.js.pins` — before
  and after any change meant to keep behaviour; a changed digest is a changed game. A
  deliberate change re-records them in its own commit.
- **Pure tests** for `physics.js`, the schemas (with fixtures), `ai.js` and the sounds
  (`sounds.test.js` against a fixture of voices).
- **Moments the pins rarely reach** — a round on points, the player winning, a goal for the
  guest — are scenarios in `test/lib/games/endings.test.js`: a match through the harness
  (`test/support/games/harness.js`), the host's state brought to the moment, both sides watched.
- **No test reaches into an engine.** Drive it through the harness, its keyboard, its channel
  (`test/support/games/fake_channel.js`) or its public state. When a line can only be reached
  through a private method, it is either a scenario still to write or dead code.
