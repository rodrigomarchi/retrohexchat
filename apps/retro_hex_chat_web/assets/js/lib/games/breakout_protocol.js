/**
 * Binary protocol for Block Breakers game state over WebRTC DataChannel.
 * All messages use DataView for zero-JSON binary encoding.
 * @module games/breakout_protocol
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
  LIFE_LOST: 4,
  FINISHED: 5,
};

// Input key enum
export const INPUT_KEY = {
  LEFT: 0,
  RIGHT: 1,
};

// Block grid dimensions
export const BLOCK_ROWS = 5;
export const BLOCK_COLS = 10;
export const TOTAL_BLOCKS = BLOCK_ROWS * BLOCK_COLS;
const BITMAP_BYTES = Math.ceil(TOTAL_BLOCKS / 8); // 7 bytes for 50 bits

// --- Sizes ---
// [type(1)][ballX(4)][ballY(4)][ballVX(4)][ballVY(4)][p1X(2)][p2X(2)][score(2)][lives(1)][phase(1)][countdown(1)][blocksRemaining(1)][bitmap(7)]
const GAME_STATE_SIZE = 1 + 4 + 4 + 4 + 4 + 2 + 2 + 2 + 1 + 1 + 1 + 1 + BITMAP_BYTES; // 34
const PLAYER_INPUT_SIZE = 3;
const GAME_END_SIZE = 4;
const GAME_READY_SIZE = 1;

/**
 * Encode block alive states as a bitmap (7 bytes for 50 blocks).
 * Bit=1 means block is alive.
 * @param {Array<{alive: boolean}>} blocks
 * @returns {Uint8Array}
 */
export function encodeBlockBitmap(blocks) {
  const bytes = new Uint8Array(BITMAP_BYTES);
  for (let i = 0; i < TOTAL_BLOCKS; i++) {
    if (blocks[i] && blocks[i].alive) {
      const byteIndex = Math.floor(i / 8);
      const bitIndex = 7 - (i % 8);
      bytes[byteIndex] |= 1 << bitIndex;
    }
  }
  return bytes;
}

/**
 * Decode block bitmap back to alive array.
 * @param {Uint8Array} bytes
 * @returns {boolean[]}
 */
export function decodeBlockBitmap(bytes) {
  const alive = [];
  for (let i = 0; i < TOTAL_BLOCKS; i++) {
    const byteIndex = Math.floor(i / 8);
    const bitIndex = 7 - (i % 8);
    alive.push((bytes[byteIndex] & (1 << bitIndex)) !== 0);
  }
  return alive;
}

/**
 * Encode full game state for host -> peer transmission.
 * Total: 34 bytes
 * @param {object} state
 * @returns {ArrayBuffer}
 */
export function encodeGameState(state) {
  const buf = new ArrayBuffer(GAME_STATE_SIZE);
  const view = new DataView(buf);
  let offset = 0;

  view.setUint8(offset, MSG_TYPE.GAME_STATE);
  offset += 1;
  view.setFloat32(offset, state.ballX, true);
  offset += 4;
  view.setFloat32(offset, state.ballY, true);
  offset += 4;
  view.setFloat32(offset, state.ballVX, true);
  offset += 4;
  view.setFloat32(offset, state.ballVY, true);
  offset += 4;
  view.setUint16(offset, Math.round(state.paddle1X), true);
  offset += 2;
  view.setUint16(offset, Math.round(state.paddle2X), true);
  offset += 2;
  view.setUint16(offset, state.score, true);
  offset += 2;
  view.setUint8(offset, state.lives);
  offset += 1;
  view.setUint8(offset, state.phase);
  offset += 1;
  view.setUint8(offset, state.countdown);
  offset += 1;
  view.setUint8(offset, state.blocksRemaining);
  offset += 1;

  // Block bitmap
  const bitmap = encodeBlockBitmap(state.blocks);
  const uint8 = new Uint8Array(buf);
  uint8.set(bitmap, offset);

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
  const ballX = view.getFloat32(offset, true);
  offset += 4;
  const ballY = view.getFloat32(offset, true);
  offset += 4;
  const ballVX = view.getFloat32(offset, true);
  offset += 4;
  const ballVY = view.getFloat32(offset, true);
  offset += 4;
  const paddle1X = view.getUint16(offset, true);
  offset += 2;
  const paddle2X = view.getUint16(offset, true);
  offset += 2;
  const score = view.getUint16(offset, true);
  offset += 2;
  const lives = view.getUint8(offset);
  offset += 1;
  const phase = view.getUint8(offset);
  offset += 1;
  const countdown = view.getUint8(offset);
  offset += 1;
  const blocksRemaining = view.getUint8(offset);
  offset += 1;

  // Block bitmap
  const bitmapBytes = new Uint8Array(buf, offset, BITMAP_BYTES);
  const blocksAlive = decodeBlockBitmap(bitmapBytes);

  return {
    ballX,
    ballY,
    ballVX,
    ballVY,
    paddle1X,
    paddle2X,
    score,
    lives,
    phase,
    countdown,
    blocksRemaining,
    blocksAlive,
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
 * Layout: [type(1)][score_hi(1)][score_lo(1)][won(1)]
 * @param {number} score
 * @param {boolean} won
 * @returns {ArrayBuffer}
 */
export function encodeGameEnd(score, won) {
  const buf = new ArrayBuffer(GAME_END_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, MSG_TYPE.GAME_END);
  view.setUint16(1, score, true);
  view.setUint8(3, won ? 1 : 0);
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
    score: view.getUint16(1, true),
    won: view.getUint8(3) === 1,
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
