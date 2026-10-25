/**
 * Hex Boxing: two boxers in a top-down ring, punches score by how they land,
 * best of three rounds or a knockout.
 *
 * Host-authoritative. The match lifecycle comes from `defineGame`; this file
 * says only what is Boxing's.
 *
 * @module games/hex_boxing
 */

import { defineGame } from "../core/define_game.js";
import { createBoxingAI, normalizeBoxingAIDifficulty } from "./ai.js";
import { BoxingAudio } from "./audio.js";
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

function countdown(game, remaining) {
  game.gameState.countdown = remaining;
  game.broadcast();
  game.invalidate();
  game.audio.playCountdown();
}

function playPhaseAudio(game, prevPhase, newPhase) {
  if (prevPhase === newPhase) return;
  if (newPhase === PHASE.COUNTDOWN) game.audio.playCountdown();
  if (newPhase === PHASE.SPAWNING) game.audio.playBellStart();
  if (newPhase === PHASE.ROUND_OVER) game.audio.playBellEnd();
}

/** The guest takes the snapshot field by field, and hears and sees every hit. */
function applySnapshot(game, decoded) {
  const prevPhase = game.gameState.phase;
  Object.assign(game.gameState, decoded);

  if (decoded.lastHitPlayer !== 0 && decoded.lastHitPoints > 0) {
    game.audio.playHit(decoded.lastHitPoints);
    const defender = decoded.lastHitPlayer === 1 ? "b2" : "b1";
    addHitParticles(game, decoded[`${defender}x`], decoded[`${defender}y`], decoded.lastHitPoints);
  }
  playPhaseAudio(game, prevPhase, decoded.phase);
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
  audio: BoxingAudio,
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
  idle: (game) => {
    if (!game.particles.length) return;
    game.particles = updateParticles(game.particles);
    game.invalidate();
  },

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      COUNTDOWN: {
        enter: (game) => {
          game.setKeyboardCaptured(true);
          countdown(game, COUNTDOWN_FROM);
        },
        every: { ticks: COUNTDOWN_EVERY_TICKS, count: COUNTDOWN_FROM },
        onEvery: (game, remaining) => {
          if (remaining > 0) countdown(game, remaining);
        },
        next: "SPAWNING",
      },
      SPAWNING: {
        enter: (game) => {
          game.setKeyboardCaptured(true);
          game.broadcast();
          game.invalidate();
          game.audio.playBellStart();
        },
        after: { ticks: SPAWNING_DELAY_TICKS },
        then: (game) => {
          game.gameState.phase = PHASE.FIGHTING;
          game.gameState.roundTimer = ROUND_DURATION;
          game.broadcast();
        },
        next: "FIGHTING",
      },
      FIGHTING: {
        enter: (game) => {
          game.setKeyboardCaptured(true);
          game.frameCount = 0;
          game.localPunchPressed = false;
          game.remotePunchPressed = false;
        },
        tick: fight,
      },
      ROUND_OVER: {
        after: { ticks: ROUND_OVER_DELAY_TICKS },
        then: (game) => {
          game.gameState = resetForNewRound(game.gameState);
        },
        next: "COUNTDOWN",
      },
      MATCH_OVER: {
        final: true,
        enter: (game) => {
          const s = game.gameState;
          const winner = s.roundWins1 >= s.roundWins2 ? 1 : 2;
          if (winner === 1) game.audio.playWin();
          else game.audio.playLose();
          game.invalidate();
          game.finish({
            end: {
              score1: s.score1,
              score2: s.score2,
              winner,
              roundWins1: s.roundWins1,
              roundWins2: s.roundWins2,
            },
            result: { score: { p1: s.roundWins1, p2: s.roundWins2 }, winner },
          });
        },
      },
    },
  },

  applySnapshot,
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
