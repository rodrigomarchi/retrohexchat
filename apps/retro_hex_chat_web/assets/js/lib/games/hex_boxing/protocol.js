/**
 * Binary protocol for Hex Boxing game state over WebRTC DataChannel.
 * All messages use DataView for zero-JSON binary encoding.
 * @module games/hex_boxing_protocol
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
  FIGHTING: 3,
  ROUND_OVER: 4,
  MATCH_OVER: 5,
};

// Input key enum
export const INPUT_KEY = {
  UP: 0,
  DOWN: 1,
  LEFT: 2,
  RIGHT: 3,
  PUNCH: 4,
};

// Punch state enum
export const PUNCH_STATE = {
  IDLE: 0,
  PUNCHING: 1,
  COOLDOWN: 2,
};

// --- Sizes ---
// Boxer: [x(2)][y(2)][dir(1)][flags(1)][punchTimer(1)] = 7 bytes each, x2 = 14
// Scores: [score1(1)][score2(1)] = 2
// Meta: [phase(1)][countdown(1)][round(1)][roundWins1(1)][roundWins2(1)][roundTimer(2)] = 7
// Events: [lastHitPlayer(1)][lastHitPoints(1)] = 2
// Total: 1 (type) + 14 + 2 + 7 + 2 = 26
const GAME_STATE_SIZE = 26;
const PLAYER_INPUT_SIZE = 3;
const GAME_END_SIZE = 6;
const GAME_READY_SIZE = 1;

/**
 * Pack boxer flags into a single byte.
 * bits [1:0] = punchState (0-2), bit 2 = arm (0=left,1=right)
 * @param {number} punchState
 * @param {number} arm
 * @returns {number}
 */
function packBoxerFlags(punchState, arm) {
  return (punchState & 0x03) | ((arm & 0x01) << 2);
}

/**
 * Unpack boxer flags from a single byte.
 * @param {number} flags
 * @returns {{ punchState: number, arm: number }}
 */
function unpackBoxerFlags(flags) {
  return {
    punchState: flags & 0x03,
    arm: (flags >> 2) & 0x01,
  };
}

/**
 * Encode full game state for host -> peer transmission.
 * Total: 26 bytes
 * @param {object} state
 * @returns {ArrayBuffer}
 */
export function encodeGameState(state) {
  const buf = new ArrayBuffer(GAME_STATE_SIZE);
  const view = new DataView(buf);
  let offset = 0;

  view.setUint8(offset, MSG_TYPE.GAME_STATE);
  offset += 1;

  // Boxer 1
  view.setUint16(offset, Math.round(state.b1x) & 0xffff, true);
  offset += 2;
  view.setUint16(offset, Math.round(state.b1y) & 0xffff, true);
  offset += 2;
  view.setUint8(offset, state.b1dir);
  offset += 1;
  view.setUint8(offset, packBoxerFlags(state.b1punchState, state.b1arm));
  offset += 1;
  view.setUint8(offset, state.b1punchTimer);
  offset += 1;

  // Boxer 2
  view.setUint16(offset, Math.round(state.b2x) & 0xffff, true);
  offset += 2;
  view.setUint16(offset, Math.round(state.b2y) & 0xffff, true);
  offset += 2;
  view.setUint8(offset, state.b2dir);
  offset += 1;
  view.setUint8(offset, packBoxerFlags(state.b2punchState, state.b2arm));
  offset += 1;
  view.setUint8(offset, state.b2punchTimer);
  offset += 1;

  // Scores
  view.setUint8(offset, state.score1);
  offset += 1;
  view.setUint8(offset, state.score2);
  offset += 1;

  // Meta
  view.setUint8(offset, state.phase);
  offset += 1;
  view.setUint8(offset, state.countdown);
  offset += 1;
  view.setUint8(offset, state.round);
  offset += 1;
  view.setUint8(offset, state.roundWins1);
  offset += 1;
  view.setUint8(offset, state.roundWins2);
  offset += 1;
  view.setUint16(offset, state.roundTimer, true);
  offset += 2;

  // Events
  view.setUint8(offset, state.lastHitPlayer);
  offset += 1;
  view.setUint8(offset, state.lastHitPoints);

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

  // Boxer 1
  const b1x = view.getUint16(offset, true);
  offset += 2;
  const b1y = view.getUint16(offset, true);
  offset += 2;
  const b1dir = view.getUint8(offset);
  offset += 1;
  const b1Flags = unpackBoxerFlags(view.getUint8(offset));
  offset += 1;
  const b1punchTimer = view.getUint8(offset);
  offset += 1;

  // Boxer 2
  const b2x = view.getUint16(offset, true);
  offset += 2;
  const b2y = view.getUint16(offset, true);
  offset += 2;
  const b2dir = view.getUint8(offset);
  offset += 1;
  const b2Flags = unpackBoxerFlags(view.getUint8(offset));
  offset += 1;
  const b2punchTimer = view.getUint8(offset);
  offset += 1;

  // Scores
  const score1 = view.getUint8(offset);
  offset += 1;
  const score2 = view.getUint8(offset);
  offset += 1;

  // Meta
  const phase = view.getUint8(offset);
  offset += 1;
  const countdown = view.getUint8(offset);
  offset += 1;
  const round = view.getUint8(offset);
  offset += 1;
  const roundWins1 = view.getUint8(offset);
  offset += 1;
  const roundWins2 = view.getUint8(offset);
  offset += 1;
  const roundTimer = view.getUint16(offset, true);
  offset += 2;

  // Events
  const lastHitPlayer = view.getUint8(offset);
  offset += 1;
  const lastHitPoints = view.getUint8(offset);

  return {
    b1x,
    b1y,
    b1dir,
    b1punchState: b1Flags.punchState,
    b1arm: b1Flags.arm,
    b1punchTimer,
    b2x,
    b2y,
    b2dir,
    b2punchState: b2Flags.punchState,
    b2arm: b2Flags.arm,
    b2punchTimer,
    score1,
    score2,
    phase,
    countdown,
    round,
    roundWins1,
    roundWins2,
    roundTimer,
    lastHitPlayer,
    lastHitPoints,
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
