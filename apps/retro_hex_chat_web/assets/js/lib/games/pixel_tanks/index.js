/**
 * Pixel Tanks: two tanks in a maze, one shell each, best of the rounds.
 *
 * Host-authoritative; the host picks the maze and the guest follows it from
 * the snapshots. The match lifecycle comes from `defineGame`; this file says
 * only what is Pixel Tanks'.
 *
 * @module games/pixel_tanks
 */

import { settleParticles } from "../core/render.js";
import { ARROWS_WASD_SPACE, ARROW_KEYS, defineGame } from "../core/define_game.js";
import { createPixelTanksAI, normalizePixelTanksAIDifficulty } from "./ai.js";
import {
  ROUND_DURATION,
  advanceRound,
  checkRoundEnd,
  createExplosion,
  createInitialState,
  createSparks,
  decodeMaze,
  getMatchWinner,
  resetForNewRound,
  selectMaze,
  stepTick,
  updateParticles,
} from "./physics.js";
import { GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS } from "./sounds.js";
import { closeRoundStep, publishStep, roundsEnding, roundsFlow } from "../core/rounds.js";

const RELEASED = { rotateLeft: false, rotateRight: false, forward: false, fire: false };

function battle(game) {
  game.updateOpponent();
  const step = stepTick(
    game.gameState,
    game.walls,
    { 1: game.localInputs, 2: game.remoteInputs },
    { 1: game.localFirePressed, 2: game.remoteFirePressed },
  );
  game.localFirePressed = step.pressed[1];
  game.remoteFirePressed = step.pressed[2];
  const s = step.state;

  // After a hit both tanks hold still until they respawn.
  if (step.paused) {
    publishStep(game, s, updateParticles);
    return;
  }

  const { fired, bounces, hit } = step.events;
  for (let i = 0; i < fired.length; i++) game.audio.playFire();
  for (const spark of bounces) {
    game.particles = [...game.particles, ...createSparks(spark.x, spark.y, game.fxRandom)];
  }
  if (bounces.length > 0) game.audio.playRicochet();
  if (hit) {
    game.audio.playHit();
    game.particles = [...game.particles, ...createExplosion(hit.x, hit.y, game.fxRandom)];
  }

  const ended = closeRoundStep(game, s, {
    checkRoundEnd,
    advanceRound,
    sound: () => game.audio.playRoundEnd(),
  });
  if (ended) return;

  publishStep(game, s, updateParticles);
}

/** The guest follows the host's maze and mode, then takes the snapshot field by field. */
function applySnapshot(game, decoded) {
  if (decoded.mazeIndex !== game.mazeIndex) {
    game.mazeIndex = decoded.mazeIndex;
    game.walls = decodeMaze(decoded.mazeIndex);
  }
  game.gameMode = decoded.mode;

  Object.assign(game.gameState, decoded);
}

export default defineGame({
  inputs: {
    rotateLeft: ARROW_KEYS.left,
    rotateRight: ARROW_KEYS.right,
    forward: ARROW_KEYS.up,
    fire: [" ", "Shift"],
  },
  captureKeys: [...ARROWS_WASD_SPACE, "Shift"],
  interpolate: { keys: ["tank1X", "tank1Y", "tank2X", "tank2Y", "m1X", "m1Y", "m2X", "m2Y"] },
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: {
    create: createPixelTanksAI,
    difficulty: normalizePixelTanksAIDifficulty,
    observe: (game) => ({
      state: game.gameState,
      gameMode: game.gameMode,
      walls: game.walls,
      difficulty: game.difficulty,
      player: 2,
    }),
  },
  audio: { sounds: SOUNDS },
  theme: getColors,
  // Shells bounce off the first wall they meet. The host chooses the maze;
  // the guest learns it from the first snapshot.
  init: (game) => {
    game.gameMode = GAME_MODE.RICOCHET;
    game.mazeIndex = game.isHost ? selectMaze(game.random) : 0;
    game.walls = decodeMaze(game.mazeIndex);
    return createInitialState(game.gameMode, game.mazeIndex);
  },
  setup: (game) => {
    game.particles = [];
    game.localFirePressed = false;
    game.remoteFirePressed = false;
  },
  onStart: (game) => {
    game.localInputs = { ...RELEASED };
  },
  onStop: (game) => {
    game.localFirePressed = false;
    // ex_dna:disable-for-lines:8 this game's own defineGame definition
    game.remoteFirePressed = false;
  },
  idle: settleParticles(updateParticles),

  flow: roundsFlow({
    phases: PHASE,
    play: "PLAYING",
    bell: (game) => game.audio.playSpawn(),
    startRound: (game) => {
      game.gameState.roundTimer = ROUND_DURATION;
    },
    states: {
      PLAYING: {
        enter: (game) => {
          game.frameCount = 0;
          game.localFirePressed = false;
          game.remoteFirePressed = false;
        },
        tick: battle,
      },
    },
    nextRound: resetForNewRound,
    winner: getMatchWinner,
  }),

  applySnapshot,
  cues: [
    { phase: PHASE.COUNTDOWN, play: "countdown" },
    { phase: PHASE.SPAWNING, play: "spawn" },
    { phase: PHASE.ROUND_OVER, play: "roundEnd" },
  ],
  ...roundsEnding(PHASE),
  render: (game) =>
    render(game.ctx, game.gameState, game.colors, game.walls, performance.now(), game.particles),
});
