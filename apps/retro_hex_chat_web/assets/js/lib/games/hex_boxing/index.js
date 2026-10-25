/**
 * Hex Boxing: two boxers in a top-down ring, punches score by how they land,
 * best of three rounds or a knockout.
 *
 * Host-authoritative. The match lifecycle comes from `defineGame`; this file
 * says only what is Boxing's.
 *
 * @module games/hex_boxing
 */

import { settleParticles } from "../core/render.js";
import { defineGame } from "../core/define_game.js";
import { createBoxingAI, normalizeBoxingAIDifficulty } from "./ai.js";
import {
  ROUND_DURATION,
  advanceRound,
  checkPunchHit,
  checkRoundEnd,
  createInitialState,
  moveBoxer,
  resetForNewRound,
  startPunch,
  tickPunchTimers,
  tickRoundTimer,
} from "./physics.js";
import { GAME_END, PHASE, SNAPSHOT } from "./protocol.js";
import { createHitParticles, getColors, render, updateParticles } from "./renderer.js";
import { SOUNDS } from "./sounds.js";
import { roundsFlow } from "../core/rounds.js";

const ROUND_OVER_DELAY_TICKS = 150; // 2.5 s
const SPAWNING_DELAY_TICKS = 60; // 1 s
const COUNTDOWN_FROM = 3;
const COUNTDOWN_EVERY_TICKS = 60; // 1 s

/** The eight directions as the ring's numbering, or -1 for none. */
export function direction({ up, down, left, right }) {
  if (right && !left) {
    if (up && !down) return 7;
    if (down && !up) return 1;
    return 0;
  }
  if (left && !right) {
    if (up && !down) return 5;
    if (down && !up) return 3;
    return 4;
  }
  if (up && !down) return 6;
  if (down && !up) return 2;
  return -1;
}

function addHitParticles(game, x, y, points) {
  game.particles = [...game.particles, ...createHitParticles(x, y, points, game.fxRandom)];
}

/** One step of the fight on the host. */
function fight(game) {
  game.updateOpponent();
  let s = { ...game.gameState, lastHitPlayer: 0, lastHitPoints: 0 };

  const p1Dir = direction(game.localInputs);
  if (p1Dir >= 0) s = moveBoxer(s, 1, p1Dir);
  const p2Dir = direction(game.remoteInputs);
  if (p2Dir >= 0) s = moveBoxer(s, 2, p2Dir);

  // A punch starts on the press, not while the key is held.
  if (game.localInputs.punch && !game.localPunchPressed) s = startPunch(s, 1);
  game.localPunchPressed = game.localInputs.punch;
  if (game.remoteInputs.punch && !game.remotePunchPressed) s = startPunch(s, 2);
  game.remotePunchPressed = game.remoteInputs.punch;

  s = tickPunchTimers(s);

  const prevScore1 = s.score1;
  s = checkPunchHit(s, 1);
  const p1HitPoints = s.score1 > prevScore1 ? s.lastHitPoints : 0;
  const prevScore2 = s.score2;
  s = checkPunchHit(s, 2);
  const p2HitPoints = s.score2 > prevScore2 ? s.lastHitPoints : 0;

  if (p1HitPoints) {
    game.audio.playHit(p1HitPoints);
    addHitParticles(game, s.b2x, s.b2y, p1HitPoints);
  }
  if (p2HitPoints) {
    game.audio.playHit(p2HitPoints);
    addHitParticles(game, s.b1x, s.b1y, p2HitPoints);
  }

  s = tickRoundTimer(s);
  if (s.roundTimer <= 900 && s.roundTimer > 0 && s.roundTimer % 60 === 0) {
    game.audio.playTimerTick();
  }

  const { ended, roundWinner } = checkRoundEnd(s);
  if (ended) {
    s = advanceRound(s, roundWinner);
    if (s.koPlayer > 0) game.audio.playKO();
    else game.audio.playBellEnd();
    game.gameState = s;
    // The match's end reports itself on entering MATCH_OVER; a round's end
    // shows the round over until the next countdown.
    if (s.phase !== PHASE.MATCH_OVER) game.broadcast();
    return;
  }

  game.particles = updateParticles(game.particles);
  game.gameState = s;
  game.invalidate();
  game.frameCount++;
  game.broadcast();
}

/** The guest takes the snapshot field by field, and hears and sees every hit. */
function applySnapshot(game, decoded) {
  Object.assign(game.gameState, decoded);

  if (decoded.lastHitPlayer !== 0 && decoded.lastHitPoints > 0) {
    game.audio.playHit(decoded.lastHitPoints);
    const defender = decoded.lastHitPlayer === 1 ? "b2" : "b1";
    addHitParticles(game, decoded[`${defender}x`], decoded[`${defender}y`], decoded.lastHitPoints);
  }
}

export default defineGame({
  inputs: {
    up: ["ArrowUp", "w", "W"],
    down: ["ArrowDown", "s", "S"],
    left: ["ArrowLeft", "a", "A"],
    right: ["ArrowRight", "d", "D"],
    punch: [" ", "Shift"],
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
  interpolate: { keys: ["b1x", "b1y", "b2x", "b2y"] },
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: { create: createBoxingAI, difficulty: normalizeBoxingAIDifficulty },
  audio: { sounds: SOUNDS },
  theme: getColors,
  init: () => createInitialState(),
  setup: (game) => {
    game.particles = [];
    game.localPunchPressed = false;
    game.remotePunchPressed = false;
  },
  onStop: (game) => {
    game.localPunchPressed = false;
    game.remotePunchPressed = false;
  },
  idle: settleParticles(updateParticles),

  flow: roundsFlow({
    phases: PHASE,
    play: "FIGHTING",
    countdown: { from: COUNTDOWN_FROM, every: COUNTDOWN_EVERY_TICKS },
    spawnTicks: SPAWNING_DELAY_TICKS,
    roundOverTicks: ROUND_OVER_DELAY_TICKS,
    bell: (game) => game.audio.playBellStart(),
    startRound: (game) => {
      game.gameState.roundTimer = ROUND_DURATION;
    },
    states: {
      FIGHTING: {
        enter: (game) => {
          game.frameCount = 0;
          game.localPunchPressed = false;
          game.remotePunchPressed = false;
        },
        tick: fight,
      },
    },
    nextRound: resetForNewRound,
    winner: (s) => (s.roundWins1 >= s.roundWins2 ? 1 : 2),
  }),

  applySnapshot,
  cues: [
    { phase: PHASE.COUNTDOWN, play: "countdown" },
    { phase: PHASE.SPAWNING, play: "bellStart" },
    { phase: PHASE.ROUND_OVER, play: "bellEnd" },
  ],
  onEnd: (game, result) => {
    game.setKeyboardCaptured(false);
    game.gameState.phase = PHASE.MATCH_OVER;
    game.gameState.roundWins1 = result.roundWins1;
    game.gameState.roundWins2 = result.roundWins2;
    if (result.winner === 2) game.audio.playWin();
    else game.audio.playLose();
    game.invalidate();
  },
  render: (game) => {
    if (game.colors) render(game.ctx, game.gameState, game.colors, game.frameCount, game.particles);
  },
  disconnectResult: (game) => ({
    score: { p1: game.gameState.roundWins1, p2: game.gameState.roundWins2 },
    winner: 0,
  }),
});
