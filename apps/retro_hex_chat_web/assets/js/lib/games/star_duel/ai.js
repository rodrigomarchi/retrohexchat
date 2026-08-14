/**
 * Deterministic opponent controller for Star Duel solo sessions.
 * The controller consumes plain game state and emits the same held-input shape
 * used by the P2P peer path.
 * @module games/star_duel_ai
 */

import { GAME_MODE, PHASE } from "./protocol.js";
import {
  CANVAS_H,
  CANVAS_W,
  MAX_MISSILES,
  MISSILE_RADIUS,
  SHIP_RADIUS,
  STAR_DANGER_RADIUS,
  STAR_X,
  STAR_Y,
} from "./physics.js";

const DEFAULT_DIFFICULTY = "normal";
const TWO_PI = Math.PI * 2;
const NEUTRAL_INPUTS = Object.freeze({
  rotateLeft: false,
  rotateRight: false,
  thrust: false,
  fire: false,
  warp: false,
});

export const STAR_DUEL_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    turnDeadzone: 0.18,
    aimTolerance: 0.09,
    thrustAngle: 0.65,
    evasionThrustAngle: 1.25,
    standoffDistance: 185,
    leadFrames: 7,
    fireCooldownFrames: 42,
    fireChance: 0.5,
    threatFrames: 28,
    threatRadius: 130,
    missileAvoidMargin: 22,
    starAvoidRadius: STAR_DANGER_RADIUS + 62,
    asteroidAvoidMargin: 36,
    asteroidShotMargin: 6,
    emergencyWarp: false,
  }),
  normal: Object.freeze({
    turnDeadzone: 0.11,
    aimTolerance: 0.15,
    thrustAngle: 0.82,
    evasionThrustAngle: 1.45,
    standoffDistance: 155,
    leadFrames: 11,
    fireCooldownFrames: 26,
    fireChance: 0.78,
    threatFrames: 42,
    threatRadius: 175,
    missileAvoidMargin: 34,
    starAvoidRadius: STAR_DANGER_RADIUS + 82,
    asteroidAvoidMargin: 50,
    asteroidShotMargin: 8,
    emergencyWarp: false,
  }),
  hard: Object.freeze({
    turnDeadzone: 0.07,
    aimTolerance: 0.24,
    thrustAngle: 1,
    evasionThrustAngle: 1.7,
    standoffDistance: 125,
    leadFrames: 16,
    fireCooldownFrames: 15,
    fireChance: 1,
    threatFrames: 62,
    threatRadius: 220,
    missileAvoidMargin: 48,
    starAvoidRadius: STAR_DANGER_RADIUS + 105,
    asteroidAvoidMargin: 64,
    asteroidShotMargin: 10,
    emergencyWarp: true,
  }),
});

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeStarDuelAIDifficulty(difficulty) {
  if (typeof difficulty !== "string") return DEFAULT_DIFFICULTY;

  const key = difficulty.toLowerCase();
  return Object.prototype.hasOwnProperty.call(STAR_DUEL_AI_DIFFICULTIES, key)
    ? key
    : DEFAULT_DIFFICULTY;
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {StarDuelAI}
 */
export function createStarDuelAI(options = {}) {
  return new StarDuelAI(options);
}

export class StarDuelAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    this.difficulty = normalizeStarDuelAIDifficulty(options.difficulty);
    this.rng = typeof options.rng === "function" ? options.rng : Math.random;
    this.frame = 0;
    this.fireCooldown = 0;
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    this.difficulty = normalizeStarDuelAIDifficulty(difficulty);
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{rotateLeft: boolean, rotateRight: boolean, thrust: boolean, fire: boolean, warp: boolean}}
   */
  nextInputs(request = {}) {
    const state = request.state;
    const player = request.player === 1 ? 1 : 2;

    this.frame++;
    if (this.fireCooldown > 0) this.fireCooldown--;

    if (!state || state.phase !== PHASE.PLAYING) return NEUTRAL_INPUTS;

    const difficulty = normalizeStarDuelAIDifficulty(request.difficulty || this.difficulty);
    if (difficulty !== this.difficulty) this.setDifficulty(difficulty);
    const config = STAR_DUEL_AI_DIFFICULTIES[difficulty];

    const actor = shipFor(state, player);
    const opponent = shipFor(state, player === 1 ? 2 : 1);
    if (!isLiveShip(actor)) return NEUTRAL_INPUTS;

    const target = chooseTarget(state, player, actor, opponent, config);
    if (!target) return NEUTRAL_INPUTS;

    const turn = turnInputs(actor.rotation, target.angle, config.turnDeadzone);
    const fire = shouldFire(state, player, target, config, this.fireCooldown, this.rng);
    if (fire) this.fireCooldown = config.fireCooldownFrames;

    return {
      ...turn,
      thrust: shouldThrust(target, config),
      fire,
      warp: shouldWarp(actor, target, config, this.rng),
    };
  }
}

/**
 * @param {number} fromX
 * @param {number} fromY
 * @param {number} toX
 * @param {number} toY
 * @returns {{dx: number, dy: number, distance: number}}
 */
export function toroidalVector(fromX, fromY, toX, toY) {
  let dx = toX - fromX;
  let dy = toY - fromY;

  if (dx > CANVAS_W / 2) dx -= CANVAS_W;
  if (dx < -CANVAS_W / 2) dx += CANVAS_W;
  if (dy > CANVAS_H / 2) dy -= CANVAS_H;
  if (dy < -CANVAS_H / 2) dy += CANVAS_H;

  return { dx, dy, distance: Math.sqrt(dx * dx + dy * dy) };
}

/**
 * Smallest signed rotation from current angle to target angle.
 * Positive values rotate right, negative values rotate left.
 * @param {number} current
 * @param {number} target
 * @returns {number}
 */
export function rotationDelta(current, target) {
  let delta = normalizeAngle(target) - normalizeAngle(current);
  if (delta > Math.PI) delta -= TWO_PI;
  if (delta < -Math.PI) delta += TWO_PI;
  return delta;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {number} [margin]
 * @returns {boolean}
 */
export function lineOfFireBlockedByAsteroid(state, player = 2, margin = 8) {
  if (!state || state.mode !== GAME_MODE.DEBRIS_FIELD || !Array.isArray(state.asteroids)) {
    return false;
  }

  const actor = shipFor(state, player);
  const opponent = shipFor(state, player === 1 ? 2 : 1);
  if (!actor || !opponent) return false;

  const target = toroidalVector(actor.x, actor.y, opponent.x, opponent.y);
  if (target.distance <= 0) return false;
  const lenSq = target.dx * target.dx + target.dy * target.dy;

  return state.asteroids.some((asteroid) => {
    const offset = toroidalVector(actor.x, actor.y, asteroid.x, asteroid.y);
    const t = clamp((offset.dx * target.dx + offset.dy * target.dy) / lenSq, 0, 1);
    const closestX = target.dx * t;
    const closestY = target.dy * t;
    const dx = offset.dx - closestX;
    const dy = offset.dy - closestY;
    const distance = Math.sqrt(dx * dx + dy * dy);
    return distance <= asteroid.radius + margin;
  });
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {object|null}
 */
export function incomingMissileThreat(
  state,
  player = 2,
  config = STAR_DUEL_AI_DIFFICULTIES.normal,
) {
  const actor = shipFor(state, player);
  if (!actor || !Array.isArray(state?.missiles)) return null;

  let best = null;

  for (const missile of state.missiles) {
    if (missile.owner === player) continue;
    if (!Number.isFinite(missile.vx) || !Number.isFinite(missile.vy)) continue;

    const vector = toroidalVector(missile.x, missile.y, actor.x, actor.y);
    const speed = Math.sqrt(missile.vx * missile.vx + missile.vy * missile.vy);
    if (speed <= 0 || vector.distance > config.threatRadius) continue;

    const projection = (missile.vx * vector.dx + missile.vy * vector.dy) / speed;
    if (projection < 0) continue;

    const frames = projection / speed;
    if (frames > config.threatFrames) continue;

    const closestSq = Math.max(0, vector.distance * vector.distance - projection * projection);
    const closest = Math.sqrt(closestSq);
    const hitWidth = SHIP_RADIUS + MISSILE_RADIUS + config.missileAvoidMargin;
    if (closest > hitWidth) continue;

    if (!best || frames < best.frames) {
      best = { missile, vector, frames, closest };
    }
  }

  return best;
}

function chooseTarget(state, player, actor, opponent, config) {
  const missileThreat = incomingMissileThreat(state, player, config);
  if (missileThreat) {
    return {
      angle: missileEvasionAngle(missileThreat),
      kind: "evade",
      urgency: missileThreat.frames <= 10 ? "emergency" : "threat",
      angleError: null,
      distance: missileThreat.vector.distance,
    };
  }

  const starThreat = starAvoidance(actor, state, config);
  if (starThreat) return starThreat;

  const asteroidThreat = asteroidAvoidance(actor, state, config);
  if (asteroidThreat) return asteroidThreat;

  if (!isLiveShip(opponent)) return null;

  const predictedOpponent = {
    x: wrap(opponent.x + (opponent.vx || 0) * config.leadFrames, CANVAS_W),
    y: wrap(opponent.y + (opponent.vy || 0) * config.leadFrames, CANVAS_H),
  };
  const attackVector = toroidalVector(actor.x, actor.y, predictedOpponent.x, predictedOpponent.y);
  if (attackVector.distance <= 0) return null;

  const angle = Math.atan2(attackVector.dy, attackVector.dx);
  return {
    angle,
    kind: "attack",
    angleError: Math.abs(rotationDelta(actor.rotation, angle)),
    distance: attackVector.distance,
  };
}

function starAvoidance(actor, state, config) {
  if (state.mode !== GAME_MODE.GRAVITY_WELL) return null;

  const dx = actor.x - STAR_X;
  const dy = actor.y - STAR_Y;
  const distance = Math.sqrt(dx * dx + dy * dy);
  if (distance > config.starAvoidRadius) return null;

  const angle = Math.atan2(dy, dx);
  return {
    angle,
    kind: "evade",
    urgency: distance <= STAR_DANGER_RADIUS + 24 ? "emergency" : "threat",
    angleError: Math.abs(rotationDelta(actor.rotation, angle)),
    distance,
  };
}

function asteroidAvoidance(actor, state, config) {
  if (state.mode !== GAME_MODE.DEBRIS_FIELD || !Array.isArray(state.asteroids)) return null;

  let closest = null;
  for (const asteroid of state.asteroids) {
    const vector = toroidalVector(asteroid.x, asteroid.y, actor.x, actor.y);
    const clearance = vector.distance - asteroid.radius - SHIP_RADIUS;
    if (clearance > config.asteroidAvoidMargin) continue;
    if (!closest || clearance < closest.clearance) {
      closest = { asteroid, vector, clearance };
    }
  }

  if (!closest) return null;

  const angle = Math.atan2(closest.vector.dy, closest.vector.dx);
  return {
    angle,
    kind: "evade",
    urgency: closest.clearance <= 12 ? "emergency" : "threat",
    angleError: Math.abs(rotationDelta(actor.rotation, angle)),
    distance: closest.vector.distance,
  };
}

function missileEvasionAngle(threat) {
  const missile = threat.missile;
  const cross = missile.vx * threat.vector.dy - missile.vy * threat.vector.dx;
  const side = cross >= 0 ? 1 : -1;
  return Math.atan2(missile.vy, missile.vx) + side * (Math.PI / 2);
}

function shouldFire(state, player, target, config, fireCooldown, rng) {
  if (target.kind !== "attack") return false;
  if (target.angleError > config.aimTolerance) return false;
  if (fireCooldown > 0) return false;

  const actor = shipFor(state, player);
  const opponent = shipFor(state, player === 1 ? 2 : 1);
  if (!isLiveShip(actor) || !isLiveShip(opponent) || opponent.invulnerable) return false;
  if ((actor.fireCooldown || 0) > 0) return false;

  const ownMissiles = (state.missiles || []).filter((missile) => missile.owner === player);
  if (ownMissiles.length >= MAX_MISSILES) return false;
  if (lineOfFireBlockedByAsteroid(state, player, config.asteroidShotMargin)) return false;

  return randomUnit(rng) <= config.fireChance;
}

function shouldThrust(target, config) {
  if (target.kind === "evade") {
    return target.angleError === null || target.angleError <= config.evasionThrustAngle;
  }

  return target.distance > config.standoffDistance && target.angleError <= config.thrustAngle;
}

function shouldWarp(actor, target, config, rng) {
  return (
    config.emergencyWarp === true &&
    target.kind === "evade" &&
    target.urgency === "emergency" &&
    (actor.warpCooldown || 0) === 0 &&
    randomUnit(rng) < 0.08
  );
}

function turnInputs(rotation, targetAngle, deadzone) {
  const delta = rotationDelta(rotation, targetAngle);
  if (Math.abs(delta) <= deadzone) {
    return { rotateLeft: false, rotateRight: false };
  }

  return delta < 0
    ? { rotateLeft: true, rotateRight: false }
    : { rotateLeft: false, rotateRight: true };
}

function shipFor(state, player) {
  return player === 1 ? state?.ship1 : state?.ship2;
}

function isLiveShip(ship) {
  return ship && ship.alive === true && ship.exploding !== true;
}

function normalizeAngle(angle) {
  if (!Number.isFinite(angle)) return 0;
  let normalized = angle % TWO_PI;
  if (normalized < 0) normalized += TWO_PI;
  return normalized;
}

function randomUnit(rng) {
  const value = typeof rng === "function" ? rng() : Math.random();
  return Number.isFinite(value) ? clamp(value, 0, 1) : 0;
}

function wrap(value, max) {
  return ((value % max) + max) % max;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
