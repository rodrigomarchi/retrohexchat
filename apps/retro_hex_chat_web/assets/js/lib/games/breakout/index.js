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
import { SOUNDS } from "./sounds.js";
import { countdownState } from "../core/rounds.js";

const SERVE_DELAY_TICKS = 48; // 0.8 s
const LIFE_LOST_PAUSE_TICKS = 90; // 1.5 s
const COUNTDOWN_FROM = 3;
const COUNTDOWN_EVERY_TICKS = 60; // 1 s

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
  audio: { sounds: SOUNDS },
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
      COUNTDOWN: countdownState({
        from: COUNTDOWN_FROM,
        every: COUNTDOWN_EVERY_TICKS,
        next: "SERVING",
        capture: true,
      }),
      SERVING: {
        enter: (game) => {
          game.gameState.countdown = 0;
          game.setKeyboardCaptured(true);
          game.broadcast();
          game.invalidate();
        },
        after: { ticks: SERVE_DELAY_TICKS },
        then: serve,
        next: "PLAYING",
      },
      PLAYING: {
        enter: (game) => {
          game.frameCount = 0;
        },
        tick: step,
      },
      // A lost life holds the board still a moment, then serves as at the start.
      LIFE_LOST: { after: { ticks: LIFE_LOST_PAUSE_TICKS }, next: "SERVING" },
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
  // The guest hears the countdown, the end, a life lost and every block hit.
  cues: [
    { phase: PHASE.COUNTDOWN, play: "countdown" },
    {
      phase: PHASE.FINISHED,
      play: (game, s) => (s.won ? game.audio.playWin() : game.audio.playLose()),
    },
    { phase: PHASE.LIFE_LOST, play: "lifeLost" },
    { change: (s) => s.score, play: (game) => game.audio.playBlockHit(0) },
  ],
  onSnapshot: (game) => game.invalidate(),
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
