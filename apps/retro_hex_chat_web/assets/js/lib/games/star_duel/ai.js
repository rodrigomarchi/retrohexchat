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
  MISSILE_SPEED,
  SHIP_RADIUS,
  STAR_DANGER_RADIUS,
  STAR_X,
  STAR_Y,
} from "./physics.js";
import {
  TableAI,
  clamp,
  createCommitment,
  createDelayedView,
  createPerThing,
  normalizeDifficulty,
  rotationDelta,
} from "../core/ai.js";

const NEUTRAL_INPUTS = Object.freeze({
  rotateLeft: false,
  rotateRight: false,
  thrust: false,
  fire: false,
  warp: false,
});

// reactionFrames: how old the rival's position and course are when this AI
// reads them. leadSkill: how much of a shot's flight time it leads the rival
// by. aimErrorAngle: the most a shot is off, drawn once per shot and kept
// until it is fired. turnDeadzone never exceeds aimTolerance, and neither
// loosens with difficulty. fireChance: the odds an opening is taken; a passed
// one waits out the cooldown. dodgeChance: the odds a missile is dodged at
// all, decided once per missile, and only once it is reactionFrames old.
export const STAR_DUEL_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    reactionFrames: 12,
    turnDeadzone: 0.05,
    aimTolerance: 0.06,
    aimErrorAngle: 0.13,
    thrustAngle: 0.65,
    evasionThrustAngle: 1.25,
    standoffDistance: 185,
    leadSkill: 0.6,
    fireCooldownFrames: 34,
    fireChance: 0.8,
    dodgeChance: 0.28,
    threatFrames: 28,
    threatRadius: 130,
    missileAvoidMargin: 22,
    starAvoidRadius: STAR_DANGER_RADIUS + 62,
    asteroidAvoidMargin: 36,
    asteroidShotMargin: 6,
    emergencyWarp: false,
  }),
  normal: Object.freeze({
    reactionFrames: 11,
    turnDeadzone: 0.05,
    aimTolerance: 0.05,
    aimErrorAngle: 0.12,
    thrustAngle: 0.82,
    evasionThrustAngle: 1.45,
    standoffDistance: 155,
    leadSkill: 0.6,
    fireCooldownFrames: 32,
    fireChance: 0.9,
    dodgeChance: 0.3,
    threatFrames: 42,
    threatRadius: 175,
    missileAvoidMargin: 34,
    starAvoidRadius: STAR_DANGER_RADIUS + 82,
    asteroidAvoidMargin: 50,
    asteroidShotMargin: 8,
    emergencyWarp: false,
  }),
  hard: Object.freeze({
    reactionFrames: 4,
    turnDeadzone: 0.04,
    aimTolerance: 0.04,
    aimErrorAngle: 0.03,
    thrustAngle: 1,
    evasionThrustAngle: 1.7,
    standoffDistance: 125,
    leadSkill: 1,
    fireCooldownFrames: 18,
    fireChance: 1,
    dodgeChance: 0.65,
    threatFrames: 62,
    threatRadius: 220,
    missileAvoidMargin: 48,
    starAvoidRadius: STAR_DANGER_RADIUS + 105,
    asteroidAvoidMargin: 64,
    asteroidShotMargin: 10,
    emergencyWarp: true,
  }),
});

// The odds the hard AI warps away from a missile it cannot otherwise escape,
// decided once per missile.
const EMERGENCY_WARP_CHANCE = 0.08;

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeStarDuelAIDifficulty(difficulty) {
  return normalizeDifficulty(difficulty, STAR_DUEL_AI_DIFFICULTIES);
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

export class StarDuelAI extends TableAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    super(options, normalizeStarDuelAIDifficulty, STAR_DUEL_AI_DIFFICULTIES);
    this.fireCooldown = 0;
    this.shot = 0;
    this._aim = createCommitment();
    this._view = createDelayedView();
    this._missiles = createPerThing();
  }

  /**
   * A new round or match: the rival unseen until it is looked at again, no
   * missile under watch, and the next shot draws a fresh aim.
   * @returns {void}
   */
  forget() {
    this._view.reset();
    this._missiles.reset();
    this._aim.reset();
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{rotateLeft: boolean, rotateRight: boolean, thrust: boolean, fire: boolean, warp: boolean}}
   */
  // ex_dna:disable-for-lines:6 this AI's own turn: its cooldowns and the phase it plays in
  nextInputs(request = {}) {
    const { state, player } = this.startTurn(request);
    if (this.fireCooldown > 0) this.fireCooldown--;

    if (!state || state.phase !== PHASE.PLAYING) return NEUTRAL_INPUTS;

    const config = this.rowFor(request);

    const actor = shipFor(state, player);
    const opponent = shipFor(state, player === 1 ? 2 : 1);
    const seen = this._view.see(opponent, config.reactionFrames);
    if (!isLiveShip(actor)) return NEUTRAL_INPUTS;

    const noticed = this._noticedMissiles(state, player, config);
    const aimError = this._aim.hold(
      this.shot,
      () => (randomUnit(this.rng) * 2 - 1) * config.aimErrorAngle,
    );
    const target = chooseTarget(
      noticed,
      player,
      actor,
      readOpponent(opponent, seen),
      config,
      aimError,
    );
    if (!target) return NEUTRAL_INPUTS;

    const turn = turnInputs(actor.rotation, target.angle, config.turnDeadzone);
    const inputs = {
      ...turn,
      thrust: shouldThrust(target, config),
      fire: false,
      warp: shouldWarp(actor, target, config),
    };
    if (!shouldFire(state, player, target, config, this.fireCooldown)) return inputs;

    // One roll per opening; a passed one waits out the cooldown like a shot.
    this.fireCooldown = config.fireCooldownFrames;
    this.shot++;
    return { ...inputs, fire: randomUnit(this.rng) < config.fireChance };
  }

  /**
   * The state as this AI sees it: a rival missile is there only once it is
   * reactionFrames old, and only if this AI is to dodge it — decided once per
   * missile, along with whether it would warp away from it.
   */
  _noticedMissiles(state, player, config) {
    const missiles = Array.isArray(state.missiles) ? state.missiles : [];
    const ids = missiles.map((missile) => `${missile.owner}:${this.frame - (missile.age || 0)}`);
    this._missiles.keep(ids);

    const kept = missiles
      .map((missile, i) => {
        if (missile.owner === player) return missile;
        const plan = this._missiles.decide(ids[i], () => ({
          dodges: randomUnit(this.rng) < config.dodgeChance,
          warps: randomUnit(this.rng) < EMERGENCY_WARP_CHANCE,
        }));
        if (!plan.dodges || (missile.age || 0) < config.reactionFrames) return null;
        return { ...missile, warps: plan.warps };
      })
      .filter(Boolean);
    return kept.length === missiles.length ? state : { ...state, missiles: kept };
  }
}

/**
 * The rival as this AI reads it: where it was and how it moved
 * reactionFrames ago, but whether it is alive and shielded as it is now.
 */
function readOpponent(opponent, seen) {
  if (!opponent || !seen) return opponent;
  return { ...opponent, x: seen.x, y: seen.y, vx: seen.vx, vy: seen.vy };
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

function chooseTarget(state, player, actor, opponent, config, aimError = 0) {
  const missileThreat = incomingMissileThreat(state, player, config);
  if (missileThreat) {
    return {
      angle: missileEvasionAngle(missileThreat),
      kind: "evade",
      urgency: missileThreat.frames <= 10 ? "emergency" : "threat",
      warps: missileThreat.missile.warps === true,
      angleError: null,
      distance: missileThreat.vector.distance,
    };
  }

  const starThreat = starAvoidance(actor, state, config);
  if (starThreat) return starThreat;

  const asteroidThreat = asteroidAvoidance(actor, state, config);
  if (asteroidThreat) return asteroidThreat;

  if (!isLiveShip(opponent)) return null;

  const flight = toroidalVector(actor.x, actor.y, opponent.x, opponent.y).distance / MISSILE_SPEED;
  const lead = flight * config.leadSkill;
  const predictedOpponent = {
    x: wrap(opponent.x + (opponent.vx || 0) * lead, CANVAS_W),
    y: wrap(opponent.y + (opponent.vy || 0) * lead, CANVAS_H),
  };
  const attackVector = toroidalVector(actor.x, actor.y, predictedOpponent.x, predictedOpponent.y);
  if (attackVector.distance <= 0) return null;

  const angle = Math.atan2(attackVector.dy, attackVector.dx) + aimError;
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

function shouldFire(state, player, target, config, fireCooldown) {
  if (target.kind !== "attack") return false;
  if (target.angleError > config.aimTolerance) return false;
  if (fireCooldown > 0) return false;

  const actor = shipFor(state, player);
  const opponent = shipFor(state, player === 1 ? 2 : 1);
  if (!isLiveShip(actor) || !isLiveShip(opponent) || opponent.invulnerable) return false;
  if ((actor.fireCooldown || 0) > 0) return false;

  const ownMissiles = (state.missiles || []).filter((missile) => missile.owner === player);
  if (ownMissiles.length >= MAX_MISSILES) return false;
  return !lineOfFireBlockedByAsteroid(state, player, config.asteroidShotMargin);
}

function shouldThrust(target, config) {
  if (target.kind === "evade") {
    return target.angleError === null || target.angleError <= config.evasionThrustAngle;
  }

  return target.distance > config.standoffDistance && target.angleError <= config.thrustAngle;
}

function shouldWarp(actor, target, config) {
  return (
    config.emergencyWarp === true &&
    target.kind === "evade" &&
    target.urgency === "emergency" &&
    target.warps === true &&
    (actor.warpCooldown || 0) === 0
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

function randomUnit(rng) {
  const value = rng();
  return Number.isFinite(value) ? clamp(value, 0, 1) : 0;
}

function wrap(value, max) {
  return ((value % max) + max) % max;
}
