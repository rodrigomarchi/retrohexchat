/**
 * Binary protocol for Hex Pong game state over WebRTC DataChannel.
 * All messages use DataView for zero-JSON binary encoding.
 * @module games/pong_protocol
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
  SERVING: 2,
  PLAYING: 3,
  SCORED: 4,
  FINISHED: 5,
};

// Input key enum
export const INPUT_KEY = {
  UP: 0,
  DOWN: 1,
};

// --- Sizes ---
const GAME_STATE_SIZE = 25;
const PLAYER_INPUT_SIZE = 3;
const GAME_END_SIZE = 4;
const GAME_READY_SIZE = 1;

/**
 * Encode full game state for host → peer transmission.
 * Layout: [type(1)][ballX(4)][ballY(4)][ballVX(4)][ballVY(4)][p1Y(2)][p2Y(2)][s1(1)][s2(1)][phase(1)][countdown(1)]
 * Total: 25 bytes
 * @param {object} state
 * @returns {ArrayBuffer}
 */
export function encodeGameState(state) {
  const buf = new ArrayBuffer(GAME_STATE_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, MSG_TYPE.GAME_STATE);
  view.setFloat32(1, state.ballX, true);
  view.setFloat32(5, state.ballY, true);
  view.setFloat32(9, state.ballVX, true);
  view.setFloat32(13, state.ballVY, true);
  view.setUint16(17, Math.round(state.paddle1Y), true);
  view.setUint16(19, Math.round(state.paddle2Y), true);
  view.setUint8(21, state.score1);
  view.setUint8(22, state.score2);
  view.setUint8(23, state.phase);
  view.setUint8(24, state.countdown);
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
  return {
    ballX: view.getFloat32(1, true),
    ballY: view.getFloat32(5, true),
    ballVX: view.getFloat32(9, true),
    ballVY: view.getFloat32(13, true),
    paddle1Y: view.getUint16(17, true),
    paddle2Y: view.getUint16(19, true),
    score1: view.getUint8(21),
    score2: view.getUint8(22),
    phase: view.getUint8(23),
    countdown: view.getUint8(24),
  };
}

/**
 * Encode player input for peer → host transmission.
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
    pressed: view.getUint8(2) === 1,
  };
}

/**
 * Encode game end for host → peer transmission.
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
 * Encode game ready signal (peer → host).
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
