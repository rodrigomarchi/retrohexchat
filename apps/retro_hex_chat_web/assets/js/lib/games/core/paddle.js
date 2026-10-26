/**
 * The bounce off a paddle, shared by the games that have one, and the ball's
 * step that Pong and Block Breakers share.
 *
 * @module games/core/paddle
 */

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
