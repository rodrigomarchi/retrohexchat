/**
 * Hex Enduro: two cars on an endless road through traffic, weather and
 * fuel stops, scoring by overtakes.
 *
 * Host-authoritative; the host seeds the road. The state travels packed
 * flat and the guest unpacks it. The AI is loaded by the page, not bundled
 * here. The match lifecycle comes from `defineGame`; this file says only
 * what is Enduro's.
 *
 * @module games/hex_enduro
 */

import {
  ARROWS_WASD_SPACE,
  ARROW_KEYS,
  defineGame,
  freshOnHost,
  seededInit,
} from "../core/define_game.js";
import { beepCountdownState } from "../core/rounds.js";
import { drawOnDisconnect, playOutcome } from "../core/result.js";
import { playFlags } from "../core/events.js";
import { normalizeEnduroAIDifficulty } from "./difficulty.js";
import {
  clearEvents,
  createInitialState,
  determineWinner,
  packState,
  stepTick,
  unpackState,
} from "./physics.js";
import { EVENT, GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS, extend } from "./sounds.js";

const MODE_MAP = {
  hex_enduro: GAME_MODE.CLASSIC_DUEL,
  hex_enduro_night: GAME_MODE.NIGHT_RACE,
  hex_enduro_sprint: GAME_MODE.SPRINT,
};

const TURBO_RELEASED = Object.freeze({ p1: false, p2: false });

/** The sound of each event bit, in the order they are heard; host and guest hear the same. */
export const EVENT_SOUNDS = [
  [EVENT.OVERTAKE_AI, "overtakeAI"],
  [EVENT.OVERTAKE_PLAYER, "overtakePlayer"],
  [EVENT.COLLISION, "collision"],
  [EVENT.FUEL_PICKUP, "fuelPickup"],
  [EVENT.TURBO_ACTIVATE, "turbo"],
  [EVENT.WEATHER_CHANGE, "weatherChange"],
];

function race(game) {
  // The AI sees the step's state with last step's events already cleared.
  game.gameState = clearEvents(game.gameState);
  game.updateOpponent();
  const step = stepTick(game.gameState, game.localInputs, game.remoteInputs, game.turboHeld);
  const s = step.state;
  game.turboHeld = step.turboHeld;
  playFlags(game, EVENT_SOUNDS, s.events);
  game.audio.updateEnginePitch((s.p1.speed + s.p2.speed) / 2);

  // The step that reaches the finish still sends it; FINISHED's entry ends the match.
  game.gameState = s;
  game.frameCount += 1;
  game.broadcast();
  game.invalidate();
}

/** The guest unpacks the host's state, keeping its own road scroll. */
function applySnapshot(game, decoded) {
  if (game.seed === 0 && decoded.seed !== 0) game.seed = decoded.seed;
  game.gameMode = decoded.mode;
  const nested = unpackState(decoded);
  nested.scrollOffset = game.gameState.scrollOffset || 0;
  nested.p1.targetLane = nested.p1.lane;
  nested.p2.targetLane = nested.p2.lane;
  game.gameState = nested;
  game.invalidate();
}

export default defineGame({
  inputs: {
    left: ARROW_KEYS.left,
    right: ARROW_KEYS.right,
    accel: ARROW_KEYS.up,
    brake: ARROW_KEYS.down,
    turbo: [" ", "Shift"],
  },
  captureKeys: [...ARROWS_WASD_SPACE, "Shift"],
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: {
    difficulty: normalizeEnduroAIDifficulty,
    observe: (game) => ({ state: game.gameState, player: 2, difficulty: game.difficulty }),
  },
  audio: { sounds: SOUNDS, extend },
  theme: getColors,
  // The game id picks the race; only the host seeds the road.
  init: seededInit(MODE_MAP, GAME_MODE.CLASSIC_DUEL, createInitialState),
  setup: (game) => {
    game.turboHeld = TURBO_RELEASED;
  },
  onStart: freshOnHost(createInitialState),
  onStop: (game) => {
    game.forgetMatch();
    game.turboHeld = TURBO_RELEASED;
    game.audio.stopEngineDrone();
  },
  onAbandon: (game) => {
    game.audio.stopEngineDrone();
    game.audio.playGameOver();
  },

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      // The beep sounds on each second that passes; the last one starts the engines.
      COUNTDOWN: beepCountdownState({
        next: "RACING",
        capture: true,
        start: (game) => {
          game.gameState.phase = PHASE.RACING;
          game.broadcast();
          game.setKeyboardCaptured(true);
          game.audio.startEngineDrone();
          game.frameCount = 0;
        },
      }),
      RACING: { tick: race },
      FINISHED: {
        final: true,
        enter: (game) => {
          const s = game.gameState;
          game.audio.stopEngineDrone();
          const winner = determineWinner(s);
          if (winner === 1) game.audio.playVictory();
          else game.audio.playGameOver();
          const end = { score1: s.p1.score, score2: s.p2.score, winner };
          game.finish({
            end,
            result: { score: { p1: end.score1, p2: end.score2 }, winner },
            broadcast: false,
          });
        },
      },
    },
  },

  toWire: (game) => packState(game.gameState),
  applySnapshot,
  cues: [{ flags: (s) => s.events, sounds: EVENT_SOUNDS }],
  onEnd: (game, result) => {
    game.gameState = { ...game.gameState, phase: PHASE.FINISHED };
    game.invalidate();
    game.setKeyboardCaptured(false);
    game.audio.stopEngineDrone();
    playOutcome(game, result.winner, "playVictory", "playGameOver");
  },
  render: (game) => {
    if (!game.ctx) return;
    render(game.ctx, game.gameState, game.colors, performance.now(), game.isHost);
  },
  disconnectResult: drawOnDisconnect((s) => [s.p1.score, s.p2.score]),
});
