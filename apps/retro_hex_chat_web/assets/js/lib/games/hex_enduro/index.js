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

import { ARROWS_WASD_SPACE, defineGame } from "../core/define_game.js";
import { drawOnDisconnect, playOutcome } from "../core/result.js";
import { playFlags } from "../core/events.js";
import { normalizeEnduroAIDifficulty } from "./difficulty.js";
import {
  activateTurbo,
  changeLane,
  checkCollisions,
  checkGameOver,
  checkOvertakes,
  checkPlayerOvertake,
  clearEvents,
  createInitialState,
  determineWinner,
  packState,
  spawnFuelStations,
  tickTimers,
  unpackState,
  updateAICars,
  updateFuel,
  updateFuelStations,
  updateLaneTransition,
  updateSlipstream,
  updateSpeed,
  updateWeather,
  updateZOffsets,
} from "./physics.js";
import { EVENT, GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS, extend } from "./sounds.js";

const MODE_MAP = {
  hex_enduro: GAME_MODE.CLASSIC_DUEL,
  hex_enduro_night: GAME_MODE.NIGHT_RACE,
  hex_enduro_sprint: GAME_MODE.SPRINT,
};

const COUNTDOWN_FROM = 3;
const COUNTDOWN_EVERY_TICKS = 60; // 1 s

const RELEASED = { left: false, right: false, accel: false, brake: false, turbo: false };

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
  let s = game.gameState;
  const local = game.localInputs;
  const remote = game.remoteInputs;
  const prevAiCars = s.aiCars.map((c) => ({ ...c }));
  const prevP1Z = s.p1.zOffset;
  const prevP2Z = s.p2.zOffset;

  if (local.left) s = changeLane(s, "p1", -1);
  if (local.right) s = changeLane(s, "p1", 1);
  if (remote.left) s = changeLane(s, "p2", -1);
  if (remote.right) s = changeLane(s, "p2", 1);

  // Turbo fires on the press, not while the key is held.
  if (local.turbo && !game.prevTurboLocal) s = activateTurbo(s, "p1");
  game.prevTurboLocal = local.turbo;
  if (remote.turbo && !game.prevTurboRemote) s = activateTurbo(s, "p2");
  game.prevTurboRemote = remote.turbo;

  s = updateLaneTransition(s, "p1");
  s = updateLaneTransition(s, "p2");
  s = updateSpeed(s, "p1", { accel: local.accel, brake: local.brake });
  s = updateSpeed(s, "p2", { accel: remote.accel, brake: remote.brake });
  s = updateZOffsets(s);
  s = updateAICars(s);
  s = updateFuel(s, "p1");
  s = updateFuel(s, "p2");
  s = spawnFuelStations(s);
  s = updateFuelStations(s);
  s = updateSlipstream(s);
  s = checkCollisions(s);
  s = checkOvertakes(s, prevAiCars);
  s = checkPlayerOvertake(s, prevP1Z, prevP2Z);
  s = updateWeather(s);
  s = tickTimers(s);
  s = checkGameOver(s);
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
    left: ["ArrowLeft", "a", "A"],
    right: ["ArrowRight", "d", "D"],
    accel: ["ArrowUp", "w", "W"],
    brake: ["ArrowDown", "s", "S"],
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
  init: (game) => {
    game.gameMode = MODE_MAP[game.gameId] ?? GAME_MODE.CLASSIC_DUEL;
    game.seed = game.isHost ? (game.random() * 0xffffffff) >>> 0 : 0;
    return createInitialState(game.gameMode, game.seed);
  },
  setup: (game) => {
    game.prevTurboLocal = false;
    game.prevTurboRemote = false;
  },
  onStart: (game) => {
    if (game.isHost) game.gameState = createInitialState(game.gameMode, game.seed);
  },
  onStop: (game) => {
    game.localInputs = { ...RELEASED };
    game.remoteInputs = { ...RELEASED };
    game.prevTurboLocal = false;
    game.prevTurboRemote = false;
    game.peerReady = false;
    game.frameCount = 0;
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
      COUNTDOWN: {
        enter: (game) => {
          game.gameState.countdown = COUNTDOWN_FROM;
          // ex_dna:disable-for-lines:9 this game's own defineGame definition
          game.setKeyboardCaptured(true);
          game.broadcast();
          game.invalidate();
        },
        every: { ticks: COUNTDOWN_EVERY_TICKS, count: COUNTDOWN_FROM },
        onEvery: (game, remaining) => {
          game.audio.playCountdown();
          if (remaining === 0) {
            game.gameState.phase = PHASE.RACING;
            game.broadcast();
            game.setKeyboardCaptured(true);
            game.audio.startEngineDrone();
            game.frameCount = 0;
            return;
          }
          game.gameState.countdown = remaining;
          game.broadcast();
          game.invalidate();
        },
        next: "RACING",
      },
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
