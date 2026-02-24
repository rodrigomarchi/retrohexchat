/**
 * Pure physics and game logic for Hex Raid (River Raid 2P).
 * All functions are pure — no side effects, no DOM, no network.
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
export const SECTION_CLEAR_DELAY = 120; // 2s

// --- Scoring ---
export const SCORE_BOAT = 30;
export const SCORE_HELI = 60;
export const SCORE_JET = 100;
export const SCORE_FUEL_DESTROYED = 80;
export const SCORE_BRIDGE = 500;
export const SCORE_MINE_HIT = 200;
export const SCORE_FUEL_OUT = 150;
export const SCORE_SECTION = 100;

// --- River geometry ---
export const SECTION_HEIGHT = 1800; // pixels per section
export const RIVER_MIN_WIDTH = 200;
export const RIVER_MAX_WIDTH = 440;
const BANK_SEGMENTS = 18; // control points per section

/**
 * Convert a world-space Y coordinate to screen-space Y.
 * In the vertical scroller: worldY 0 = bottom of section, SECTION_HEIGHT = top.
 * Screen: 0 = top, CANVAS_H = bottom.
 * As scrollY increases, higher worldY values come into view from above.
 * @param {number} worldY - Y position in section coordinates
 * @param {number} scrollY - current scroll offset
 * @returns {number} screen Y coordinate
 */
export function worldToScreenY(worldY, scrollY) {
  const sectionOffset = scrollY % SECTION_HEIGHT;
  return CANVAS_H - (worldY - sectionOffset);
}

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

/**
 * Get river width for a given section number.
 * @param {number} section - 1-based section number
 * @param {number} mode - GAME_MODE enum
 * @returns {number} river width in pixels
 */
export function getRiverWidth(section, mode) {
  const effectiveSection = mode === GAME_MODE.BLITZ ? section + 3 : section;
  const t = Math.min((effectiveSection - 1) / 9, 1);
  return RIVER_MAX_WIDTH - t * (RIVER_MAX_WIDTH - RIVER_MIN_WIDTH);
}

/**
 * Generate river bank control points for a section.
 * Returns arrays of {y, leftX, rightX} for each vertical segment.
 * @param {number} section - 1-based
 * @param {function} rng - seeded PRNG
 * @param {number} mode - GAME_MODE enum
 * @returns {Array<{y: number, leftX: number, rightX: number}>}
 */
export function generateBanks(section, rng, mode) {
  const width = getRiverWidth(section, mode);
  const centerX = CANVAS_W / 2;
  const halfWidth = width / 2;
  const banks = [];
  const wobble = Math.max(10, 40 - section * 3);

  for (let i = 0; i <= BANK_SEGMENTS; i++) {
    const y = (i / BANK_SEGMENTS) * SECTION_HEIGHT;
    const offset = (rng() - 0.5) * wobble;
    banks.push({
      y,
      leftX: centerX - halfWidth + offset,
      rightX: centerX + halfWidth + offset,
    });
  }
  return banks;
}

/**
 * Get left and right bank X at a specific Y within a section's banks.
 * Interpolates between control points.
 * @param {Array} banks - bank control points
 * @param {number} localY - Y position within the section (0 = top of section)
 * @returns {{leftX: number, rightX: number}}
 */
export function getBankAt(banks, localY) {
  if (banks.length < 2) return { leftX: 0, rightX: CANVAS_W };

  const clampedY = Math.max(0, Math.min(localY, SECTION_HEIGHT));

  // Find the segment
  for (let i = 0; i < banks.length - 1; i++) {
    if (clampedY >= banks[i].y && clampedY <= banks[i + 1].y) {
      const segLen = banks[i + 1].y - banks[i].y;
      const t = segLen > 0 ? (clampedY - banks[i].y) / segLen : 0;
      return {
        leftX: banks[i].leftX + t * (banks[i + 1].leftX - banks[i].leftX),
        rightX: banks[i].rightX + t * (banks[i + 1].rightX - banks[i].rightX),
      };
    }
  }

  // Fallback: use last point
  const last = banks[banks.length - 1];
  return { leftX: last.leftX, rightX: last.rightX };
}

/**
 * Generate enemies for a section.
 * @param {number} section - 1-based
 * @param {function} rng - seeded PRNG
 * @param {Array} banks - bank control points for spatial placement
 * @param {number} mode - GAME_MODE enum
 * @returns {Array<{type: number, x: number, y: number, alive: boolean, vx: number}>}
 */
export function generateEnemies(section, rng, banks, mode) {
  const effectiveSection = mode === GAME_MODE.BLITZ ? section + 3 : section;
  const count = Math.min(MAX_ENEMIES, Math.floor(2 + effectiveSection * 0.7));
  const enemies = [];

  for (let i = 0; i < count; i++) {
    // Distribute enemies across the section height
    const y = 100 + rng() * (SECTION_HEIGHT - 300);
    const bank = getBankAt(banks, y);
    const margin = 20;
    const x = bank.leftX + margin + rng() * (bank.rightX - bank.leftX - margin * 2);

    // Determine enemy type based on section difficulty
    let type;
    const roll = rng();
    if (effectiveSection >= 7 && roll < 0.3) {
      type = ENEMY_TYPE.JET;
    } else if (effectiveSection >= 4 && roll < 0.5) {
      type = ENEMY_TYPE.HELI;
    } else {
      type = ENEMY_TYPE.BOAT;
    }

    // Lateral velocity
    const speed = type === ENEMY_TYPE.JET ? 0 : type === ENEMY_TYPE.HELI ? 1.5 : 0.8;
    const vx = (rng() > 0.5 ? 1 : -1) * speed;

    enemies.push({ type, x, y, alive: true, vx });
  }

  return enemies;
}

/**
 * Generate fuel stations for a section.
 * @param {number} section - 1-based
 * @param {function} rng - seeded PRNG
 * @param {Array} banks - bank control points
 * @param {number} mode - GAME_MODE enum
 * @returns {Array<{x: number, y: number, available: boolean}>}
 */
export function generateFuels(section, rng, banks, mode) {
  const effectiveSection = mode === GAME_MODE.BLITZ ? section + 3 : section;
  const count = Math.min(MAX_FUEL, Math.max(1, 3 - Math.floor(effectiveSection / 4)));
  const fuels = [];

  for (let i = 0; i < count; i++) {
    const y = 200 + rng() * (SECTION_HEIGHT - 500);
    const bank = getBankAt(banks, y);
    const margin = 30;
    const x = bank.leftX + margin + rng() * (bank.rightX - bank.leftX - margin * 2);
    fuels.push({ x, y, available: true });
  }

  return fuels;
}

/**
 * Generate a complete section's data.
 * @param {number} section - 1-based
 * @param {number} seed - base seed
 * @param {number} mode - GAME_MODE enum
 * @returns {{banks: Array, enemies: Array, fuels: Array, bridgeY: number}}
 */
export function generateSection(section, seed, mode) {
  // Derive section-specific seed
  const rng = mulberry32(seed + section * 7919);
  const banks = generateBanks(section, rng, mode);
  const enemies = generateEnemies(section, rng, banks, mode);
  const fuels = generateFuels(section, rng, banks, mode);
  const bridgeY = SECTION_HEIGHT - 50; // Bridge at bottom of section

  return { banks, enemies, fuels, bridgeY };
}

/**
 * Get total sections for a game mode.
 * @param {number} mode
 * @returns {number}
 */
export function getTotalSections(mode) {
  return mode === GAME_MODE.BLITZ ? 5 : 10;
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
  const sectionData = generateSection(1, seed, mode);

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

    // Entities (from current section)
    enemies: sectionData.enemies,
    enemyCount: sectionData.enemies.length,
    fuels: sectionData.fuels,
    fuelCount: sectionData.fuels.length,
    mines: [],
    mineCount: 0,

    // Bridge
    bridgeY: sectionData.bridgeY,
    bridgeHp: BRIDGE_HP,
    bridgeActive: true,

    // Meta
    score1: 0,
    score2: 0,
    phase: PHASE.WAITING,
    countdown: 3,
    section: 1,
    scrollY: 0,
    mode,
    seed,

    // Section data (not serialized — regenerated on both sides from seed)
    banks: sectionData.banks,

    // Section clear timer (host only)
    sectionClearTimer: 0,

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
 * Update missiles (travel upward in screen space = toward lower scrollY).
 * @param {object} state
 * @returns {object}
 */
export function updateMissiles(state) {
  const s = { ...state };

  // Missile 1
  if (s.m1Active) {
    s.m1Y -= MISSILE_SPEED;
    if (s.m1Y < 0) {
      s.m1Active = false;
    }
  }

  // Missile 2
  if (s.m2Active) {
    s.m2Y -= MISSILE_SPEED;
    if (s.m2Y < 0) {
      s.m2Active = false;
    }
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

  // Check max mines per player
  const playerMines = state.mines.filter((m) => m.active && m.owner === player);
  if (playerMines.length >= MAX_MINES_PER_PLAYER) return state;

  const mine = {
    x: state[`${jetPrefix}X`],
    y: state[`${jetPrefix}Y`] + 20, // Deploy behind jet
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
 * Update mines (float downstream with scroll offset).
 * Mines that scroll off-screen are deactivated.
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
 * Enemies stay in world coordinates; the scroll camera reveals them.
 * Boats/helis move laterally, enemy jets fly toward the player (decrease worldY).
 * @param {object} state
 * @param {number} _scrollDelta - unused (kept for API compat)
 * @returns {object}
 */
export function updateEnemies(state, _scrollDelta) {
  if (state.enemyCount === 0) return state;

  const enemies = state.enemies.map((e) => {
    if (!e.alive) return e;

    let newX = e.x + (e.vx || 0);
    let newY = e.y;

    // Bounce off approximate river boundaries
    const bank = getBankAt(state.banks, e.y);
    if (newX < bank.leftX + 20 || newX > bank.rightX - 20) {
      return { ...e, x: e.x, y: newY, vx: -(e.vx || 0) };
    }

    // Enemy jets fly toward the player (lower worldY = closer to bottom)
    if (e.type === ENEMY_TYPE.JET) {
      newY = e.y - 2;
    }

    return { ...e, x: newX, y: newY };
  });

  // Remove enemies that scrolled off-screen (below bottom or above top)
  const visible = enemies.filter((e) => {
    if (!e.alive) return false;
    const screenY = worldToScreenY(e.y, state.scrollY);
    return screenY > -100 && screenY < CANVAS_H + 100;
  });

  return {
    ...state,
    enemies: visible,
    enemyCount: visible.length,
  };
}

// --- Scroll ---

/**
 * Update scroll position based on fastest player's speed.
 * @param {object} state
 * @returns {{state: object, scrollDelta: number}}
 */
export function updateScroll(state) {
  const speed1 = state.jet1Alive ? state.jet1Speed : 0;
  const speed2 = state.jet2Alive ? state.jet2Speed : 0;
  const scrollDelta = Math.max(speed1, speed2, SPEED_MIN);

  return {
    state: { ...state, scrollY: state.scrollY + scrollDelta },
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
        // Out of fuel = death
        s = {
          ...s,
          [fuelKey]: 0,
        };
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

  // Convert screen Y to section-local Y (scrollY resets per section)
  const localY = (state.scrollY % SECTION_HEIGHT) + (CANVAS_H - state[yKey]);

  const bank = getBankAt(state.banks, localY);
  const x = state[xKey];

  return x - JET_RADIUS < bank.leftX || x + JET_RADIUS > bank.rightX;
}

/**
 * Check missile-enemy collisions.
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
      const enemyScreenY = worldToScreenY(enemies[i].y, s.scrollY);
      const dy = my - enemyScreenY;
      const hitDist = MISSILE_RADIUS + 8; // enemy ~8px radius

      if (dx * dx + dy * dy < hitDist * hitDist) {
        enemies[i] = { ...enemies[i], alive: false };
        s = { ...s, [`${prefix}Active`]: false };

        // Score
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
    const bridgeScreenY = worldToScreenY(s.bridgeY, s.scrollY);

    // Bridge spans full river width; check Y proximity
    if (Math.abs(my - bridgeScreenY) < BRIDGE_HEIGHT) {
      s = { ...s, [`${prefix}Active`]: false };
      const newHp = s.bridgeHp - 1;
      events.bridgeHit = true;

      if (newHp <= 0) {
        // Bridge destroyed — credit to this player
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
      const enemyScreenY = worldToScreenY(e.y, s.scrollY);
      const dy = s[yKey] - enemyScreenY;
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
      const fuelScreenY = worldToScreenY(fuels[i].y, s.scrollY);
      const dy = s[yKey] - fuelScreenY;

      if (dx * dx + dy * dy < 15 * 15) {
        // Capture!
        fuels[i] = { ...fuels[i], available: false };
        const newFuel = Math.min(255, s[fuelKey] + FUEL_REFILL);
        s = { ...s, [fuelKey]: newFuel };
        events.fuelCapture = player;
        break; // First player to overlap captures
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
      const fScreenY = worldToScreenY(fuels[i].y, s.scrollY);
      const dy = s[`${prefix}Y`] - fScreenY;

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
      if (mines[i].owner === player) continue; // Own mines don't hurt

      const dx = s[xKey] - mines[i].x;
      const dy = s[yKey] - mines[i].y;
      const hitDist = JET_RADIUS + MINE_RADIUS;

      if (dx * dx + dy * dy < hitDist * hitDist) {
        mines[i] = { ...mines[i], active: false };
        events.mineHit = player;
        events.death = player;

        // Score for mine owner
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
  const bridgeScreenY = worldToScreenY(s.bridgeY, s.scrollY);

  for (const player of [1, 2]) {
    const yKey = player === 1 ? "jet1Y" : "jet2Y";
    const aliveKey = player === 1 ? "jet1Alive" : "jet2Alive";
    const invulnKey = player === 1 ? "jet1Invuln" : "jet2Invuln";

    if (!s[aliveKey] || s[invulnKey]) continue;

    if (Math.abs(s[yKey] - bridgeScreenY) < BRIDGE_HEIGHT + JET_RADIUS) {
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
 * Process respawn timers. Respawn behind the opponent.
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

    // Respawn
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

// --- Section management ---

/**
 * Check if section is clear (bridge destroyed).
 * @param {object} state
 * @returns {object}
 */
export function checkSectionClear(state) {
  if (state.bridgeActive) return state;
  if (state.phase === PHASE.SECTION_CLEAR) return state;

  return {
    ...state,
    phase: PHASE.SECTION_CLEAR,
    sectionClearTimer: SECTION_CLEAR_DELAY,
    // Section bonus for both players
    score1: state.score1 + SCORE_SECTION,
    score2: state.score2 + SCORE_SECTION,
  };
}

/**
 * Advance to next section.
 * @param {object} state
 * @returns {object}
 */
export function advanceSection(state) {
  const newSection = state.section + 1;
  const totalSections = getTotalSections(state.mode);

  if (newSection > totalSections) {
    return {
      ...state,
      phase: PHASE.FINISHED,
      enemies: [],
      enemyCount: 0,
      fuels: [],
      fuelCount: 0,
      mines: [],
      mineCount: 0,
      bridgeActive: false,
    };
  }

  const sectionData = generateSection(newSection, state.seed, state.mode);

  return {
    ...state,
    section: newSection,
    phase: PHASE.FLYING,
    enemies: sectionData.enemies,
    enemyCount: sectionData.enemies.length,
    fuels: sectionData.fuels,
    fuelCount: sectionData.fuels.length,
    bridgeY: sectionData.bridgeY,
    bridgeHp: BRIDGE_HP,
    bridgeActive: true,
    banks: sectionData.banks,
    scrollY: 0,
    // Reset jet Y positions
    jet1Y: CANVAS_H - 60,
    jet2Y: CANVAS_H - 60,
  };
}

// --- Game over ---

/**
 * Check if the game is over.
 * @param {object} state
 * @returns {{ended: boolean, winner: number}}
 */
export function checkGameOver(state) {
  const p1Dead = state.jet1Lives <= 0 && !state.jet1Alive;
  const p2Dead = state.jet2Lives <= 0 && !state.jet2Alive;

  if (p1Dead && p2Dead) {
    // Both dead — higher score wins
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
  return 1; // P1 wins ties
}

// --- Timers ---

/**
 * Tick all timers.
 * @param {object} state
 * @returns {object}
 */
export function tickTimers(state) {
  const s = { ...state };

  // Invulnerability
  if (s.jet1InvulnTimer > 0) {
    s.jet1InvulnTimer -= 1;
    if (s.jet1InvulnTimer <= 0) s.jet1Invuln = false;
  }
  if (s.jet2InvulnTimer > 0) {
    s.jet2InvulnTimer -= 1;
    if (s.jet2InvulnTimer <= 0) s.jet2Invuln = false;
  }

  // Missile cooldowns
  if (s.jet1MissileCooldown > 0) s.jet1MissileCooldown -= 1;
  if (s.jet2MissileCooldown > 0) s.jet2MissileCooldown -= 1;

  // Mine cooldowns
  if (s.jet1MineCooldown > 0) s.jet1MineCooldown -= 1;
  if (s.jet2MineCooldown > 0) s.jet2MineCooldown -= 1;

  // Section clear timer
  if (s.sectionClearTimer > 0) s.sectionClearTimer -= 1;

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
