/**
 * Binary protocol for Pixel Tanks game state over WebRTC DataChannel.
 * All messages use DataView for zero-JSON binary encoding.
 * @module games/pixel_tanks_protocol
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
  MATCH_OVER: 5,
};

// Input key enum
export const INPUT_KEY = {
  ROTATE_LEFT: 0,
  ROTATE_RIGHT: 1,
  FORWARD: 2,
  FIRE: 3,
};

// Game mode enum (protocol-ready for future modes)
export const GAME_MODE = {
  CLASSIC: 0,
  MAZE_BATTLE: 1,
  RICOCHET: 2,
  GUIDED: 3,
};

// --- Sizes ---
// Tank: [x(4)][y(4)][rotation(2)][flags(1)] = 11 bytes each, x2 = 22
// Missile: [x(4)][y(4)][vx(4)][vy(4)][flags(1)] = 17 bytes each, x2 = 34
// Meta: [score1(1)][score2(1)][phase(1)][countdown(1)][mode(1)][mazeIndex(1)]
//       [round(1)][roundWins1(1)][roundWins2(1)][roundTimer(2)] = 11
// Total: 1 (type) + 22 + 34 + 11 = 68
const GAME_STATE_SIZE = 68;
const PLAYER_INPUT_SIZE = 3;
const GAME_END_SIZE = 6;
const GAME_READY_SIZE = 1;

/**
 * Encode full game state for host -> peer transmission.
 * Total: 68 bytes
 * @param {object} state
 * @returns {ArrayBuffer}
 */
export function encodeGameState(state) {
  const buf = new ArrayBuffer(GAME_STATE_SIZE);
  const view = new DataView(buf);
  let offset = 0;

  view.setUint8(offset, MSG_TYPE.GAME_STATE);
  offset += 1;

  // Tank 1
  view.setFloat32(offset, state.tank1X, true);
  offset += 4;
  view.setFloat32(offset, state.tank1Y, true);
  offset += 4;
  view.setUint16(offset, Math.round(state.tank1Rot * 10000) & 0xffff, true);
  offset += 2;
  view.setUint8(offset, (state.tank1Alive ? 1 : 0) | (state.tank1Invuln ? 2 : 0));
  offset += 1;

  // Tank 2
  view.setFloat32(offset, state.tank2X, true);
  offset += 4;
  view.setFloat32(offset, state.tank2Y, true);
  offset += 4;
  view.setUint16(offset, Math.round(state.tank2Rot * 10000) & 0xffff, true);
  offset += 2;
  view.setUint8(offset, (state.tank2Alive ? 1 : 0) | (state.tank2Invuln ? 2 : 0));
  offset += 1;

  // Missile 1
  view.setFloat32(offset, state.m1X, true);
  offset += 4;
  view.setFloat32(offset, state.m1Y, true);
  offset += 4;
  view.setFloat32(offset, state.m1VX, true);
  offset += 4;
  view.setFloat32(offset, state.m1VY, true);
  offset += 4;
  view.setUint8(offset, (state.m1Active ? 1 : 0) | (state.m1Bounced ? 2 : 0));
  offset += 1;

  // Missile 2
  view.setFloat32(offset, state.m2X, true);
  offset += 4;
  view.setFloat32(offset, state.m2Y, true);
  offset += 4;
  view.setFloat32(offset, state.m2VX, true);
  offset += 4;
  view.setFloat32(offset, state.m2VY, true);
  offset += 4;
  view.setUint8(offset, (state.m2Active ? 1 : 0) | (state.m2Bounced ? 2 : 0));
  offset += 1;

  // Meta
  view.setUint8(offset, state.score1);
  offset += 1;
  view.setUint8(offset, state.score2);
  offset += 1;
  view.setUint8(offset, state.phase);
  offset += 1;
  view.setUint8(offset, state.countdown);
  offset += 1;
  view.setUint8(offset, state.mode);
  offset += 1;
  view.setUint8(offset, state.mazeIndex);
  offset += 1;
  view.setUint8(offset, state.round);
  offset += 1;
  view.setUint8(offset, state.roundWins1);
  offset += 1;
  view.setUint8(offset, state.roundWins2);
  offset += 1;
  view.setUint16(offset, state.roundTimer, true);

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

  let offset = 1;

  // Tank 1
  const tank1X = view.getFloat32(offset, true);
  offset += 4;
  const tank1Y = view.getFloat32(offset, true);
  offset += 4;
  const tank1Rot = view.getUint16(offset, true) / 10000;
  offset += 2;
  const t1Flags = view.getUint8(offset);
  offset += 1;

  // Tank 2
  const tank2X = view.getFloat32(offset, true);
  offset += 4;
  const tank2Y = view.getFloat32(offset, true);
  offset += 4;
  const tank2Rot = view.getUint16(offset, true) / 10000;
  offset += 2;
  const t2Flags = view.getUint8(offset);
  offset += 1;

  // Missile 1
  const m1X = view.getFloat32(offset, true);
  offset += 4;
  const m1Y = view.getFloat32(offset, true);
  offset += 4;
  const m1VX = view.getFloat32(offset, true);
  offset += 4;
  const m1VY = view.getFloat32(offset, true);
  offset += 4;
  const m1Flags = view.getUint8(offset);
  offset += 1;

  // Missile 2
  const m2X = view.getFloat32(offset, true);
  offset += 4;
  const m2Y = view.getFloat32(offset, true);
  offset += 4;
  const m2VX = view.getFloat32(offset, true);
  offset += 4;
  const m2VY = view.getFloat32(offset, true);
  offset += 4;
  const m2Flags = view.getUint8(offset);
  offset += 1;

  // Meta
  const score1 = view.getUint8(offset);
  offset += 1;
  const score2 = view.getUint8(offset);
  offset += 1;
  const phase = view.getUint8(offset);
  offset += 1;
  const countdown = view.getUint8(offset);
  offset += 1;
  const mode = view.getUint8(offset);
  offset += 1;
  const mazeIndex = view.getUint8(offset);
  offset += 1;
  const round = view.getUint8(offset);
  offset += 1;
  const roundWins1 = view.getUint8(offset);
  offset += 1;
  const roundWins2 = view.getUint8(offset);
  offset += 1;
  const roundTimer = view.getUint16(offset, true);

  return {
    tank1X,
    tank1Y,
    tank1Rot,
    tank1Alive: (t1Flags & 1) !== 0,
    tank1Invuln: (t1Flags & 2) !== 0,
    tank2X,
    tank2Y,
    tank2Rot,
    tank2Alive: (t2Flags & 1) !== 0,
    tank2Invuln: (t2Flags & 2) !== 0,
    m1X,
    m1Y,
    m1VX,
    m1VY,
    m1Active: (m1Flags & 1) !== 0,
    m1Bounced: (m1Flags & 2) !== 0,
    m2X,
    m2Y,
    m2VX,
    m2VY,
    m2Active: (m2Flags & 1) !== 0,
    m2Bounced: (m2Flags & 2) !== 0,
    score1,
    score2,
    phase,
    countdown,
    mode,
    mazeIndex,
    round,
    roundWins1,
    roundWins2,
    roundTimer,
  };
}

/**
 * Encode player input for peer -> host transmission.
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
 * Encode game end for host -> peer transmission.
 * Layout: [type(1)][score1(1)][score2(1)][winner(1)][roundWins1(1)][roundWins2(1)]
 * @param {object} result
 * @returns {ArrayBuffer}
 */
export function encodeGameEnd(result) {
  const buf = new ArrayBuffer(GAME_END_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, MSG_TYPE.GAME_END);
  view.setUint8(1, result.score1);
  view.setUint8(2, result.score2);
  view.setUint8(3, result.winner);
  view.setUint8(4, result.roundWins1);
  view.setUint8(5, result.roundWins2);
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
    roundWins1: view.getUint8(4),
    roundWins2: view.getUint8(5),
  };
}

/**
 * Encode game ready signal (peer -> host).
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
