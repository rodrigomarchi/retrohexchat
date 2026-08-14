/**
 * Deterministic opponent controller for Hex Tennis solo sessions.
 * The controller consumes plain game state and emits the same held-input shape
 * used by the P2P peer path.
 * @module games/hex_tennis_ai
 */

import { PHASE } from "./protocol.js";
import {
  COURT_LEFT,
  COURT_RIGHT,
  COURT_TOP,
  COURT_BOTTOM,
  COURT_CENTER_X,
  NET_Y,
  NET_HALF_H,
  SERVICE_LINE_TOP,
  HIT_ZONE_H,
} from "./physics.js";

const DEFAULT_DIFFICULTY = "normal";
const PLAYER_HALF_SIZE = 12;
const PLAYER_MIN_X = COURT_LEFT + PLAYER_HALF_SIZE;
const PLAYER_MAX_X = COURT_RIGHT - PLAYER_HALF_SIZE;
const P2_MIN_Y = COURT_TOP + PLAYER_HALF_SIZE;
const P2_MAX_Y = NET_Y - NET_HALF_H - 10;
const P1_MIN_Y = NET_Y + NET_HALF_H + 10;
const P1_MAX_Y = COURT_BOTTOM - PLAYER_HALF_SIZE;

const NEUTRAL_INPUTS = Object.freeze({
  up: false,
  down: false,
  left: false,
  right: false,
  serve: false,
});

export const TENNIS_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    reactionFrames: 18,
    decisionInterval: 5,
    targetErrorPx: 34,
    deadzonePx: 15,
    serveDelayFrames: 62,
    serveChance: 0.55,
    recoverBias: 0.36,
  }),
  normal: Object.freeze({
    reactionFrames: 10,
    decisionInterval: 3,
    targetErrorPx: 18,
    deadzonePx: 10,
    serveDelayFrames: 34,
    serveChance: 0.82,
    recoverBias: 0.48,
  }),
  hard: Object.freeze({
    reactionFrames: 4,
    decisionInterval: 1,
    targetErrorPx: 6,
    deadzonePx: 6,
    serveDelayFrames: 12,
    serveChance: 1,
    recoverBias: 0.62,
  }),
});

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeTennisAIDifficulty(difficulty) {
  if (typeof difficulty !== "string") return DEFAULT_DIFFICULTY;

  const key = difficulty.toLowerCase();
  return Object.prototype.hasOwnProperty.call(TENNIS_AI_DIFFICULTIES, key)
    ? key
    : DEFAULT_DIFFICULTY;
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {TennisAI}
 */
export function createTennisAI(options = {}) {
  return new TennisAI(options);
}

export class TennisAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    this.difficulty = normalizeTennisAIDifficulty(options.difficulty);
    this.rng = typeof options.rng === "function" ? options.rng : Math.random;
    this.frame = 0;
    this.serveDelay = 0;
    this._lastServeKey = null;
    this._target = null;
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    this.difficulty = normalizeTennisAIDifficulty(difficulty);
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{up: boolean, down: boolean, left: boolean, right: boolean, serve: boolean}}
   */
  nextInputs(request = {}) {
    const state = request.state;
    const player = request.player === 1 ? 1 : 2;

    this.frame++;

    if (!state || (state.phase !== PHASE.SERVING && state.phase !== PHASE.RALLY)) {
      this._target = null;
      return NEUTRAL_INPUTS;
    }

    const difficulty = normalizeTennisAIDifficulty(request.difficulty || this.difficulty);
    if (difficulty !== this.difficulty) this.setDifficulty(difficulty);
    const config = TENNIS_AI_DIFFICULTIES[difficulty];

    if (state.phase === PHASE.SERVING) {
      return this._servingInputs(state, player, config);
    }

    const target = this._rallyTarget(state, player, config);
    return movementInputs(state, player, target, config.deadzonePx);
  }

  /**
   * @param {object} state
   * @param {1|2} player
   * @param {object} config
   * @returns {{up: boolean, down: boolean, left: boolean, right: boolean, serve: boolean}}
   */
  _servingInputs(state, player, config) {
    const target = servingReadyPosition(state, player);
    const movement = movementInputs(state, player, target, config.deadzonePx);

    if (state.server !== player) {
      this._lastServeKey = null;
      this.serveDelay = 0;
      return movement;
    }

    const serveKey = `${state.server}:${state.p1Games}:${state.p2Games}:${state.p1Points}:${state.p2Points}:${state.totalPointsInGame}`;
    if (serveKey !== this._lastServeKey) {
      this._lastServeKey = serveKey;
      this.serveDelay = config.serveDelayFrames;
    }

    if (this.serveDelay > 0) {
      this.serveDelay--;
      return movement;
    }

    if (this.rng() <= config.serveChance) {
      this.serveDelay = config.serveDelayFrames;
      return { ...movement, serve: true };
    }

    this.serveDelay = Math.max(6, Math.floor(config.serveDelayFrames / 3));
    return movement;
  }

  /**
   * @param {object} state
   * @param {1|2} player
   * @param {object} config
   * @returns {{x: number, y: number}}
   */
  _rallyTarget(state, player, config) {
    if (this.frame % config.decisionInterval === 0 || !this._target) {
      const incoming = isBallIncoming(state, player);
      const predicted = incoming
        ? predictTennisIntercept(state, player, config.reactionFrames)
        : null;
      const recovery = recoveryPosition(state, player, config.recoverBias);

      const x = predicted
        ? predicted.x + errorOffset(config.targetErrorPx, this.rng)
        : recovery.x + errorOffset(config.targetErrorPx * 0.35, this.rng);

      const y = predicted ? clamp(predicted.y, playerMinY(player), playerMaxY(player)) : recovery.y;

      this._target = {
        x: clamp(x, PLAYER_MIN_X, PLAYER_MAX_X),
        y,
      };
    }

    return this._target;
  }
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {number} [reactionFrames]
 * @returns {{x: number, y: number, frames: number}|null}
 */
export function predictTennisIntercept(state, player = 2, reactionFrames = 0) {
  const ball = state?.ball;
  if (!ball || !Number.isFinite(ball.vx) || !Number.isFinite(ball.vy)) return null;
  if (!isBallIncoming(state, player)) return null;

  const playerY = player === 1 ? state.p1y : state.p2y;
  const targetY = playerY + (player === 1 ? -HIT_ZONE_H * 0.25 : HIT_ZONE_H * 0.25);
  const frames = (targetY - ball.y) / ball.vy;
  if (!Number.isFinite(frames) || frames < 0) return null;

  const adjustedFrames = Math.max(0, frames - reactionFrames);
  return {
    x: clamp(ball.x + ball.vx * adjustedFrames, PLAYER_MIN_X, PLAYER_MAX_X),
    y: clamp(ball.y + ball.vy * adjustedFrames, playerMinY(player), playerMaxY(player)),
    frames: adjustedFrames,
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {number} [bias]
 * @returns {{x: number, y: number}}
 */
export function recoveryPosition(state, player = 2, bias = 0.5) {
  const x = clamp(
    (state?.ball?.x ?? COURT_CENTER_X) * bias + COURT_CENTER_X * (1 - bias),
    PLAYER_MIN_X,
    PLAYER_MAX_X,
  );
  const y = player === 1 ? P1_MIN_Y + 92 : P2_MAX_Y - 76;
  return { x, y };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {{x: number, y: number}}
 */
export function servingReadyPosition(state, player = 2) {
  const isDeuceCourt = (state?.totalPointsInGame ?? 0) % 2 === 0;
  const x = isDeuceCourt ? COURT_CENTER_X + 74 : COURT_CENTER_X - 74;
  const y = player === 1 ? SERVICE_LINE_TOP + 170 : SERVICE_LINE_TOP - 58;
  return {
    x: clamp(x, PLAYER_MIN_X, PLAYER_MAX_X),
    y: clamp(y, playerMinY(player), playerMaxY(player)),
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {boolean}
 */
function isBallIncoming(state, player) {
  const vy = state?.ball?.vy ?? 0;
  return player === 1 ? vy > 0 : vy < 0;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {{x: number, y: number}} target
 * @param {number} deadzone
 * @returns {{up: boolean, down: boolean, left: boolean, right: boolean, serve: boolean}}
 */
function movementInputs(state, player, target, deadzone) {
  const px = player === 1 ? state.p1x : state.p2x;
  const py = player === 1 ? state.p1y : state.p2y;
  const dx = target.x - px;
  const dy = target.y - py;

  return {
    up: dy < -deadzone,
    down: dy > deadzone,
    left: dx < -deadzone,
    right: dx > deadzone,
    serve: false,
  };
}

/**
 * @param {1|2} player
 * @returns {number}
 */
function playerMinY(player) {
  return player === 1 ? P1_MIN_Y : P2_MIN_Y;
}

/**
 * @param {1|2} player
 * @returns {number}
 */
function playerMaxY(player) {
  return player === 1 ? P1_MAX_Y : P2_MAX_Y;
}

/**
 * @param {number} amount
 * @param {() => number} rng
 * @returns {number}
 */
function errorOffset(amount, rng) {
  if (amount <= 0) return 0;
  return (rng() * 2 - 1) * amount;
}

/**
 * @param {number} value
 * @param {number} min
 * @param {number} max
 * @returns {number}
 */
function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
