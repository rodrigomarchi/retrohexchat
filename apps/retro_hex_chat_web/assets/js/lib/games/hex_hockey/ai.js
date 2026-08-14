/**
 * Deterministic opponent controller for Hex Hockey solo sessions.
 * It reads plain game state and emits the same held-input shape used by the P2P
 * peer path, so the host simulation stays shared between solo and P2P.
 * @module games/hex_hockey_ai
 */

import { PHASE } from "./protocol.js";
import {
  RINK_LEFT,
  RINK_RIGHT,
  RINK_TOP,
  RINK_BOTTOM,
  RINK_CX,
  RINK_CY,
  GOAL_TOP,
  GOAL_BOTTOM,
  GOAL_LINE_LEFT,
  GOAL_LINE_RIGHT,
} from "./physics.js";

const DEFAULT_DIFFICULTY = "normal";
const PLAYER_HALF_SIZE = 4;
const PLAYER_MIN_X = RINK_LEFT + PLAYER_HALF_SIZE;
const PLAYER_MAX_X = RINK_RIGHT - PLAYER_HALF_SIZE;
const PLAYER_MIN_Y = RINK_TOP + PLAYER_HALF_SIZE;
const PLAYER_MAX_Y = RINK_BOTTOM - PLAYER_HALF_SIZE;
const GOAL_LANE_MARGIN = 12;
const ATTACK_SHOOT_DISTANCE = 190;
const TACKLE_COOLDOWN_MIN = 10;

const NEUTRAL_INPUTS = Object.freeze({
  left: false,
  right: false,
  up: false,
  down: false,
  action: false,
});

export const HOCKEY_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    decisionInterval: 8,
    targetErrorPx: 34,
    deadzonePx: 10,
    shootCooldownFrames: 54,
    shootChance: 0.45,
    tackleRangePx: 16,
    tackleChance: 0.38,
    defensiveBias: 0.42,
  }),
  normal: Object.freeze({
    decisionInterval: 4,
    targetErrorPx: 18,
    deadzonePx: 7,
    shootCooldownFrames: 32,
    shootChance: 0.72,
    tackleRangePx: 22,
    tackleChance: 0.65,
    defensiveBias: 0.58,
  }),
  hard: Object.freeze({
    decisionInterval: 1,
    targetErrorPx: 6,
    deadzonePx: 4,
    shootCooldownFrames: 18,
    shootChance: 1,
    tackleRangePx: 28,
    tackleChance: 0.9,
    defensiveBias: 0.74,
  }),
});

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeHockeyAIDifficulty(difficulty) {
  if (typeof difficulty !== "string") return DEFAULT_DIFFICULTY;

  const key = difficulty.toLowerCase();
  return Object.prototype.hasOwnProperty.call(HOCKEY_AI_DIFFICULTIES, key)
    ? key
    : DEFAULT_DIFFICULTY;
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {HockeyAI}
 */
export function createHockeyAI(options = {}) {
  return new HockeyAI(options);
}

export class HockeyAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    this.difficulty = normalizeHockeyAIDifficulty(options.difficulty);
    this.rng = typeof options.rng === "function" ? options.rng : Math.random;
    this.frame = 0;
    this.actionCooldown = 0;
    this._target = null;
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    this.difficulty = normalizeHockeyAIDifficulty(difficulty);
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{left: boolean, right: boolean, up: boolean, down: boolean, action: boolean}}
   */
  nextInputs(request = {}) {
    const state = request.state;
    const player = request.player === 1 ? 1 : 2;

    this.frame++;
    if (this.actionCooldown > 0) this.actionCooldown--;

    if (!state || (state.phase !== PHASE.PLAYING && state.phase !== PHASE.SUDDEN_DEATH)) {
      this._target = null;
      return NEUTRAL_INPUTS;
    }

    const actor = player === 1 ? state.p1 : state.p2;
    if (!actor || actor.stunTimer > 0) return NEUTRAL_INPUTS;

    const difficulty = normalizeHockeyAIDifficulty(request.difficulty || this.difficulty);
    if (difficulty !== this.difficulty) this.setDifficulty(difficulty);
    const config = HOCKEY_AI_DIFFICULTIES[difficulty];

    if (this.frame % config.decisionInterval === 0 || !this._target) {
      const target = chooseHockeyTarget(state, player, config);
      this._target = applyTargetError(target, config.targetErrorPx, this.rng);
    }

    const movement = movementInputs(state, player, this._target, config.deadzonePx);
    const action = this._actionPressed(state, player, config);
    return { ...movement, action };
  }

  /**
   * @param {object} state
   * @param {1|2} player
   * @param {object} config
   * @returns {boolean}
   */
  _actionPressed(state, player, config) {
    if (this.actionCooldown > 0) return false;

    if (playerHasPuck(state, player)) {
      if (!shouldShoot(state, player)) return false;
      if (this.rng() > config.shootChance) return false;

      this.actionCooldown = config.shootCooldownFrames;
      return true;
    }

    const opponent = player === 1 ? state.p2 : state.p1;
    if (!opponent?.hasPuck) return false;
    if (distance(playerState(state, player), opponent) > config.tackleRangePx) return false;
    if (this.rng() > config.tackleChance) return false;

    this.actionCooldown = Math.max(TACKLE_COOLDOWN_MIN, Math.floor(config.shootCooldownFrames / 2));
    return true;
  }
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {{x: number, y: number, kind: "attack"|"chase"|"defend"|"tackle"}}
 */
export function chooseHockeyTarget(state, player = 2, config = HOCKEY_AI_DIFFICULTIES.normal) {
  const actor = playerState(state, player);
  const opponent = playerState(state, player === 1 ? 2 : 1);

  if (actor?.hasPuck) {
    return { ...attackingGoalCenter(state, player), kind: "attack" };
  }

  if (opponent?.hasPuck) {
    return { x: opponent.x, y: opponent.y, kind: "tackle" };
  }

  if (puckThreatensOwnGoal(state, player)) {
    return defensiveHomePosition(state, player, config.defensiveBias);
  }

  return {
    x: clamp(state.puck.x, PLAYER_MIN_X, PLAYER_MAX_X),
    y: clamp(state.puck.y, PLAYER_MIN_Y, PLAYER_MAX_Y),
    kind: "chase",
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {{x: number, y: number}}
 */
export function attackingGoalCenter(state, player = 2) {
  const attackingRight = player === 1 ? state.sidesSwapped === false : state.sidesSwapped === true;

  return {
    x: attackingRight ? GOAL_LINE_RIGHT + GOAL_LANE_MARGIN : GOAL_LINE_LEFT - GOAL_LANE_MARGIN,
    y: RINK_CY,
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {number} [bias]
 * @returns {{x: number, y: number, kind: "defend"}}
 */
export function defensiveHomePosition(state, player = 2, bias = 0.58) {
  const defendsRight = player === 1 ? state.sidesSwapped === true : state.sidesSwapped === false;
  const homeX = defendsRight ? RINK_RIGHT - 85 : RINK_LEFT + 85;
  const puckY = state?.puck?.y ?? RINK_CY;

  return {
    x: homeX,
    y: clamp(puckY * bias + RINK_CY * (1 - bias), GOAL_TOP, GOAL_BOTTOM),
    kind: "defend",
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {{x: number, y: number}} target
 * @param {number} deadzone
 * @returns {{left: boolean, right: boolean, up: boolean, down: boolean, action: boolean}}
 */
export function movementInputs(state, player, target, deadzone) {
  const actor = playerState(state, player);
  if (!actor || !target) return NEUTRAL_INPUTS;

  const dx = target.x - actor.x;
  const dy = target.y - actor.y;

  return {
    left: dx < -deadzone,
    right: dx > deadzone,
    up: dy < -deadzone,
    down: dy > deadzone,
    action: false,
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {boolean}
 */
export function shouldShoot(state, player = 2) {
  const actor = playerState(state, player);
  if (!actor?.hasPuck) return false;

  const goal = attackingGoalCenter(state, player);
  const attackingRight = goal.x > RINK_CX;
  const facingGoal = attackingRight
    ? actor.facing === 0 || actor.facing === 1 || actor.facing === 7
    : actor.facing === 3 || actor.facing === 4 || actor.facing === 5;
  if (!facingGoal) return false;

  const inLane = actor.y >= GOAL_TOP - 18 && actor.y <= GOAL_BOTTOM + 18;
  const closeEnough = Math.abs(goal.x - actor.x) <= ATTACK_SHOOT_DISTANCE;
  return inLane || closeEnough;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {boolean}
 */
function playerHasPuck(state, player) {
  return playerState(state, player)?.hasPuck === true;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {object|null}
 */
function playerState(state, player) {
  return player === 1 ? state?.p1 || null : state?.p2 || null;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {boolean}
 */
function puckThreatensOwnGoal(state, player) {
  const puck = state?.puck;
  if (!puck || puck.possessedBy !== 0) return false;

  const defendsRight = player === 1 ? state.sidesSwapped === true : state.sidesSwapped === false;
  const movingTowardGoal = defendsRight ? puck.vx > 0 : puck.vx < 0;
  const onDefensiveHalf = defendsRight ? puck.x > RINK_CX : puck.x < RINK_CX;
  return movingTowardGoal && onDefensiveHalf;
}

/**
 * @param {{x: number, y: number, kind: string}} target
 * @param {number} amount
 * @param {() => number} rng
 * @returns {{x: number, y: number, kind: string}}
 */
function applyTargetError(target, amount, rng) {
  if (!target || amount <= 0) return target;

  return {
    ...target,
    x: clamp(target.x + errorOffset(amount, rng), PLAYER_MIN_X, PLAYER_MAX_X),
    y: clamp(target.y + errorOffset(amount, rng), PLAYER_MIN_Y, PLAYER_MAX_Y),
  };
}

/**
 * @param {object} a
 * @param {object} b
 * @returns {number}
 */
function distance(a, b) {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return Math.sqrt(dx * dx + dy * dy);
}

/**
 * @param {number} amount
 * @param {() => number} rng
 * @returns {number}
 */
function errorOffset(amount, rng) {
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
