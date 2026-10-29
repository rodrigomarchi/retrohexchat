/**
 * Block Breakers: two paddles share one wall of blocks and one pool of lives,
 * clearing the board together.
 *
 * Host-authoritative. The match lifecycle comes from `defineGame`; this file
 * says only what is Block Breakers'.
 *
 * @module games/breakout
 */

import { ARROW_KEYS, defineGame } from "../core/define_game.js";
import { guestEnd } from "../core/result.js";
import { createBreakoutAI, normalizeBreakoutAIDifficulty } from "./ai.js";
import {
  createBlockParticles,
  createInitialState,
  // ex_dna:disable-for-lines:17 this game's own imports
  serveAfter,
  stepTick,
  updateParticles,
} from "./physics.js";
import { GAME_END, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS } from "./sounds.js";
import {
  countdownToServe,
  endTick,
  playTick,
  playingState,
  releaseOnStop,
  servingState,
} from "../core/paddle_flow.js";

const LIFE_LOST_PAUSE_TICKS = 90; // 1.5 s

/** One simulation step on the host. */
function step(game) {
  const { state: s, events } = playTick(game, stepTick);
  if (events.blockHit) {
    game.audio.playBlockHit(s.hitBlockRow);
    s.particles = [
      ...(s.particles || []),
      ...createBlockParticles(s.hitBlockX, s.hitBlockY, s.hitBlockColor, game.fxRandom),
    ];
  }
  if (events.exitSide) {
    game.audio.playLifeLost();
    game.lastExitSide = events.exitSide;
  }
  endTick(game, s, updateParticles);
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

/** Each difficulty the player picks, and the partner that gives it. */
const PARTNER_FOR = Object.freeze({ easy: "hard", normal: "normal", hard: "easy" });

/**
 * The AI here plays beside the player, not against them, so the difficulty
 * the player picks names how hard their game is: an easy game gets the
 * strongest partner, a hard game the weakest.
 * @param {unknown} chosen - the difficulty the player picked
 * @returns {"easy"|"normal"|"hard"} the AI's own difficulty
 */
export function partnerDifficulty(chosen) {
  return PARTNER_FOR[normalizeBreakoutAIDifficulty(chosen)];
}

export default defineGame({
  inputs: {
    left: ARROW_KEYS.left,
    right: ARROW_KEYS.right,
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
    difficulty: partnerDifficulty,
  },
  audio: { sounds: SOUNDS },
  theme: getColors,
  init: () => createInitialState(),
  setup: (game) => {
    game.lastExitSide = null;
  },
  onStop: releaseOnStop({ left: false, right: false }),

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      COUNTDOWN: countdownToServe({ capture: true }),
      SERVING: servingState({
        prepare: (game) => {
          game.gameState.countdown = 0;
          game.setKeyboardCaptured(true);
        },
        // The ball goes back toward the side it left by, or either way the first time.
        serve: (game) => serveAfter(game.gameState, game.lastExitSide, game.random),
      }),
      PLAYING: playingState(step),
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
  onEnd: guestEnd({
    phase: PHASE.FINISHED,
    fields: ["won", "score"],
    sound: (game, result) => (result.won ? game.audio.playWin() : game.audio.playLose()),
  }),
  render: (game) => render(game.ctx, game.gameState, game.colors, performance.now()),
  disconnectResult: (game) => ({
    score: { p1: game.gameState.score, p2: game.gameState.score },
    winner: -1,
  }),
});
