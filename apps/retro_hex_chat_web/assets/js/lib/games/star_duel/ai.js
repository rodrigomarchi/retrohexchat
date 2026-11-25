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
  DRAG,
  MAX_MISSILES,
  MISSILE_RADIUS,
  MISSILE_SPEED,
  ROTATION_SPEED,
  SHIP_RADIUS,
  STAR_DANGER_RADIUS,
  STAR_X,
  STAR_Y,
  THRUST_ACCEL,
  applyGravity,
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
    starAvoidRadius: STAR_DANGER_RADIUS + 40,
    asteroidAvoidMargin: 36,
    asteroidShotMargin: 6,
    hazardLookahead: 20,
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
    starAvoidRadius: STAR_DANGER_RADIUS + 62,
    asteroidAvoidMargin: 50,
    asteroidShotMargin: 8,
    hazardLookahead: 25,
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
    starAvoidRadius: STAR_DANGER_RADIUS + 82,
    asteroidAvoidMargin: 64,
    asteroidShotMargin: 10,
    hazardLookahead: 30,
    emergencyWarp: true,
  }),
});

// The odds the hard AI warps away from a missile it cannot otherwise escape,
// decided once per missile.
const EMERGENCY_WARP_CHANCE = 0.08;

// How near the nose must point outward to thrust away from a star or a rock.
const HAZARD_THRUST_ANGLE = 0.5;
// Any heading this near straight outward gets clear of a star or a rock;
// the one nearest the nose is taken, since a ship turns slowly.
const ESCAPE_CONE = 1.2;
const ESCAPE_TIE = 0.3;
// A missile passing nearer the star than this is bent off its aim.
const STAR_SHOT_CLEARANCE = STAR_DANGER_RADIUS + 5;
// How long a burst of thrust is weighed for before it is let go.
const THRUST_PROBE_FRAMES = 10;

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
  // The star and the rocks come first: a dodge into either is no dodge.
  const obstacles = obstaclesFor(state, config);
  const hazard = escapeFrom(actor, state, obstacles, config);
  if (hazard) return hazard;

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

  if (!isLiveShip(opponent)) return null;
  const aim = aimAt(actor, opponent, config, aimError, obstacles);
  if (!aim || obstacles.length === 0) return aim;
  return { ...aim, thrustSafe: thrustIsSafe(actor, state, obstacles, config) };
}

/**
 * Where to point to hit the rival, led by its course. The arena wraps, so
 * the rival is there by several ways — straight, or out across an edge —
 * and the shortest one that keeps clear of the star and the rocks is taken.
 */
function aimAt(actor, opponent, config, aimError, obstacles = []) {
  const flight = toroidalVector(actor.x, actor.y, opponent.x, opponent.y).distance / MISSILE_SPEED;
  const lead = flight * config.leadSkill;
  const predictedOpponent = {
    x: wrap(opponent.x + (opponent.vx || 0) * lead, CANVAS_W),
    y: wrap(opponent.y + (opponent.vy || 0) * lead, CANVAS_H),
  };
  const attackVector = clearWay(actor, predictedOpponent, obstacles);
  if (attackVector.distance <= 0) return null;

  const angle = Math.atan2(attackVector.dy, attackVector.dx) + aimError;
  return {
    angle,
    kind: "attack",
    angleError: Math.abs(rotationDelta(actor.rotation, angle)),
    distance: attackVector.distance,
    blocked: attackVector.blocked === true,
  };
}

/**
 * The shortest way from the ship to a point that passes no obstacle nearer
 * than a shot may — the straight one or one across the arena's edges — or
 * the straight one, `blocked`, when every way is.
 */
function clearWay(actor, point, obstacles) {
  const direct = toroidalVector(actor.x, actor.y, point.x, point.y);
  if (obstacles.length === 0) return direct;

  const ways = [];
  for (const sx of [-CANVAS_W, 0, CANVAS_W]) {
    for (const sy of [-CANVAS_H, 0, CANVAS_H]) {
      const dx = direct.dx + sx;
      const dy = direct.dy + sy;
      ways.push({ dx, dy, distance: Math.hypot(dx, dy) });
    }
  }
  ways.sort((a, b) => a.distance - b.distance);
  const clear = ways.find((way) => !obstacles.some((o) => passesNear(actor, way, o)));
  return clear ?? { ...direct, blocked: true };
}

/** Whether the straight way from the ship, unwrapped, passes within a shot's clearance of an obstacle. */
function passesNear(actor, way, obstacle) {
  const lenSq = way.dx * way.dx + way.dy * way.dy;
  if (lenSq <= 0) return false;
  for (const sx of [-CANVAS_W, 0, CANVAS_W]) {
    for (const sy of [-CANVAS_H, 0, CANVAS_H]) {
      const ox = obstacle.x + sx - actor.x;
      const oy = obstacle.y + sy - actor.y;
      const t = clamp((ox * way.dx + oy * way.dy) / lenSq, 0, 1);
      if (Math.hypot(ox - way.dx * t, oy - way.dy * t) <= obstacle.shot) return true;
    }
  }
  return false;
}

/**
 * What this arena has to keep clear of: the star, or every asteroid. `keep`
 * is how near this AI lets the ship's centre get, `shot` how near a missile
 * may pass and still fly true.
 */
function obstaclesFor(state, config) {
  if (state.mode === GAME_MODE.GRAVITY_WELL) {
    return [{ x: STAR_X, y: STAR_Y, keep: config.starAvoidRadius, shot: STAR_SHOT_CLEARANCE }];
  }
  if (state.mode === GAME_MODE.DEBRIS_FIELD && Array.isArray(state.asteroids)) {
    return state.asteroids.map((asteroid) => ({
      x: asteroid.x,
      y: asteroid.y,
      keep: asteroid.radius + SHIP_RADIUS + config.asteroidAvoidMargin,
      shot: asteroid.radius + config.asteroidShotMargin,
    }));
  }
  return [];
}

/**
 * Nose out and thrust, from the star or a rock the ship would otherwise
 * drift too near — before it is too late to turn: the ship looks ahead as
 * long as turning outward takes it, and `hazardLookahead` frames more to
 * brake. Outward changes smoothly as the ship moves, so it never dithers
 * between two ways out. Near the star a ship that waits cannot climb out:
 * its pull beats the thrust inside about twice the star's deadly radius.
 */
function escapeFrom(actor, state, obstacles, config) {
  for (const obstacle of obstacles) {
    const out = toroidalVector(obstacle.x, obstacle.y, actor.x, actor.y);
    const outward = Math.atan2(out.dy, out.dx);
    const off = rotationDelta(outward, actor.rotation);
    // A nose straight at it could swing either way: every ship swings the
    // same way round, so two ships fleeing the star circle it together
    // instead of meeting head on.
    const side = Math.abs(off) > Math.PI - ESCAPE_TIE ? 1 : Math.sign(off);
    const angle = Math.abs(off) <= ESCAPE_CONE ? actor.rotation : outward + side * ESCAPE_CONE;
    const turning = Math.abs(rotationDelta(actor.rotation, angle)) / ROTATION_SPEED;
    const frames = Math.ceil(turning) + config.hazardLookahead;
    const into = coastsInto(actor, state, obstacle, frames);
    if (into === null) continue;
    return {
      angle,
      kind: "evade",
      hazard: true,
      urgency: into <= 10 ? "emergency" : "threat",
      angleError: Math.abs(rotationDelta(actor.rotation, angle)),
      distance: out.distance,
    };
  }
  return null;
}

/**
 * Whether a burst of thrust the way the nose points leaves the ship clear of
 * every obstacle while it coasts on afterwards.
 */
function thrustIsSafe(actor, state, obstacles, config) {
  const thrust = { ...actor };
  thrust.vx = (actor.vx || 0) + Math.cos(actor.rotation) * THRUST_ACCEL * THRUST_PROBE_FRAMES;
  thrust.vy = (actor.vy || 0) + Math.sin(actor.rotation) * THRUST_ACCEL * THRUST_PROBE_FRAMES;
  const frames = Math.ceil(Math.PI / ROTATION_SPEED) + config.hazardLookahead;
  return obstacles.every((obstacle) => coastsInto(thrust, state, obstacle, frames) === null);
}

/**
 * The frame the ship, coasting from here — pulled by the star in Gravity
 * Well — comes within an obstacle's `keep`, or null if it does not within
 * `frames`. A ship already inside and not moving outward is in it now.
 */
function coastsInto(actor, state, obstacle, frames) {
  let ship = actor;
  let last = toroidalVector(obstacle.x, obstacle.y, ship.x, ship.y).distance;
  if (last <= obstacle.keep) {
    const next = toroidalVector(
      obstacle.x,
      obstacle.y,
      ship.x + (ship.vx || 0),
      ship.y + (ship.vy || 0),
    );
    return next.distance <= last + 0.5 ? 0 : null;
  }
  // A rock further off than the ship can coast in the time is no danger;
  // the star's pull speeds a ship up, so it is always followed.
  const reach = Math.hypot(ship.vx || 0, ship.vy || 0) * frames;
  if (state.mode !== GAME_MODE.GRAVITY_WELL && last - obstacle.keep > reach) return null;
  for (let frame = 1; frame <= frames; frame++) {
    ship = coast(ship, state.mode);
    last = toroidalVector(obstacle.x, obstacle.y, ship.x, ship.y).distance;
    if (last <= obstacle.keep) return frame;
  }
  return null;
}

/** One frame of a ship with its hands off the keys: drag, the star's pull, drift. */
function coast(ship, mode) {
  const pulled = mode === GAME_MODE.GRAVITY_WELL ? applyGravity(ship, STAR_X, STAR_Y) : ship;
  const vx = (pulled.vx || 0) * DRAG;
  const vy = (pulled.vy || 0) * DRAG;
  return { x: wrap(ship.x + vx, CANVAS_W), y: wrap(ship.y + vy, CANVAS_H), vx, vy };
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
  return !target.blocked;
}

function shouldThrust(target, config) {
  if (target.hazard) return target.angleError <= HAZARD_THRUST_ANGLE;
  if (target.kind === "evade") {
    return target.angleError === null || target.angleError <= config.evasionThrustAngle;
  }

  return (
    target.thrustSafe !== false &&
    target.distance > config.standoffDistance &&
    target.angleError <= config.thrustAngle
  );
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
