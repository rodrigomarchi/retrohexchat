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
  SHIELD_W,
} from "./physics.js";
import {
  clamp,
  createApproachAim,
  dutyFrame,
  finiteMotion,
  interceptAt,
  normalizeDifficulty,
  randomUnit,
  reflect,
  toward,
} from "../core/ai.js";
import { PaddleAI } from "../core/paddle_ai.js";

const FIREBALL_MIN_Y = FIREBALL_SIZE / 2;
const FIREBALL_MAX_Y = CANVAS_H - FIREBALL_SIZE / 2;
const SHIELD_MIN_CENTER_Y = SHIELD_H / 2;
const SHIELD_MAX_CENTER_Y = CANVAS_H - SHIELD_H / 2;
const TABLE_CENTER_Y = CANVAS_H / 2;
const NEUTRAL_INPUTS = Object.freeze({ up: false, down: false, space: false });

/**
 * How each difficulty plays. `errorPx` is the aim error drawn once for each
 * approach of the fireball: past SHIELD_H / 2 + FIREBALL_SIZE / 2 (34 px) the
 * shield misses it.
 */
export const WARLORD_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    decisionFrames: 14,
    errorPx: 64,
    deadzonePx: 18,
    movementDuty: 0.55,
    defensiveBias: 0.35,
    catchFrames: 28,
    catchChance: 0.45,
    releaseFrames: 42,
  }),
  normal: Object.freeze({
    decisionFrames: 7,
    errorPx: 48,
    deadzonePx: 11,
    movementDuty: 0.82,
    defensiveBias: 0.55,
    catchFrames: 42,
    catchChance: 0.72,
    releaseFrames: 24,
  }),
  hard: Object.freeze({
    decisionFrames: 3,
    errorPx: 42,
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
  if (!finiteMotion(state, "fireball") || state.caughtBy !== 0) return null;

  const movingTowardShield = player === 1 ? state.fireballVX < 0 : state.fireballVX > 0;
  if (!movingTowardShield) return null;

  return interceptAt(
    state.fireballX,
    state.fireballVX,
    shieldFaceX(player),
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
 * Whether to hold Space for a catch: the fireball is about to reach the
 * shield, near enough its middle, and `decide` — drawn once per approach
 * by the AI — says to.
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @param {() => boolean} decide
 * @returns {boolean}
 */
export function shouldHoldCatch(state, player, config, decide) {
  const interceptY = predictWarlordInterceptY(state, player);
  const shieldCenterY = shieldCenterFor(state, player);
  if (interceptY === null || shieldCenterY === null) return false;

  const frames = framesUntilShield(state, player);
  if (frames === null || frames > config.catchFrames) return false;
  if (Math.abs(interceptY - shieldCenterY) > SHIELD_H * 0.65) return false;

  return decide();
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

export class WarlordAI extends PaddleAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    super(options, normalizeWarlordAIDifficulty, WARLORD_AI_DIFFICULTIES);
    this.sampledTargetY = TABLE_CENTER_Y;
    this.caughtFrames = 0;
    this.catchPlan = createApproachAim();
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    super.setDifficulty(difficulty);
    this.caughtFrames = 0;
  }

  /**
   * A new round: also no catch held, and the next approach decides afresh.
   * @returns {void}
   */
  forget() {
    super.forget();
    this.caughtFrames = 0;
    this.catchPlan.reset();
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{up: boolean, down: boolean, space: boolean}}
   */
  nextInputs(request = {}) {
    const turn = this.playFrame(request, PHASE.PLAYING, {
      incoming: (state, player) => predictWarlordInterceptY(state, player) !== null,
      every: "decisionFrames",
      look: (state, player, config) => this._sampleTargetY(state, player, config),
    });
    if (!turn) {
      this.caughtFrames = 0;
      return NEUTRAL_INPUTS;
    }

    const { state, player, config } = turn;
    this.sampledTargetY = turn.target;

    const movement = dutyFrame(this.frame, config.movementDuty)
      ? warlordMovementInputs(state, player, this.sampledTargetY, config.deadzonePx)
      : { up: false, down: false };
    const space = this._spaceHeld(state, player, config);

    this.frame++;
    return { ...movement, space };
  }

  _sampleTargetY(state, player, config) {
    const targetY = warlordTargetY(state, player, config);
    if (!this.aim.incoming) return targetY;

    const error = this.aimError(config.errorPx);
    return clamp(targetY + error, SHIELD_MIN_CENTER_Y, SHIELD_MAX_CENTER_Y);
  }

  _spaceHeld(state, player, config) {
    if (state.caughtBy === player) {
      this.caughtFrames++;
      return this.caughtFrames < config.releaseFrames;
    }

    this.caughtFrames = 0;
    this.catchPlan.track(predictWarlordInterceptY(state, player) !== null);
    if (state.caughtBy !== 0) return false;

    return shouldHoldCatch(state, player, config, () =>
      this.catchPlan.hold(() => randomUnit(this.rng) <= config.catchChance),
    );
  }
}

/**
 * Where the fireball's centre is when it touches a shield's face: the right
 * edge of shield one, the left edge of shield two.
 * @param {1|2} player
 * @returns {number}
 */
function shieldFaceX(player) {
  return player === 1
    ? P1_SHIELD_X + SHIELD_W + FIREBALL_SIZE / 2
    : P2_SHIELD_X - FIREBALL_SIZE / 2;
}

function shieldCenterFor(state, player) {
  const key = player === 1 ? "shield1Y" : "shield2Y";
  const shieldY = state?.[key];
  return Number.isFinite(shieldY) ? shieldY + SHIELD_H / 2 : null;
}

function framesUntilShield(state, player) {
  if (!finiteMotion(state, "fireball")) return null;
  const frames = (shieldFaceX(player) - state.fireballX) / state.fireballVX;
  return Number.isFinite(frames) && frames >= 0 ? frames : null;
}
