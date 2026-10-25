/**
 * Hex Pong: two paddles, one ball, first to eleven.
 *
 * Host-authoritative: the host runs the physics and the guest draws the
 * snapshots it receives. The match lifecycle comes from `defineGame`; this
 * file says only what is Pong's.
 *
 * @module games/pong
 */

import { defineGame } from "../core/define_game.js";
import { createPongAI, normalizePongAIDifficulty } from "./ai.js";
import { PongAudio } from "./audio.js";
import {
  CANVAS_W,
  checkPaddleCollision,
  checkScore,
  checkWallBounce,
  checkWin,
  createInitialState,
  createScoreParticles,
  serveBall,
  updateBall,
  updatePaddle,
  updateParticles,
} from "./physics.js";
import { GAME_END, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";

const SERVE_DELAY_TICKS = 48; // 0.8 s
const SCORE_PAUSE_TICKS = 90; // 1.5 s
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

  s = checkScore(s);
  if (s.scored) {
    game.audio.playScore();
    s.particles = createScoreParticles(
      s.lastScorer === 1 ? CANVAS_W - 20 : 20,
      s.ballY,
      game.fxRandom,
    );
    s.scored = false;
  }

  s = checkWin(s);
  if (s.particles && s.particles.length > 0) s.particles = updateParticles(s.particles);

  game.gameState = s;
  game.invalidate();
  game.frameCount++;
  game.broadcast();
}

/** The fanfare for whoever won at this screen, the falling one otherwise. */
function playEnd(game, winner) {
  if (game.outcome(winner) === "win") game.audio.playWin();
  else game.audio.playLose();
}

function countdown(game, remaining) {
  game.gameState.countdown = remaining;
  game.broadcast();
  game.invalidate();
  game.audio.playCountdown();
}

/** The guest hears the countdown and every point from the snapshots; the end from GAME_END. */
function onSnapshot(game, decoded, previous) {
  if (previous.phase !== decoded.phase && decoded.phase === PHASE.COUNTDOWN) {
    game.audio.playCountdown();
  }
  if (game.gameState.score1 !== previous.score1 || game.gameState.score2 !== previous.score2) {
    game.audio.playScore();
  }
}

export default defineGame({
  inputs: {
    up: ["ArrowUp", "w", "W"],
    down: ["ArrowDown", "s", "S"],
  },
  captureKeys: [
    "ArrowUp",
    "ArrowDown",
    "ArrowLeft",
    "ArrowRight",
    " ",
    "Spacebar",
    "w",
    "W",
    "a",
    "A",
    "s",
    "S",
    "d",
    "D",
  ],
  interpolate: { keys: ["ballX", "ballY", "paddle1Y", "paddle2Y"] },
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: { create: createPongAI, difficulty: normalizePongAIDifficulty },
  audio: PongAudio,
  theme: getColors,
  init: () => createInitialState(),

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      COUNTDOWN: {
        enter: (game) => countdown(game, COUNTDOWN_FROM),
        every: { ticks: COUNTDOWN_EVERY_TICKS, count: COUNTDOWN_FROM },
        onEvery: (game, remaining) => {
          if (remaining > 0) countdown(game, remaining);
        },
        next: "SERVING",
      },
      SERVING: {
        enter: (game) => {
          game.gameState.countdown = 0;
          game.broadcast();
          game.invalidate();
        },
        after: { ticks: SERVE_DELAY_TICKS },
        then: (game) => {
          game.gameState = serveBall(game.gameState, game.random);
          game.broadcast();
        },
        next: "PLAYING",
      },
      PLAYING: {
        enter: (game) => {
          game.frameCount = 0;
        },
        tick: step,
      },
      SCORED: { after: { ticks: SCORE_PAUSE_TICKS }, next: "SERVING" },
      FINISHED: {
        final: true,
        enter: (game) => {
          const { score1, score2, winner } = game.gameState;
          playEnd(game, winner);
          game.finish({
            end: { score1, score2, winner },
            result: { score: { p1: score1, p2: score2 }, winner },
          });
        },
      },
    },
  },

  onSnapshot,
  onEnd: (game, result) => {
    game.setKeyboardCaptured(false);
    game.gameState.phase = PHASE.FINISHED;
    game.gameState.winner = result.winner;
    game.gameState.score1 = result.score1;
    game.gameState.score2 = result.score2;
    playEnd(game, result.winner);
    game.invalidate();
  },
  render: (game) => {
    if (game.colors) {
      render(game.ctx, game.gameState, game.colors, performance.now(), { mode: game.mode });
    }
  },
  disconnectResult: (game) => ({
    score: { p1: game.gameState.score1, p2: game.gameState.score2 },
    winner: 0,
  }),
});
