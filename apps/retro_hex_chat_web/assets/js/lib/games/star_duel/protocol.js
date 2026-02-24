/**
 * Binary protocol for Star Duel space combat game over WebRTC DataChannel.
 * All messages use DataView for zero-JSON binary encoding.
 *
 * GAME_STATE is variable-length: 51 bytes header + 18 bytes per missile (max 6).
 * Ship rotation is encoded as Uint16 = rotation * 10000 (0-62831 for 0-2pi).
 * Ship flags pack 5 booleans into a single byte (bits 0-4).
 *
 * @module games/star_duel_protocol
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
  SPAWNING: 2,
  PLAYING: 3,
  ROUND_OVER: 4,
  FINISHED: 5,
};

// Input key enum
export const INPUT_KEY = {
  ROTATE_LEFT: 0,
  ROTATE_RIGHT: 1,
  THRUST: 2,
  FIRE: 3,
  WARP: 4,
};

// Game mode enum
export const GAME_MODE = {
  OPEN_SPACE: 0,
  GRAVITY_WELL: 1,
  DEBRIS_FIELD: 2,
};

// --- Sizes ---
const GAME_STATE_HEADER_SIZE = 51; // 51 bytes header + 18 bytes per missile
const MISSILE_SIZE = 18;
const MAX_MISSILES = 6;
const PLAYER_INPUT_SIZE = 3;
const GAME_END_SIZE = 4;
const GAME_READY_SIZE = 1;

// --- Ship offset helpers ---
// Ship block: x(4) y(4) vx(4) vy(4) rot(2) flags(1) = 19 bytes
const SHIP_BLOCK_SIZE = 19;
const SHIP1_OFFSET = 1;
const SHIP2_OFFSET = 1 + SHIP_BLOCK_SIZE; // 20

// --- Rotation encoding ---
const ROTATION_SCALE = 10000;

/**
 * Encode ship flags into a single byte.
 * bit0=alive, bit1=thrustActive, bit2=exploding, bit3=warping, bit4=invulnerable
 * @param {object} flags
 * @param {boolean} flags.alive
 * @param {boolean} flags.thrustActive
 * @param {boolean} flags.exploding
 * @param {boolean} flags.warping
 * @param {boolean} flags.invulnerable
 * @returns {number}
 */
export function encodeShipFlags(flags) {
  let byte = 0;
  if (flags.alive) byte |= 1;
  if (flags.thrustActive) byte |= 2;
  if (flags.exploding) byte |= 4;
  if (flags.warping) byte |= 8;
  if (flags.invulnerable) byte |= 16;
  return byte;
}

/**
 * Decode ship flags from a single byte.
 * @param {number} byte
 * @returns {{alive: boolean, thrustActive: boolean, exploding: boolean, warping: boolean, invulnerable: boolean}}
 */
export function decodeShipFlags(byte) {
  return {
    alive: (byte & 1) !== 0,
    thrustActive: (byte & 2) !== 0,
    exploding: (byte & 4) !== 0,
    warping: (byte & 8) !== 0,
    invulnerable: (byte & 16) !== 0,
  };
}

/**
 * Write a ship block into a DataView at the given offset.
 * Layout: [x(4)][y(4)][vx(4)][vy(4)][rot(2)][flags(1)] = 19 bytes
 * @param {DataView} view
 * @param {number} offset
 * @param {object} ship
 */
function writeShip(view, offset, ship) {
  view.setFloat32(offset, ship.x, true);
  view.setFloat32(offset + 4, ship.y, true);
  view.setFloat32(offset + 8, ship.vx, true);
  view.setFloat32(offset + 12, ship.vy, true);
  const TWO_PI = Math.PI * 2;
  const normalizedRot = ((ship.rotation % TWO_PI) + TWO_PI) % TWO_PI;
  view.setUint16(offset + 16, Math.round(normalizedRot * ROTATION_SCALE), true);
  const flags = typeof ship.flags === "number" ? ship.flags : encodeShipFlags(ship.flags);
  view.setUint8(offset + 18, flags);
}

/**
 * Read a ship block from a DataView at the given offset.
 * @param {DataView} view
 * @param {number} offset
 * @returns {object}
 */
function readShip(view, offset) {
  return {
    x: view.getFloat32(offset, true),
    y: view.getFloat32(offset + 4, true),
    vx: view.getFloat32(offset + 8, true),
    vy: view.getFloat32(offset + 12, true),
    rotation: view.getUint16(offset + 16, true) / ROTATION_SCALE,
    flags: decodeShipFlags(view.getUint8(offset + 18)),
  };
}

/**
 * Encode full game state for host -> peer transmission.
 * Layout (variable length, 51 + 18*N bytes):
 *   Header (51 bytes):
 *     [type(1)]
 *     [ship1: x(4) y(4) vx(4) vy(4) rot(2) flags(1)] = 19 bytes
 *     [ship2: x(4) y(4) vx(4) vy(4) rot(2) flags(1)] = 19 bytes
 *     [score1(1) score2(1) phase(1) countdown(1) mode(1) missileCount(1) asteroidSeed(2)] = 8 bytes
 *     [invuln1(1) invuln2(1)] = 2 bytes
 *     [warpCooldown1(1) warpCooldown2(1)] = 2 bytes
 *   Per missile (18 bytes each, max 6):
 *     [mx(4)][my(4)][mvx(4)][mvy(4)][owner(1)][age(1)]
 * @param {object} state
 * @returns {ArrayBuffer}
 */
export function encodeGameState(state) {
  const missiles = state.missiles || [];
  const missileCount = Math.min(missiles.length, MAX_MISSILES);
  const totalSize = GAME_STATE_HEADER_SIZE + missileCount * MISSILE_SIZE;
  const buf = new ArrayBuffer(totalSize);
  const view = new DataView(buf);

  // Type
  view.setUint8(0, MSG_TYPE.GAME_STATE);

  // Ships
  writeShip(view, SHIP1_OFFSET, state.ship1);
  writeShip(view, SHIP2_OFFSET, state.ship2);

  // Scores, phase, countdown, mode, missileCount, asteroidSeed
  const metaOffset = 1 + SHIP_BLOCK_SIZE * 2; // 39
  view.setUint8(metaOffset, state.score1);
  view.setUint8(metaOffset + 1, state.score2);
  view.setUint8(metaOffset + 2, state.phase);
  view.setUint8(metaOffset + 3, state.countdown);
  view.setUint8(metaOffset + 4, state.mode);
  view.setUint8(metaOffset + 5, missileCount);
  view.setUint16(metaOffset + 6, state.asteroidSeed || 0, true);

  // Invulnerability timers
  view.setUint8(metaOffset + 8, state.invuln1 || 0);
  view.setUint8(metaOffset + 9, state.invuln2 || 0);

  // Warp cooldowns
  view.setUint8(metaOffset + 10, state.warpCooldown1 || 0);
  view.setUint8(metaOffset + 11, state.warpCooldown2 || 0);

  // Missiles
  for (let i = 0; i < missileCount; i++) {
    const m = missiles[i];
    const mOff = GAME_STATE_HEADER_SIZE + i * MISSILE_SIZE;
    view.setFloat32(mOff, m.x, true);
    view.setFloat32(mOff + 4, m.y, true);
    view.setFloat32(mOff + 8, m.vx || 0, true);
    view.setFloat32(mOff + 12, m.vy || 0, true);
    view.setUint8(mOff + 16, m.owner);
    view.setUint8(mOff + 17, m.age);
  }

  return buf;
}

/**
 * Decode game state from binary buffer.
 * @param {ArrayBuffer} buf
 * @returns {object|null}
 */
export function decodeGameState(buf) {
  if (buf.byteLength < GAME_STATE_HEADER_SIZE) return null;
  const view = new DataView(buf);
  if (view.getUint8(0) !== MSG_TYPE.GAME_STATE) return null;

  const ship1 = readShip(view, SHIP1_OFFSET);
  const ship2 = readShip(view, SHIP2_OFFSET);

  const metaOffset = 1 + SHIP_BLOCK_SIZE * 2; // 39
  const score1 = view.getUint8(metaOffset);
  const score2 = view.getUint8(metaOffset + 1);
  const phase = Math.min(view.getUint8(metaOffset + 2), 5); // max PHASE.FINISHED
  const countdown = view.getUint8(metaOffset + 3);
  const mode = Math.min(view.getUint8(metaOffset + 4), 2); // max GAME_MODE.DEBRIS_FIELD
  const missileCount = view.getUint8(metaOffset + 5);
  const asteroidSeed = view.getUint16(metaOffset + 6, true);
  const invuln1 = view.getUint8(metaOffset + 8);
  const invuln2 = view.getUint8(metaOffset + 9);
  const warpCooldown1 = view.getUint8(metaOffset + 10);
  const warpCooldown2 = view.getUint8(metaOffset + 11);

  // Missiles
  const missiles = [];
  for (let i = 0; i < missileCount; i++) {
    const mOff = GAME_STATE_HEADER_SIZE + i * MISSILE_SIZE;
    if (mOff + MISSILE_SIZE > buf.byteLength) break;
    missiles.push({
      x: view.getFloat32(mOff, true),
      y: view.getFloat32(mOff + 4, true),
      vx: view.getFloat32(mOff + 8, true),
      vy: view.getFloat32(mOff + 12, true),
      owner: view.getUint8(mOff + 16),
      age: view.getUint8(mOff + 17),
    });
  }

  return {
    ship1,
    ship2,
    score1,
    score2,
    phase,
    countdown,
    mode,
    missileCount: missiles.length,
    asteroidSeed,
    invuln1,
    invuln2,
    warpCooldown1,
    warpCooldown2,
    missiles,
  };
}

/**
 * Encode player input for peer -> host transmission.
 * Layout: [type(1)][keyCode(1)][pressed(1)]
 * Total: 3 bytes
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
    pressed: view.getUint8(2) !== 0,
  };
}

/**
 * Encode game end for host -> peer transmission.
 * Layout: [type(1)][score1(1)][score2(1)][winner(1)]
 * Total: 4 bytes
 * @param {number} score1
 * @param {number} score2
 * @param {number} winner - 1 or 2
 * @returns {ArrayBuffer}
 */
export function encodeGameEnd(score1, score2, winner) {
  const buf = new ArrayBuffer(GAME_END_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, MSG_TYPE.GAME_END);
  view.setUint8(1, score1);
  view.setUint8(2, score2);
  view.setUint8(3, winner);
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
    score1: view.getUint8(1),
    score2: view.getUint8(2),
    winner: view.getUint8(3),
  };
}

/**
 * Encode game ready signal (peer -> host).
 * Layout: [type(1)]
 * Total: 1 byte
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
