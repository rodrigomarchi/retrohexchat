/**
 * What the bat-and-ball games (Hex Pong, Block Breakers, Hex Warlords) share
 * in their match flow: the countdown into the serve, the serve after a short
 * wait, play a tick at a time, and the end of each host tick.
 *
 * @module games/core/paddle_flow
 */

import { countdownState } from "./rounds.js";

const COUNTDOWN_FROM = 3;
const COUNTDOWN_EVERY_TICKS = 60; // 1 s
const SERVE_DELAY_TICKS = 48; // 0.8 s

/**
 * Three, two, one, then the serve.
 * @param {{ capture?: boolean }} [options] - whether the countdown takes the keyboard
 * @returns {object} a flow state
 */
export function countdownToServe({ capture = false } = {}) {
  return countdownState({
    from: COUNTDOWN_FROM,
    every: COUNTDOWN_EVERY_TICKS,
    next: "SERVING",
    ...(capture && { capture }),
  });
}

/**
 * The wait before the serve: `prepare` sets the table and the match is told,
 * then after a moment `serve` puts the ball in play and play begins.
 * @param {object} options
 * @param {(game: object) => void} options.prepare
 * @param {(game: object) => object} options.serve - the state with the ball served
 * @param {string} [options.as] - the phase the guest is shown meanwhile
 * @returns {object} a flow state
 */
export function servingState({ prepare, serve, as }) {
  return {
    ...(as && { as }),
    enter: (game) => {
      prepare(game);
      game.broadcast();
      game.invalidate();
    },
    after: { ticks: SERVE_DELAY_TICKS },
    then: (game) => {
      game.gameState = serve(game);
      game.broadcast();
    },
    next: "PLAYING",
  };
}

/**
 * Play, a host tick at a time, counted from zero.
 * @param {(game: object) => void} tick
 * @returns {object} a flow state
 */
export function playingState(tick) {
  return {
    enter: (game) => {
      game.frameCount = 0;
    },
    tick,
  };
}

/**
 * The start of a host tick: the AI (if any) picks its keys, the game's
 * `stepTick` plays the tick on both sides' keys, and the ball's bounces off
 * the walls and the paddles are heard.
 * @param {object} game
 * @param {(state: object, local: object, remote: object) => { state: object, events: object }} stepTick
 * @returns {{ state: object, events: object }}
 */
export function playTick(game, stepTick) {
  game.updateOpponent();
  const tick = stepTick(game.gameState, game.localInputs, game.remoteInputs);
  if (tick.events.wallBounced) game.audio.playWallBounce();
  if (tick.events.paddleHit) game.audio.playPaddleHit();
  return tick;
}

/**
 * The end of a host tick: the sparks move on, and the new state is drawn,
 * counted and sent.
 * @param {object} game
 * @param {object} state
 * @param {(particles: Array) => Array} fade - the game's spark step
 */
export function endTick(game, state, fade) {
  if (state.particles && state.particles.length > 0) state.particles = fade(state.particles);
  game.gameState = state;
  game.invalidate();
  game.frameCount++;
  game.broadcast();
}

/**
 * On stopping, both sides' keys are let go and the peer is no longer ready.
 * @param {object} released - the game's input shape with every key up
 * @returns {(game: object) => void}
 */
export function releaseOnStop(released) {
  return (game) => {
    game.localInputs = { ...released };
    game.remoteInputs = { ...released };
    game.peerReady = false;
  };
}
