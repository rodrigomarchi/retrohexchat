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

const DEFAULT_DIFFICULTY = "normal";
const BALL_MIN_Y = BALL_SIZE / 2;
const BALL_MAX_Y = CANVAS_H - BALL_SIZE / 2;
const PADDLE_MIN_CENTER_Y = PADDLE_H / 2;
const PADDLE_MAX_CENTER_Y = CANVAS_H - PADDLE_H / 2;
const TABLE_CENTER_Y = CANVAS_H / 2;
const NEUTRAL_INPUTS = Object.freeze({ up: false, down: false });

export const PONG_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    reactionFrames: 14,
    errorPx: 44,
    deadzonePx: 18,
    movementDuty: 0.55,
  }),
  normal: Object.freeze({
    reactionFrames: 7,
    errorPx: 18,
    deadzonePx: 10,
    movementDuty: 0.8,
  }),
  hard: Object.freeze({
    reactionFrames: 3,
    errorPx: 6,
    deadzonePx: 6,
    movementDuty: 1,
  }),
});

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizePongAIDifficulty(difficulty) {
  if (typeof difficulty !== "string") return DEFAULT_DIFFICULTY;

  const key = difficulty.toLowerCase();
  return Object.prototype.hasOwnProperty.call(PONG_AI_DIFFICULTIES, key) ? key : DEFAULT_DIFFICULTY;
}

/**
 * Reflect a projected ball center against the top and bottom walls.
 * @param {number} y
 * @returns {number}
 */
export function reflectPongY(y) {
  if (!Number.isFinite(y)) return TABLE_CENTER_Y;

  const span = BALL_MAX_Y - BALL_MIN_Y;
  const cycle = span * 2;
  let offset = (y - BALL_MIN_Y) % cycle;
  if (offset < 0) offset += cycle;

  return offset <= span ? BALL_MIN_Y + offset : BALL_MAX_Y - (offset - span);
}

/**
 * Predict where the ball center will reach a player's paddle face.
 * @param {object} state
 * @param {1|2} [player]
 * @returns {number|null}
 */
export function predictPaddleInterceptY(state, player = 2) {
  if (!isPredictableState(state)) return null;

  const targetX =
    player === 1
      ? PADDLE_MARGIN + PADDLE_W + BALL_SIZE / 2
      : CANVAS_W - PADDLE_MARGIN - PADDLE_W - BALL_SIZE / 2;
  const movingTowardPaddle = player === 1 ? state.ballVX < 0 : state.ballVX > 0;
  if (!movingTowardPaddle) return null;

  const framesUntilPaddle = (targetX - state.ballX) / state.ballVX;
  if (!Number.isFinite(framesUntilPaddle) || framesUntilPaddle < 0) return null;

  return reflectPongY(state.ballY + state.ballVY * framesUntilPaddle);
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

export class PongAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    this.difficulty = normalizePongAIDifficulty(options.difficulty);
    this.rng = typeof options.rng === "function" ? options.rng : Math.random;
    this.frame = 0;
    this.sampleAge = Number.POSITIVE_INFINITY;
    this.sampledTargetY = TABLE_CENTER_Y;
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    this.difficulty = normalizePongAIDifficulty(difficulty);
    this.sampleAge = Number.POSITIVE_INFINITY;
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{up: boolean, down: boolean}}
   */
  nextInputs(request = {}) {
    const state = request.state;
    const player = request.player === 1 ? 1 : 2;

    if (!state || state.phase !== PHASE.PLAYING) {
      this.frame++;
      return NEUTRAL_INPUTS;
    }

    const difficulty = normalizePongAIDifficulty(request.difficulty || this.difficulty);
    if (difficulty !== this.difficulty) this.setDifficulty(difficulty);

    const config = PONG_AI_DIFFICULTIES[difficulty];
    if (this.sampleAge >= config.reactionFrames) {
      this.sampledTargetY = this._sampleTargetY(state, player, config);
      this.sampleAge = 0;
    }

    const inputs = this._inputsForTarget(state, player, config);
    this.frame++;
    this.sampleAge++;
    return inputs;
  }

  _sampleTargetY(state, player, config) {
    const interceptY = predictPaddleInterceptY(state, player);
    const targetY = interceptY === null ? TABLE_CENTER_Y : interceptY;
    const error = ((this.rng() || 0) * 2 - 1) * config.errorPx;

    return clamp(targetY + error, PADDLE_MIN_CENTER_Y, PADDLE_MAX_CENTER_Y);
  }

  _inputsForTarget(state, player, config) {
    if (!isMovementFrame(this.frame, config)) return NEUTRAL_INPUTS;

    const paddleCenterY = paddleCenterFor(state, player);
    if (paddleCenterY === null) return NEUTRAL_INPUTS;

    const delta = this.sampledTargetY - paddleCenterY;
    const deadzone = Math.max(config.deadzonePx, PADDLE_SPEED / 2);
    if (Math.abs(delta) <= deadzone) return NEUTRAL_INPUTS;

    return delta < 0 ? { up: true, down: false } : { up: false, down: true };
  }
}

function isPredictableState(state) {
  return (
    state &&
    Number.isFinite(state.ballX) &&
    Number.isFinite(state.ballY) &&
    Number.isFinite(state.ballVX) &&
    Number.isFinite(state.ballVY)
  );
}

function paddleCenterFor(state, player) {
  const key = player === 1 ? "paddle1Y" : "paddle2Y";
  const paddleY = state[key];
  return Number.isFinite(paddleY) ? paddleY + PADDLE_H / 2 : null;
}

function isMovementFrame(frame, config) {
  if (config.movementDuty >= 1) return true;

  return (frame % 10) / 10 < config.movementDuty;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
