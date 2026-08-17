/**
 * Deterministic opponent controller for Hex Boxing solo sessions.
 * It emits the same held-input shape used by the P2P peer path.
 * @module games/hex_boxing_ai
 */

import { PHASE, PUNCH_STATE } from "./protocol.js";
import {
  BOXER_BODY_RADIUS,
  FIST_RADIUS,
  PUNCH_RANGE,
  RING_BOTTOM,
  RING_LEFT,
  RING_RIGHT,
  RING_TOP,
} from "./physics.js";

const DEFAULT_DIFFICULTY = "normal";
const PLAYER_HALF_SIZE = BOXER_BODY_RADIUS;
const PLAYER_MIN_X = RING_LEFT + PLAYER_HALF_SIZE;
const PLAYER_MAX_X = RING_RIGHT - PLAYER_HALF_SIZE;
const PLAYER_MIN_Y = RING_TOP + PLAYER_HALF_SIZE;
const PLAYER_MAX_Y = RING_BOTTOM - PLAYER_HALF_SIZE;

const NEUTRAL_INPUTS = Object.freeze({
  up: false,
  down: false,
  left: false,
  right: false,
  punch: false,
});

export const BOXING_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    decisionInterval: 9,
    targetErrorPx: 28,
    deadzonePx: 9,
    idealDistancePx: 38,
    retreatDistancePx: 20,
    punchDistancePx: PUNCH_RANGE + BOXER_BODY_RADIUS + FIST_RADIUS - 6,
    punchAlignmentPx: 15,
    punchChance: 0.42,
    punchCooldownFrames: 42,
    dodgeChance: 0.2,
  }),
  normal: Object.freeze({
    decisionInterval: 5,
    targetErrorPx: 14,
    deadzonePx: 6,
    idealDistancePx: 34,
    retreatDistancePx: 18,
    punchDistancePx: PUNCH_RANGE + BOXER_BODY_RADIUS + FIST_RADIUS - 3,
    punchAlignmentPx: 19,
    punchChance: 0.68,
    punchCooldownFrames: 28,
    dodgeChance: 0.38,
  }),
  hard: Object.freeze({
    decisionInterval: 2,
    targetErrorPx: 5,
    deadzonePx: 4,
    idealDistancePx: 31,
    retreatDistancePx: 16,
    punchDistancePx: PUNCH_RANGE + BOXER_BODY_RADIUS + FIST_RADIUS,
    punchAlignmentPx: 24,
    punchChance: 0.92,
    punchCooldownFrames: 17,
    dodgeChance: 0.58,
  }),
});

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeBoxingAIDifficulty(difficulty) {
  if (typeof difficulty !== "string") return DEFAULT_DIFFICULTY;

  const key = difficulty.toLowerCase();
  return Object.prototype.hasOwnProperty.call(BOXING_AI_DIFFICULTIES, key)
    ? key
    : DEFAULT_DIFFICULTY;
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {BoxingAI}
 */
export function createBoxingAI(options = {}) {
  return new BoxingAI(options);
}

export class BoxingAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    this.difficulty = normalizeBoxingAIDifficulty(options.difficulty);
    this.rng = typeof options.rng === "function" ? options.rng : Math.random;
    this.frame = 0;
    this.punchCooldown = 0;
    this._target = null;
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    this.difficulty = normalizeBoxingAIDifficulty(difficulty);
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{up: boolean, down: boolean, left: boolean, right: boolean, punch: boolean}}
   */
  nextInputs(request = {}) {
    const state = request.state;
    const player = request.player === 1 ? 1 : 2;

    this.frame++;
    if (this.punchCooldown > 0) this.punchCooldown--;

    if (!state || state.phase !== PHASE.FIGHTING) {
      this._target = null;
      return NEUTRAL_INPUTS;
    }

    const actor = boxerState(state, player);
    const opponent = boxerState(state, player === 1 ? 2 : 1);
    if (!actor || !opponent) return NEUTRAL_INPUTS;

    const difficulty = normalizeBoxingAIDifficulty(request.difficulty || this.difficulty);
    if (difficulty !== this.difficulty) this.setDifficulty(difficulty);
    const config = BOXING_AI_DIFFICULTIES[difficulty];

    if (this.frame % config.decisionInterval === 0 || !this._target) {
      const target = boxingTargetPosition(state, player, config, this.rng);
      this._target = applyTargetError(target, config.targetErrorPx, this.rng);
    }

    const movement = boxingMovementInputs(actor, this._target, config.deadzonePx);
    const punch = this.punchCooldown <= 0 && shouldThrowPunch(state, player, config, this.rng);
    if (punch) this.punchCooldown = config.punchCooldownFrames;

    return { ...movement, punch };
  }
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {{x: number, y: number, kind: "approach"|"retreat"|"dodge"}}
 */
export function boxingTargetPosition(
  state,
  player = 2,
  config = BOXING_AI_DIFFICULTIES.normal,
  rng = () => 0,
) {
  const actor = boxerState(state, player);
  const opponent = boxerState(state, player === 1 ? 2 : 1);
  if (!actor || !opponent) return { x: 320, y: 240, kind: "approach" };

  const dx = opponent.x - actor.x;
  const dy = opponent.y - actor.y;
  const distance = Math.hypot(dx, dy);
  const side = player === 1 ? -1 : 1;

  if (
    opponent.punchState === PUNCH_STATE.PUNCHING &&
    distance < config.punchDistancePx + 6 &&
    rng() <= config.dodgeChance
  ) {
    const dodgeY = actor.y <= opponent.y ? actor.y - 36 : actor.y + 36;
    return {
      x: clamp(actor.x + side * 22, PLAYER_MIN_X, PLAYER_MAX_X),
      y: clamp(dodgeY, PLAYER_MIN_Y, PLAYER_MAX_Y),
      kind: "dodge",
    };
  }

  const targetDistance =
    distance < config.retreatDistancePx ? config.retreatDistancePx + 12 : config.idealDistancePx;

  return {
    x: clamp(opponent.x + side * targetDistance, PLAYER_MIN_X, PLAYER_MAX_X),
    y: clamp(opponent.y, PLAYER_MIN_Y, PLAYER_MAX_Y),
    kind: distance < config.retreatDistancePx ? "retreat" : "approach",
  };
}

/**
 * @param {{x: number, y: number}} actor
 * @param {{x: number, y: number}} target
 * @param {number} deadzone
 * @returns {{up: boolean, down: boolean, left: boolean, right: boolean, punch: boolean}}
 */
export function boxingMovementInputs(actor, target, deadzone) {
  if (!actor || !target) return NEUTRAL_INPUTS;

  const dx = target.x - actor.x;
  const dy = target.y - actor.y;

  return {
    left: dx < -deadzone,
    right: dx > deadzone,
    up: dy < -deadzone,
    down: dy > deadzone,
    punch: false,
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @param {() => number} [rng]
 * @returns {boolean}
 */
export function shouldThrowPunch(state, player = 2, config = BOXING_AI_DIFFICULTIES.normal, rng) {
  const actor = boxerState(state, player);
  const opponent = boxerState(state, player === 1 ? 2 : 1);
  if (!actor || !opponent) return false;
  if (actor.punchState !== PUNCH_STATE.IDLE) return false;

  const dx = opponent.x - actor.x;
  const dy = opponent.y - actor.y;
  const distance = Math.hypot(dx, dy);
  if (distance > config.punchDistancePx) return false;
  if (Math.abs(dy) > config.punchAlignmentPx) return false;
  if (!directionFacesOpponent(actor.dir, dx, dy)) return false;

  const roll = typeof rng === "function" ? rng() : 0;
  return roll <= config.punchChance;
}

/**
 * @param {number} dir
 * @param {number} dx
 * @param {number} dy
 * @returns {boolean}
 */
export function directionFacesOpponent(dir, dx, dy) {
  if (Math.abs(dx) >= Math.abs(dy)) {
    return dx < 0 ? dir >= 3 && dir <= 5 : dir === 0 || dir === 1 || dir === 7;
  }

  return dy < 0 ? dir >= 5 && dir <= 7 : dir >= 1 && dir <= 3;
}

function boxerState(state, player) {
  const prefix = player === 1 ? "b1" : "b2";
  if (typeof state?.[`${prefix}x`] !== "number" || typeof state?.[`${prefix}y`] !== "number") {
    return null;
  }

  return {
    x: state[`${prefix}x`],
    y: state[`${prefix}y`],
    dir: state[`${prefix}dir`],
    punchState: state[`${prefix}punchState`],
  };
}

function applyTargetError(target, amount, rng) {
  if (!amount) return target;
  const offsetX = (rng() * 2 - 1) * amount;
  const offsetY = (rng() * 2 - 1) * amount;

  return {
    ...target,
    x: clamp(target.x + offsetX, PLAYER_MIN_X, PLAYER_MAX_X),
    y: clamp(target.y + offsetY, PLAYER_MIN_Y, PLAYER_MAX_Y),
  };
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
