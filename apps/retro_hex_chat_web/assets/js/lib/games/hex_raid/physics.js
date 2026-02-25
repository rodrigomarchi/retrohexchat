/**
 * Pure physics and game logic for Hex Raid (River Raid 2P).
 * All functions are pure — no side effects, no DOM, no network.
 *
 * Architecture: continuous infinite scrolling with screen-space entities.
 * - scrollY is a monotonically increasing counter (total distance traveled)
 * - All entities (enemies, fuel, bridges) live in screen coordinates
 * - Entities drift downward each frame by scrollDelta
 * - Banks are computed on-the-fly from getBankAtWorld(worldY, seed)
 * - Difficulty scales with scrollY (total distance)
 *
 * @module games/hex_raid_physics
 */

import { PHASE, GAME_MODE, ENEMY_TYPE, MAX_ENEMIES, MAX_FUEL } from "./protocol.js";

// --- Canvas ---
export const CANVAS_W = 640;
export const CANVAS_H = 480;

// --- Jet ---
export const JET_RADIUS = 6;
export const JET_LATERAL_SPEED = 3.0;
export const INITIAL_LIVES = 3;
export const INITIAL_FUEL = 255;

// Speed levels (pixels per frame of scroll)
export const SPEED_MIN = 1;
export const SPEED_BASE = 2;
export const SPEED_MAX = 4;

// --- Missile ---
export const MISSILE_SPEED = 6;
export const MISSILE_COOLDOWN = 20; // frames
export const MISSILE_RADIUS = 3;

// --- Mine ---
export const MINE_RADIUS = 5;
export const MAX_MINES_PER_PLAYER = 2;
export const MINE_COOLDOWN_DUEL = 300; // 5s at 60fps
export const MINE_COOLDOWN_BLITZ = 180; // 3s at 60fps

// --- Bridge ---
export const BRIDGE_HP = 3;
export const BRIDGE_HEIGHT = 8;

// --- Fuel ---
export const FUEL_DRAIN_SLOW = 8; // drain 1 unit every N frames at min speed
export const FUEL_DRAIN_BASE = 4;
export const FUEL_DRAIN_FAST = 2;
export const FUEL_REFILL = 80; // how much fuel a station gives

// --- Respawn ---
export const RESPAWN_DELAY = 180; // 3s at 60fps
export const INVULN_DURATION = 180; // 3s

// --- Scoring ---
export const SCORE_BOAT = 30;
export const SCORE_HELI = 60;
export const SCORE_JET = 100;
export const SCORE_FUEL_DESTROYED = 80;
export const SCORE_BRIDGE = 500;
export const SCORE_MINE_HIT = 200;
export const SCORE_FUEL_OUT = 150;

// --- River geometry ---
export const RIVER_MIN_WIDTH = 200;
export const RIVER_MAX_WIDTH = 420;
const BANK_SEGMENT_SIZE = 100; // pixels per bank control segment

// --- Spawn intervals (base values, adjusted by difficulty) ---
const ENEMY_SPAWN_BASE = 140; // scroll pixels between enemy spawns
const ENEMY_SPAWN_MIN = 60;
const FUEL_SPAWN_BASE = 500;
const FUEL_SPAWN_MAX = 900;
const BRIDGE_SPAWN_INTERVAL = 2000;
// Initial gap before first bridge/enemies
const INITIAL_SAFE_ZONE = 300;

// --- Seeded PRNG (mulberry32) ---

/**
 * Create a seeded PRNG using mulberry32.
 * @param {number} seed - Uint32 seed
 * @returns {function(): number} Returns 0-1 float
 */
export function mulberry32(seed) {
  let s = seed | 0;
  return () => {
    s = (s + 0x6d2b79f5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// --- Difficulty ---

/**
 * Get difficulty parameters based on total scroll distance.
 * @param {number} scrollY - total distance scrolled
 * @param {number} mode - GAME_MODE enum
 * @returns {{enemyInterval: number, fuelInterval: number, enemySpeed: number, riverWidth: number}}
 */
export function getDifficulty(scrollY, mode) {
  const dist = mode === GAME_MODE.BLITZ ? scrollY + 5000 : scrollY;

  // Difficulty ramp: 0→1 over ~25000px
  const t = Math.min(dist / 25000, 1);

  return {
    enemyInterval: ENEMY_SPAWN_BASE - t * (ENEMY_SPAWN_BASE - ENEMY_SPAWN_MIN),
    fuelInterval: FUEL_SPAWN_BASE + t * (FUEL_SPAWN_MAX - FUEL_SPAWN_BASE),
    enemySpeed: 1.0 + t * 1.5,
    riverWidth: RIVER_MAX_WIDTH - t * (RIVER_MAX_WIDTH - RIVER_MIN_WIDTH),
  };
}

/**
 * Get river width at a given scroll position.
 * @param {number} scrollY - total distance
 * @param {number} mode - GAME_MODE enum
 * @returns {number} river width in pixels
 */
export function getRiverWidthAtScroll(scrollY, mode) {
  return getDifficulty(scrollY, mode).riverWidth;
}

// --- River bank generation (deterministic, on-the-fly) ---

/**
 * Get river bank edges at any world Y position.
 * Pure function — deterministic from worldY + seed.
 * Uses segment-based PRNG with interpolation for smooth banks.
 * @param {number} worldY - absolute world Y position
 * @param {number} seed - shared game seed
 * @param {number} mode - GAME_MODE enum
 * @returns {{leftX: number, rightX: number}}
 */
export function getBankAtWorld(worldY, seed, mode) {
  const segIndex = Math.floor(worldY / BANK_SEGMENT_SIZE);
  const segFrac = (worldY % BANK_SEGMENT_SIZE) / BANK_SEGMENT_SIZE;

  // Deterministic RNG for this segment and next
  const rng0 = mulberry32(seed + segIndex * 7919);
  const rng1 = mulberry32(seed + (segIndex + 1) * 7919);

  // Width narrows with distance
  const width = getRiverWidthAtScroll(worldY, mode);
  const wobble = Math.max(10, 40 - worldY * 0.001);
  const offset0 = (rng0() - 0.5) * wobble;
  const offset1 = (rng1() - 0.5) * wobble;

  // Smooth interpolation between segment boundaries
  const offset = offset0 + segFrac * (offset1 - offset0);
  const centerX = CANVAS_W / 2;
  const halfWidth = width / 2;

  return {
    leftX: centerX - halfWidth + offset,
    rightX: centerX + halfWidth + offset,
  };
}

// --- Spawn system ---

/**
 * Determine enemy type based on distance and RNG roll.
 * @param {number} scrollY - total distance
 * @param {number} roll - 0-1 random value
 * @param {number} mode - GAME_MODE enum
 * @returns {number} ENEMY_TYPE enum
 */
function pickEnemyType(scrollY, roll, mode) {
  const dist = mode === GAME_MODE.BLITZ ? scrollY + 5000 : scrollY;

  if (dist >= 8000 && roll < 0.3) return ENEMY_TYPE.JET;
  if (dist >= 3000 && roll < 0.5) return ENEMY_TYPE.HELI;
  return ENEMY_TYPE.BOAT;
}

/**
 * Spawn new entities as scrollY advances past thresholds.
 * Entities spawn at y = -20 (just above screen top) with screen-space coords.
 * @param {object} state
 * @returns {object} updated state with new entities
 */
export function spawnEntities(state) {
  if (state.phase !== PHASE.FLYING) return state;

  let s = { ...state };
  const diff = getDifficulty(s.scrollY, s.mode);

  // --- Spawn enemies ---
  while (s.scrollY >= s.nextEnemySpawnDist && s.enemies.length < MAX_ENEMIES) {
    const rng = mulberry32(s.seed + Math.floor(s.nextEnemySpawnDist) * 31);
    const worldYAtTop = s.scrollY + CANVAS_H;
    const bank = getBankAtWorld(worldYAtTop, s.seed, s.mode);
    const margin = 25;
    const riverW = bank.rightX - bank.leftX - margin * 2;

    // Spawn 1-3 enemies per row depending on difficulty
    const count = Math.min(
      MAX_ENEMIES - s.enemies.length,
      1 + Math.floor(rng() * Math.min(3, 1 + s.scrollY / 8000)),
    );

    const newEnemies = [...s.enemies];
    for (let i = 0; i < count; i++) {
      const roll = rng();
      const type = pickEnemyType(s.scrollY, roll, s.mode);
      const x = bank.leftX + margin + rng() * Math.max(riverW, 50);
      const speed =
        type === ENEMY_TYPE.JET
          ? 0
          : type === ENEMY_TYPE.HELI
            ? 2.0 * diff.enemySpeed
            : 1.0 * diff.enemySpeed;
      const vx = (rng() > 0.5 ? 1 : -1) * speed;

      newEnemies.push({
        type,
        x,
        y: -15 - i * 20, // stagger slightly above screen
        alive: true,
        vx,
      });
    }

    s = {
      ...s,
      enemies: newEnemies,
      enemyCount: newEnemies.length,
      nextEnemySpawnDist: s.nextEnemySpawnDist + diff.enemyInterval,
    };
  }

  // --- Spawn fuel depots ---
  while (s.scrollY >= s.nextFuelSpawnDist && s.fuels.filter((f) => f.available).length < MAX_FUEL) {
    const rng = mulberry32(s.seed + Math.floor(s.nextFuelSpawnDist) * 53);
    const worldYAtTop = s.scrollY + CANVAS_H;
    const bank = getBankAtWorld(worldYAtTop, s.seed, s.mode);
    const margin = 30;
    const x = bank.leftX + margin + rng() * Math.max(bank.rightX - bank.leftX - margin * 2, 40);

    const newFuels = [...s.fuels.filter((f) => f.available), { x, y: -10, available: true }];
    s = {
      ...s,
      fuels: newFuels,
      fuelCount: newFuels.length,
      nextFuelSpawnDist: s.nextFuelSpawnDist + diff.fuelInterval,
    };
  }

  // --- Spawn bridge ---
  if (!s.bridgeActive && s.scrollY >= s.nextBridgeSpawnDist) {
    s = {
      ...s,
      bridgeY: -10,
      bridgeHp: BRIDGE_HP,
      bridgeActive: true,
      nextBridgeSpawnDist: s.nextBridgeSpawnDist + BRIDGE_SPAWN_INTERVAL,
    };
  }

  return s;
}

/**
 * Get mine cooldown for a game mode.
 * @param {number} mode
 * @returns {number} cooldown in frames
 */
export function getMineCooldown(mode) {
  if (mode === GAME_MODE.PACIFIST) return Infinity;
  return mode === GAME_MODE.BLITZ ? MINE_COOLDOWN_BLITZ : MINE_COOLDOWN_DUEL;
}

/**
 * Create initial game state.
 * @param {number} mode - GAME_MODE enum
 * @param {number} seed - shared seed
 * @returns {object}
 */
export function createInitialState(mode, seed) {
  return {
    // Jet 1 (host/P1)
    jet1X: CANVAS_W / 2 - 30,
    jet1Y: CANVAS_H - 60,
    jet1Speed: SPEED_BASE,
    jet1Fuel: INITIAL_FUEL,
    jet1Lives: INITIAL_LIVES,
    jet1Alive: true,
    jet1Invuln: false,
    jet1Respawning: false,
    jet1InvulnTimer: 0,
    jet1RespawnTimer: 0,
    jet1MissileCooldown: 0,
    jet1MineCooldown: 0,

    // Jet 2 (peer/P2)
    jet2X: CANVAS_W / 2 + 30,
    jet2Y: CANVAS_H - 60,
    jet2Speed: SPEED_BASE,
    jet2Fuel: INITIAL_FUEL,
    jet2Lives: INITIAL_LIVES,
    jet2Alive: true,
    jet2Invuln: false,
    jet2Respawning: false,
    jet2InvulnTimer: 0,
    jet2RespawnTimer: 0,
    jet2MissileCooldown: 0,
    jet2MineCooldown: 0,

    // Missiles
    m1X: 0,
    m1Y: 0,
    m1Active: false,
    m2X: 0,
    m2Y: 0,
    m2Active: false,

    // Entities (screen-space, populated by spawnEntities)
    enemies: [],
    enemyCount: 0,
    fuels: [],
    fuelCount: 0,
    mines: [],
    mineCount: 0,

    // Bridge (single bridge at a time)
    bridgeY: 0,
    bridgeHp: 0,
    bridgeActive: false,

    // Meta
    score1: 0,
    score2: 0,
    phase: PHASE.WAITING,
    countdown: 3,
    section: 0, // repurposed as distance milestone (scrollY / 2000)
    scrollY: 0,
    mode,
    seed,

    // Spawn thresholds (host only, not serialized)
    nextEnemySpawnDist: INITIAL_SAFE_ZONE,
    nextFuelSpawnDist: INITIAL_SAFE_ZONE + 200,
    nextBridgeSpawnDist: BRIDGE_SPAWN_INTERVAL,

    // Event flags (host only, cleared each frame)
    events: {
      enemyKill: 0, // player who killed: 0=none, 1=P1, 2=P2
      enemyKillType: 0,
      fuelCapture: 0,
      fuelDestroyed: false,
      bridgeHit: false,
      bridgeDestroyed: 0, // player who destroyed: 0=none
      mineDeployed: 0,
      mineHit: 0, // player who got hit
      death: 0, // player who died
      fuelEmpty: 0, // player whose fuel ran out
      killSteal: false,
    },
  };
}

// --- Movement ---

/**
 * Move a jet laterally.
 * @param {object} state
 * @param {number} player - 1 or 2
 * @param {number} direction - -1 (left) or 1 (right)
 * @returns {object}
 */
export function moveJet(state, player, direction) {
  const xKey = player === 1 ? "jet1X" : "jet2X";
  const aliveKey = player === 1 ? "jet1Alive" : "jet2Alive";

  if (!state[aliveKey]) return state;

  const newX = state[xKey] + direction * JET_LATERAL_SPEED;
  return { ...state, [xKey]: Math.max(0, Math.min(CANVAS_W, newX)) };
}

/**
 * Accelerate or decelerate a jet.
 * @param {object} state
 * @param {number} player - 1 or 2
 * @param {number} delta - +1 to accelerate, -1 to decelerate
 * @returns {object}
 */
export function accelerateJet(state, player, delta) {
  const key = player === 1 ? "jet1Speed" : "jet2Speed";
  const aliveKey = player === 1 ? "jet1Alive" : "jet2Alive";

  if (!state[aliveKey]) return state;

  const newSpeed = Math.max(SPEED_MIN, Math.min(SPEED_MAX, state[key] + delta));
  return { ...state, [key]: newSpeed };
}

// --- Missiles ---

/**
 * Fire a missile from a jet.
 * @param {object} state
 * @param {number} player - 1 or 2
 * @returns {object}
 */
export function fireMissile(state, player) {
  const prefix = player === 1 ? "m1" : "m2";
  const jetPrefix = player === 1 ? "jet1" : "jet2";
  const cdKey = `${jetPrefix}MissileCooldown`;

  if (!state[`${jetPrefix}Alive`]) return state;
  if (state[`${prefix}Active`]) return state;
  if (state[cdKey] > 0) return state;

  return {
    ...state,
    [`${prefix}X`]: state[`${jetPrefix}X`],
    [`${prefix}Y`]: state[`${jetPrefix}Y`],
    [`${prefix}Active`]: true,
    [cdKey]: MISSILE_COOLDOWN,
  };
}

/**
 * Update missiles (travel upward in screen space).
 * @param {object} state
 * @returns {object}
 */
export function updateMissiles(state) {
  const s = { ...state };

  if (s.m1Active) {
    s.m1Y -= MISSILE_SPEED;
    if (s.m1Y < 0) s.m1Active = false;
  }

  if (s.m2Active) {
    s.m2Y -= MISSILE_SPEED;
    if (s.m2Y < 0) s.m2Active = false;
  }

  return s;
}

// --- Mines ---

/**
 * Deploy a mine at a jet's position.
 * @param {object} state
 * @param {number} player - 1 or 2
 * @returns {object}
 */
export function deployMine(state, player) {
  if (state.mode === GAME_MODE.PACIFIST) return state;

  const jetPrefix = player === 1 ? "jet1" : "jet2";
  const cdKey = `${jetPrefix}MineCooldown`;

  if (!state[`${jetPrefix}Alive`]) return state;
  if (state[cdKey] > 0) return state;

  const playerMines = state.mines.filter((m) => m.active && m.owner === player);
  if (playerMines.length >= MAX_MINES_PER_PLAYER) return state;

  const mine = {
    x: state[`${jetPrefix}X`],
    y: state[`${jetPrefix}Y`] + 20,
    owner: player,
    active: true,
  };

  const cooldown = getMineCooldown(state.mode);

  return {
    ...state,
    mines: [...state.mines, mine],
    mineCount: state.mineCount + 1,
    [cdKey]: cooldown,
    events: { ...state.events, mineDeployed: player },
  };
}

/**
 * Update mines (drift downward with scroll).
 * @param {object} state
 * @param {number} scrollDelta - how much scroll moved this frame
 * @returns {object}
 */
export function updateMines(state, scrollDelta) {
  if (state.mines.length === 0) return state;

  const mines = state.mines
    .map((m) => (m.active ? { ...m, y: m.y + scrollDelta * 0.5 } : m))
    .filter((m) => m.active && m.y < CANVAS_H + 50);

  return { ...state, mines, mineCount: mines.length };
}

// --- Enemies ---

/**
 * Update enemy positions.
 * Entities are in screen-space; they drift downward by scrollDelta each frame.
 * Boats/helis move laterally, enemy jets rush downward faster.
 * @param {object} state
 * @param {number} scrollDelta - pixels scrolled this frame
 * @returns {object}
 */
export function updateEnemies(state, scrollDelta) {
  if (state.enemyCount === 0) return state;

  const enemies = state.enemies.map((e) => {
    if (!e.alive) return e;

    // Drift down with scroll
    let newY = e.y + scrollDelta;
    let newX = e.x + (e.vx || 0);

    // Bounce off river boundaries
    const worldY = state.scrollY + (CANVAS_H - e.y);
    const bank = getBankAtWorld(worldY, state.seed, state.mode);
    if (newX < bank.leftX + 20 || newX > bank.rightX - 20) {
      newX = e.x;
      return { ...e, x: newX, y: newY, vx: -(e.vx || 0) };
    }

    // Enemy jets rush downward (toward player)
    if (e.type === ENEMY_TYPE.JET) {
      newY += 3;
    }

    return { ...e, x: newX, y: newY };
  });

  // Remove enemies that scrolled off-screen below
  const visible = enemies.filter((e) => e.alive && e.y < CANVAS_H + 50);

  return {
    ...state,
    enemies: visible,
    enemyCount: visible.length,
  };
}

// --- Scroll ---

/**
 * Update scroll position based on fastest player's speed.
 * Also updates the section display value (distance milestone).
 * @param {object} state
 * @returns {{state: object, scrollDelta: number}}
 */
export function updateScroll(state) {
  const speed1 = state.jet1Alive ? state.jet1Speed : 0;
  const speed2 = state.jet2Alive ? state.jet2Speed : 0;
  const scrollDelta = Math.max(speed1, speed2, SPEED_MIN);

  const newScrollY = state.scrollY + scrollDelta;
  return {
    state: {
      ...state,
      scrollY: newScrollY,
      section: Math.floor(newScrollY / 2000), // distance milestone for HUD
    },
    scrollDelta,
  };
}

// --- Fuel ---

/**
 * Drain fuel from both jets based on their speed.
 * @param {object} state
 * @param {number} frameCount - for modulo-based drain rate
 * @returns {object}
 */
export function drainFuel(state, frameCount) {
  let s = { ...state };
  const events = { ...s.events };

  for (const player of [1, 2]) {
    const fuelKey = player === 1 ? "jet1Fuel" : "jet2Fuel";
    const speedKey = player === 1 ? "jet1Speed" : "jet2Speed";
    const aliveKey = player === 1 ? "jet1Alive" : "jet2Alive";

    if (!s[aliveKey]) continue;

    const drainRate =
      s[speedKey] >= SPEED_MAX
        ? FUEL_DRAIN_FAST
        : s[speedKey] <= SPEED_MIN
          ? FUEL_DRAIN_SLOW
          : FUEL_DRAIN_BASE;

    if (frameCount % drainRate === 0) {
      const newFuel = s[fuelKey] - 1;
      if (newFuel <= 0) {
        s = { ...s, [fuelKey]: 0 };
        events.fuelEmpty = player;
      } else {
        s = { ...s, [fuelKey]: newFuel };
      }
    }
  }

  return { ...s, events };
}

// --- Collision detection ---

/**
 * Check if a jet collides with river banks.
 * @param {object} state
 * @param {number} player - 1 or 2
 * @returns {boolean}
 */
export function checkRiverCollision(state, player) {
  const xKey = player === 1 ? "jet1X" : "jet2X";
  const yKey = player === 1 ? "jet1Y" : "jet2Y";
  const aliveKey = player === 1 ? "jet1Alive" : "jet2Alive";
  const invulnKey = player === 1 ? "jet1Invuln" : "jet2Invuln";

  if (!state[aliveKey] || state[invulnKey]) return false;

  // Convert screen Y to world Y for bank lookup
  const worldY = state.scrollY + (CANVAS_H - state[yKey]);
  const bank = getBankAtWorld(worldY, state.seed, state.mode);
  const x = state[xKey];

  return x - JET_RADIUS < bank.leftX || x + JET_RADIUS > bank.rightX;
}

/**
 * Check missile-enemy collisions.
 * All entities are in screen space — direct comparison.
 * @param {object} state
 * @returns {object}
 */
export function checkMissileHits(state) {
  let s = { ...state };
  const events = { ...s.events };
  const enemies = [...s.enemies];

  for (const mNum of [1, 2]) {
    const prefix = mNum === 1 ? "m1" : "m2";
    if (!s[`${prefix}Active`]) continue;

    const mx = s[`${prefix}X`];
    const my = s[`${prefix}Y`];

    for (let i = 0; i < enemies.length; i++) {
      if (!enemies[i].alive) continue;

      const dx = mx - enemies[i].x;
      const dy = my - enemies[i].y;
      const hitDist = MISSILE_RADIUS + 8;

      if (dx * dx + dy * dy < hitDist * hitDist) {
        enemies[i] = { ...enemies[i], alive: false };
        s = { ...s, [`${prefix}Active`]: false };

        const scoreKey = mNum === 1 ? "score1" : "score2";
        let points = 0;
        if (enemies[i].type === ENEMY_TYPE.BOAT) points = SCORE_BOAT;
        else if (enemies[i].type === ENEMY_TYPE.HELI) points = SCORE_HELI;
        else if (enemies[i].type === ENEMY_TYPE.JET) points = SCORE_JET;

        s = { ...s, [scoreKey]: s[scoreKey] + points };
        events.enemyKill = mNum;
        events.enemyKillType = enemies[i].type;
        break;
      }
    }
  }

  return { ...s, enemies, events };
}

/**
 * Check missile-bridge collisions.
 * @param {object} state
 * @returns {object}
 */
export function checkBridgeHits(state) {
  if (!state.bridgeActive) return state;

  let s = { ...state };
  const events = { ...s.events };

  for (const mNum of [1, 2]) {
    const prefix = mNum === 1 ? "m1" : "m2";
    if (!s[`${prefix}Active`]) continue;

    const my = s[`${prefix}Y`];

    if (Math.abs(my - s.bridgeY) < BRIDGE_HEIGHT) {
      s = { ...s, [`${prefix}Active`]: false };
      const newHp = s.bridgeHp - 1;
      events.bridgeHit = true;

      if (newHp <= 0) {
        const scoreKey = mNum === 1 ? "score1" : "score2";
        s = {
          ...s,
          bridgeHp: 0,
          bridgeActive: false,
          [scoreKey]: s[scoreKey] + SCORE_BRIDGE,
        };
        events.bridgeDestroyed = mNum;
      } else {
        s = { ...s, bridgeHp: newHp };
      }
      break;
    }
  }

  return { ...s, events };
}

/**
 * Check jet-enemy collisions.
 * @param {object} state
 * @returns {object}
 */
export function checkEnemyCollisions(state) {
  const s = { ...state };
  const events = { ...s.events };

  for (const player of [1, 2]) {
    const xKey = player === 1 ? "jet1X" : "jet2X";
    const yKey = player === 1 ? "jet1Y" : "jet2Y";
    const aliveKey = player === 1 ? "jet1Alive" : "jet2Alive";
    const invulnKey = player === 1 ? "jet1Invuln" : "jet2Invuln";

    if (!s[aliveKey] || s[invulnKey]) continue;

    for (const e of s.enemies) {
      if (!e.alive) continue;
      const dx = s[xKey] - e.x;
      const dy = s[yKey] - e.y;
      const hitDist = JET_RADIUS + 8;

      if (dx * dx + dy * dy < hitDist * hitDist) {
        events.death = player;
        break;
      }
    }
  }

  return { ...s, events };
}

/**
 * Check fuel station captures.
 * @param {object} state
 * @returns {object}
 */
export function checkFuelCapture(state) {
  let s = { ...state };
  const events = { ...s.events };
  const fuels = [...s.fuels];

  for (let i = 0; i < fuels.length; i++) {
    if (!fuels[i].available) continue;

    for (const player of [1, 2]) {
      const xKey = player === 1 ? "jet1X" : "jet2X";
      const yKey = player === 1 ? "jet1Y" : "jet2Y";
      const aliveKey = player === 1 ? "jet1Alive" : "jet2Alive";
      const fuelKey = player === 1 ? "jet1Fuel" : "jet2Fuel";

      if (!s[aliveKey]) continue;

      const dx = s[xKey] - fuels[i].x;
      const dy = s[yKey] - fuels[i].y;

      if (dx * dx + dy * dy < 15 * 15) {
        fuels[i] = { ...fuels[i], available: false };
        const newFuel = Math.min(255, s[fuelKey] + FUEL_REFILL);
        s = { ...s, [fuelKey]: newFuel };
        events.fuelCapture = player;
        break;
      }
    }
  }

  // Check missile hits on fuel stations
  for (let i = 0; i < fuels.length; i++) {
    if (!fuels[i].available) continue;

    for (const mNum of [1, 2]) {
      const prefix = mNum === 1 ? "m1" : "m2";
      if (!s[`${prefix}Active`]) continue;

      const dx = s[`${prefix}X`] - fuels[i].x;
      const dy = s[`${prefix}Y`] - fuels[i].y;

      if (dx * dx + dy * dy < 12 * 12) {
        fuels[i] = { ...fuels[i], available: false };
        s = { ...s, [`${prefix}Active`]: false };
        const scoreKey = mNum === 1 ? "score1" : "score2";
        s = { ...s, [scoreKey]: s[scoreKey] + SCORE_FUEL_DESTROYED };
        events.fuelDestroyed = true;
        break;
      }
    }
  }

  return { ...s, fuels, events };
}

/**
 * Check mine-jet collisions.
 * @param {object} state
 * @returns {object}
 */
export function checkMineCollisions(state) {
  if (state.mineCount === 0) return state;

  let s = { ...state };
  const events = { ...s.events };
  let mines = [...s.mines];

  for (const player of [1, 2]) {
    const xKey = player === 1 ? "jet1X" : "jet2X";
    const yKey = player === 1 ? "jet1Y" : "jet2Y";
    const aliveKey = player === 1 ? "jet1Alive" : "jet2Alive";
    const invulnKey = player === 1 ? "jet1Invuln" : "jet2Invuln";

    if (!s[aliveKey] || s[invulnKey]) continue;

    for (let i = 0; i < mines.length; i++) {
      if (!mines[i].active) continue;
      if (mines[i].owner === player) continue;

      const dx = s[xKey] - mines[i].x;
      const dy = s[yKey] - mines[i].y;
      const hitDist = JET_RADIUS + MINE_RADIUS;

      if (dx * dx + dy * dy < hitDist * hitDist) {
        mines[i] = { ...mines[i], active: false };
        events.mineHit = player;
        events.death = player;

        const ownerScoreKey = mines[i].owner === 1 ? "score1" : "score2";
        s = { ...s, [ownerScoreKey]: s[ownerScoreKey] + SCORE_MINE_HIT };
        break;
      }
    }
  }

  mines = mines.filter((m) => m.active);
  return { ...s, mines, mineCount: mines.length, events };
}

/**
 * Check bridge collision (jet hitting intact bridge).
 * @param {object} state
 * @returns {object}
 */
export function checkBridgeCollision(state) {
  if (!state.bridgeActive) return state;

  const s = { ...state };
  const events = { ...s.events };

  for (const player of [1, 2]) {
    const yKey = player === 1 ? "jet1Y" : "jet2Y";
    const aliveKey = player === 1 ? "jet1Alive" : "jet2Alive";
    const invulnKey = player === 1 ? "jet1Invuln" : "jet2Invuln";

    if (!s[aliveKey] || s[invulnKey]) continue;

    if (Math.abs(s[yKey] - s.bridgeY) < BRIDGE_HEIGHT + JET_RADIUS) {
      events.death = player;
    }
  }

  return { ...s, events };
}

// --- Death and respawn ---

/**
 * Handle player death.
 * @param {object} state
 * @param {number} player - 1 or 2
 * @returns {object}
 */
export function handleDeath(state, player) {
  const livesKey = player === 1 ? "jet1Lives" : "jet2Lives";
  const aliveKey = player === 1 ? "jet1Alive" : "jet2Alive";
  const respawnKey = player === 1 ? "jet1Respawning" : "jet2Respawning";
  const respawnTimerKey = player === 1 ? "jet1RespawnTimer" : "jet2RespawnTimer";

  const newLives = state[livesKey] - 1;

  return {
    ...state,
    [livesKey]: newLives,
    [aliveKey]: false,
    [respawnKey]: newLives > 0,
    [respawnTimerKey]: newLives > 0 ? RESPAWN_DELAY : 0,
  };
}

/**
 * Process respawn timers. Respawn at center bottom.
 * @param {object} state
 * @returns {object}
 */
export function processRespawns(state) {
  let s = { ...state };

  for (const player of [1, 2]) {
    const respawnKey = player === 1 ? "jet1Respawning" : "jet2Respawning";
    const timerKey = player === 1 ? "jet1RespawnTimer" : "jet2RespawnTimer";

    if (!s[respawnKey]) continue;

    if (s[timerKey] > 0) {
      s = { ...s, [timerKey]: s[timerKey] - 1 };
      continue;
    }

    const aliveKey = player === 1 ? "jet1Alive" : "jet2Alive";
    const invulnKey = player === 1 ? "jet1Invuln" : "jet2Invuln";
    const invulnTimerKey = player === 1 ? "jet1InvulnTimer" : "jet2InvulnTimer";
    const xKey = player === 1 ? "jet1X" : "jet2X";
    const yKey = player === 1 ? "jet1Y" : "jet2Y";
    const speedKey = player === 1 ? "jet1Speed" : "jet2Speed";

    s = {
      ...s,
      [aliveKey]: true,
      [respawnKey]: false,
      [invulnKey]: true,
      [invulnTimerKey]: INVULN_DURATION,
      [xKey]: CANVAS_W / 2,
      [yKey]: CANVAS_H - 40,
      [speedKey]: SPEED_BASE,
    };
  }

  return s;
}

// --- Game over ---

/**
 * Check if the game is over (both players out of lives).
 * @param {object} state
 * @returns {{ended: boolean, winner: number}}
 */
export function checkGameOver(state) {
  const p1Dead = state.jet1Lives <= 0 && !state.jet1Alive;
  const p2Dead = state.jet2Lives <= 0 && !state.jet2Alive;

  if (p1Dead && p2Dead) {
    const winner = state.score1 >= state.score2 ? 1 : 2;
    return { ended: true, winner };
  }
  if (p1Dead) return { ended: true, winner: 2 };
  if (p2Dead) return { ended: true, winner: 1 };

  return { ended: false, winner: 0 };
}

/**
 * Determine winner from final state.
 * @param {object} state
 * @returns {number} 1 or 2
 */
export function getWinner(state) {
  if (state.score1 > state.score2) return 1;
  if (state.score2 > state.score1) return 2;
  return 1;
}

// --- Timers ---

/**
 * Tick all timers.
 * @param {object} state
 * @returns {object}
 */
export function tickTimers(state) {
  const s = { ...state };

  if (s.jet1InvulnTimer > 0) {
    s.jet1InvulnTimer -= 1;
    if (s.jet1InvulnTimer <= 0) s.jet1Invuln = false;
  }
  if (s.jet2InvulnTimer > 0) {
    s.jet2InvulnTimer -= 1;
    if (s.jet2InvulnTimer <= 0) s.jet2Invuln = false;
  }

  if (s.jet1MissileCooldown > 0) s.jet1MissileCooldown -= 1;
  if (s.jet2MissileCooldown > 0) s.jet2MissileCooldown -= 1;
  if (s.jet1MineCooldown > 0) s.jet1MineCooldown -= 1;
  if (s.jet2MineCooldown > 0) s.jet2MineCooldown -= 1;

  return s;
}

/**
 * Clear event flags for next frame.
 * @param {object} state
 * @returns {object}
 */
export function clearEvents(state) {
  return {
    ...state,
    events: {
      enemyKill: 0,
      enemyKillType: 0,
      fuelCapture: 0,
      fuelDestroyed: false,
      bridgeHit: false,
      bridgeDestroyed: 0,
      mineDeployed: 0,
      mineHit: 0,
      death: 0,
      fuelEmpty: 0,
      killSteal: false,
    },
  };
}

/**
 * Format fuel level as percentage string.
 * @param {number} fuel - 0-255
 * @returns {string}
 */
export function formatFuel(fuel) {
  return `${Math.round((fuel / 255) * 100)}%`;
}

/**
 * Update fuel station positions (drift downward with scroll).
 * @param {object} state
 * @param {number} scrollDelta
 * @returns {object}
 */
export function updateFuels(state, scrollDelta) {
  if (state.fuelCount === 0) return state;

  const fuels = state.fuels
    .map((f) => (f.available ? { ...f, y: f.y + scrollDelta } : f))
    .filter((f) => f.available && f.y < CANVAS_H + 50);

  return { ...state, fuels, fuelCount: fuels.length };
}

/**
 * Update bridge position (drifts downward with scroll).
 * @param {object} state
 * @param {number} scrollDelta
 * @returns {object}
 */
export function updateBridge(state, scrollDelta) {
  if (!state.bridgeActive) return state;

  const newY = state.bridgeY + scrollDelta;
  if (newY > CANVAS_H + 50) {
    return { ...state, bridgeY: newY, bridgeActive: false };
  }
  return { ...state, bridgeY: newY };
}
