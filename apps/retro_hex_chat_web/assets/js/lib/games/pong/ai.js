/**
 * Deterministic opponent controller for Hex Pong solo sessions.
 * The controller consumes plain game state and emits the same input shape used
 * by the P2P peer path.
 * @module games/pong_ai
 */

import {
  BALL_SIZE,
  CANVAS_H,
  CANVAS_W,
  PADDLE_H,
  PADDLE_MARGIN,
  PADDLE_SPEED,
  PADDLE_W,
} from "./physics.js";
import { PHASE } from "./protocol.js";
import {
  clamp,
  dutyFrame,
  finiteMotion,
  interceptAt,
  normalizeDifficulty,
  reflect,
  toward,
} from "../core/ai.js";
import { PaddleAI } from "../core/paddle_ai.js";

const BALL_MIN_Y = BALL_SIZE / 2;
const BALL_MAX_Y = CANVAS_H - BALL_SIZE / 2;
const PADDLE_MIN_CENTER_Y = PADDLE_H / 2;
const PADDLE_MAX_CENTER_Y = CANVAS_H - PADDLE_H / 2;
const TABLE_CENTER_Y = CANVAS_H / 2;
const NEUTRAL_INPUTS = Object.freeze({ up: false, down: false });

/**
 * How each difficulty plays. `errorPx` is the aim error drawn once for each
 * approach of the ball: past PADDLE_H / 2 + BALL_SIZE / 2 (45 px) it misses,
 * and a wide `deadzonePx` stops the paddle short of where it aimed.
 */
export const PONG_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    reactionFrames: 14,
    errorPx: 56,
    deadzonePx: 13,
    movementDuty: 0.55,
  }),
  normal: Object.freeze({
    reactionFrames: 7,
    errorPx: 55,
    deadzonePx: 10,
    movementDuty: 0.8,
  }),
  hard: Object.freeze({
    reactionFrames: 3,
    errorPx: 53.5,
    deadzonePx: 6,
    movementDuty: 1,
  }),
});

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizePongAIDifficulty(difficulty) {
  return normalizeDifficulty(difficulty, PONG_AI_DIFFICULTIES);
}

/**
 * Reflect a projected ball center against the top and bottom walls.
 * @param {number} y
 * @returns {number}
 */
export function reflectPongY(y) {
  return reflect(y, BALL_MIN_Y, BALL_MAX_Y, TABLE_CENTER_Y);
}

/**
 * Predict where the ball center will reach a player's paddle face.
 * @param {object} state
 * @param {1|2} [player]
 * @returns {number|null}
 */
export function predictPaddleInterceptY(state, player = 2) {
  if (!finiteMotion(state, "ball")) return null;

  const targetX =
    player === 1
      ? PADDLE_MARGIN + PADDLE_W + BALL_SIZE / 2
      : CANVAS_W - PADDLE_MARGIN - PADDLE_W - BALL_SIZE / 2;
  const movingTowardPaddle = player === 1 ? state.ballVX < 0 : state.ballVX > 0;
  if (!movingTowardPaddle) return null;

  return interceptAt(
    state.ballX,
    state.ballVX,
    targetX,
    state.ballY,
    state.ballVY,
    BALL_MIN_Y,
    BALL_MAX_Y,
    TABLE_CENTER_Y,
  );
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {PongAI}
 */
export function createPongAI(options = {}) {
  return new PongAI(options);
}

export class PongAI extends PaddleAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    super(options, normalizePongAIDifficulty, PONG_AI_DIFFICULTIES);
    this.sampledTargetY = TABLE_CENTER_Y;
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{up: boolean, down: boolean}}
   */
  nextInputs(request = {}) {
    const turn = this.playFrame(request, PHASE.PLAYING, {
      incoming: (state, player) => predictPaddleInterceptY(state, player) !== null,
      every: "reactionFrames",
      look: (state, player, config) => this._sampleTargetY(state, player, config),
    });
    if (!turn) return NEUTRAL_INPUTS;

    this.sampledTargetY = turn.target;
    const inputs = this._inputsForTarget(turn.state, turn.player, turn.config);
    this.frame++;
    return inputs;
  }

  _sampleTargetY(state, player, config) {
    const interceptY = predictPaddleInterceptY(state, player);
    if (interceptY === null) return TABLE_CENTER_Y;

    const error = this.aimError(config.errorPx);
    return clamp(interceptY + error, PADDLE_MIN_CENTER_Y, PADDLE_MAX_CENTER_Y);
  }

  _inputsForTarget(state, player, config) {
    if (!dutyFrame(this.frame, config.movementDuty)) return NEUTRAL_INPUTS;

    const paddleCenterY = paddleCenterFor(state, player);
    if (paddleCenterY === null) return NEUTRAL_INPUTS;

    const deadzone = Math.max(config.deadzonePx, PADDLE_SPEED / 2);
    const [up, down] = toward(paddleCenterY, this.sampledTargetY, deadzone);
    return { up, down };
  }
}

function paddleCenterFor(state, player) {
  const key = player === 1 ? "paddle1Y" : "paddle2Y";
  const paddleY = state[key];
  return Number.isFinite(paddleY) ? paddleY + PADDLE_H / 2 : null;
}
