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
| The engine class from a definition | `core/define_game.js` — `defineGame(def)`; its header lists every field and hook |
| Phases and their timing | `core/flow.js` — states with `tick`, `enter`, `after: { ticks }`, `every`, `next`, `final` |
| A match played in rounds | `core/rounds.js` — `roundsFlow({ … })`: countdown, bell, round, round-over pause, match end |
| The wire | `core/codec.js` — `schema(type, fields)` with `u8`, `i16`, `flags`, `struct`, `list`, … |
| Message types and dispatch | `core/messages.js` |
| Randomness | `core/rng.js` — `createRng(seed)`; a game gets `game.random` (simulation), `game.fxRandom` (effects) and its AI a stream of its own |
| Sounds | `core/synth.js` — a sound is data (`blip`, `sweep`, `notes`, voices); `createGameAudio` turns a table into `playX()` methods |
| What the guest hears | `core/events.js` — `cues` (phase, change, rise, flags, when) and `playFlags` for the host |
| The result the server is told | `core/result.js` — `matchResult(p1, p2, winner)` |
| Drawing chrome | `core/render.js` — background, scanlines, vignette, grid, digits, centred and glitched text, the closing banner, countdown, waiting, particles |
| A ball off a paddle | `core/paddle.js` — `paddleBounce`: the angle from where it hit, the speed up to a ceiling |
| AI pieces | `core/ai.js` — `normalizeDifficulty`, `interceptAt`/`reflect`, `toward`, `dutyFrame`, `createReaction`, `aiRng`, `rotationDelta` |

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
