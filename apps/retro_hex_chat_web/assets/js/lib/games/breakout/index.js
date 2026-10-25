/**
 * Block Breakers: two paddles share one wall of blocks and one pool of lives,
 * clearing the board together.
 *
 * Host-authoritative. The match lifecycle comes from `defineGame`; this file
 * says only what is Block Breakers'.
 *
 * @module games/breakout
 */

import { defineGame } from "../core/define_game.js";
import { createBreakoutAI, normalizeBreakoutAIDifficulty } from "./ai.js";
import { BreakoutAudio } from "./audio.js";
import {
  BALL_SIZE,
  checkBlockCollision,
  checkLifeLost,
  checkPaddleCollision,
  checkWallBounce,
  checkWin,
  createBlockParticles,
  createInitialState,
  serveBall,
  updateBall,
  updatePaddle,
  updateParticles,
} from "./physics.js";
import { GAME_END, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";

const SERVE_DELAY_MS = 800;
const LIFE_LOST_PAUSE_MS = 1500;
const COUNTDOWN_FROM = 3;
const COUNTDOWN_EVERY_MS = 1000;

/** One simulation step on the host. */
function step(game) {
  game.updateOpponent();
  let s = game.gameState;

  s = updatePaddle(s, 1, game.localInputs);
  s = updatePaddle(s, 2, game.remoteInputs);
  s = updateBall(s);
  s = checkWallBounce(s);
  if (s.wallBounced) {
    game.audio.playWallBounce();
    s.wallBounced = false;
  }

  s = checkPaddleCollision(s);
  if (s.paddleHit) {
    game.audio.playPaddleHit();
    s.paddleHit = false;
  }

  s = checkBlockCollision(s);
  if (s.blockHit) {
    game.audio.playBlockHit(s.hitBlockRow);
    s.particles = [
      ...(s.particles || []),
      ...createBlockParticles(s.hitBlockX, s.hitBlockY, s.hitBlockColor, game.fxRandom),
    ];
    s.blockHit = false;
  }

  s = checkLifeLost(s);
  if (s.lifeLost) {
    game.audio.playLifeLost();
    game.lastExitSide = s.ballY <= 0 + BALL_SIZE / 2 ? "top" : "bottom";
    s.lifeLost = false;
  }

  s = checkWin(s);
  if (s.particles && s.particles.length > 0) s.particles = updateParticles(s.particles);

  game.gameState = s;
  game.invalidate();
  game.frameCount++;
  game.broadcast();
}

/** The ball goes back toward the side it left by, or either way the first time. */
function serve(game) {
  let direction;
  if (game.lastExitSide === "bottom") direction = -1;
  else if (game.lastExitSide === "top") direction = 1;
  else direction = game.random() < 0.5 ? 1 : -1;
  game.gameState = serveBall(game.gameState, direction, game.random);
  game.broadcast();
}

function applySnapshot(game, decoded) {
  const s = game.gameState;
  for (const key of [
    "ballX",
    "ballY",
    "ballVX",
    "ballVY",
    "paddle1X",
    "paddle2X",
    "score",
    "lives",
    "phase",
    "countdown",
    "blocksRemaining",
  ]) {
    s[key] = decoded[key];
  }
  if (decoded.blocksAlive && s.blocks) {
    for (let i = 0; i < s.blocks.length; i++) s.blocks[i].alive = decoded.blocksAlive[i] || false;
  }
}

/** The guest hears the countdown, the end, a life lost and every block hit. */
function onSnapshot(game, decoded, previous) {
  if (previous.phase !== decoded.phase) {
    if (decoded.phase === PHASE.COUNTDOWN) game.audio.playCountdown();
    if (decoded.phase === PHASE.FINISHED) {
      if (game.gameState.won) game.audio.playWin();
      else game.audio.playLose();
    }
    if (decoded.phase === PHASE.LIFE_LOST) game.audio.playLifeLost();
  }
  if (game.gameState.score !== previous.score) game.audio.playBlockHit(0);
  game.invalidate();
}

export default defineGame({
  inputs: {
    left: ["ArrowLeft", "a", "A"],
    right: ["ArrowRight", "d", "D"],
  },
  captureKeys: [
    "ArrowLeft",
    "ArrowRight",
    "ArrowUp",
    "ArrowDown",
    " ",
    "Spacebar",
    "a",
    "A",
    "d",
    "D",
  ],
  interpolate: { keys: ["ballX", "ballY", "paddle1X", "paddle2X"] },
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: {
    create: createBreakoutAI,
    difficulty: normalizeBreakoutAIDifficulty,
    observe: (game) => ({ state: game.gameState, player: 2, difficulty: game.difficulty }),
  },
  audio: BreakoutAudio,
  theme: getColors,
  init: () => createInitialState(),
  setup: (game) => {
    game.lastExitSide = null;
  },
  onStop: (game) => {
    game.localInputs = { left: false, right: false };
    game.remoteInputs = { left: false, right: false };
    game.peerReady = false;
  },

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      COUNTDOWN: {
        enter: (game) => {
          game.gameState.countdown = COUNTDOWN_FROM;
          game.setKeyboardCaptured(true);
          game.broadcast();
          game.audio.playCountdown();
        },
        every: { ms: COUNTDOWN_EVERY_MS, count: COUNTDOWN_FROM },
        onEvery: (game, remaining) => {
          if (remaining === 0) return;
          game.gameState.countdown = remaining;
          game.broadcast();
          game.invalidate();
          game.audio.playCountdown();
        },
        next: "SERVING",
      },
      SERVING: {
        enter: (game) => {
          game.gameState.countdown = 0;
          game.setKeyboardCaptured(true);
          game.broadcast();
          game.invalidate();
        },
        after: { ms: SERVE_DELAY_MS },
        then: serve,
        next: "PLAYING",
      },
      PLAYING: {
        steps: true,
        enter: (game) => {
          game.frameCount = 0;
        },
        tick: step,
      },
      // A lost life holds the board still a moment, then serves as at the start.
      LIFE_LOST: { after: { ms: LIFE_LOST_PAUSE_MS }, next: "SERVING" },
      FINISHED: {
        final: true,
        enter: (game) => {
          const { score, won } = game.gameState;
          if (won) game.audio.playWin();
          else game.audio.playLose();
          game.finish({
            end: { score, won },
            // The pair wins or loses together: 0 for a cleared board, -1 for no lives left.
            result: { score: { p1: score, p2: score }, winner: won ? 0 : -1 },
          });
        },
      },
    },
  },

  applySnapshot,
  onSnapshot,
  onEnd: (game, result) => {
    game.setKeyboardCaptured(false);
    game.gameState.phase = PHASE.FINISHED;
    game.gameState.won = result.won;
    game.gameState.score = result.score;
    if (result.won) game.audio.playWin();
    else game.audio.playLose();
    game.invalidate();
  },
  render: (game) => {
    if (game.colors) render(game.ctx, game.gameState, game.colors, performance.now());
  },
  disconnectResult: (game) => ({
    score: { p1: game.gameState.score, p2: game.gameState.score },
    winner: -1,
  }),
});
