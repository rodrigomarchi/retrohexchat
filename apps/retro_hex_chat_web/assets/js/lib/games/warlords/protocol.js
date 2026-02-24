/**
 * Binary protocol for Hex Warlords game state over WebRTC DataChannel.
 * All messages use DataView for zero-JSON binary encoding.
 * @module games/warlords_protocol
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
  KING_HIT: 3,
  FINISHED: 4,
};

// Input key enum
export const INPUT_KEY = {
  UP: 0,
  DOWN: 1,
  SPACE: 2,
};

// Castle constants
export const BRICKS_ROWS = 6;
export const BRICKS_COLS = 4;
export const BRICKS_PER_CASTLE = BRICKS_ROWS * BRICKS_COLS; // 24
const BITMAP_BYTES_PER_CASTLE = Math.ceil(BRICKS_PER_CASTLE / 8); // 3 bytes for 24 bits
export const INITIAL_LIVES = 3;

// --- Sizes ---
// [type(1)][fbX(4)][fbY(4)][fbVX(4)][fbVY(4)][s1Y(2)][s2Y(2)][p1Bricks(3)][p2Bricks(3)]
// [p1Lives(1)][p2Lives(1)][phase(1)][countdown(1)][round(1)][caughtBy(1)]
const GAME_STATE_SIZE =
  1 + 4 + 4 + 4 + 4 + 2 + 2 + BITMAP_BYTES_PER_CASTLE * 2 + 1 + 1 + 1 + 1 + 1 + 1; // 33
const PLAYER_INPUT_SIZE = 3;
const GAME_END_SIZE = 4;
const GAME_READY_SIZE = 1;

/**
 * Encode brick alive states as a bitmap (3 bytes for 24 bricks).
 * Bit=1 means brick is alive.
 * @param {Array<{alive: boolean}>} bricks
 * @returns {Uint8Array}
 */
export function encodeBrickBitmap(bricks) {
  const bytes = new Uint8Array(BITMAP_BYTES_PER_CASTLE);
  for (let i = 0; i < BRICKS_PER_CASTLE; i++) {
    if (bricks[i] && bricks[i].alive) {
      const byteIndex = Math.floor(i / 8);
      const bitIndex = 7 - (i % 8);
      bytes[byteIndex] |= 1 << bitIndex;
    }
  }
  return bytes;
}

/**
 * Decode brick bitmap back to alive array.
 * @param {Uint8Array} bytes
 * @returns {boolean[]}
 */
export function decodeBrickBitmap(bytes) {
  const alive = [];
  for (let i = 0; i < BRICKS_PER_CASTLE; i++) {
    const byteIndex = Math.floor(i / 8);
    const bitIndex = 7 - (i % 8);
    alive.push((bytes[byteIndex] & (1 << bitIndex)) !== 0);
  }
  return alive;
}

/**
 * Encode full game state for host -> peer transmission.
 * Total: 33 bytes
 * @param {object} state
 * @returns {ArrayBuffer}
 */
export function encodeGameState(state) {
  const buf = new ArrayBuffer(GAME_STATE_SIZE);
  const view = new DataView(buf);
  let offset = 0;

  view.setUint8(offset, MSG_TYPE.GAME_STATE);
  offset += 1;
  view.setFloat32(offset, state.fireballX, true);
  offset += 4;
  view.setFloat32(offset, state.fireballY, true);
  offset += 4;
  view.setFloat32(offset, state.fireballVX, true);
  offset += 4;
  view.setFloat32(offset, state.fireballVY, true);
  offset += 4;
  view.setUint16(offset, Math.round(state.shield1Y), true);
  offset += 2;
  view.setUint16(offset, Math.round(state.shield2Y), true);
  offset += 2;

  // P1 brick bitmap
  const p1Bitmap = encodeBrickBitmap(state.p1Bricks);
  const uint8 = new Uint8Array(buf);
  uint8.set(p1Bitmap, offset);
  offset += BITMAP_BYTES_PER_CASTLE;

  // P2 brick bitmap
  const p2Bitmap = encodeBrickBitmap(state.p2Bricks);
  uint8.set(p2Bitmap, offset);
  offset += BITMAP_BYTES_PER_CASTLE;

  view.setUint8(offset, state.p1Lives);
  offset += 1;
  view.setUint8(offset, state.p2Lives);
  offset += 1;
  view.setUint8(offset, state.phase);
  offset += 1;
  view.setUint8(offset, state.countdown);
  offset += 1;
  view.setUint8(offset, state.round);
  offset += 1;
  view.setUint8(offset, state.caughtBy);

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
  const fireballX = view.getFloat32(offset, true);
  offset += 4;
  const fireballY = view.getFloat32(offset, true);
  offset += 4;
  const fireballVX = view.getFloat32(offset, true);
  offset += 4;
  const fireballVY = view.getFloat32(offset, true);
  offset += 4;
  const shield1Y = view.getUint16(offset, true);
  offset += 2;
  const shield2Y = view.getUint16(offset, true);
  offset += 2;

  // P1 brick bitmap
  const p1BitmapBytes = new Uint8Array(buf, offset, BITMAP_BYTES_PER_CASTLE);
  const p1BricksAlive = decodeBrickBitmap(p1BitmapBytes);
  offset += BITMAP_BYTES_PER_CASTLE;

  // P2 brick bitmap
  const p2BitmapBytes = new Uint8Array(buf, offset, BITMAP_BYTES_PER_CASTLE);
  const p2BricksAlive = decodeBrickBitmap(p2BitmapBytes);
  offset += BITMAP_BYTES_PER_CASTLE;

  const p1Lives = view.getUint8(offset);
  offset += 1;
  const p2Lives = view.getUint8(offset);
  offset += 1;
  const phase = view.getUint8(offset);
  offset += 1;
  const countdown = view.getUint8(offset);
  offset += 1;
  const round = view.getUint8(offset);
  offset += 1;
  const caughtBy = view.getUint8(offset);

  return {
    fireballX,
    fireballY,
    fireballVX,
    fireballVY,
    shield1Y,
    shield2Y,
    p1BricksAlive,
    p2BricksAlive,
    p1Lives,
    p2Lives,
    phase,
    countdown,
    round,
    caughtBy,
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
 * Layout: [type(1)][p1Lives(1)][p2Lives(1)][winner(1)]
 * @param {number} p1Lives
 * @param {number} p2Lives
 * @param {number} winner - 1 or 2
 * @returns {ArrayBuffer}
 */
export function encodeGameEnd(p1Lives, p2Lives, winner) {
  const buf = new ArrayBuffer(GAME_END_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, MSG_TYPE.GAME_END);
  view.setUint8(1, p1Lives);
  view.setUint8(2, p2Lives);
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
    p1Lives: view.getUint8(1),
    p2Lives: view.getUint8(2),
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
