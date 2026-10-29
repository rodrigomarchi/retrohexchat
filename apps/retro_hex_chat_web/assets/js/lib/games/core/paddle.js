/**
 * What the bat-and-ball games (Hex Pong, Block Breakers, Hex Warlords) share
 * in their physics: the bounce off a paddle, the ball's step, the start of a
 * tick, the serve from the middle and the fading of their sparks.
 *
 * @module games/core/paddle
 */

import { gameColor } from "../../game_colors.js";
import { burst, stepParticles } from "./render.js";

/**
 * Where on the paddle the ball meets it sets how steeply it leaves: square
 * off the middle, up to `maxAngle` off either end. Every hit is a little
 * faster, up to `maxSpeed`. The caller puts `across` on the axis away from
 * the paddle (with its sign) and `along` on the axis the paddle runs.
 * @param {number} hit - the ball's coordinate along the paddle
 * @param {number} center - the paddle's middle on that axis
 * @param {number} half - half the paddle's length
 * @param {number} speed - the ball's speed before the hit
 * @param {{ maxAngle: number, increment: number, maxSpeed: number }} rules
 * @returns {{ speed: number, across: number, along: number }}
 */
export function paddleBounce(hit, center, half, speed, { maxAngle, increment, maxSpeed }) {
  const offset = Math.max(-1, Math.min(1, (hit - center) / half));
  const angle = offset * maxAngle;
  const next = Math.min(speed + increment, maxSpeed);
  return { speed: next, across: next * Math.cos(angle), along: next * Math.sin(angle) };
}

/**
 * The ball one frame on along its velocity, while the match is in `playing`;
 * in any other phase it stays where it is.
 * @param {{ phase: number, ballX: number, ballY: number, ballVX: number, ballVY: number }} state
 * @param {number} playing - the game's PHASE.PLAYING
 * @returns {object} new state
 */
export function moveBall(state, playing) {
  if (state.phase !== playing) return state;
  return { ...state, ballX: state.ballX + state.ballVX, ballY: state.ballY + state.ballVY };
}

/**
 * Whether `flag` is up on the state, which is left with it down.
 * @param {object} state - changed in place
 * @param {string} flag
 * @returns {boolean}
 */
export function lowerFlag(state, flag) {
  const up = state[flag] === true;
  if (up) state[flag] = false;
  return up;
}

/**
 * The start of a tick of Pong or Block Breakers: both paddles move by their
 * keys, the ball moves and bounces off the walls and the paddles. The game's
 * own steps do the work; the bounces come back beside the state, whose flags
 * are left down.
 * @param {object} state
 * @param {object} local - paddle one's keys
 * @param {object} remote - paddle two's keys
 * @param {{ updatePaddle: Function, updateBall: Function, checkWallBounce: Function, checkPaddleCollision: Function }} steps
 * @returns {{ state: object, wallBounced: boolean, paddleHit: boolean }}
 */
export function startPaddleTick(state, local, remote, steps) {
  let s = steps.updatePaddle(state, 1, local);
  s = steps.updatePaddle(s, 2, remote);
  s = steps.checkWallBounce(steps.updateBall(s));
  const wallBounced = lowerFlag(s, "wallBounced");
  s = steps.checkPaddleCollision(s);
  const paddleHit = lowerFlag(s, "paddleHit");
  return { state: s, wallBounced, paddleHit };
}

/**
 * The ball put in play from the middle of the table at `speed`, up to 30°
 * off square: `toward` is the sign along `axis`, the axis between the
 * paddles.
 * @param {object} state
 * @param {{ width: number, height: number, speed: number, axis: "x"|"y", toward: number, playing: number }} serve
 * @param {() => number} random - draws in [0, 1)
 * @returns {object} new state
 */
export function serveFromMiddle(state, { width, height, speed, axis, toward, playing }, random) {
  const angle = ((random() * 60 - 30) * Math.PI) / 180;
  const across = toward * speed * Math.cos(angle);
  const along = speed * Math.sin(angle);
  return {
    ...state,
    ballX: width / 2,
    ballY: height / 2,
    ballVX: axis === "x" ? across : along,
    ballVY: axis === "x" ? along : across,
    ballSpeed: speed,
    phase: playing,
  };
}

/**
 * Sparks one tick on: they slow and fade by `fade` a tick, and the gone ones drop out.
 * @param {Array} particles
 * @param {number} fade
 * @returns {Array}
 */
export function fadeSparks(particles, fade) {
  return stepParticles(particles, { drag: 0.96, fade });
}

/**
 * The sparks of a broken block: eight of them in `color`, amber by default.
 * @param {number} x
 * @param {number} y
 * @param {string} [color]
 * @param {() => number} [random=Math.random] - draws in [0, 1)
 * @returns {Array}
 */
export function brickSparks(x, y, color, random = Math.random) {
  return burst(
    x,
    y,
    8,
    { speed: [2, 3], extra: () => ({ life: 1.0, color: color || gameColor("ffaa00") }) },
    random,
  );
}
