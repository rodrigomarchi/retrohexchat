/**
 * Deterministic opponent controller for Hex Invaders solo sessions.
 * The controller consumes plain game state and emits the same held-input shape
 * used by the P2P peer path.
 * @module games/hex_invaders_ai
 */

import { ALIEN_TYPE, GAME_MODE, PHASE } from "./protocol.js";
import {
  ALIEN_H,
  ALIEN_W,
  CANVAS_W,
  CANNON_W,
  CANNON_Y_OFFSET,
  DIVIDER_X,
  HALF_W,
} from "./physics.js";

const DEFAULT_DIFFICULTY = "normal";
const UFO_W = 24;
const NEUTRAL_INPUTS = Object.freeze({
  left: false,
  right: false,
  fire: false,
});

export const INVADERS_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    decisionInterval: 8,
    aimTolerancePx: 10,
    targetErrorPx: 22,
    targetDeadzonePx: 8,
    fireCooldownFrames: 34,
    fireChance: 0.45,
    bombDangerY: 330,
    bombDangerX: 26,
    dodgeDistancePx: 42,
    ufoPriority: false,
  }),
  normal: Object.freeze({
    decisionInterval: 4,
    aimTolerancePx: 8,
    targetErrorPx: 12,
    targetDeadzonePx: 6,
    fireCooldownFrames: 22,
    fireChance: 0.72,
    bombDangerY: 300,
    bombDangerX: 34,
    dodgeDistancePx: 52,
    ufoPriority: true,
  }),
  hard: Object.freeze({
    decisionInterval: 1,
    aimTolerancePx: 6,
    targetErrorPx: 4,
    targetDeadzonePx: 4,
    fireCooldownFrames: 12,
    fireChance: 1,
    bombDangerY: 260,
    bombDangerX: 42,
    dodgeDistancePx: 64,
    ufoPriority: true,
  }),
});

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeInvadersAIDifficulty(difficulty) {
  if (typeof difficulty !== "string") return DEFAULT_DIFFICULTY;

  const key = difficulty.toLowerCase();
  return Object.prototype.hasOwnProperty.call(INVADERS_AI_DIFFICULTIES, key)
    ? key
    : DEFAULT_DIFFICULTY;
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {HexInvadersAI}
 */
export function createHexInvadersAI(options = {}) {
  return new HexInvadersAI(options);
}

export class HexInvadersAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    this.difficulty = normalizeInvadersAIDifficulty(options.difficulty);
    this.rng = typeof options.rng === "function" ? options.rng : Math.random;
    this.frame = 0;
    this.fireCooldown = 0;
    this._target = null;
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    this.difficulty = normalizeInvadersAIDifficulty(difficulty);
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{left: boolean, right: boolean, fire: boolean}}
   */
  nextInputs(request = {}) {
    const state = request.state;
    const player = request.player === 1 ? 1 : 2;

    this.frame++;
    if (this.fireCooldown > 0) this.fireCooldown--;

    if (!state || state.phase !== PHASE.PLAYING) {
      this._target = null;
      return NEUTRAL_INPUTS;
    }

    const difficulty = normalizeInvadersAIDifficulty(request.difficulty || this.difficulty);
    if (difficulty !== this.difficulty) this.setDifficulty(difficulty);
    const config = INVADERS_AI_DIFFICULTIES[difficulty];

    const threat = incomingBombThreat(state, player, config);
    if (threat) {
      const target = dodgeTarget(state, player, threat, config);
      return {
        ...movementInputs(state, player, target.x, config.targetDeadzonePx),
        fire: false,
      };
    }

    if (
      this.frame % config.decisionInterval === 0 ||
      !isTargetStillValid(state, player, this._target)
    ) {
      this._target = chooseInvaderTarget(state, player, config, this.rng);
    }

    if (!this._target) return NEUTRAL_INPUTS;

    const movement = movementInputs(state, player, this._target.x, config.targetDeadzonePx);
    const fire = shouldFire(state, player, this._target, config, this.fireCooldown, this.rng);
    if (fire) this.fireCooldown = config.fireCooldownFrames;

    return {
      ...movement,
      fire,
    };
  }
}

/**
 * @param {object} state
 * @param {1|2} [player]
 * @param {object} [config]
 * @param {() => number} [rng]
 * @returns {{kind: "alien"|"ufo", x: number, y: number, index?: number}|null}
 */
export function chooseInvaderTarget(
  state,
  player = 2,
  config = INVADERS_AI_DIFFICULTIES.normal,
  rng = Math.random,
) {
  if (!state) return null;

  const bounds = cannonBounds(state, player);
  const ufoX = (state.ufoX || 0) + UFO_W / 2;
  if (
    config.ufoPriority &&
    state.ufoActive &&
    ufoX >= bounds.min - CANNON_W &&
    ufoX <= bounds.max + CANNON_W
  ) {
    return {
      kind: "ufo",
      x: clamp(ufoX + errorOffset(config.targetErrorPx, rng), bounds.min, bounds.max),
      y: 18,
    };
  }

  const aliens = aliensForPlayer(state, player);
  const actorX = cannonX(state, player);
  let best = null;
  let bestScore = -Infinity;

  for (let index = 0; index < aliens.length; index++) {
    const alien = aliens[index];
    if (!alien || alien.type === ALIEN_TYPE.NONE) continue;

    const x = alien.x + ALIEN_W / 2;
    const y = alien.y + ALIEN_H / 2;
    const typeBonus =
      alien.type === ALIEN_TYPE.ARMORED ? 14 : alien.type === ALIEN_TYPE.TOP ? 8 : 0;
    const score = y * 1.8 - Math.abs(x - actorX) + typeBonus;

    if (score > bestScore) {
      bestScore = score;
      best = { kind: "alien", index, x, y };
    }
  }

  if (!best) return null;

  return {
    ...best,
    x: clamp(best.x + errorOffset(config.targetErrorPx, rng), bounds.min, bounds.max),
  };
}

/**
 * @param {object} state
 * @param {1|2} [player]
 * @param {object} [config]
 * @returns {{side: number, x: number, y: number}|null}
 */
export function incomingBombThreat(state, player = 2, config = INVADERS_AI_DIFFICULTIES.normal) {
  if (!state || !Array.isArray(state.bombs)) return null;

  const actorX = cannonX(state, player);
  const relevant = state.bombs
    .filter((bomb) => bombThreatensPlayer(state, player, bomb))
    .filter(
      (bomb) =>
        bomb.y >= config.bombDangerY &&
        bomb.y <= CANNON_Y_OFFSET + CANNON_W &&
        Math.abs(bomb.x - actorX) <= config.bombDangerX,
    )
    .sort((a, b) => b.y - a.y);

  return relevant[0] || null;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {number} targetX
 * @param {number} [deadzonePx]
 * @returns {{left: boolean, right: boolean}}
 */
export function movementInputs(state, player, targetX, deadzonePx = 4) {
  const actorX = cannonX(state, player);

  return {
    left: targetX < actorX - deadzonePx,
    right: targetX > actorX + deadzonePx,
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {number}
 */
function cannonX(state, player) {
  return player === 1 ? state.cannon1X : state.cannon2X;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {Array<object>}
 */
function aliensForPlayer(state, player) {
  if (state.mode === GAME_MODE.COOP) return state.aliens1 || [];
  return player === 1 ? state.aliens1 || [] : state.aliens2 || [];
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {{min: number, max: number}}
 */
function cannonBounds(state, player) {
  const halfCannon = CANNON_W / 2;

  if (state.mode === GAME_MODE.COOP) {
    return { min: halfCannon, max: CANVAS_W - halfCannon };
  }

  if (player === 1) {
    return { min: halfCannon, max: HALF_W - halfCannon };
  }

  return { min: DIVIDER_X + halfCannon, max: CANVAS_W - halfCannon };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object|null} target
 * @returns {boolean}
 */
function isTargetStillValid(state, player, target) {
  if (!target) return false;
  if (target.kind === "ufo") return state.ufoActive === true;
  if (target.kind !== "alien" || !Number.isInteger(target.index)) return false;

  const alien = aliensForPlayer(state, player)[target.index];
  return !!alien && alien.type !== ALIEN_TYPE.NONE;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} target
 * @param {object} config
 * @param {number} cooldown
 * @param {() => number} rng
 * @returns {boolean}
 */
function shouldFire(state, player, target, config, cooldown, rng) {
  if (cooldown > 0) return false;
  if (player === 1 ? state.m1Active : state.m2Active) return false;

  return (
    Math.abs(cannonX(state, player) - target.x) <= config.aimTolerancePx &&
    rng() <= config.fireChance
  );
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {{side: number, x: number, y: number}} bomb
 * @returns {boolean}
 */
function bombThreatensPlayer(state, player, bomb) {
  return state.mode === GAME_MODE.COOP || bomb.side === player;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {{x: number}} threat
 * @param {object} config
 * @returns {{kind: "dodge", x: number}}
 */
function dodgeTarget(state, player, threat, config) {
  const actorX = cannonX(state, player);
  const bounds = cannonBounds(state, player);
  const preferredDirection = threat.x <= actorX ? 1 : -1;
  const preferredX = actorX + preferredDirection * config.dodgeDistancePx;
  const fallbackX = actorX - preferredDirection * config.dodgeDistancePx;
  const targetX = preferredX >= bounds.min && preferredX <= bounds.max ? preferredX : fallbackX;

  return {
    kind: "dodge",
    x: clamp(targetX, bounds.min, bounds.max),
  };
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

/**
 * @param {number} maxPx
 * @param {() => number} rng
 * @returns {number}
 */
function errorOffset(maxPx, rng) {
  if (!Number.isFinite(maxPx) || maxPx <= 0) return 0;
  return (rng() * 2 - 1) * maxPx;
}
