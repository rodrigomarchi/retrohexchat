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
import { ARROWS_WASD_SPACE, ARROW_KEYS, defineGame } from "../core/define_game.js";
import { createBoxingAI, normalizeBoxingAIDifficulty } from "./ai.js";
import {
  ROUND_DURATION,
  advanceRound,
  checkRoundEnd,
  createInitialState,
  resetForNewRound,
  stepTick,
} from "./physics.js";
import { GAME_END, PHASE, SNAPSHOT } from "./protocol.js";
import { createHitParticles, getColors, render, updateParticles } from "./renderer.js";
import { SOUNDS } from "./sounds.js";
import { closeRoundStep, publishStep, roundsEnding, roundsFlow } from "../core/rounds.js";

function addHitParticles(game, x, y, points) {
  game.particles = [...game.particles, ...createHitParticles(x, y, points, game.fxRandom)];
}

/** One step of the fight on the host. */
function fight(game) {
  game.updateOpponent();
  const step = stepTick(
    game.gameState,
    { 1: game.localInputs, 2: game.remoteInputs },
    { 1: game.localPunchPressed, 2: game.remotePunchPressed },
  );
  game.localPunchPressed = step.pressed[1];
  game.remotePunchPressed = step.pressed[2];
  const s = step.state;

  for (const { attacker, points } of step.events.hits) {
    const defender = attacker === 1 ? "b2" : "b1";
    game.audio.playHit(points);
    addHitParticles(game, s[`${defender}x`], s[`${defender}y`], points);
  }

  // A round's end shows the round over until the next countdown.
  const ended = closeRoundStep(game, s, {
    checkRoundEnd,
    advanceRound,
    sound: (next) => (next.koPlayer > 0 ? game.audio.playKO() : game.audio.playBellEnd()),
  });
  if (ended) return;

  publishStep(game, s, updateParticles);
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
    up: ARROW_KEYS.up,
    down: ARROW_KEYS.down,
    left: ARROW_KEYS.left,
    right: ARROW_KEYS.right,
    punch: [" ", "Shift"],
  },
  captureKeys: [...ARROWS_WASD_SPACE, "Shift"],
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
  ...roundsEnding(PHASE),
  render: (game) => render(game.ctx, game.gameState, game.colors, game.frameCount, game.particles),
});
