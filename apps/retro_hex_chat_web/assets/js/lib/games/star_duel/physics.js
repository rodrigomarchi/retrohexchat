/**
 * Pure physics and game logic for Star Duel space combat.
 * All functions are pure — no side effects, no DOM, no network.
 * @module games/star_duel_physics
 */

import { PHASE, GAME_MODE } from "./protocol.js";

// --- Constants ---

export const CANVAS_W = 640;
export const CANVAS_H = 480;
export const ROTATION_SPEED = 0.05; // rad/frame
export const THRUST_ACCEL = 0.12;
export const MAX_SPEED = 6;
export const DRAG = 0.995;
export const MISSILE_SPEED = 8;
export const MAX_MISSILES = 3; // per player
export const MISSILE_LIFETIME = 90; // frames
export const MISSILE_COOLDOWN = 12; // frames
export const SHIP_RADIUS = 12;
export const MISSILE_RADIUS = 2;
export const WIN_SCORE = 7;
export const SPAWN_INVULN = 120; // frames
export const GRAVITY_CONSTANT = 800;
export const STAR_RADIUS = 15;
export const STAR_DANGER_RADIUS = 40;
export const STAR_X = CANVAS_W / 2;
export const STAR_Y = CANVAS_H / 2;
export const WARP_COOLDOWN = 180; // frames
export const WARP_DEATH_CHANCE = 0.2;
export const WARP_INVULN = 30; // frames
export const ASTEROID_COUNT = 8;
export const ASTEROID_MIN_RADIUS = 15;
export const ASTEROID_MAX_RADIUS = 30;

// --- Internal helpers ---

/**
 * Seeded PRNG (mulberry32).
 * @param {number} seed
 * @returns {function(): number} returns values in [0, 1)
 */
function mulberry32(seed) {
  return function () {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * Normalize an angle to [0, 2*PI).
 * @param {number} angle
 * @returns {number}
 */
function normalizeAngle(angle) {
  const TWO_PI = Math.PI * 2;
  let a = angle % TWO_PI;
  if (a < 0) a += TWO_PI;
  return a;
}

/**
 * Compute distance between two points.
 * @param {number} x1
 * @param {number} y1
 * @param {number} x2
 * @param {number} y2
 * @returns {number}
 */
function distance(x1, y1, x2, y2) {
  const dx = x1 - x2;
  const dy = y1 - y2;
  return Math.sqrt(dx * dx + dy * dy);
}

/**
 * Toroidal distance — accounts for wraparound edges.
 * @param {number} x1
 * @param {number} y1
 * @param {number} x2
 * @param {number} y2
 * @returns {number}
 */
function toroidalDistance(x1, y1, x2, y2) {
  let dx = Math.abs(x1 - x2);
  let dy = Math.abs(y1 - y2);
  if (dx > CANVAS_W / 2) dx = CANVAS_W - dx;
  if (dy > CANVAS_H / 2) dy = CANVAS_H - dy;
  return Math.sqrt(dx * dx + dy * dy);
}

/**
 * Wrap a coordinate to stay within canvas bounds.
 * Uses modulo for correctness with large velocities.
 * @param {number} val
 * @param {number} max
 * @returns {number}
 */
function wrap(val, max) {
  return ((val % max) + max) % max;
}

// --- Ship creation ---

/**
 * Create a default ship at the given position.
 * @param {number} x
 * @param {number} y
 * @param {number} rotation
 * @returns {object}
 */
function createShip(x, y, rotation) {
  return {
    x,
    y,
    vx: 0,
    vy: 0,
    rotation,
    alive: true,
    thrustActive: false,
    exploding: false,
    warping: false,
    invulnerable: true,
    invulnTimer: SPAWN_INVULN,
    fireCooldown: 0,
    warpCooldown: 0,
  };
}

// --- State creation ---

/**
 * Create the initial game state.
 * @param {number} mode - GAME_MODE enum value
 * @param {number|null} [seed=null] - optional PRNG seed (random if null)
 * @returns {object}
 */
export function createInitialState(mode, seed = null) {
  if (seed === null) seed = Math.floor(Math.random() * 65536);
  return {
    ship1: createShip(160, 240, 0),
    ship2: createShip(480, 240, Math.PI),
    missiles: [],
    asteroids: mode === GAME_MODE.DEBRIS_FIELD ? generateAsteroids(seed) : [],
    score1: 0,
    score2: 0,
    phase: PHASE.WAITING,
    countdown: 3,
    mode,
    asteroidSeed: mode === GAME_MODE.DEBRIS_FIELD ? seed : 0,
    particles: [],
  };
}

// --- Ship movement ---

/**
 * Update ship rotation based on left/right inputs.
 * @param {object} ship
 * @param {boolean} rotateLeft
 * @param {boolean} rotateRight
 * @returns {object} new ship
 */
export function updateShipRotation(ship, rotateLeft, rotateRight) {
  let { rotation } = ship;
  if (rotateLeft) rotation -= ROTATION_SPEED;
  if (rotateRight) rotation += ROTATION_SPEED;
  return { ...ship, rotation: normalizeAngle(rotation) };
}

/**
 * Apply thrust acceleration in the direction the ship is facing.
 * @param {object} ship
 * @returns {object} new ship
 */
export function applyThrust(ship) {
  if (!ship.thrustActive) return ship;
  return {
    ...ship,
    vx: ship.vx + Math.cos(ship.rotation) * THRUST_ACCEL,
    vy: ship.vy + Math.sin(ship.rotation) * THRUST_ACCEL,
  };
}

/**
 * Apply drag to ship velocity.
 * @param {object} ship
 * @returns {object} new ship
 */
export function applyDrag(ship) {
  return {
    ...ship,
    vx: ship.vx * DRAG,
    vy: ship.vy * DRAG,
  };
}

/**
 * Clamp ship speed to MAX_SPEED.
 * @param {object} ship
 * @returns {object} new ship
 */
export function capSpeed(ship) {
  const speed = Math.sqrt(ship.vx * ship.vx + ship.vy * ship.vy);
  if (speed <= MAX_SPEED) return ship;
  const ratio = MAX_SPEED / speed;
  return {
    ...ship,
    vx: ship.vx * ratio,
    vy: ship.vy * ratio,
  };
}

/**
 * Update ship position with wraparound.
 * @param {object} ship
 * @returns {object} new ship
 */
export function updateShipPosition(ship) {
  return {
    ...ship,
    x: wrap(ship.x + ship.vx, CANVAS_W),
    y: wrap(ship.y + ship.vy, CANVAS_H),
  };
}

// --- Missiles ---

/**
 * Fire a missile from a ship if cooldown allows and missile count is under limit.
 * @param {object} ship
 * @param {number} playerIndex - 1 or 2
 * @param {Array} missiles - current missiles array
 * @returns {{ship: object, missile: object}|null} new ship and missile, or null if can't fire
 */
export function fireMissile(ship, playerIndex, missiles) {
  if (ship.fireCooldown > 0) return null;

  const ownMissiles = missiles.filter((m) => m.owner === playerIndex);
  if (ownMissiles.length >= MAX_MISSILES) return null;

  const missile = {
    x: ship.x + Math.cos(ship.rotation) * SHIP_RADIUS,
    y: ship.y + Math.sin(ship.rotation) * SHIP_RADIUS,
    vx: Math.cos(ship.rotation) * MISSILE_SPEED + ship.vx,
    vy: Math.sin(ship.rotation) * MISSILE_SPEED + ship.vy,
    owner: playerIndex,
    age: 0,
  };

  const newShip = { ...ship, fireCooldown: MISSILE_COOLDOWN };

  return { ship: newShip, missile };
}

/**
 * Update all missiles: move, wraparound, age, and remove expired.
 * @param {Array} missiles
 * @returns {Array} updated missiles (alive only)
 */
export function updateMissiles(missiles) {
  return missiles
    .map((m) => ({
      ...m,
      x: wrap(m.x + m.vx, CANVAS_W),
      y: wrap(m.y + m.vy, CANVAS_H),
      age: m.age + 1,
    }))
    .filter((m) => m.age < MISSILE_LIFETIME);
}

// --- Cooldowns ---

/**
 * Tick down ship cooldowns and invulnerability timer.
 * @param {object} ship
 * @returns {object} new ship
 */
export function tickCooldowns(ship) {
  const fireCooldown = Math.max(0, ship.fireCooldown - 1);
  const warpCooldown = Math.max(0, ship.warpCooldown - 1);
  const invulnTimer = Math.max(0, ship.invulnTimer - 1);
  const invulnerable = invulnTimer > 0;

  return { ...ship, fireCooldown, warpCooldown, invulnTimer, invulnerable };
}

// --- Collisions ---

/**
 * Check if any enemy missile collides with a ship.
 * @param {Array} missiles
 * @param {object} ship
 * @param {number} shipIndex - 1 or 2 (owner index of this ship)
 * @returns {{hit: boolean, missiles: Array}} hit flag and filtered missiles
 */
export function checkMissileShipCollision(missiles, ship, shipIndex) {
  if (!ship.alive || ship.invulnerable) {
    return { hit: false, missiles };
  }

  let hit = false;
  const remaining = missiles.filter((m) => {
    if (m.owner === shipIndex) return true;
    const dist = toroidalDistance(m.x, m.y, ship.x, ship.y);
    if (dist < SHIP_RADIUS + MISSILE_RADIUS) {
      hit = true;
      return false;
    }
    return true;
  });

  return { hit, missiles: remaining };
}

/**
 * Check if two ships collide with each other.
 * @param {object} ship1
 * @param {object} ship2
 * @returns {boolean}
 */
export function checkShipShipCollision(ship1, ship2) {
  if (!ship1.alive || !ship2.alive) return false;
  if (ship1.invulnerable || ship2.invulnerable) return false;
  return toroidalDistance(ship1.x, ship1.y, ship2.x, ship2.y) < SHIP_RADIUS * 2;
}

// --- Warp ---

/**
 * Attempt a hyperspace warp. Random destination with a chance of death.
 * @param {object} ship
 * @param {function} randomFn - returns a value in [0, 1)
 * @returns {{ship: object, died: boolean}|null} null if warp is on cooldown or ship is dead/exploding
 */
export function attemptWarp(ship, randomFn) {
  if (!ship.alive || ship.exploding) return null;
  if (ship.warpCooldown > 0) return null;

  const died = randomFn() < WARP_DEATH_CHANCE;
  const newShip = {
    ...ship,
    x: randomFn() * CANVAS_W,
    y: randomFn() * CANVAS_H,
    warpCooldown: WARP_COOLDOWN,
    warping: true,
    alive: !died,
    exploding: died,
    invulnerable: !died,
    invulnTimer: died ? 0 : WARP_INVULN,
  };

  return { ship: newShip, died };
}

// --- Respawn ---

/**
 * Reset both ships to initial spawn positions with invulnerability.
 * Preserves scores, mode, asteroids, and other game state.
 * @param {object} state
 * @returns {object} new state
 */
export function spawnShips(state) {
  return {
    ...state,
    ship1: createShip(160, 240, 0),
    ship2: createShip(480, 240, Math.PI),
    missiles: [],
    particles: [],
  };
}

// --- Gravity Well mode ---

/**
 * Apply gravitational pull from a star toward a ship.
 * F = GRAVITY_CONSTANT / r^2, applied as acceleration toward the star.
 * @param {object} ship
 * @param {number} starX
 * @param {number} starY
 * @returns {object} new ship
 */
export function applyGravity(ship, starX, starY) {
  const dx = starX - ship.x;
  const dy = starY - ship.y;
  const distSq = dx * dx + dy * dy;
  const dist = Math.sqrt(distSq);

  if (dist < 1) return ship;

  const force = Math.min(GRAVITY_CONSTANT / distSq, MAX_SPEED);
  const ax = (dx / dist) * force;
  const ay = (dy / dist) * force;

  return {
    ...ship,
    vx: ship.vx + ax,
    vy: ship.vy + ay,
  };
}

/**
 * Apply gravitational pull to a missile (Gravity Well mode).
 * Same physics as ship gravity but without any guard beyond dist < 1.
 * @param {object} missile - {x, y, vx, vy, ...}
 * @param {number} starX
 * @param {number} starY
 * @returns {object} new missile
 */
export function applyGravityToMissile(missile, starX, starY) {
  const dx = starX - missile.x;
  const dy = starY - missile.y;
  const distSq = dx * dx + dy * dy;
  const dist = Math.sqrt(distSq);
  if (dist < 1) return missile;
  const force = Math.min(GRAVITY_CONSTANT / distSq, MAX_SPEED);
  const ax = (dx / dist) * force;
  const ay = (dy / dist) * force;
  return { ...missile, vx: missile.vx + ax, vy: missile.vy + ay };
}

/**
 * Check if a ship has collided with the central star.
 * @param {object} ship
 * @returns {boolean}
 */
export function checkStarCollision(ship) {
  if (!ship.alive || ship.invulnerable) return false;
  return toroidalDistance(ship.x, ship.y, STAR_X, STAR_Y) < STAR_DANGER_RADIUS;
}

// --- Debris Field mode ---

/**
 * Generate asteroids deterministically from a seed.
 * Each asteroid has a center position, radius, and jagged polygon vertices.
 * Asteroids avoid ship spawn points at (160,240) and (480,240).
 * @param {number} seed
 * @returns {Array<{x: number, y: number, radius: number, vertices: Array<{x: number, y: number}>}>}
 */
export function generateAsteroids(seed) {
  const rng = mulberry32(seed);
  const asteroids = [];
  const spawnPoints = [
    { x: 160, y: 240 },
    { x: 480, y: 240 },
  ];
  const minSpawnDist = 80;

  let attempts = 0;
  while (asteroids.length < ASTEROID_COUNT && attempts < 500) {
    attempts++;
    const x = rng() * CANVAS_W;
    const y = rng() * CANVAS_H;
    const radius = ASTEROID_MIN_RADIUS + rng() * (ASTEROID_MAX_RADIUS - ASTEROID_MIN_RADIUS);

    // Check distance from spawn points
    const tooClose = spawnPoints.some((sp) => distance(x, y, sp.x, sp.y) < minSpawnDist + radius);
    if (tooClose) continue;

    // Check overlap with existing asteroids
    const overlaps = asteroids.some((a) => distance(x, y, a.x, a.y) < radius + a.radius + 4);
    if (overlaps) continue;

    // Generate jagged polygon vertices
    const vertexCount = 8 + Math.floor(rng() * 5); // 8-12 vertices
    const vertices = [];
    for (let i = 0; i < vertexCount; i++) {
      const angle = (i / vertexCount) * Math.PI * 2;
      const variation = 0.7 + rng() * 0.6; // ±30% radius variation
      const r = radius * variation;
      vertices.push({
        x: Math.cos(angle) * r,
        y: Math.sin(angle) * r,
      });
    }

    asteroids.push({ x, y, radius, vertices });
  }

  return asteroids;
}

/**
 * Check if a ship collides with any asteroid (circle-circle).
 * @param {object} ship
 * @param {Array} asteroids
 * @returns {boolean}
 */
export function checkAsteroidShipCollision(ship, asteroids) {
  if (!ship.alive || ship.invulnerable) return false;
  return asteroids.some((a) => toroidalDistance(ship.x, ship.y, a.x, a.y) < SHIP_RADIUS + a.radius);
}

/**
 * Filter out missiles that collide with asteroids.
 * @param {Array} missiles
 * @param {Array} asteroids
 * @returns {Array} missiles that did not hit any asteroid
 */
export function checkAsteroidMissileCollision(missiles, asteroids) {
  return missiles.filter(
    (m) => !asteroids.some((a) => toroidalDistance(m.x, m.y, a.x, a.y) < MISSILE_RADIUS + a.radius),
  );
}

// --- Particles ---

/**
 * Generate explosion particles at a position.
 * @param {number} x - origin x
 * @param {number} y - origin y
 * @param {number} [count=15] - number of particles
 * @param {function} [randomFn=Math.random] - random number generator
 * @returns {Array} particle array
 */
export function createExplosionParticles(x, y, count = 15, randomFn = Math.random) {
  const particles = [];
  for (let i = 0; i < count; i++) {
    const angle = randomFn() * Math.PI * 2;
    const speed = 1 + randomFn() * 4;
    particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life: 1.0,
    });
  }
  return particles;
}

/**
 * Update particles (decay + move).
 * @param {Array} particles
 * @returns {Array} updated particles (alive only)
 */
export function updateParticles(particles) {
  return particles
    .map((p) => ({
      ...p,
      x: p.x + p.vx,
      y: p.y + p.vy,
      vx: p.vx * 0.96,
      vy: p.vy * 0.96,
      life: p.life - 0.03,
    }))
    .filter((p) => p.life > 0);
}
