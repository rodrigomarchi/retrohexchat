/**
 * Deterministic opponent controller for Hex Warlords solo sessions.
 * It controls the right-side shield by emitting the same held-input shape used
 * by the P2P peer path, including the hold/release space mechanic.
 * @module games/warlords_ai
 */

import { PHASE } from "./protocol.js";
import {
  CANVAS_H,
  FIREBALL_SIZE,
  P1_KING_Y,
  P1_SHIELD_X,
  P2_KING_Y,
  P2_SHIELD_X,
  SHIELD_H,
  SHIELD_SPEED,
} from "./physics.js";
import {
  aiRng,
  clamp,
  createReaction,
  dutyFrame,
  interceptAt,
  normalizeDifficulty,
  randomUnit,
  reflect,
  toward,
} from "../core/ai.js";

const FIREBALL_MIN_Y = FIREBALL_SIZE / 2;
const FIREBALL_MAX_Y = CANVAS_H - FIREBALL_SIZE / 2;
const SHIELD_MIN_CENTER_Y = SHIELD_H / 2;
const SHIELD_MAX_CENTER_Y = CANVAS_H - SHIELD_H / 2;
const TABLE_CENTER_Y = CANVAS_H / 2;
const NEUTRAL_INPUTS = Object.freeze({ up: false, down: false, space: false });

export const WARLORD_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    decisionFrames: 14,
    errorPx: 48,
    deadzonePx: 18,
    movementDuty: 0.55,
    defensiveBias: 0.35,
    catchFrames: 28,
    catchChance: 0.45,
    releaseFrames: 42,
  }),
  normal: Object.freeze({
    decisionFrames: 7,
    errorPx: 24,
    deadzonePx: 11,
    movementDuty: 0.82,
    defensiveBias: 0.55,
    catchFrames: 42,
    catchChance: 0.72,
    releaseFrames: 24,
  }),
  hard: Object.freeze({
    decisionFrames: 3,
    errorPx: 8,
    deadzonePx: 7,
    movementDuty: 1,
    defensiveBias: 0.75,
    catchFrames: 60,
    catchChance: 0.92,
    releaseFrames: 14,
  }),
});

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeWarlordAIDifficulty(difficulty) {
  return normalizeDifficulty(difficulty, WARLORD_AI_DIFFICULTIES);
}

/**
 * Reflect a projected fireball center against the top and bottom walls.
 * @param {number} y
 * @returns {number}
 */
export function reflectWarlordY(y) {
  return reflect(y, FIREBALL_MIN_Y, FIREBALL_MAX_Y, TABLE_CENTER_Y);
}

/**
 * Predict where the fireball center will reach a player's shield face.
 * @param {object} state
 * @param {1|2} [player]
 * @returns {number|null}
 */
export function predictWarlordInterceptY(state, player = 2) {
  if (!isPredictableState(state) || state.caughtBy !== 0) return null;

  const movingTowardShield = player === 1 ? state.fireballVX < 0 : state.fireballVX > 0;
  if (!movingTowardShield) return null;

  const targetX = player === 1 ? P1_SHIELD_X + FIREBALL_SIZE / 2 : P2_SHIELD_X - FIREBALL_SIZE / 2;
  return interceptAt(
    state.fireballX,
    state.fireballVX,
    targetX,
    state.fireballY,
    state.fireballVY,
    FIREBALL_MIN_Y,
    FIREBALL_MAX_Y,
    TABLE_CENTER_Y,
  );
}

/**
 * @param {object} state
 * @param {1|2} [player]
 * @param {object} [config]
 * @returns {number}
 */
export function warlordTargetY(state, player = 2, config = WARLORD_AI_DIFFICULTIES.normal) {
  if (state?.caughtBy === player) {
    return clamp(player === 1 ? P2_KING_Y : P1_KING_Y, SHIELD_MIN_CENTER_Y, SHIELD_MAX_CENTER_Y);
  }

  const interceptY = predictWarlordInterceptY(state, player);
  if (interceptY !== null) return interceptY;

  const fireballY = Number.isFinite(state?.fireballY) ? state.fireballY : TABLE_CENTER_Y;
  const defensiveBias = Number.isFinite(config.defensiveBias) ? config.defensiveBias : 0.55;
  const targetY = fireballY * defensiveBias + TABLE_CENTER_Y * (1 - defensiveBias);
  return clamp(targetY, SHIELD_MIN_CENTER_Y, SHIELD_MAX_CENTER_Y);
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {number} targetY
 * @param {number} deadzonePx
 * @returns {{up: boolean, down: boolean}}
 */
export function warlordMovementInputs(state, player, targetY, deadzonePx) {
  const shieldCenterY = shieldCenterFor(state, player);
  if (shieldCenterY === null || !Number.isFinite(targetY)) {
    return { up: false, down: false };
  }

  const deadzone = Math.max(deadzonePx, SHIELD_SPEED / 2);
  const [up, down] = toward(shieldCenterY, targetY, deadzone);
  return { up, down };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @param {() => number} rng
 * @returns {boolean}
 */
export function shouldHoldCatch(state, player, config, rng = Math.random) {
  const interceptY = predictWarlordInterceptY(state, player);
  const shieldCenterY = shieldCenterFor(state, player);
  if (interceptY === null || shieldCenterY === null) return false;

  const frames = framesUntilShield(state, player);
  if (frames === null || frames > config.catchFrames) return false;
  if (Math.abs(interceptY - shieldCenterY) > SHIELD_H * 0.65) return false;

  return randomUnit(rng) <= config.catchChance;
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {WarlordAI}
 */
export function createWarlordAI(options = {}) {
  return new WarlordAI(options);
}

export class WarlordAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    this.difficulty = normalizeWarlordAIDifficulty(options.difficulty);
    this.rng = aiRng(options);
    this.frame = 0;
    this.reaction = createReaction();
    this.sampledTargetY = TABLE_CENTER_Y;
    this.caughtFrames = 0;
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    this.difficulty = normalizeWarlordAIDifficulty(difficulty);
    this.reaction.reset();
    this.caughtFrames = 0;
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{up: boolean, down: boolean, space: boolean}}
   */
  nextInputs(request = {}) {
    const state = request.state;
    const player = request.player === 1 ? 1 : 2;

    if (!state || state.phase !== PHASE.PLAYING) {
      this.frame++;
      this.caughtFrames = 0;
      return NEUTRAL_INPUTS;
    }

    const difficulty = normalizeWarlordAIDifficulty(request.difficulty || this.difficulty);
    if (difficulty !== this.difficulty) this.setDifficulty(difficulty);

    const config = WARLORD_AI_DIFFICULTIES[difficulty];
    this.sampledTargetY = this.reaction.sample(config.decisionFrames, () =>
      this._sampleTargetY(state, player, config),
    );

    const movement = dutyFrame(this.frame, config.movementDuty)
      ? warlordMovementInputs(state, player, this.sampledTargetY, config.deadzonePx)
      : { up: false, down: false };
    const space = this._spaceHeld(state, player, config);

    this.frame++;
    return { ...movement, space };
  }

  _sampleTargetY(state, player, config) {
    const targetY = warlordTargetY(state, player, config);
    const error = (randomUnit(this.rng) * 2 - 1) * config.errorPx || 0;
    return clamp(targetY + error, SHIELD_MIN_CENTER_Y, SHIELD_MAX_CENTER_Y);
  }

  _spaceHeld(state, player, config) {
    if (state.caughtBy === player) {
      this.caughtFrames++;
      return this.caughtFrames < config.releaseFrames;
    }

    this.caughtFrames = 0;
    if (state.caughtBy !== 0) return false;

    return shouldHoldCatch(state, player, config, this.rng);
  }
}

function isPredictableState(state) {
  return (
    state &&
    Number.isFinite(state.fireballX) &&
    Number.isFinite(state.fireballY) &&
    Number.isFinite(state.fireballVX) &&
    Number.isFinite(state.fireballVY)
  );
}

function shieldCenterFor(state, player) {
  const key = player === 1 ? "shield1Y" : "shield2Y";
  const shieldY = state?.[key];
  return Number.isFinite(shieldY) ? shieldY + SHIELD_H / 2 : null;
}

function framesUntilShield(state, player) {
  if (!isPredictableState(state)) return null;
  const targetX = player === 1 ? P1_SHIELD_X + FIREBALL_SIZE / 2 : P2_SHIELD_X - FIREBALL_SIZE / 2;
  const frames = (targetX - state.fireballX) / state.fireballVX;
  return Number.isFinite(frames) && frames >= 0 ? frames : null;
}
