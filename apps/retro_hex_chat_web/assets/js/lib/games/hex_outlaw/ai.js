/**
 * Deterministic opponent controller for Hex Outlaw solo sessions.
 * The controller consumes plain game state and emits the same held-input shape
 * used by the P2P peer path.
 * @module games/hex_outlaw_ai
 */

import { GAME_MODE, PHASE } from "./protocol.js";
import {
  ARENA_BOTTOM,
  ARENA_LEFT,
  ARENA_RIGHT,
  ARENA_TOP,
  BULLET_RADIUS,
  BULLET_SPEED_X,
  GUNSLINGER_H,
  GUNSLINGER_HIT_H,
  GUNSLINGER_HIT_W,
  NML_P2_MIN_X,
  RICOCHET_ANGLE,
  getObstacleRect,
} from "./physics.js";

const DEFAULT_DIFFICULTY = "normal";
const NEUTRAL_INPUTS = Object.freeze({
  up: false,
  down: false,
  left: false,
  right: false,
  fire: false,
});
const PLAYER_PREFIX = Object.freeze({
  1: "p1",
  2: "p2",
});
const BULLET_PREFIX = Object.freeze({
  1: "b1",
  2: "b2",
});
const INPUT_TARGET_DEADZONE = 2;

export const OUTLAW_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    dodgeTriggerPx: 18,
    threatFrames: 26,
    fireWindowPx: 8,
    fireCooldownFrames: 74,
    fireChance: 0.45,
    targetDeadzonePx: 18,
    preferredNmlOffset: 76,
  }),
  normal: Object.freeze({
    dodgeTriggerPx: 26,
    threatFrames: 40,
    fireWindowPx: 13,
    fireCooldownFrames: 46,
    fireChance: 0.78,
    targetDeadzonePx: 11,
    preferredNmlOffset: 54,
  }),
  hard: Object.freeze({
    dodgeTriggerPx: 34,
    threatFrames: 58,
    fireWindowPx: 18,
    fireCooldownFrames: 28,
    fireChance: 1,
    targetDeadzonePx: 7,
    preferredNmlOffset: 34,
  }),
});

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeOutlawAIDifficulty(difficulty) {
  if (typeof difficulty !== "string") return DEFAULT_DIFFICULTY;

  const key = difficulty.toLowerCase();
  return Object.prototype.hasOwnProperty.call(OUTLAW_AI_DIFFICULTIES, key)
    ? key
    : DEFAULT_DIFFICULTY;
}

/**
 * Predict where the opponent's active bullet will cross the requested player.
 * Returns null when the bullet is inactive, moving away, blocked, or too far
 * in the future for the requested horizon.
 * @param {object} state
 * @param {1|2} [player]
 * @param {object} [options]
 * @param {number} [options.maxFrames]
 * @returns {number|null}
 */
export function predictIncomingBulletY(state, player = 2, options = {}) {
  if (!state) return null;

  const actor = playerState(state, player);
  const incomingBulletPlayer = player === 1 ? 2 : 1;
  const bullet = bulletState(state, incomingBulletPlayer);
  if (!actor || !bullet.active || !Number.isFinite(bullet.vx) || bullet.vx === 0) return null;

  const movingTowardActor = player === 1 ? bullet.vx < 0 : bullet.vx > 0;
  if (!movingTowardActor) return null;

  return simulateBulletCrossing(state, bullet, actor.x, {
    maxFrames: Number.isFinite(options.maxFrames) ? options.maxFrames : 80,
  });
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {OutlawAI}
 */
export function createOutlawAI(options = {}) {
  return new OutlawAI(options);
}

export class OutlawAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    this.difficulty = normalizeOutlawAIDifficulty(options.difficulty);
    this.rng = typeof options.rng === "function" ? options.rng : Math.random;
    this.frame = 0;
    this.fireCooldown = 0;
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    this.difficulty = normalizeOutlawAIDifficulty(difficulty);
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{up: boolean, down: boolean, left: boolean, right: boolean, fire: boolean}}
   */
  nextInputs(request = {}) {
    const state = request.state;
    const player = request.player === 1 ? 1 : 2;

    this.frame++;
    if (this.fireCooldown > 0) this.fireCooldown--;

    if (!state || state.phase !== PHASE.PLAYING) return NEUTRAL_INPUTS;

    const difficulty = normalizeOutlawAIDifficulty(request.difficulty || this.difficulty);
    if (difficulty !== this.difficulty) this.setDifficulty(difficulty);
    const config = OUTLAW_AI_DIFFICULTIES[difficulty];

    const actor = playerState(state, player);
    const opponent = playerState(state, player === 1 ? 2 : 1);
    if (!actor || !opponent) return NEUTRAL_INPUTS;

    const threat = incomingThreat(state, player, config);
    if (threat) {
      return {
        ...movementAwayFromThreat(state, player, threat.y),
        fire: false,
      };
    }

    const attack = chooseAttack(state, player, config);
    const fire = shouldFire(state, player, attack, config, this.fireCooldown, this.rng);
    if (fire) this.fireCooldown = config.fireCooldownFrames;

    return {
      ...movementTowardAttack(state, player, attack, config),
      fire,
    };
  }
}

function incomingThreat(state, player, config) {
  const actor = playerState(state, player);
  const y = predictIncomingBulletY(state, player, { maxFrames: config.threatFrames });
  if (!actor || y === null) return null;

  return Math.abs(y - actor.y) <= config.dodgeTriggerPx ? { y } : null;
}

function chooseAttack(state, player, config) {
  if (state.gameMode === GAME_MODE.RICOCHET) {
    const ricochet = findRicochetShot(state, player);
    if (ricochet) {
      return { targetY: ricochet.aimUp ? ARENA_TOP : ARENA_BOTTOM, aimUp: ricochet.aimUp };
    }
  }

  const actor = playerState(state, player);
  const opponent = playerState(state, player === 1 ? 2 : 1);
  const targetY = chooseStraightShotY(state, player, actor, opponent, config);
  const targetX =
    state.gameMode === GAME_MODE.NO_MANS_LAND && player === 2
      ? NML_P2_MIN_X + config.preferredNmlOffset
      : actor.x;

  return { targetY, targetX, aimUp: targetY < actor.y };
}

function chooseStraightShotY(state, player, actor, opponent, config) {
  const rect = getObstacleRect(state);
  const desiredY = clamp(opponent.y, minPlayerY(), maxPlayerY());

  if (!rect || !lineBlockedAtY(desiredY, actor.x, opponent.x, rect)) return desiredY;

  const above = clamp(
    rect.y - GUNSLINGER_HIT_H - config.targetDeadzonePx,
    minPlayerY(),
    maxPlayerY(),
  );
  const below = clamp(
    rect.y + rect.h + GUNSLINGER_HIT_H + config.targetDeadzonePx,
    minPlayerY(),
    maxPlayerY(),
  );

  return Math.abs(actor.y - above) <= Math.abs(actor.y - below) ? above : below;
}

function shouldFire(state, player, attack, config, fireCooldown, rng) {
  if (fireCooldown > 0) return false;
  if (bulletState(state, player).active) return false;
  if (randomUnit(rng) > config.fireChance) return false;

  if (state.gameMode === GAME_MODE.RICOCHET) {
    return !!findRicochetShot(state, player, attack.aimUp);
  }

  const actor = playerState(state, player);
  const opponent = playerState(state, player === 1 ? 2 : 1);
  if (!actor || !opponent) return false;
  if (Math.abs(actor.y - opponent.y) > config.fireWindowPx) return false;

  const rect = getObstacleRect(state);
  return !rect || !lineBlockedAtY(actor.y, actor.x, opponent.x, rect);
}

function movementTowardAttack(state, player, attack, config) {
  const actor = playerState(state, player);
  if (!actor) return NEUTRAL_INPUTS;

  const vertical = movementTowardY(actor.y, attack.targetY, config.targetDeadzonePx);
  const horizontal =
    state.gameMode === GAME_MODE.NO_MANS_LAND
      ? movementTowardX(actor.x, attack.targetX)
      : { left: false, right: false };

  if (
    state.gameMode === GAME_MODE.RICOCHET &&
    Math.abs(actor.y - attack.targetY) <= config.fireWindowPx
  ) {
    vertical.up = attack.aimUp === true;
    vertical.down = attack.aimUp === false;
  }

  return {
    up: vertical.up,
    down: vertical.down,
    left: horizontal.left,
    right: horizontal.right,
  };
}

function movementAwayFromThreat(state, player, threatY) {
  const actor = playerState(state, player);
  if (!actor) return { up: false, down: false, left: false, right: false };

  const minY = minPlayerY();
  const maxY = maxPlayerY();
  const roomUp = actor.y - minY;
  const roomDown = maxY - actor.y;
  const moveDown =
    roomUp <= GUNSLINGER_H || (roomDown > GUNSLINGER_H && (threatY < actor.y || roomDown > roomUp));

  return {
    up: !moveDown,
    down: moveDown,
    left: false,
    right: state.gameMode === GAME_MODE.NO_MANS_LAND,
  };
}

function movementTowardY(currentY, targetY, deadzone) {
  const delta = targetY - currentY;
  if (Math.abs(delta) <= Math.max(deadzone, INPUT_TARGET_DEADZONE)) {
    return { up: false, down: false };
  }

  return delta < 0 ? { up: true, down: false } : { up: false, down: true };
}

function movementTowardX(currentX, targetX) {
  const delta = targetX - currentX;
  if (Math.abs(delta) <= INPUT_TARGET_DEADZONE) return { left: false, right: false };
  return delta < 0 ? { left: true, right: false } : { left: false, right: true };
}

function findRicochetShot(state, player, preferredAimUp = null) {
  const actor = playerState(state, player);
  const opponent = playerState(state, player === 1 ? 2 : 1);
  if (!actor || !opponent) return null;

  const candidates =
    typeof preferredAimUp === "boolean"
      ? [preferredAimUp, !preferredAimUp]
      : [opponent.y < actor.y, opponent.y >= actor.y];

  for (const aimUp of candidates) {
    const dirX = player === 1 ? 1 : -1;
    const bullet = {
      x: actor.x + dirX * (GUNSLINGER_HIT_W / 2 + BULLET_RADIUS),
      y: actor.y,
      vx: BULLET_SPEED_X * Math.cos(RICOCHET_ANGLE) * dirX,
      vy: BULLET_SPEED_X * Math.sin(RICOCHET_ANGLE) * (aimUp ? -1 : 1),
      bounced: false,
    };

    if (simulatedShotHits(state, bullet, opponent)) return { aimUp };
  }

  return null;
}

function simulatedShotHits(state, bullet, opponent) {
  let x = bullet.x;
  let y = bullet.y;
  let vy = bullet.vy;
  let bounced = bullet.bounced;
  const rect = getObstacleRect(state);

  for (let frame = 0; frame < 100; frame++) {
    x += bullet.vx;
    y += vy;

    if (!bounced && vy !== 0) {
      if (y - BULLET_RADIUS <= ARENA_TOP) {
        y = ARENA_TOP + BULLET_RADIUS;
        vy = -vy;
        bounced = true;
      } else if (y + BULLET_RADIUS >= ARENA_BOTTOM) {
        y = ARENA_BOTTOM - BULLET_RADIUS;
        vy = -vy;
        bounced = true;
      }
    }

    if (rect && bulletHitsRect(x, y, rect)) return false;
    if (bulletHitsGunslinger(x, y, opponent.x, opponent.y)) return true;
    if (x < ARENA_LEFT - BULLET_RADIUS || x > ARENA_RIGHT + BULLET_RADIUS) return false;
    if (bounced && (y - BULLET_RADIUS < ARENA_TOP || y + BULLET_RADIUS > ARENA_BOTTOM)) {
      return false;
    }
  }

  return false;
}

function simulateBulletCrossing(state, bullet, targetX, options) {
  let x = bullet.x;
  let y = bullet.y;
  let vy = bullet.vy;
  let bounced = bullet.bounced;
  const rect = getObstacleRect(state);

  for (let frame = 0; frame < options.maxFrames; frame++) {
    x += bullet.vx;
    y += vy;

    if (!bounced && vy !== 0) {
      if (y - BULLET_RADIUS <= ARENA_TOP) {
        y = ARENA_TOP + BULLET_RADIUS;
        vy = -vy;
        bounced = true;
      } else if (y + BULLET_RADIUS >= ARENA_BOTTOM) {
        y = ARENA_BOTTOM - BULLET_RADIUS;
        vy = -vy;
        bounced = true;
      }
    }

    if (rect && bulletHitsRect(x, y, rect)) return null;

    if (
      (bullet.vx > 0 && x >= targetX - GUNSLINGER_HIT_W / 2) ||
      (bullet.vx < 0 && x <= targetX + GUNSLINGER_HIT_W / 2)
    ) {
      return y;
    }

    if (x < ARENA_LEFT - BULLET_RADIUS || x > ARENA_RIGHT + BULLET_RADIUS) return null;
    if (bounced && (y - BULLET_RADIUS < ARENA_TOP || y + BULLET_RADIUS > ARENA_BOTTOM)) return null;
  }

  return null;
}

function lineBlockedAtY(y, fromX, toX, rect) {
  const minX = Math.min(fromX, toX);
  const maxX = Math.max(fromX, toX);
  const crossesX = rect.x <= maxX && rect.x + rect.w >= minX;
  const crossesY = y + BULLET_RADIUS >= rect.y && y - BULLET_RADIUS <= rect.y + rect.h;
  return crossesX && crossesY;
}

function bulletHitsRect(bx, by, rect) {
  const closestX = clamp(bx, rect.x, rect.x + rect.w);
  const closestY = clamp(by, rect.y, rect.y + rect.h);
  const dx = bx - closestX;
  const dy = by - closestY;
  return dx * dx + dy * dy <= BULLET_RADIUS * BULLET_RADIUS;
}

function bulletHitsGunslinger(bx, by, gx, gy) {
  const halfW = GUNSLINGER_HIT_W / 2;
  const halfH = GUNSLINGER_HIT_H / 2;
  const closestX = clamp(bx, gx - halfW, gx + halfW);
  const closestY = clamp(by, gy - halfH, gy + halfH);
  const dx = bx - closestX;
  const dy = by - closestY;
  return dx * dx + dy * dy <= BULLET_RADIUS * BULLET_RADIUS;
}

function playerState(state, player) {
  const prefix = PLAYER_PREFIX[player];
  if (!prefix) return null;
  const x = state[`${prefix}x`];
  const y = state[`${prefix}y`];
  return Number.isFinite(x) && Number.isFinite(y) ? { x, y } : null;
}

function bulletState(state, player) {
  const prefix = BULLET_PREFIX[player];
  return {
    x: state[`${prefix}x`],
    y: state[`${prefix}y`],
    vx: state[`${prefix}vx`],
    vy: state[`${prefix}vy`],
    active: state[`${prefix}active`] === true,
    bounced: state[`${prefix}bounced`] === true,
  };
}

function minPlayerY() {
  return ARENA_TOP + GUNSLINGER_H / 2;
}

function maxPlayerY() {
  return ARENA_BOTTOM - GUNSLINGER_H / 2;
}

function randomUnit(rng) {
  const value = Number(rng());
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(value, 0.999999999));
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
