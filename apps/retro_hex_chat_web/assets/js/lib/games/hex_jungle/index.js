/**
 * Hex Jungle: one explorer, 255 screens of jungle and tunnel, 32 treasures
 * and twenty minutes. A one-player game: no opponent, nothing on the wire.
 *
 * The match lifecycle comes from `defineGame`; this file says only what is
 * the jungle's — its keys, its phases and what each one does.
 *
 * @module games/hex_jungle
 */

import { ARROWS_WASD_SPACE, defineGame } from "../core/define_game.js";
import { playFlags } from "../core/events.js";
import { soloResult } from "../core/result.js";
import {
  createInitialState,
  loseLife,
  respawn,
  stepRespawn,
  stepTick,
  tickClock,
} from "./physics.js";
import { DEATH_TICKS, EVENT, PHASE } from "./protocol.js";
import { readColors, render } from "./renderer.js";
import { MASTER_VOLUME, SOUNDS, extend } from "./sounds.js";

/** The sound of each event bit. */
const EVENT_SOUNDS = [
  [EVENT.JUMP, "jump"],
  [EVENT.VINE, "vine"],
  [EVENT.TREASURE, "treasure"],
  [EVENT.HOLE, "hole"],
  [EVENT.DEATH, "death"],
  [EVENT.WALL, "wall"],
];

function advance(game, step) {
  game.frameCount++;
  game.gameState = step(game.gameState);
  game.invalidate();
}

/** One tick of play, and what it sounds like; a log over the player buzzes. */
function play(game) {
  advance(game, (s) => tickClock(stepTick(s, game.localInputs)));
  playFlags(game, EVENT_SOUNDS, game.gameState.events);
  if (game.gameState.player.kneeling && game.gameState.phase === PHASE.PLAYING) {
    game.audio.startLogBuzz();
  } else {
    game.audio.stopLogBuzz();
  }
}

export default defineGame({
  players: 1,
  inputs: {
    left: ["ArrowLeft", "a", "A"],
    right: ["ArrowRight", "d", "D"],
    up: ["ArrowUp", "w", "W"],
    down: ["ArrowDown", "s", "S"],
    jump: [" ", "Spacebar"],
  },
  captureKeys: ARROWS_WASD_SPACE,
  audio: { sounds: SOUNDS, masterVolume: MASTER_VOLUME, extend },
  theme: readColors,
  init: () => createInitialState(),
  setup: (game) => {
    game.frameCount = 0;
  },
  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "PLAYING",
    states: {
      PLAYING: { tick: play },
      // The death's tune plays out with the clock stopped; then the next life,
      // or the end.
      DYING: {
        enter: (game) => advance(game, loseLife),
        after: { ticks: DEATH_TICKS },
        next: (game) => (game.gameState.lives > 0 ? "RESPAWN" : "FINISHED"),
      },
      RESPAWN: {
        enter: (game) => advance(game, respawn),
        tick: (game) => advance(game, stepRespawn),
      },
      FINISHED: {
        final: true,
        enter: (game) => {
          game.audio.stopLogBuzz();
          game.audio.playFinale();
          game.invalidate();
          game.finish({ result: soloResult(game.gameState.score) });
        },
      },
    },
  },
  onStop: (game) => game.audio.stopLogBuzz(),
  onAbandon: (game) => game.audio.stopLogBuzz(),
  standing: (game) => soloResult(game.gameState.score),
  render: (game) => render(game.ctx, game.gameState, game.colors, game.frameCount),
});
