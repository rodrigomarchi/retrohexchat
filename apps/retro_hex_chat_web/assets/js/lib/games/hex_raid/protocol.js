/**
 * Binary protocol for Hex Raid game state over WebRTC DataChannel.
 * All messages use DataView for zero-JSON binary encoding.
 * @module games/hex_raid_protocol
 */

// Message types (shared with game_engine.js 0x80+ range)
export const MSG_TYPE = {
  GAME_STATE: 0x80,
  PLAYER_INPUT: 0x81,
  GAME_START: 0x82,
  GAME_END: 0x83,
  GAME_READY: 0x84,
};

// Game phase enum
export const PHASE = {
  WAITING: 0,
  COUNTDOWN: 1,
  FLYING: 2,
  FINISHED: 5, // kept at 5 for protocol backward compat
};

// Input key enum
export const INPUT_KEY = {
  LEFT: 0,
  RIGHT: 1,
  ACCEL: 2,
  DECEL: 3,
  FIRE: 4,
  MINE: 5,
};

// Game mode enum
export const GAME_MODE = {
  RIVER_DUEL: 0,
  PACIFIST: 1,
  BLITZ: 2,
};

// --- Entity limits ---
export const MAX_ENEMIES = 16;
export const MAX_FUEL = 3;
export const MAX_MINES = 4;

// Enemy type enum
export const ENEMY_TYPE = {
  NONE: 0,
  BOAT: 1,
  HELI: 2,
  JET: 3,
};

// --- Sizes ---
// Jet: [x(2)][y(2)][speed(1)][fuel(1)][lives(1)][flags(1)] = 8 bytes × 2 = 16
// Missiles: [m1x(2)][m1y(2)][m1Flags(1)][m2x(2)][m2y(2)][m2Flags(1)] = 10
// Enemies ×16: [type(1)][x(2)][y(2)][flags(1)] = 6 × 16 = 96
// Fuel ×3: [x(2)][y(2)][flags(1)] = 5 × 3 = 15
// Mines ×4: [x(2)][y(2)][owner(1)][flags(1)] = 6 × 4 = 24
// Bridge: [y(2)][hp(1)][flags(1)] = 4
// Meta: [score1(2)][score2(2)][phase(1)][countdown(1)][section(1)][scrollY(4)]
//       [mode(1)][seed(4)][enemyCount(1)][fuelCount(1)][mineCount(1)] = 19
// Total: 1 + 16 + 10 + 96 + 15 + 24 + 4 + 19 = 185
const GAME_STATE_SIZE = 185;
const PLAYER_INPUT_SIZE = 3;
const GAME_END_SIZE = 6;
const GAME_READY_SIZE = 1;

/**
 * Encode full game state for host → peer transmission.
 * Total: 137 bytes
 * @param {object} state
 * @returns {ArrayBuffer}
 */
export function encodeGameState(state) {
  const buf = new ArrayBuffer(GAME_STATE_SIZE);
  const view = new DataView(buf);
  let o = 0;

  view.setUint8(o, MSG_TYPE.GAME_STATE);
  o += 1;

  // Jet 1: [x(2)][y(2)][speed(1)][fuel(1)][lives(1)][flags(1)]
  view.setUint16(o, Math.round(state.jet1X) & 0xffff, true);
  o += 2;
  view.setUint16(o, Math.round(state.jet1Y) & 0xffff, true);
  o += 2;
  view.setUint8(o, state.jet1Speed & 0xff);
  o += 1;
  view.setUint8(o, state.jet1Fuel & 0xff);
  o += 1;
  view.setUint8(o, state.jet1Lives & 0xff);
  o += 1;
  view.setUint8(
    o,
    (state.jet1Alive ? 1 : 0) | (state.jet1Invuln ? 2 : 0) | (state.jet1Respawning ? 4 : 0),
  );
  o += 1;

  // Jet 2: [x(2)][y(2)][speed(1)][fuel(1)][lives(1)][flags(1)]
  view.setUint16(o, Math.round(state.jet2X) & 0xffff, true);
  o += 2;
  view.setUint16(o, Math.round(state.jet2Y) & 0xffff, true);
  o += 2;
  view.setUint8(o, state.jet2Speed & 0xff);
  o += 1;
  view.setUint8(o, state.jet2Fuel & 0xff);
  o += 1;
  view.setUint8(o, state.jet2Lives & 0xff);
  o += 1;
  view.setUint8(
    o,
    (state.jet2Alive ? 1 : 0) | (state.jet2Invuln ? 2 : 0) | (state.jet2Respawning ? 4 : 0),
  );
  o += 1;

  // Missiles: [m1x(2)][m1y(2)][m1Flags(1)][m2x(2)][m2y(2)][m2Flags(1)]
  view.setUint16(o, Math.round(state.m1X) & 0xffff, true);
  o += 2;
  view.setUint16(o, Math.round(state.m1Y) & 0xffff, true);
  o += 2;
  view.setUint8(o, state.m1Active ? 1 : 0);
  o += 1;
  view.setUint16(o, Math.round(state.m2X) & 0xffff, true);
  o += 2;
  view.setUint16(o, Math.round(state.m2Y) & 0xffff, true);
  o += 2;
  view.setUint8(o, state.m2Active ? 1 : 0);
  o += 1;

  // Enemies ×8: [type(1)][x(2)][y(2)][flags(1)]
  const ec = Math.min(state.enemyCount || 0, MAX_ENEMIES);
  for (let i = 0; i < MAX_ENEMIES; i++) {
    if (i < ec && state.enemies[i]) {
      const e = state.enemies[i];
      view.setUint8(o, e.type & 0xff);
      view.setUint16(o + 1, Math.round(e.x) & 0xffff, true);
      view.setUint16(o + 3, Math.round(e.y) & 0xffff, true);
      view.setUint8(o + 5, e.alive ? 1 : 0);
    } else {
      // Empty slot
      view.setUint8(o, 0);
      view.setUint16(o + 1, 0, true);
      view.setUint16(o + 3, 0, true);
      view.setUint8(o + 5, 0);
    }
    o += 6;
  }

  // Fuel ×3: [x(2)][y(2)][flags(1)]
  const fc = Math.min(state.fuelCount || 0, MAX_FUEL);
  for (let i = 0; i < MAX_FUEL; i++) {
    if (i < fc && state.fuels[i]) {
      const f = state.fuels[i];
      view.setUint16(o, Math.round(f.x) & 0xffff, true);
      view.setUint16(o + 2, Math.round(f.y) & 0xffff, true);
      view.setUint8(o + 4, f.available ? 1 : 0);
    } else {
      view.setUint16(o, 0, true);
      view.setUint16(o + 2, 0, true);
      view.setUint8(o + 4, 0);
    }
    o += 5;
  }

  // Mines ×4: [x(2)][y(2)][owner(1)][flags(1)]
  const mc = Math.min(state.mineCount || 0, MAX_MINES);
  for (let i = 0; i < MAX_MINES; i++) {
    if (i < mc && state.mines[i]) {
      const m = state.mines[i];
      view.setUint16(o, Math.round(m.x) & 0xffff, true);
      view.setUint16(o + 2, Math.round(m.y) & 0xffff, true);
      view.setUint8(o + 4, m.owner & 0xff);
      view.setUint8(o + 5, m.active ? 1 : 0);
    } else {
      view.setUint16(o, 0, true);
      view.setUint16(o + 2, 0, true);
      view.setUint8(o + 4, 0);
      view.setUint8(o + 5, 0);
    }
    o += 6;
  }

  // Bridge: [y(2)][hp(1)][flags(1)]
  view.setUint16(o, Math.round(state.bridgeY) & 0xffff, true);
  o += 2;
  view.setUint8(o, state.bridgeHp & 0xff);
  o += 1;
  view.setUint8(o, state.bridgeActive ? 1 : 0);
  o += 1;

  // Meta: [score1(2)][score2(2)][phase(1)][countdown(1)][section(1)][scrollY(4)]
  //       [mode(1)][seed(4)][enemyCount(1)][fuelCount(1)][mineCount(1)]
  view.setUint16(o, state.score1 & 0xffff, true);
  o += 2;
  view.setUint16(o, state.score2 & 0xffff, true);
  o += 2;
  view.setUint8(o, state.phase & 0xff);
  o += 1;
  view.setUint8(o, state.countdown & 0xff);
  o += 1;
  view.setUint8(o, state.section & 0xff);
  o += 1;
  view.setFloat32(o, state.scrollY, true);
  o += 4;
  view.setUint8(o, state.mode & 0xff);
  o += 1;
  view.setUint32(o, state.seed >>> 0, true);
  o += 4;
  view.setUint8(o, ec);
  o += 1;
  view.setUint8(o, fc);
  o += 1;
  view.setUint8(o, mc);

  return buf;
}

/**
 * Decode game state from binary buffer.
 * @param {ArrayBuffer} buf
 * @returns {object|null}
 */
export function decodeGameState(buf) {
  if (buf.byteLength < GAME_STATE_SIZE) return null;
  const view = new DataView(buf);
  if (view.getUint8(0) !== MSG_TYPE.GAME_STATE) return null;

  let o = 1;

  // Jet 1
  const jet1X = view.getUint16(o, true);
  o += 2;
  const jet1Y = view.getUint16(o, true);
  o += 2;
  const jet1Speed = view.getUint8(o);
  o += 1;
  const jet1Fuel = view.getUint8(o);
  o += 1;
  const jet1Lives = view.getUint8(o);
  o += 1;
  const j1Flags = view.getUint8(o);
  o += 1;

  // Jet 2
  const jet2X = view.getUint16(o, true);
  o += 2;
  const jet2Y = view.getUint16(o, true);
  o += 2;
  const jet2Speed = view.getUint8(o);
  o += 1;
  const jet2Fuel = view.getUint8(o);
  o += 1;
  const jet2Lives = view.getUint8(o);
  o += 1;
  const j2Flags = view.getUint8(o);
  o += 1;

  // Missiles
  const m1X = view.getUint16(o, true);
  o += 2;
  const m1Y = view.getUint16(o, true);
  o += 2;
  const m1Flags = view.getUint8(o);
  o += 1;
  const m2X = view.getUint16(o, true);
  o += 2;
  const m2Y = view.getUint16(o, true);
  o += 2;
  const m2Flags = view.getUint8(o);
  o += 1;

  // Enemies ×8
  const enemies = [];
  for (let i = 0; i < MAX_ENEMIES; i++) {
    enemies.push({
      type: view.getUint8(o),
      x: view.getUint16(o + 1, true),
      y: view.getUint16(o + 3, true),
      alive: (view.getUint8(o + 5) & 1) !== 0,
    });
    o += 6;
  }

  // Fuel ×3
  const fuels = [];
  for (let i = 0; i < MAX_FUEL; i++) {
    fuels.push({
      x: view.getUint16(o, true),
      y: view.getUint16(o + 2, true),
      available: (view.getUint8(o + 4) & 1) !== 0,
    });
    o += 5;
  }

  // Mines ×4
  const mines = [];
  for (let i = 0; i < MAX_MINES; i++) {
    mines.push({
      x: view.getUint16(o, true),
      y: view.getUint16(o + 2, true),
      owner: view.getUint8(o + 4),
      active: (view.getUint8(o + 5) & 1) !== 0,
    });
    o += 6;
  }

  // Bridge
  const bridgeY = view.getUint16(o, true);
  o += 2;
  const bridgeHp = view.getUint8(o);
  o += 1;
  const bridgeActive = (view.getUint8(o) & 1) !== 0;
  o += 1;

  // Meta
  const score1 = view.getUint16(o, true);
  o += 2;
  const score2 = view.getUint16(o, true);
  o += 2;
  const phase = view.getUint8(o);
  o += 1;
  const countdown = view.getUint8(o);
  o += 1;
  const section = view.getUint8(o);
  o += 1;
  const scrollY = view.getFloat32(o, true);
  o += 4;
  const mode = view.getUint8(o);
  o += 1;
  const seed = view.getUint32(o, true);
  o += 4;
  const enemyCount = view.getUint8(o);
  o += 1;
  const fuelCount = view.getUint8(o);
  o += 1;
  const mineCount = view.getUint8(o);

  return {
    jet1X,
    jet1Y,
    jet1Speed,
    jet1Fuel,
    jet1Lives,
    jet1Alive: (j1Flags & 1) !== 0,
    jet1Invuln: (j1Flags & 2) !== 0,
    jet1Respawning: (j1Flags & 4) !== 0,
    jet2X,
    jet2Y,
    jet2Speed,
    jet2Fuel,
    jet2Lives,
    jet2Alive: (j2Flags & 1) !== 0,
    jet2Invuln: (j2Flags & 2) !== 0,
    jet2Respawning: (j2Flags & 4) !== 0,
    m1X,
    m1Y,
    m1Active: (m1Flags & 1) !== 0,
    m2X,
    m2Y,
    m2Active: (m2Flags & 1) !== 0,
    enemies,
    fuels,
    mines,
    bridgeY,
    bridgeHp,
    bridgeActive,
    score1,
    score2,
    phase,
    countdown,
    section,
    scrollY,
    mode,
    seed,
    enemyCount,
    fuelCount,
    mineCount,
  };
}

/**
 * Encode player input for peer → host transmission.
 * Layout: [type(1)][keyCode(1)][pressed(1)]
 * @param {number} keyCode - INPUT_KEY enum value
 * @param {boolean} pressed
 * @returns {ArrayBuffer}
 */
export function encodePlayerInput(keyCode, pressed) {
  const buf = new ArrayBuffer(PLAYER_INPUT_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, MSG_TYPE.PLAYER_INPUT);
  view.setUint8(1, keyCode);
  view.setUint8(2, pressed ? 1 : 0);
  return buf;
}

/**
 * Decode player input from binary buffer.
 * @param {ArrayBuffer} buf
 * @returns {object|null}
 */
export function decodePlayerInput(buf) {
  if (buf.byteLength < PLAYER_INPUT_SIZE) return null;
  const view = new DataView(buf);
  if (view.getUint8(0) !== MSG_TYPE.PLAYER_INPUT) return null;
  return {
    keyCode: view.getUint8(1),
    pressed: view.getUint8(2) === 1,
  };
}

/**
 * Encode game end for host → peer transmission.
 * Layout: [type(1)][score1Hi(1)][score1Lo(1)][score2Hi(1)][score2Lo(1)][winner(1)]
 * @param {object} result
 * @returns {ArrayBuffer}
 */
export function encodeGameEnd(result) {
  const buf = new ArrayBuffer(GAME_END_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, MSG_TYPE.GAME_END);
  view.setUint8(1, (result.score1 >> 8) & 0xff);
  view.setUint8(2, result.score1 & 0xff);
  view.setUint8(3, (result.score2 >> 8) & 0xff);
  view.setUint8(4, result.score2 & 0xff);
  view.setUint8(5, result.winner);
  return buf;
}

/**
 * Decode game end from binary buffer.
 * @param {ArrayBuffer} buf
 * @returns {object|null}
 */
export function decodeGameEnd(buf) {
  if (buf.byteLength < GAME_END_SIZE) return null;
  const view = new DataView(buf);
  if (view.getUint8(0) !== MSG_TYPE.GAME_END) return null;
  return {
    score1: (view.getUint8(1) << 8) | view.getUint8(2),
    score2: (view.getUint8(3) << 8) | view.getUint8(4),
    winner: view.getUint8(5),
  };
}

/**
 * Encode game ready signal (peer → host).
 * Layout: [type(1)]
 * @returns {ArrayBuffer}
 */
export function encodeGameReady() {
  const buf = new ArrayBuffer(GAME_READY_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, MSG_TYPE.GAME_READY);
  return buf;
}

/**
 * Get message type from raw buffer.
 * @param {ArrayBuffer} buf
 * @returns {number|null}
 */
export function getMessageType(buf) {
  if (buf.byteLength < 1) return null;
  return new DataView(buf).getUint8(0);
}
