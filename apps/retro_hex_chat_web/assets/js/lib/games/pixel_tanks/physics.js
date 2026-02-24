/**
 * Pure physics and game logic for Pixel Tanks.
 * All functions are pure — no side effects, no DOM, no network.
 * @module games/pixel_tanks_physics
 */

import { PHASE, GAME_MODE } from "./protocol.js";

// --- Canvas ---
export const CANVAS_W = 640;
export const CANVAS_H = 480;

// --- Grid ---
export const WALL_SIZE = 16;
export const GRID_COLS = CANVAS_W / WALL_SIZE; // 40
export const GRID_ROWS = CANVAS_H / WALL_SIZE; // 30

// --- Tank ---
export const TANK_RADIUS = 10;
export const TANK_SPEED = 2.0;
export const ROTATION_SPEED = 0.06; // rad/frame (~3.4 deg/frame)

// --- Missile ---
export const MISSILE_SPEED = 5.0;
export const MISSILE_LIFETIME = 120; // frames (~2s)
export const MISSILE_COOLDOWN = 30; // frames (~0.5s)
export const MISSILE_RADIUS = 3;

// --- Gameplay ---
export const SPAWN_INVULN = 120; // frames (~2s)
export const ROUND_DURATION = 7200; // frames (2 min at 60fps)
export const RESPAWN_PAUSE = 60; // frames (~1s) pause after hit
export const MAX_ROUNDS = 3;
export const ROUNDS_TO_WIN = 2;

// --- Spawn positions ---
const P1_SPAWN = { x: 48, y: CANVAS_H / 2, rot: 0 }; // facing right
const P2_SPAWN = { x: CANVAS_W - 48, y: CANVAS_H / 2, rot: Math.PI }; // facing left

// --- Maze layouts ---
// Each maze is stored as rows of hex strings (left half only, mirrored horizontally).
// Each hex char = 4 columns of the left half (20 cols = 5 hex chars per row).
// 30 rows x 5 hex chars = 150 chars per maze.
// Bit order: MSB = leftmost column of the nibble.

const MAZE_LAYOUTS = [
  // Maze 0: Open field (null = borders only)
  null,
  // Maze 1: Simple blocks — light cover, wide corridors
  "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00300" + // row 7
    "00300" +
    "00000" +
    "00000" +
    "00000" +
    "03c30" + // row 12
    "03c30" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00300" + // row 21
    "00300" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000",
  // Maze 2: Cross — central cross with open corners
  "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00f00" + // row 9
    "00100" +
    "00100" +
    "00100" +
    "0f100" + // row 13 — horizontal + vertical
    "0f100" +
    "00100" +
    "00100" +
    "00100" +
    "00f00" + // row 18
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000",
  // Maze 3: Corridors — long walls creating lanes
  "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "0ff00" + // row 5
    "00000" +
    "00000" +
    "00000" +
    "000f0" + // row 9
    "000f0" +
    "000f0" +
    "00000" +
    "00000" +
    "0f000" + // row 14
    "0f000" +
    "0f000" +
    "00000" +
    "00000" +
    "000f0" + // row 19
    "000f0" +
    "000f0" +
    "00000" +
    "00000" +
    "0ff00" + // row 24
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000",
  // Maze 4: Arena — rectangular rings with gaps
  "00000" +
    "00000" +
    "00000" +
    "00000" +
    "0ffc0" + // row 4
    "08020" +
    "08020" +
    "08020" +
    "00020" + // gap left
    "00020" +
    "0ffc0" + // row 10
    "00000" +
    "00000" +
    "00000" +
    "00000" + // center gap
    "00000" +
    "00000" +
    "00000" +
    "0ffc0" + // row 18
    "08000" + // gap right
    "08000" +
    "08020" +
    "08020" +
    "08020" +
    "0ffc0" + // row 24
    "00000" +
    "00000" +
    "00000" +
    "00000" +
    "00000",
  // Maze 5: Labyrinth — dense walls, narrow passages
  "00000" +
    "00000" +
    "00000" +
    "0e0e0" + // row 3
    "00000" +
    "03830" + // row 5
    "00000" +
    "0e0e0" + // row 7
    "00000" +
    "03830" + // row 9
    "00000" +
    "0e0e0" + // row 11
    "00000" +
    "03830" + // row 13
    "00000" +
    "0e0e0" + // row 15
    "00000" +
    "03830" + // row 17
    "00000" +
    "0e0e0" + // row 19
    "00000" +
    "03830" + // row 21
    "00000" +
    "0e0e0" + // row 23
    "00000" +
    "03830" + // row 25
    "00000" +
    "00000" +
    "00000" +
    "00000",
];

/**
 * Decode a maze layout into a flat Uint8Array (GRID_COLS * GRID_ROWS).
 * 1 = wall, 0 = empty. Always includes border walls.
 * Left half is decoded from hex data, right half is horizontally mirrored.
 * @param {number} index - Maze layout index (0-5)
 * @returns {Uint8Array}
 */
export function decodeMaze(index) {
  const walls = new Uint8Array(GRID_COLS * GRID_ROWS);

  // Border walls
  for (let col = 0; col < GRID_COLS; col++) {
    walls[col] = 1; // top
    walls[(GRID_ROWS - 1) * GRID_COLS + col] = 1; // bottom
  }
  for (let row = 0; row < GRID_ROWS; row++) {
    walls[row * GRID_COLS] = 1; // left
    walls[row * GRID_COLS + GRID_COLS - 1] = 1; // right
  }

  const data = MAZE_LAYOUTS[index];
  if (!data) return walls;

  // Each row has 5 hex chars = 20 bits = 20 columns (left half)
  const halfCols = GRID_COLS / 2; // 20
  for (let row = 0; row < GRID_ROWS; row++) {
    for (let h = 0; h < 5; h++) {
      const nibble = parseInt(data[row * 5 + h], 16);
      for (let bit = 0; bit < 4; bit++) {
        const col = h * 4 + bit;
        if (col >= halfCols) break;
        const isWall = (nibble >> (3 - bit)) & 1;
        if (isWall) {
          walls[row * GRID_COLS + col] = 1;
          // Mirror to right half
          walls[row * GRID_COLS + (GRID_COLS - 1 - col)] = 1;
        }
      }
    }
  }

  return walls;
}

/**
 * Create initial game state.
 * @param {number} mode - GAME_MODE enum
 * @param {number} mazeIndex - Maze layout index
 * @returns {object}
 */
export function createInitialState(mode, mazeIndex) {
  return {
    // Tanks
    tank1X: P1_SPAWN.x,
    tank1Y: P1_SPAWN.y,
    tank1Rot: P1_SPAWN.rot,
    tank1Alive: true,
    tank1Invuln: false,
    tank1InvulnTimer: 0,
    tank1Cooldown: 0,

    tank2X: P2_SPAWN.x,
    tank2Y: P2_SPAWN.y,
    tank2Rot: P2_SPAWN.rot,
    tank2Alive: true,
    tank2Invuln: false,
    tank2InvulnTimer: 0,
    tank2Cooldown: 0,

    // Missiles
    m1X: 0,
    m1Y: 0,
    m1VX: 0,
    m1VY: 0,
    m1Active: false,
    m1Age: 0,
    m1Bounced: false,

    m2X: 0,
    m2Y: 0,
    m2VX: 0,
    m2VY: 0,
    m2Active: false,
    m2Age: 0,
    m2Bounced: false,

    // Scores
    score1: 0,
    score2: 0,

    // Game meta
    phase: PHASE.WAITING,
    countdown: 3,
    mode,
    mazeIndex,
    round: 1,
    roundWins1: 0,
    roundWins2: 0,
    roundTimer: ROUND_DURATION,

    // Respawn pause timer (not serialized, host-only)
    respawnPause: 0,

    // Event flags (cleared each frame, host-only)
    tankHit: 0, // 0=none, 1=P1 hit, 2=P2 hit
    missileExpired: 0, // 0=none, 1=m1, 2=m2
    wallBounced: 0, // 0=none, 1=m1, 2=m2
  };
}

/**
 * Check if a circle at (x, y) with given radius collides with any wall.
 * @param {number} x
 * @param {number} y
 * @param {number} radius
 * @param {Uint8Array} walls
 * @returns {boolean}
 */
export function collidesWithWall(x, y, radius, walls) {
  const minCol = Math.max(0, Math.floor((x - radius) / WALL_SIZE));
  const maxCol = Math.min(GRID_COLS - 1, Math.floor((x + radius) / WALL_SIZE));
  const minRow = Math.max(0, Math.floor((y - radius) / WALL_SIZE));
  const maxRow = Math.min(GRID_ROWS - 1, Math.floor((y + radius) / WALL_SIZE));

  for (let row = minRow; row <= maxRow; row++) {
    for (let col = minCol; col <= maxCol; col++) {
      if (!walls[row * GRID_COLS + col]) continue;
      const wx = col * WALL_SIZE;
      const wy = row * WALL_SIZE;
      const closestX = Math.max(wx, Math.min(x, wx + WALL_SIZE));
      const closestY = Math.max(wy, Math.min(y, wy + WALL_SIZE));
      const dx = x - closestX;
      const dy = y - closestY;
      if (dx * dx + dy * dy < radius * radius) return true;
    }
  }
  return false;
}

/**
 * Rotate a tank.
 * @param {object} state - Full game state
 * @param {number} player - 1 or 2
 * @param {number} direction - -1 (left) or 1 (right)
 * @returns {object} Updated state
 */
export function rotateTank(state, player, direction) {
  const key = player === 1 ? "tank1Rot" : "tank2Rot";
  let rot = state[key] + direction * ROTATION_SPEED;
  // Normalize to [0, 2*PI)
  if (rot < 0) rot += Math.PI * 2;
  if (rot >= Math.PI * 2) rot -= Math.PI * 2;
  return { ...state, [key]: rot };
}

/**
 * Move a tank forward in its facing direction with wall collision + axis sliding.
 * @param {object} state - Full game state
 * @param {number} player - 1 or 2
 * @param {Uint8Array} walls
 * @returns {object} Updated state
 */
export function moveTank(state, player, walls) {
  const xKey = player === 1 ? "tank1X" : "tank2X";
  const yKey = player === 1 ? "tank1Y" : "tank2Y";
  const rotKey = player === 1 ? "tank1Rot" : "tank2Rot";
  const aliveKey = player === 1 ? "tank1Alive" : "tank2Alive";

  if (!state[aliveKey]) return state;

  const rot = state[rotKey];
  const newX = state[xKey] + Math.cos(rot) * TANK_SPEED;
  const newY = state[yKey] + Math.sin(rot) * TANK_SPEED;

  if (!collidesWithWall(newX, newY, TANK_RADIUS, walls)) {
    return { ...state, [xKey]: newX, [yKey]: newY };
  }

  // Axis sliding: try each axis independently
  const slideX = !collidesWithWall(newX, state[yKey], TANK_RADIUS, walls);
  const slideY = !collidesWithWall(state[xKey], newY, TANK_RADIUS, walls);

  return {
    ...state,
    [xKey]: slideX ? newX : state[xKey],
    [yKey]: slideY ? newY : state[yKey],
  };
}

/**
 * Fire a missile from a tank's barrel.
 * @param {object} state - Full game state
 * @param {number} player - 1 or 2
 * @param {Uint8Array} walls - Maze wall data
 * @returns {object} Updated state (unchanged if can't fire)
 */
export function fireMissile(state, player, walls) {
  const prefix = player === 1 ? "m1" : "m2";
  const tankPrefix = player === 1 ? "tank1" : "tank2";
  const cdKey = `${tankPrefix}Cooldown`;

  if (!state[`${tankPrefix}Alive`]) return state;
  if (state[`${prefix}Active`]) return state;
  if (state[cdKey] > 0) return state;

  const rot = state[`${tankPrefix}Rot`];
  const cos = Math.cos(rot);
  const sin = Math.sin(rot);

  // Spawn missile from barrel tip; if position is inside a wall, skip firing
  const spawnX = state[`${tankPrefix}X`] + cos * (TANK_RADIUS + 2);
  const spawnY = state[`${tankPrefix}Y`] + sin * (TANK_RADIUS + 2);
  const spawnCol = Math.floor(spawnX / WALL_SIZE);
  const spawnRow = Math.floor(spawnY / WALL_SIZE);
  if (
    spawnCol < 0 ||
    spawnCol >= GRID_COLS ||
    spawnRow < 0 ||
    spawnRow >= GRID_ROWS ||
    (walls && walls[spawnRow * GRID_COLS + spawnCol])
  ) {
    return state;
  }

  return {
    ...state,
    [`${prefix}X`]: spawnX,
    [`${prefix}Y`]: spawnY,
    [`${prefix}VX`]: cos * MISSILE_SPEED,
    [`${prefix}VY`]: sin * MISSILE_SPEED,
    [`${prefix}Active`]: true,
    [`${prefix}Age`]: 0,
    [`${prefix}Bounced`]: false,
  };
}

/**
 * Update a missile (straight-line travel, wall destruction).
 * @param {object} state - Full game state
 * @param {number} missileNum - 1 or 2
 * @param {Uint8Array} walls
 * @returns {object} Updated state
 */
export function updateMissile(state, missileNum, walls) {
  const prefix = missileNum === 1 ? "m1" : "m2";
  const playerCdKey = missileNum === 1 ? "tank1Cooldown" : "tank2Cooldown";

  if (!state[`${prefix}Active`]) return state;

  const newX = state[`${prefix}X`] + state[`${prefix}VX`];
  const newY = state[`${prefix}Y`] + state[`${prefix}VY`];
  const newAge = state[`${prefix}Age`] + 1;

  // Check lifetime
  if (newAge >= MISSILE_LIFETIME) {
    return {
      ...state,
      [`${prefix}Active`]: false,
      [playerCdKey]: MISSILE_COOLDOWN,
      missileExpired: missileNum,
    };
  }

  // Check wall collision
  const col = Math.floor(newX / WALL_SIZE);
  const row = Math.floor(newY / WALL_SIZE);
  const outOfBounds = col < 0 || col >= GRID_COLS || row < 0 || row >= GRID_ROWS;

  if (outOfBounds || walls[row * GRID_COLS + col]) {
    return {
      ...state,
      [`${prefix}Active`]: false,
      [playerCdKey]: MISSILE_COOLDOWN,
      missileExpired: missileNum,
    };
  }

  return {
    ...state,
    [`${prefix}X`]: newX,
    [`${prefix}Y`]: newY,
    [`${prefix}Age`]: newAge,
  };
}

/**
 * Update a missile in ricochet mode (bounces once off walls).
 * @param {object} state - Full game state
 * @param {number} missileNum - 1 or 2
 * @param {Uint8Array} walls
 * @returns {object} Updated state
 */
export function updateMissileRicochet(state, missileNum, walls) {
  const prefix = missileNum === 1 ? "m1" : "m2";
  const playerCdKey = missileNum === 1 ? "tank1Cooldown" : "tank2Cooldown";

  if (!state[`${prefix}Active`]) return state;

  const newAge = state[`${prefix}Age`] + 1;

  // Check lifetime
  if (newAge >= MISSILE_LIFETIME) {
    return {
      ...state,
      [`${prefix}Active`]: false,
      [playerCdKey]: MISSILE_COOLDOWN,
      missileExpired: missileNum,
    };
  }

  const vx = state[`${prefix}VX`];
  const vy = state[`${prefix}VY`];
  const newX = state[`${prefix}X`] + vx;
  const newY = state[`${prefix}Y`] + vy;

  const col = Math.floor(newX / WALL_SIZE);
  const row = Math.floor(newY / WALL_SIZE);
  const outOfBounds = col < 0 || col >= GRID_COLS || row < 0 || row >= GRID_ROWS;

  if (outOfBounds || walls[row * GRID_COLS + col]) {
    // Already bounced once — destroy
    if (state[`${prefix}Bounced`]) {
      return {
        ...state,
        [`${prefix}Active`]: false,
        [playerCdKey]: MISSILE_COOLDOWN,
        missileExpired: missileNum,
      };
    }

    // Determine reflection axis
    const prevCol = Math.floor(state[`${prefix}X`] / WALL_SIZE);
    const prevRow = Math.floor(state[`${prefix}Y`] / WALL_SIZE);
    let nvx = vx;
    let nvy = vy;

    if (outOfBounds) {
      // Reflect off screen edge
      if (col < 0 || col >= GRID_COLS) nvx = -nvx;
      if (row < 0 || row >= GRID_ROWS) nvy = -nvy;
    } else {
      const hitHoriz = prevCol !== col && walls[prevRow * GRID_COLS + col];
      const hitVert = prevRow !== row && walls[row * GRID_COLS + prevCol];

      if (hitHoriz && hitVert) {
        // Corner hit: wall on both axes — full reverse
        nvx = -nvx;
        nvy = -nvy;
      } else if (hitHoriz) {
        nvx = -nvx;
      } else if (hitVert) {
        nvy = -nvy;
      } else {
        // Fallback: missile entered a diagonal-only wall cell — full reverse
        nvx = -nvx;
        nvy = -nvy;
      }
    }

    // Validate post-bounce position; destroy if still inside a wall
    const bounceX = state[`${prefix}X`] + nvx;
    const bounceY = state[`${prefix}Y`] + nvy;
    const bCol = Math.floor(bounceX / WALL_SIZE);
    const bRow = Math.floor(bounceY / WALL_SIZE);
    const bounceOOB = bCol < 0 || bCol >= GRID_COLS || bRow < 0 || bRow >= GRID_ROWS;

    if (bounceOOB || walls[bRow * GRID_COLS + bCol]) {
      return {
        ...state,
        [`${prefix}Active`]: false,
        [playerCdKey]: MISSILE_COOLDOWN,
        missileExpired: missileNum,
      };
    }

    return {
      ...state,
      [`${prefix}X`]: bounceX,
      [`${prefix}Y`]: bounceY,
      [`${prefix}VX`]: nvx,
      [`${prefix}VY`]: nvy,
      [`${prefix}Age`]: newAge,
      [`${prefix}Bounced`]: true,
      wallBounced: missileNum,
    };
  }

  return {
    ...state,
    [`${prefix}X`]: newX,
    [`${prefix}Y`]: newY,
    [`${prefix}Age`]: newAge,
  };
}

/**
 * Check if a missile hits an enemy tank.
 * @param {object} state - Full game state
 * @param {number} missileNum - 1 or 2 (missile 1 hits tank 2, missile 2 hits tank 1)
 * @returns {object} Updated state with tankHit flag if hit
 */
export function checkMissileHit(state, missileNum) {
  const mPrefix = missileNum === 1 ? "m1" : "m2";
  const targetPlayer = missileNum === 1 ? 2 : 1;
  const tPrefix = targetPlayer === 1 ? "tank1" : "tank2";

  if (!state[`${mPrefix}Active`]) return state;
  if (!state[`${tPrefix}Alive`]) return state;
  if (state[`${tPrefix}Invuln`]) return state;

  const dx = state[`${mPrefix}X`] - state[`${tPrefix}X`];
  const dy = state[`${mPrefix}Y`] - state[`${tPrefix}Y`];
  const dist = MISSILE_RADIUS + TANK_RADIUS;

  if (dx * dx + dy * dy < dist * dist) {
    const shooterScore = missileNum === 1 ? "score1" : "score2";
    return {
      ...state,
      [`${mPrefix}Active`]: false,
      tankHit: targetPlayer,
      [shooterScore]: state[shooterScore] + 1,
    };
  }

  return state;
}

/**
 * Respawn both tanks at their starting positions after a hit.
 * @param {object} state
 * @returns {object} Updated state
 */
export function respawnTanks(state) {
  return {
    ...state,
    tank1X: P1_SPAWN.x,
    tank1Y: P1_SPAWN.y,
    tank1Rot: P1_SPAWN.rot,
    tank1Alive: true,
    tank1Invuln: true,
    tank1InvulnTimer: SPAWN_INVULN,
    tank1Cooldown: 0,

    tank2X: P2_SPAWN.x,
    tank2Y: P2_SPAWN.y,
    tank2Rot: P2_SPAWN.rot,
    tank2Alive: true,
    tank2Invuln: true,
    tank2InvulnTimer: SPAWN_INVULN,
    tank2Cooldown: 0,

    // Clear missiles
    m1Active: false,
    m1Age: 0,
    m2Active: false,
    m2Age: 0,

    respawnPause: RESPAWN_PAUSE,
    tankHit: 0,
  };
}

/**
 * Tick timers: invulnerability, cooldowns, round timer.
 * @param {object} state
 * @returns {object} Updated state
 */
export function tickTimers(state) {
  const s = { ...state };

  // Invulnerability timers
  if (s.tank1InvulnTimer > 0) {
    s.tank1InvulnTimer -= 1;
    if (s.tank1InvulnTimer <= 0) s.tank1Invuln = false;
  }
  if (s.tank2InvulnTimer > 0) {
    s.tank2InvulnTimer -= 1;
    if (s.tank2InvulnTimer <= 0) s.tank2Invuln = false;
  }

  // Cooldowns
  if (s.tank1Cooldown > 0) s.tank1Cooldown -= 1;
  if (s.tank2Cooldown > 0) s.tank2Cooldown -= 1;

  // Respawn pause
  if (s.respawnPause > 0) s.respawnPause -= 1;

  // Round timer (clamp to 0 to prevent underflow wrapping as Uint16)
  if (s.phase === PHASE.PLAYING && s.respawnPause <= 0) {
    s.roundTimer = Math.max(0, s.roundTimer - 1);
  }

  return s;
}

/**
 * Check if the round should end (timer expired).
 * @param {object} state
 * @returns {{ ended: boolean, roundWinner: number }} roundWinner: 1, 2, or 0 (tie)
 */
export function checkRoundEnd(state) {
  if (state.roundTimer <= 0) {
    let roundWinner = 0;
    if (state.score1 > state.score2) roundWinner = 1;
    else if (state.score2 > state.score1) roundWinner = 2;
    return { ended: true, roundWinner };
  }
  return { ended: false, roundWinner: 0 };
}

/**
 * Advance to the next round or finish the match.
 * @param {object} state
 * @param {number} roundWinner - 1 or 2 (0 = draw, no round win counted)
 * @returns {object} Updated state
 */
export function advanceRound(state, roundWinner) {
  let rw1 = state.roundWins1;
  let rw2 = state.roundWins2;

  if (roundWinner === 1) rw1 += 1;
  else if (roundWinner === 2) rw2 += 1;

  // Check match winner (also end if max rounds reached to prevent infinite draws)
  if (rw1 >= ROUNDS_TO_WIN || rw2 >= ROUNDS_TO_WIN || state.round >= MAX_ROUNDS) {
    return {
      ...state,
      roundWins1: rw1,
      roundWins2: rw2,
      phase: PHASE.MATCH_OVER,
    };
  }

  // Next round
  return {
    ...state,
    roundWins1: rw1,
    roundWins2: rw2,
    round: state.round + 1,
    score1: 0,
    score2: 0,
    roundTimer: ROUND_DURATION,
    phase: PHASE.ROUND_OVER,
  };
}

/**
 * Reset state for a new round (called after ROUND_OVER display).
 * @param {object} state
 * @returns {object} Updated state ready for countdown
 */
export function resetForNewRound(state) {
  return {
    ...state,
    tank1X: P1_SPAWN.x,
    tank1Y: P1_SPAWN.y,
    tank1Rot: P1_SPAWN.rot,
    tank1Alive: true,
    tank1Invuln: false,
    tank1InvulnTimer: 0,
    tank1Cooldown: 0,

    tank2X: P2_SPAWN.x,
    tank2Y: P2_SPAWN.y,
    tank2Rot: P2_SPAWN.rot,
    tank2Alive: true,
    tank2Invuln: false,
    tank2InvulnTimer: 0,
    tank2Cooldown: 0,

    m1Active: false,
    m1Age: 0,
    m2Active: false,
    m2Age: 0,

    score1: 0,
    score2: 0,
    roundTimer: ROUND_DURATION,
    respawnPause: 0,
    phase: PHASE.COUNTDOWN,
    countdown: 3,
  };
}

/**
 * Create explosion particles at a position.
 * @param {number} x
 * @param {number} y
 * @returns {Array<object>}
 */
export function createExplosion(x, y) {
  const particles = [];
  const count = 12;
  for (let i = 0; i < count; i++) {
    const angle = (Math.PI * 2 * i) / count + (Math.random() - 0.5) * 0.3;
    const speed = 1.5 + Math.random() * 2;
    particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life: 30 + Math.random() * 20,
      maxLife: 50,
    });
  }
  return particles;
}

/**
 * Create ricochet spark particles at a position.
 * @param {number} x
 * @param {number} y
 * @returns {Array<object>}
 */
export function createSparks(x, y) {
  const particles = [];
  const count = 6;
  for (let i = 0; i < count; i++) {
    const angle = Math.random() * Math.PI * 2;
    const speed = 1 + Math.random() * 2;
    particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life: 15 + Math.random() * 10,
      maxLife: 25,
      spark: true,
    });
  }
  return particles;
}

/**
 * Update particle positions and lifetime.
 * @param {Array<object>} particles
 * @returns {Array<object>} Remaining alive particles
 */
export function updateParticles(particles) {
  return particles
    .map((p) => ({
      ...p,
      x: p.x + p.vx,
      y: p.y + p.vy,
      vx: p.vx * 0.96,
      vy: p.vy * 0.96,
      life: p.life - 1,
    }))
    .filter((p) => p.life > 0);
}

/**
 * Get the match winner from state (1, 2, or 0 for draw).
 * @param {object} state
 * @returns {number}
 */
export function getMatchWinner(state) {
  if (state.roundWins1 >= ROUNDS_TO_WIN) return 1;
  if (state.roundWins2 >= ROUNDS_TO_WIN) return 2;
  return 0;
}

/**
 * Format round timer as "M:SS".
 * @param {number} frames
 * @returns {string}
 */
export function formatTimer(frames) {
  const totalSec = Math.ceil(frames / 60);
  const min = Math.floor(totalSec / 60);
  const sec = totalSec % 60;
  return `${min}:${sec.toString().padStart(2, "0")}`;
}

/**
 * Select maze index based on game mode.
 * Classic/Guided use open field (0), Maze/Ricochet use random maze (1-5).
 * @param {number} mode - GAME_MODE enum
 * @returns {number}
 */
export function selectMazeForMode(mode) {
  if (mode === GAME_MODE.CLASSIC || mode === GAME_MODE.GUIDED) {
    return 0;
  }
  return 1 + Math.floor(Math.random() * (MAZE_LAYOUTS.length - 1));
}
