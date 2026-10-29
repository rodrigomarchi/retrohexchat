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

const BALL_MIN_X = BALL_SIZE / 2;
const BALL_MAX_X = CANVAS_W - BALL_SIZE / 2;
const PADDLE_MIN_CENTER_X = PADDLE_W / 2;
const PADDLE_MAX_CENTER_X = CANVAS_W - PADDLE_W / 2;
const TABLE_CENTER_X = CANVAS_W / 2;
const P2_PADDLE_FACE_Y = PADDLE_MARGIN + PADDLE_H + BALL_SIZE / 2;
const P1_PADDLE_FACE_Y = CANVAS_H - PADDLE_MARGIN - PADDLE_H - BALL_SIZE / 2;
const NEUTRAL_INPUTS = Object.freeze({ left: false, right: false });

/**
 * How each difficulty plays, "hard" being the strongest paddle. `errorPx` is
 * the aim error drawn once for each approach of the ball: past
 * PADDLE_W / 2 + BALL_SIZE / 2 (44 px) the paddle misses it.
 */
export const BREAKOUT_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    reactionFrames: 14,
    errorPx: 90,
    deadzonePx: 18,
    movementDuty: 0.55,
    followBias: 0.25,
  }),
  normal: Object.freeze({
    reactionFrames: 7,
    errorPx: 64,
    deadzonePx: 10,
    movementDuty: 0.82,
    followBias: 0.45,
  }),
  hard: Object.freeze({
    reactionFrames: 3,
    errorPx: 54,
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
  return normalizeDifficulty(difficulty, BREAKOUT_AI_DIFFICULTIES);
}

/**
 * Reflect a projected ball center against the left and right walls.
 * @param {number} x
 * @returns {number}
 */
export function reflectBreakoutX(x) {
  return reflect(x, BALL_MIN_X, BALL_MAX_X, TABLE_CENTER_X);
}

/**
 * Predict where the ball center will reach a player's paddle face.
 * @param {object} state
 * @param {1|2} [player]
 * @returns {number|null}
 */
export function predictBreakoutInterceptX(state, player = 2) {
  if (!finiteMotion(state, "ball")) return null;

  const movingTowardPaddle = player === 1 ? state.ballVY > 0 : state.ballVY < 0;
  if (!movingTowardPaddle) return null;

  const targetY = player === 1 ? P1_PADDLE_FACE_Y : P2_PADDLE_FACE_Y;
  return interceptAt(
    state.ballY,
    state.ballVY,
    targetY,
    state.ballX,
    state.ballVX,
    BALL_MIN_X,
    BALL_MAX_X,
    TABLE_CENTER_X,
  );
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

  const deadzone = Math.max(deadzonePx, PADDLE_SPEED / 2);
  const [left, right] = toward(paddleCenterX, targetX, deadzone);
  return { left, right };
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

export class BreakoutAI extends PaddleAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    super(options, normalizeBreakoutAIDifficulty, BREAKOUT_AI_DIFFICULTIES);
    this.sampledTargetX = TABLE_CENTER_X;
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{left: boolean, right: boolean}}
   */
  nextInputs(request = {}) {
    const turn = this.playFrame(request, PHASE.PLAYING, {
      incoming: (state, player) => predictBreakoutInterceptX(state, player) !== null,
      every: "reactionFrames",
      look: (state, player, config) => this._sampleTargetX(state, player, config),
    });
    if (!turn) return NEUTRAL_INPUTS;

    const { state, player, config } = turn;
    this.sampledTargetX = turn.target;
    const inputs = dutyFrame(this.frame, config.movementDuty)
      ? breakoutMovementInputs(state, player, this.sampledTargetX, config.deadzonePx)
      : NEUTRAL_INPUTS;

    this.frame++;
    return inputs;
  }

  _sampleTargetX(state, player, config) {
    const targetX = breakoutTargetX(state, player, config);
    if (!this.aim.incoming) return targetX;

    const error = this.aimError(config.errorPx);
    return clamp(targetX + error, PADDLE_MIN_CENTER_X, PADDLE_MAX_CENTER_X);
  }
}

function paddleCenterFor(state, player) {
  const key = player === 1 ? "paddle1X" : "paddle2X";
  const paddleX = state?.[key];
  return Number.isFinite(paddleX) ? paddleX + PADDLE_W / 2 : null;
}
