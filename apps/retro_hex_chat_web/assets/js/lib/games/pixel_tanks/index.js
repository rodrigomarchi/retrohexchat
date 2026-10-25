/**
 * Pixel Tanks: two tanks in a maze, one shell each, best of the rounds.
 *
 * Host-authoritative; the host picks the maze and the guest follows it from
 * the snapshots. The match lifecycle comes from `defineGame`; this file says
 * only what is Pixel Tanks'.
 *
 * @module games/pixel_tanks
 */

import { defineGame } from "../core/define_game.js";
import { createPixelTanksAI, normalizePixelTanksAIDifficulty } from "./ai.js";
import {
  ROUND_DURATION,
  advanceRound,
  checkMissileHit,
  checkRoundEnd,
  createExplosion,
  createInitialState,
  decodeMaze,
  fireMissile,
  getMatchWinner,
  moveTank,
  resetForNewRound,
  respawnTanks,
  rotateTank,
  selectMazeForMode,
  tickTimers,
  updateMissile,
  updateMissileRicochet,
  updateParticles,
} from "./physics.js";
import { GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS } from "./sounds.js";
import { roundsFlow } from "../core/rounds.js";

const ROUND_OVER_DELAY_TICKS = 150; // 2.5 s
const SPAWNING_DELAY_TICKS = 60; // 1 s
const COUNTDOWN_FROM = 3;
const COUNTDOWN_EVERY_TICKS = 60; // 1 s

const RELEASED = { rotateLeft: false, rotateRight: false, forward: false, fire: false };

/** Publish a step's state: particles settle, the frame repaints, the guest hears of it. */
function publish(game, s) {
  game.particles = updateParticles(game.particles);
  game.gameState = s;
  game.invalidate();
  game.frameCount++;
  game.broadcast();
}

/** A shell is fired on the press, not while the key is held. */
function fire(game, s, player, inputs, pressedKey, missileKey) {
  let next = s;
  if (inputs.fire && !game[pressedKey]) {
    next = fireMissile(next, player, game.walls);
    if (next[missileKey] && game.gameState[missileKey] !== next[missileKey]) game.audio.playFire();
  }
  game[pressedKey] = inputs.fire;
  return next;
}

function battle(game) {
  game.updateOpponent();
  let s = game.gameState;

  // After a hit both tanks hold still until they respawn.
  if (s.respawnPause > 0) {
    publish(game, tickTimers(s));
    return;
  }

  s = { ...s, tankHit: 0, missileExpired: 0, wallBounced: 0 };
  const local = game.localInputs;
  const remote = game.remoteInputs;
  if (local.rotateLeft) s = rotateTank(s, 1, -1);
  if (local.rotateRight) s = rotateTank(s, 1, 1);
  if (local.forward) s = moveTank(s, 1, game.walls);
  if (remote.rotateLeft) s = rotateTank(s, 2, -1);
  if (remote.rotateRight) s = rotateTank(s, 2, 1);
  if (remote.forward) s = moveTank(s, 2, game.walls);

  s = fire(game, s, 1, local, "localFirePressed", "m1Active");
  s = fire(game, s, 2, remote, "remoteFirePressed", "m2Active");

  const updateShell = game.gameMode === GAME_MODE.RICOCHET ? updateMissileRicochet : updateMissile;
  s = updateShell(s, 1, game.walls);
  s = updateShell(s, 2, game.walls);
  if (s.wallBounced) game.audio.playRicochet();

  s = checkMissileHit(s, 1);
  s = checkMissileHit(s, 2);
  if (s.tankHit !== 0) {
    game.audio.playHit();
    const hitX = s.tankHit === 1 ? s.tank1X : s.tank2X;
    const hitY = s.tankHit === 1 ? s.tank1Y : s.tank2Y;
    game.particles = [...game.particles, ...createExplosion(hitX, hitY, game.fxRandom)];
    s = respawnTanks(s);
  }

  s = tickTimers(s);
  if (s.roundTimer <= 900 && s.roundTimer > 0 && s.roundTimer % 60 === 0) {
    game.audio.playTimerTick();
  }

  const { ended, roundWinner } = checkRoundEnd(s);
  if (ended) {
    s = advanceRound(s, roundWinner);
    game.audio.playRoundEnd();
    game.gameState = s;
    // The match's end reports itself on entering MATCH_OVER.
    if (s.phase !== PHASE.MATCH_OVER) game.broadcast();
    return;
  }

  publish(game, s);
}

/** The guest follows the host's maze and mode, then takes the snapshot field by field. */
function applySnapshot(game, decoded) {
  if (decoded.mazeIndex !== game.mazeIndex) {
    game.mazeIndex = decoded.mazeIndex;
    game.walls = decodeMaze(decoded.mazeIndex);
  }
  if (decoded.mode !== game.gameMode) game.gameMode = decoded.mode;

  Object.assign(game.gameState, decoded);
}

export default defineGame({
  inputs: {
    rotateLeft: ["ArrowLeft", "a", "A"],
    rotateRight: ["ArrowRight", "d", "D"],
    forward: ["ArrowUp", "w", "W"],
    fire: [" ", "Shift"],
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
  // The host chooses the maze; the guest learns it from the first snapshot.
  init: (game) => {
    game.gameMode = GAME_MODE.MAZE_BATTLE;
    game.mazeIndex = game.isHost ? selectMazeForMode(game.gameMode, game.random) : 0;
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
    game.remoteFirePressed = false;
  },
  idle: (game) => {
    if (!game.particles.length) return;
    game.particles = updateParticles(game.particles);
    game.invalidate();
  },

  flow: roundsFlow({
    phases: PHASE,
    play: "PLAYING",
    countdown: { from: COUNTDOWN_FROM, every: COUNTDOWN_EVERY_TICKS },
    spawnTicks: SPAWNING_DELAY_TICKS,
    roundOverTicks: ROUND_OVER_DELAY_TICKS,
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
  onEnd: (game, result) => {
    game.setKeyboardCaptured(false);
    Object.assign(game.gameState, {
      phase: PHASE.MATCH_OVER,
      roundWins1: result.roundWins1,
      roundWins2: result.roundWins2,
    });
    if (result.winner === 2) game.audio.playWin();
    else game.audio.playLose();
    game.invalidate();
  },
  render: (game) => {
    if (game.colors) {
      render(game.ctx, game.gameState, game.colors, game.walls, performance.now(), game.particles);
    }
  },
  disconnectResult: (game) => ({
    score: { p1: game.gameState.roundWins1, p2: game.gameState.roundWins2 },
    winner: 0,
  }),
});
