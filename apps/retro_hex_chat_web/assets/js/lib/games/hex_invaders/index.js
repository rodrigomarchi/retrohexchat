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

import { ARROW_KEYS, defineGame, seededInit } from "../core/define_game.js";
import { beepCountdownState } from "../core/rounds.js";
import { drawOnDisconnect, finishScored } from "../core/result.js";
import { createHexInvadersAI, normalizeInvadersAIDifficulty } from "./ai.js";
// ex_dna:disable-for-lines:7 this game's own imports
import { coopSurvived, createInitialState, createWave, stepTick } from "./physics.js";
import { GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS } from "./sounds.js";

const MODE_MAP = {
  hex_invaders: GAME_MODE.INVASION_WAR,
  hex_invaders_coop: GAME_MODE.COOP,
  hex_invaders_blitz: GAME_MODE.BLITZ,
};

const WAVE_CLEAR_TICKS = 120; // 2 s
const WAVE_START_TICKS = 60; // 1 s

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
 * The wave in play: the frame's simulation, then what the engine makes of
 * it. Returns `false` when the step ends here: the match's end reports itself
 * on entering FINISHED, and a cleared wave announces itself at once.
 */
function battle(game) {
  const step = stepTick(game.gameState, game.localInputs, game.remoteInputs, {
    local: game.localFirePressed,
    remote: game.remoteFirePressed,
  });
  game.localFirePressed = step.held.local;
  game.remoteFirePressed = step.held.remote;
  if (step.fired.local) game.audio.playFire();
  if (step.fired.remote) game.audio.playFire();
  if (step.marched) game.audio.playMarch();
  playEvents(game.audio, step.state.events);
  game.gameState = step.state;

  if (step.over.ended) {
    game.endResult = step.over;
    return false;
  }
  if (step.state.phase === PHASE.WAVE_CLEAR) {
    game.audio.playWaveClear();
    game.broadcast();
    game.invalidate();
    return false;
  }
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

/**
 * The next wave comes in. The last wave never gets here: clearing it ends the
 * match in the step that clears it (checkGameOver).
 */
function nextWave(game) {
  const s = game.gameState;
  game.gameState = createWave(s, s.wave + 1);
  game.gameState.phase = PHASE.WAVE_START;
  game.broadcast();
  game.invalidate();
}

/**
 * The fanfare for whoever won at this screen, the invasion sting otherwise.
 * Co-op is won or lost together, and its result names no winner.
 */
function playEnd(game, winner) {
  const won =
    game.gameState.mode === GAME_MODE.COOP
      ? coopSurvived(game.gameState)
      : game.outcome(winner) === "win";
  if (won) game.audio.playVictory();
  else game.audio.playInvaded();
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
    left: ARROW_KEYS.left,
    right: ARROW_KEYS.right,
    fire: [" ", "Spacebar"],
  },
  captureKeys: ["ArrowLeft", "ArrowRight", " ", "Spacebar", "a", "A", "d", "D"],
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: { create: createHexInvadersAI, difficulty: normalizeInvadersAIDifficulty },
  audio: { sounds: SOUNDS },
  theme: getColors,
  // The game id picks the mode; only the host seeds the waves.
  init: seededInit(MODE_MAP, GAME_MODE.INVASION_WAR, createInitialState),
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
      COUNTDOWN: beepCountdownState({
        next: "PLAYING",
        start: (game) => {
          game.gameState = createWave(game.gameState, 1);
          game.gameState.phase = PHASE.PLAYING;
          game.broadcast();
          game.frameCount = 0;
        },
      }),
      PLAYING: { tick: step },
      WAVE_CLEAR: {
        tick: step,
        after: { ticks: WAVE_CLEAR_TICKS },
        then: nextWave,
        next: "WAVE_START",
      },
      WAVE_START: {
        tick: step,
        after: { ticks: WAVE_START_TICKS },
        next: "PLAYING",
      },
      FINISHED: {
        final: true,
        enter: (game) => {
          const { score1, score2 } = game.gameState;
          const { winner } = game.endResult;
          game.broadcast();
          game.invalidate();
          playEnd(game, winner);
          finishScored(game, score1, score2, winner, { broadcast: false });
        },
      },
    },
  },

  applySnapshot,
  onEnd: (game, result) => {
    game.setKeyboardCaptured(false);
    game.gameState = { ...game.gameState, phase: PHASE.FINISHED };
    playEnd(game, result.winner);
    game.invalidate();
  },
  render: (game) => render(game.ctx, game.gameState, game.colors, performance.now()),
  disconnectResult: drawOnDisconnect((s) => [s.score1, s.score2]),
});
