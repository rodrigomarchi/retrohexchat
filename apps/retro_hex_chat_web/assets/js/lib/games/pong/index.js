/**
 * Hex Pong: two paddles, one ball, first to eleven.
 *
 * Host-authoritative: the host runs the physics and the guest draws the
 * snapshots it receives. The match lifecycle comes from `defineGame`; this
 * file says only what is Pong's.
 *
 * @module games/pong
 */

import { ARROWS_WASD_SPACE, ARROW_KEYS, defineGame } from "../core/define_game.js";
import { drawOnDisconnect, finishScored, guestEnd, playOutcome } from "../core/result.js";
import {
  countdownToServe,
  endTick,
  playTick,
  playingState,
  servingState,
} from "../core/paddle_flow.js";
import { createPongAI, normalizePongAIDifficulty } from "./ai.js";
import {
  CANVAS_W,
  createInitialState,
  createScoreParticles,
  // ex_dna:disable-for-lines:9 this game's own imports
  serveBall,
  stepTick,
  updateParticles,
} from "./physics.js";
import { GAME_END, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS } from "./sounds.js";

const SCORE_PAUSE_TICKS = 90; // 1.5 s

/** One simulation step on the host. */
function step(game) {
  const { state: s, events } = playTick(game, stepTick);
  if (events.scored) {
    game.audio.playScore();
    s.particles = createScoreParticles(
      s.lastScorer === 1 ? CANVAS_W - 20 : 20,
      s.ballY,
      game.fxRandom,
    );
  }
  endTick(game, s, updateParticles);
}

export default defineGame({
  inputs: {
    up: ARROW_KEYS.up,
    down: ARROW_KEYS.down,
  },
  captureKeys: ARROWS_WASD_SPACE,
  interpolate: { keys: ["ballX", "ballY", "paddle1Y", "paddle2Y"] },
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: { create: createPongAI, difficulty: normalizePongAIDifficulty },
  audio: { sounds: SOUNDS },
  theme: getColors,
  init: () => createInitialState(),

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      COUNTDOWN: countdownToServe(),
      SERVING: servingState({
        prepare: (game) => {
          game.gameState.countdown = 0;
        },
        serve: (game) => serveBall(game.gameState, game.random),
      }),
      PLAYING: playingState(step),
      SCORED: { after: { ticks: SCORE_PAUSE_TICKS }, next: "SERVING" },
      FINISHED: {
        final: true,
        enter: (game) => {
          const { score1, score2, winner } = game.gameState;
          playOutcome(game, winner);
          finishScored(game, score1, score2, winner);
        },
      },
    },
  },

  // The guest hears the countdown and every point; the end comes with GAME_END.
  cues: [
    { phase: PHASE.COUNTDOWN, play: "countdown" },
    { change: (s) => `${s.score1}:${s.score2}`, play: "score" },
  ],
  onEnd: guestEnd({
    phase: PHASE.FINISHED,
    fields: ["winner", "score1", "score2"],
    sound: (game, result) => playOutcome(game, result.winner),
  }),
  render: (game) =>
    render(game.ctx, game.gameState, game.colors, performance.now(), { mode: game.mode }),
  disconnectResult: drawOnDisconnect((s) => [s.score1, s.score2]),
});
