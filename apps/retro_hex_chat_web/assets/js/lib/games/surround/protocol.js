/**
 * Binary protocol for Light Trails game state over WebRTC DataChannel.
 * All messages use DataView for zero-JSON binary encoding.
 * @module games/surround_protocol
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
  PLAYING: 2,
  ROUND_OVER: 3,
  MATCH_OVER: 4,
};

// Direction enum
export const DIR = {
  UP: 0,
  DOWN: 1,
  LEFT: 2,
  RIGHT: 3,
};

// Input key enum (same values as DIR for this game)
export const INPUT_KEY = {
  UP: 0,
  DOWN: 1,
  LEFT: 2,
  RIGHT: 3,
};

// Grid constants
export const GRID_W = 60;
export const GRID_H = 40;
export const WINS_NEEDED = 3;

// --- Sizes ---
// [type(1)][p1x(1)][p1y(1)][p1dir(1)][p2x(1)][p2y(1)][p2dir(1)][s1(1)][s2(1)][phase(1)][countdown(1)][round(1)]
const GAME_STATE_SIZE = 12;
const PLAYER_INPUT_SIZE = 3;
const GAME_END_SIZE = 4;
const GAME_READY_SIZE = 1;

/**
 * Encode full game state for host -> peer transmission.
 * Total: 12 bytes (heads-only — peer reconstructs grid locally).
 * @param {object} state
 * @returns {ArrayBuffer}
 */
export function encodeGameState(state) {
  const buf = new ArrayBuffer(GAME_STATE_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, MSG_TYPE.GAME_STATE);
  view.setUint8(1, state.p1.x);
  view.setUint8(2, state.p1.y);
  view.setUint8(3, state.p1.dir);
  view.setUint8(4, state.p2.x);
  view.setUint8(5, state.p2.y);
  view.setUint8(6, state.p2.dir);
  view.setUint8(7, state.score1);
  view.setUint8(8, state.score2);
  view.setUint8(9, state.phase);
  view.setUint8(10, state.countdown);
  view.setUint8(11, state.round & 0xff);
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
    p1x: view.getUint8(1),
    p1y: view.getUint8(2),
    p1dir: view.getUint8(3),
    p2x: view.getUint8(4),
    p2y: view.getUint8(5),
    p2dir: view.getUint8(6),
    score1: view.getUint8(7),
    score2: view.getUint8(8),
    phase: view.getUint8(9),
    countdown: view.getUint8(10),
    round: view.getUint8(11),
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
 * Layout: [type(1)][score1(1)][score2(1)][winner(1)]
 * winner: 1=player1, 2=player2, 0=draw
 * @param {number} score1
 * @param {number} score2
 * @param {number} winner
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
