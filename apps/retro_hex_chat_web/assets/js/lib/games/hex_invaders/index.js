/**
 * Hex Invaders: two cannons under alien waves, rivals or side by side,
 * through a fixed number of waves.
 *
 * Host-authoritative; the host seeds the waves and the guest builds the
 * same ones from the seed in its first snapshot. Once play starts the
 * simulation never pauses: the wave-clear and wave-start overlays keep
 * stepping and sending. The match lifecycle comes from `defineGame`; this
 * file says only what is Invaders'.
 *
 * @module games/hex_invaders
 */

import { defineGame } from "../core/define_game.js";
import { createHexInvadersAI, normalizeInvadersAIDifficulty } from "./ai.js";
import { HexInvadersAudio } from "./audio.js";
import {
  checkAlienReachedGround,
  checkBombCannonHits,
  checkBombShieldHits,
  checkGameOver,
  checkMissileAlienHits,
  checkMissileUFOHit,
  checkWaveClear,
  clearEvents,
  createInitialState,
  createWave,
  fireMissile,
  moveAliens,
  moveCannon,
  processDropQueue,
  spawnBombs,
  tickTimers,
  updateBombs,
  updateCombos,
  updateMissiles,
  updateUFO,
} from "./physics.js";
import { GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";

const MODE_MAP = {
  hex_invaders: GAME_MODE.INVASION_WAR,
  hex_invaders_coop: GAME_MODE.COOP,
  hex_invaders_blitz: GAME_MODE.BLITZ,
};

const WAVE_CLEAR_MS = 2000;
const WAVE_START_MS = 1000;
const COUNTDOWN_FROM = 3;
const COUNTDOWN_EVERY_MS = 1000;

/** The sounds of a step's events, in the order they are heard. */
export function playEvents(audio, events) {
  if (events.alienKill) audio.playAlienDestroyed();
  if (events.armoredHit) audio.playArmoredClang();
  if (events.cannonHit) audio.playCannonHit();
  if (events.shieldHit) audio.playShieldHit();
  if (events.ufoKill) audio.playUFODestroyed();
  if (events.ufoAppear) audio.playUFOAppear();
  if (events.combo > 0) audio.playCombo(events.combo);
  if (events.dropLand) audio.playDropLand();
  if (events.invaded) audio.playInvaded();
}

/**
 * The wave in play. Returns `false` when the step ends here: the match's
 * end reports itself on entering FINISHED, and a cleared wave announces
 * itself at once.
 */
function battle(game) {
  const prev = game.gameState;
  let s = clearEvents(prev);
  const local = game.localInputs;
  const remote = game.remoteInputs;
  if (local.left) s = moveCannon(s, 1, -1);
  if (local.right) s = moveCannon(s, 1, 1);
  if (remote.left) s = moveCannon(s, 2, -1);
  if (remote.right) s = moveCannon(s, 2, 1);

  // A missile goes on the press, not while the key is held.
  if (local.fire && !game.localFirePressed) {
    s = fireMissile(s, 1);
    game.audio.playFire();
  }
  game.localFirePressed = local.fire;
  if (remote.fire && !game.remoteFirePressed) {
    s = fireMissile(s, 2);
    game.audio.playFire();
  }
  game.remoteFirePressed = remote.fire;

  s = moveAliens(s, 1);
  if (s.mode !== GAME_MODE.COOP) s = moveAliens(s, 2);
  if (s.alien1MoveTimer > prev.alien1MoveTimer + 5) game.audio.playMarch();

  s = spawnBombs(s);
  s = updateMissiles(s);
  s = updateBombs(s);
  s = updateUFO(s);
  s = checkMissileAlienHits(s);
  s = checkMissileUFOHit(s);
  s = checkBombShieldHits(s);
  s = checkBombCannonHits(s);
  s = checkAlienReachedGround(s);
  s = processDropQueue(s);
  s = updateCombos(s);
  playEvents(game.audio, s.events);

  const over = checkGameOver(s);
  if (over.ended) {
    s.phase = PHASE.FINISHED;
    game.endResult = over;
    game.gameState = s;
    return false;
  }
  if (checkWaveClear(s)) {
    s.phase = PHASE.WAVE_CLEAR;
    s.events.waveCleared = true;
    game.audio.playWaveClear();
    game.gameState = s;
    game.broadcast();
    game.invalidate();
    return false;
  }
  game.gameState = tickTimers(s);
  return true;
}

/** Every step: the wave plays only in PLAYING, but every phase repaints and sends. */
function step(game) {
  game.updateOpponent();
  if (game.gameState.phase === PHASE.PLAYING && !battle(game)) return;
  game.invalidate();
  game.frameCount += 1;
  game.broadcast();
}

/** After the last wave the match ends; otherwise the next wave comes in. */
function nextWave(game) {
  const s = game.gameState;
  const maxWaves = s.mode === GAME_MODE.BLITZ ? 5 : 10;
  const wave = s.wave + 1;
  if (wave > maxWaves) {
    const over = checkGameOver({ ...s, wave, phase: PHASE.PLAYING });
    game.endResult = over.ended ? over : { ended: true, winner: s.score1 >= s.score2 ? 1 : 2 };
    s.phase = PHASE.FINISHED;
    return;
  }
  game.gameState = createWave(s, wave);
  game.gameState.phase = PHASE.WAVE_START;
  game.broadcast();
  game.invalidate();
}

/** The guest builds the host's waves from the seed, keeping its own shield layout. */
export function applySnapshot(game, decoded) {
  if (game.seed === 0 && decoded.seed !== 0) {
    game.seed = decoded.seed;
    game.gameState = createInitialState(game.gameMode, game.seed);
  }
  const shieldPositions = game.gameState._shieldPositions;
  Object.assign(game.gameState, decoded);
  game.gameState._shieldPositions = shieldPositions;
  game.invalidate();
}

export default defineGame({
  inputs: {
    left: ["ArrowLeft", "a", "A"],
    right: ["ArrowRight", "d", "D"],
    fire: [" ", "Spacebar"],
  },
  captureKeys: ["ArrowLeft", "ArrowRight", " ", "Spacebar", "a", "A", "d", "D"],
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: { create: createHexInvadersAI, difficulty: normalizeInvadersAIDifficulty },
  audio: HexInvadersAudio,
  theme: getColors,
  // The game id picks the mode; only the host seeds the waves.
  init: (game) => {
    game.gameMode = MODE_MAP[game.gameId] ?? GAME_MODE.INVASION_WAR;
    game.seed = game.isHost ? (Math.random() * 0xffffffff) >>> 0 : 0;
    return createInitialState(game.gameMode, game.seed);
  },
  setup: (game) => {
    game.localFirePressed = false;
    game.remoteFirePressed = false;
    game.endResult = null;
  },
  onStop: (game) => {
    game.localFirePressed = false;
    game.remoteFirePressed = false;
  },

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      // The beep sounds on each second that passes; the last one brings the first wave.
      COUNTDOWN: {
        enter: (game) => {
          game.gameState.countdown = COUNTDOWN_FROM;
          game.broadcast();
          game.invalidate();
        },
        every: { ms: COUNTDOWN_EVERY_MS, count: COUNTDOWN_FROM },
        onEvery: (game, remaining) => {
          game.audio.playCountdown();
          if (remaining === 0) {
            game.gameState = createWave(game.gameState, 1);
            game.gameState.phase = PHASE.PLAYING;
            game.broadcast();
            game.frameCount = 0;
            return;
          }
          game.gameState.countdown = remaining;
          game.broadcast();
          game.invalidate();
        },
        next: "PLAYING",
      },
      PLAYING: { steps: true, tick: step },
      WAVE_CLEAR: {
        steps: true,
        tick: step,
        after: { ms: WAVE_CLEAR_MS },
        then: nextWave,
        next: (game) => (game.gameState.phase === PHASE.FINISHED ? "FINISHED" : "WAVE_START"),
      },
      WAVE_START: {
        steps: true,
        tick: step,
        after: { ms: WAVE_START_MS },
        next: "PLAYING",
      },
      FINISHED: {
        final: true,
        enter: (game) => {
          const { score1, score2 } = game.gameState;
          const { winner } = game.endResult;
          game.broadcast();
          game.invalidate();
          if (winner > 0) game.audio.playVictory();
          else game.audio.playInvaded();
          game.finish({
            end: { score1, score2, winner },
            result: { score: { p1: score1, p2: score2 }, winner },
            broadcast: false,
          });
        },
      },
    },
  },

  applySnapshot,
  onEnd: (game, result) => {
    game.setKeyboardCaptured(false);
    game.gameState = { ...game.gameState, phase: PHASE.FINISHED };
    game.invalidate();
    game._reportResult({ score: { p1: result.score1, p2: result.score2 }, winner: result.winner });
  },
  render: (game) => {
    if (game.colors) render(game.ctx, game.gameState, game.colors, performance.now());
  },
  disconnectResult: (game) => ({
    score: { p1: game.gameState.score1, p2: game.gameState.score2 },
    winner: 0,
  }),
});
