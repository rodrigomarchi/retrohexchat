/**
 * Hex Outlaw: two gunslingers across a frontier street, a hit wins the
 * round, best of the rounds takes the match.
 *
 * Host-authoritative. A hit that does not end the round freezes the street
 * for a moment (HIT_PAUSE), entered and left by the simulation itself. The
 * match lifecycle comes from `defineGame`; this file says only what is
 * Outlaw's.
 *
 * @module games/hex_outlaw
 */

import { settleParticles } from "../core/render.js";
import { ARROWS_WASD_SPACE, ARROW_KEYS, defineGame } from "../core/define_game.js";
import { createOutlawAI, normalizeOutlawAIDifficulty } from "./ai.js";
import { createInitialState, resetForNewRound, stepTick } from "./physics.js";
import { GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { createHitParticles, getColors, render, updateParticles } from "./renderer.js";
import { SOUNDS } from "./sounds.js";
import { endRoundStep, publishStep, roundsEnding, roundsFlow } from "../core/rounds.js";

const MODE_MAP = {
  hex_outlaw_ricochet: GAME_MODE.RICOCHET,
  hex_outlaw_stagecoach: GAME_MODE.STAGECOACH,
  hex_outlaw_nml: GAME_MODE.NO_MANS_LAND,
};

/** Up aims the next shot high, down aims it level; the last one pressed holds. */
function aimRemote(game) {
  if (game.remoteInputs.up) game.remoteAimUp = true;
  if (game.remoteInputs.down) game.remoteAimUp = false;
}

function addHitParticles(game, x, y) {
  game.particles = [...game.particles, ...createHitParticles(x, y, game.fxRandom)];
}

function duel(game) {
  const playing = game.gameState.phase !== PHASE.HIT_PAUSE;
  if (playing) {
    game.updateOpponent();
    // In solo play the AI's aim counts for this step's shot.
    if (game.mode === "solo") aimRemote(game);
  }

  const step = stepTick(
    game.gameState,
    { 1: game.localInputs, 2: game.remoteInputs },
    { 1: game.localFirePressed, 2: game.remoteFirePressed },
    { 1: game.localAimUp, 2: game.remoteAimUp },
  );
  const s = step.state;
  if (step.paused) {
    publishStep(game, s, updateParticles);
    return;
  }

  game.localFirePressed = step.pressed[1];
  game.remoteFirePressed = step.pressed[2];
  aimRemote(game);

  const { fired, ricochets, hit, obstacleHit, roundOver } = step.events;
  for (let i = 0; i < fired.length; i++) game.audio.playGunshot();
  for (let i = 0; i < ricochets; i++) game.audio.playRicochet();
  if (hit) {
    game.audio.playHit();
    addHitParticles(game, hit.x, hit.y);
  }
  if (obstacleHit) game.audio.playObstacleHit();

  if (hit) {
    if (roundOver) {
      endRoundStep(game, s);
      return;
    }
    game.gameState = s;
    game.broadcast();
  }

  publishStep(game, s, updateParticles);
}

/** The guest takes the snapshot field by field, and sees every hit. */
function applySnapshot(game, decoded) {
  Object.assign(game.gameState, decoded);
  if (decoded.lastHitPlayer !== 0) {
    const defender = decoded.lastHitPlayer === 1 ? "p2" : "p1";
    addHitParticles(game, decoded[`${defender}x`], decoded[`${defender}y`]);
  }
}

const releaseTriggers = (game) => {
  game.localFirePressed = false;
  game.remoteFirePressed = false;
};

export default defineGame({
  inputs: {
    up: ARROW_KEYS.up,
    down: ARROW_KEYS.down,
    left: ARROW_KEYS.left,
    right: ARROW_KEYS.right,
    fire: [" ", "Shift"],
  },
  captureKeys: ARROWS_WASD_SPACE,
  interpolate: { keys: ["p1x", "p1y", "p2x", "p2y", "b1x", "b1y", "b2x", "b2y"] },
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: { create: createOutlawAI, difficulty: normalizeOutlawAIDifficulty },
  audio: { sounds: SOUNDS },
  theme: getColors,
  // The game id picks the street: quick draw, ricochet, stagecoach or no man's land.
  init: (game) => createInitialState(MODE_MAP[game.gameId] ?? GAME_MODE.QUICK_DRAW),
  setup: (game) => {
    game.particles = [];
    releaseTriggers(game);
    game.localAimUp = false;
    game.remoteAimUp = false;
  },
  onStop: releaseTriggers,
  onBlur: releaseTriggers,
  onKeyDown: (game, event) => {
    const input = game.keyInput(event);
    if (input === "up") game.localAimUp = true;
    // ex_dna:disable-for-lines:8 this game's own defineGame definition
    if (input === "down") game.localAimUp = false;
  },
  idle: settleParticles(updateParticles),

  flow: roundsFlow({
    phases: PHASE,
    play: "PLAYING",
    bell: (game) => game.audio.playBell(),
    // A trigger already held at the bell does not fire until pressed again.
    startRound: (game) => {
      game.frameCount = 0;
      game.localFirePressed = game.localInputs.fire;
      game.remoteFirePressed = game.remoteInputs.fire;
    },
    states: { PLAYING: { tick: duel }, HIT_PAUSE: { tick: duel } },
    nextRound: resetForNewRound,
    winner: (s) => (s.roundWins1 >= s.roundWins2 ? 1 : 2),
  }),

  applySnapshot,
  // The guest hears every shot and hit, the countdown and the bell.
  cues: [
    { rise: (s) => s.b1active, play: "gunshot" },
    { rise: (s) => s.b2active, play: "gunshot" },
    { when: (s) => s.lastHitPlayer !== 0, play: "hit" },
    { phase: PHASE.COUNTDOWN, play: "countdown" },
    { phase: PHASE.SPAWNING, play: "bell" },
  ],
  onSnapshot: (game) => game.invalidate(),
  ...roundsEnding(PHASE),
  render: (game) => render(game.ctx, game.gameState, game.colors, game.frameCount, game.particles),
});
