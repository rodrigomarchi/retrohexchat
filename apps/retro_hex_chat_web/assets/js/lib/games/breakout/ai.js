/**
 * Deterministic opponent controller for Block Breakers solo sessions.
 * It controls the top paddle by emitting the same held-input shape used by the
 * P2P peer path.
 * @module games/breakout_ai
 */

import { PHASE } from "./protocol.js";
import {
  BALL_SIZE,
  CANVAS_H,
  CANVAS_W,
  PADDLE_H,
  PADDLE_MARGIN,
  PADDLE_SPEED,
  PADDLE_W,
} from "./physics.js";

const DEFAULT_DIFFICULTY = "normal";
const BALL_MIN_X = BALL_SIZE / 2;
const BALL_MAX_X = CANVAS_W - BALL_SIZE / 2;
const PADDLE_MIN_CENTER_X = PADDLE_W / 2;
const PADDLE_MAX_CENTER_X = CANVAS_W - PADDLE_W / 2;
const TABLE_CENTER_X = CANVAS_W / 2;
const P2_PADDLE_FACE_Y = PADDLE_MARGIN + PADDLE_H + BALL_SIZE / 2;
const P1_PADDLE_FACE_Y = CANVAS_H - PADDLE_MARGIN - PADDLE_H - BALL_SIZE / 2;
const NEUTRAL_INPUTS = Object.freeze({ left: false, right: false });

export const BREAKOUT_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    reactionFrames: 14,
    errorPx: 46,
    deadzonePx: 18,
    movementDuty: 0.55,
    followBias: 0.25,
  }),
  normal: Object.freeze({
    reactionFrames: 7,
    errorPx: 22,
    deadzonePx: 10,
    movementDuty: 0.82,
    followBias: 0.45,
  }),
  hard: Object.freeze({
    reactionFrames: 3,
    errorPx: 8,
    deadzonePx: 6,
    movementDuty: 1,
    followBias: 0.7,
  }),
});

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeBreakoutAIDifficulty(difficulty) {
  if (typeof difficulty !== "string") return DEFAULT_DIFFICULTY;

  const key = difficulty.toLowerCase();
  return Object.prototype.hasOwnProperty.call(BREAKOUT_AI_DIFFICULTIES, key)
    ? key
    : DEFAULT_DIFFICULTY;
}

/**
 * Reflect a projected ball center against the left and right walls.
 * @param {number} x
 * @returns {number}
 */
export function reflectBreakoutX(x) {
  if (!Number.isFinite(x)) return TABLE_CENTER_X;

  const span = BALL_MAX_X - BALL_MIN_X;
  const cycle = span * 2;
  let offset = (x - BALL_MIN_X) % cycle;
  if (offset < 0) offset += cycle;

  return offset <= span ? BALL_MIN_X + offset : BALL_MAX_X - (offset - span);
}

/**
 * Predict where the ball center will reach a player's paddle face.
 * @param {object} state
 * @param {1|2} [player]
 * @returns {number|null}
 */
export function predictBreakoutInterceptX(state, player = 2) {
  if (!isPredictableState(state)) return null;

  const movingTowardPaddle = player === 1 ? state.ballVY > 0 : state.ballVY < 0;
  if (!movingTowardPaddle) return null;

  const targetY = player === 1 ? P1_PADDLE_FACE_Y : P2_PADDLE_FACE_Y;
  const framesUntilPaddle = (targetY - state.ballY) / state.ballVY;
  if (!Number.isFinite(framesUntilPaddle) || framesUntilPaddle < 0) return null;

  return reflectBreakoutX(state.ballX + state.ballVX * framesUntilPaddle);
}

/**
 * @param {object} state
 * @param {1|2} [player]
 * @param {object} [config]
 * @returns {number}
 */
export function breakoutTargetX(state, player = 2, config = BREAKOUT_AI_DIFFICULTIES.normal) {
  const interceptX = predictBreakoutInterceptX(state, player);
  if (interceptX !== null) return interceptX;

  const ballX = Number.isFinite(state?.ballX) ? state.ballX : TABLE_CENTER_X;
  const followBias = Number.isFinite(config.followBias) ? config.followBias : 0.45;
  const targetX = ballX * followBias + TABLE_CENTER_X * (1 - followBias);
  return clamp(targetX, PADDLE_MIN_CENTER_X, PADDLE_MAX_CENTER_X);
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {number} targetX
 * @param {number} deadzonePx
 * @returns {{left: boolean, right: boolean}}
 */
export function breakoutMovementInputs(state, player, targetX, deadzonePx) {
  const paddleCenterX = paddleCenterFor(state, player);
  if (paddleCenterX === null || !Number.isFinite(targetX)) return NEUTRAL_INPUTS;

  const delta = targetX - paddleCenterX;
  const deadzone = Math.max(deadzonePx, PADDLE_SPEED / 2);
  if (Math.abs(delta) <= deadzone) return NEUTRAL_INPUTS;

  return delta < 0 ? { left: true, right: false } : { left: false, right: true };
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {BreakoutAI}
 */
export function createBreakoutAI(options = {}) {
  return new BreakoutAI(options);
}

export class BreakoutAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    this.difficulty = normalizeBreakoutAIDifficulty(options.difficulty);
    this.rng = typeof options.rng === "function" ? options.rng : Math.random;
    this.frame = 0;
    this.sampleAge = Number.POSITIVE_INFINITY;
    this.sampledTargetX = TABLE_CENTER_X;
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    this.difficulty = normalizeBreakoutAIDifficulty(difficulty);
    this.sampleAge = Number.POSITIVE_INFINITY;
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{left: boolean, right: boolean}}
   */
  nextInputs(request = {}) {
    const state = request.state;
    const player = request.player === 1 ? 1 : 2;

    if (!state || state.phase !== PHASE.PLAYING) {
      this.frame++;
      return NEUTRAL_INPUTS;
    }

    const difficulty = normalizeBreakoutAIDifficulty(request.difficulty || this.difficulty);
    if (difficulty !== this.difficulty) this.setDifficulty(difficulty);

    const config = BREAKOUT_AI_DIFFICULTIES[difficulty];
    if (this.sampleAge >= config.reactionFrames) {
      this.sampledTargetX = this._sampleTargetX(state, player, config);
      this.sampleAge = 0;
    }

    const inputs = isMovementFrame(this.frame, config)
      ? breakoutMovementInputs(state, player, this.sampledTargetX, config.deadzonePx)
      : NEUTRAL_INPUTS;

    this.frame++;
    this.sampleAge++;
    return inputs;
  }

  _sampleTargetX(state, player, config) {
    const targetX = breakoutTargetX(state, player, config);
    const error = (randomUnit(this.rng) * 2 - 1) * config.errorPx || 0;
    return clamp(targetX + error, PADDLE_MIN_CENTER_X, PADDLE_MAX_CENTER_X);
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
  const key = player === 1 ? "paddle1X" : "paddle2X";
  const paddleX = state?.[key];
  return Number.isFinite(paddleX) ? paddleX + PADDLE_W / 2 : null;
}

function isMovementFrame(frame, config) {
  if (config.movementDuty >= 1) return true;

  return (frame % 10) / 10 < config.movementDuty;
}

function randomUnit(rng) {
  const value = Number(rng());
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(value, 0.999999999));
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
