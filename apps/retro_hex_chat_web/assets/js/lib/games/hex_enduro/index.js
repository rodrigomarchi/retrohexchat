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

import { defineGame } from "../core/define_game.js";
import { HexEnduroAudio } from "./audio.js";
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

const MODE_MAP = {
  hex_enduro: GAME_MODE.CLASSIC_DUEL,
  hex_enduro_night: GAME_MODE.NIGHT_RACE,
  hex_enduro_sprint: GAME_MODE.SPRINT,
};

const COUNTDOWN_FROM = 3;
const COUNTDOWN_EVERY_MS = 1000;

const RELEASED = { left: false, right: false, accel: false, brake: false, turbo: false };

/** The sounds of a step's events, a bit field, in the order they are heard. */
export function playEvents(audio, events) {
  if (events & EVENT.OVERTAKE_AI) audio.playOvertakeAI();
  if (events & EVENT.OVERTAKE_PLAYER) audio.playOvertakePlayer();
  if (events & EVENT.COLLISION) audio.playCollision();
  if (events & EVENT.FUEL_PICKUP) audio.playFuelPickup();
  if (events & EVENT.TURBO_ACTIVATE) audio.playTurbo();
  if (events & EVENT.WEATHER_CHANGE) audio.playWeatherChange();
}

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
  playEvents(game.audio, s.events);
  game.audio.updateEnginePitch((s.p1.speed + s.p2.speed) / 2);

  // The step that reaches the finish still sends it; FINISHED's entry ends the match.
  game.gameState = s;
  game.frameCount += 1;
  game.broadcast();
  game.invalidate();
}

/** The guest unpacks the host's state, keeping its own road scroll, and hears its events. */
function applySnapshot(game, decoded) {
  if (game.seed === 0 && decoded.seed !== 0) game.seed = decoded.seed;
  game.gameMode = decoded.mode;
  const nested = unpackState(decoded);
  nested.scrollOffset = game.gameState.scrollOffset || 0;
  nested.p1.targetLane = nested.p1.lane;
  nested.p2.targetLane = nested.p2.lane;
  playEvents(game.audio, decoded.events);
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
  captureKeys: [
    "ArrowUp",
    "ArrowDown",
    "ArrowLeft",
    "ArrowRight",
    " ",
    "Spacebar",
    "Shift",
    "w",
    "W",
    "a",
    "A",
    "s",
    "S",
    "d",
    "D",
  ],
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: {
    difficulty: normalizeEnduroAIDifficulty,
    observe: (game) => ({ state: game.gameState, player: 2, difficulty: game.difficulty }),
  },
  audio: HexEnduroAudio,
  theme: getColors,
  // The game id picks the race; only the host seeds the road.
  init: (game) => {
    game.gameMode = MODE_MAP[game.gameId] ?? GAME_MODE.CLASSIC_DUEL;
    game.seed = game.isHost ? (Math.random() * 0xffffffff) >>> 0 : 0;
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
          game.setKeyboardCaptured(true);
          game.broadcast();
          game.invalidate();
        },
        every: { ms: COUNTDOWN_EVERY_MS, count: COUNTDOWN_FROM },
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
      RACING: { steps: true, tick: race },
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
  onEnd: (game, result) => {
    game.gameState = { ...game.gameState, phase: PHASE.FINISHED };
    game.invalidate();
    game.setKeyboardCaptured(false);
    game.audio.stopEngineDrone();
    if (result.winner === (game.isHost ? 1 : 2)) game.audio.playVictory();
    else game.audio.playGameOver();
    game._reportResult({ score: { p1: result.score1, p2: result.score2 }, winner: result.winner });
  },
  render: (game) => {
    if (!game.ctx || !game.colors) return;
    render(game.ctx, game.gameState, game.colors, performance.now(), game.isHost);
  },
  disconnectResult: (game) => ({
    score: { p1: game.gameState.p1.score, p2: game.gameState.p2.score },
    winner: 0,
  }),
});
