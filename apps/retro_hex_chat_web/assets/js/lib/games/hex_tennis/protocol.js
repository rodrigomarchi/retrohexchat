/**
 * Binary protocol for Hex Tennis game state over WebRTC DataChannel.
 * All messages use DataView for zero-JSON binary encoding.
 * @module games/hex_tennis/protocol
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
  RALLY: 3,
  POINT: 4,
  CHANGEOVER: 5,
  GAME_OVER: 6,
};

// Input key enum
export const INPUT_KEY = {
  UP: 0,
  DOWN: 1,
  LEFT: 2,
  RIGHT: 3,
  SERVE: 4,
};

// Game mode enum
export const GAME_MODE = {
  CLASSIC: 0,
  QUICK: 1,
  SUDDEN_DEATH: 2,
};

// Announcement enum
export const ANNOUNCEMENT = {
  NONE: 0,
  DEUCE: 1,
  ADV_P1: 2,
  ADV_P2: 3,
  GAME: 4,
  TIEBREAK: 5,
};

// Out type enum
export const OUT_TYPE = {
  NONE: 0,
  WIDE: 1,
  LONG: 2,
  ACE: 3,
  DEAD: 4,
};

// --- Sizes ---
const GAME_STATE_SIZE = 32;
const PLAYER_INPUT_SIZE = 3;
const GAME_END_SIZE = 6;
const GAME_READY_SIZE = 1;

/**
 * Encode full game state for host → peer transmission.
 * Layout (32 bytes):
 *   [type(1)][p1x(2)][p1y(2)][p2x(2)][p2y(2)]
 *   [ballX(2)][ballY(2)][ballVX(2)][ballVY(2)][ballHeight(1)]
 *   [p1Points(1)][p2Points(1)][p1Games(1)][p2Games(1)]
 *   [phase(1)][countdown(1)][flags(1)]
 *   [outType(1)][pointWinner(1)][announcement(1)]
 *   [lastHitter(1)][rallyCount(1)][gameMode(1)][serveTimer(1)]
 * @param {object} state
 * @returns {ArrayBuffer}
 */
export function encodeGameState(state) {
  const buf = new ArrayBuffer(GAME_STATE_SIZE);
  const view = new DataView(buf);

  view.setUint8(0, MSG_TYPE.GAME_STATE);

  // Player positions (Uint16)
  view.setUint16(1, Math.round(state.p1x), true);
  view.setUint16(3, Math.round(state.p1y), true);
  view.setUint16(5, Math.round(state.p2x), true);
  view.setUint16(7, Math.round(state.p2y), true);

  // Ball position (Uint16, stored as x*10 for 0.1 precision, clamped to non-negative)
  view.setUint16(9, Math.max(0, Math.round(state.ballX * 10)), true);
  view.setUint16(11, Math.max(0, Math.round(state.ballY * 10)), true);

  // Ball velocity (Int16, stored as vx*100 for 0.01 precision)
  view.setInt16(13, Math.round(state.ballVX * 100), true);
  view.setInt16(15, Math.round(state.ballVY * 100), true);

  // Ball height (Uint8, 0-255 mapped to 0.0-1.0)
  view.setUint8(17, Math.round(Math.min(1, Math.max(0, state.ballHeight)) * 255));

  // Score
  view.setUint8(18, state.p1Points);
  view.setUint8(19, state.p2Points);
  view.setUint8(20, state.p1Games);
  view.setUint8(21, state.p2Games);

  // Phase and countdown
  view.setUint8(22, state.phase);
  view.setUint8(23, state.countdown);

  // Packed flags byte:
  //   bit 0: server (0=P1, 1=P2)
  //   bit 1: isTiebreak
  //   bit 2: hitEvent
  //   bit 3: serveEvent
  //   bit 4: netFault
  //   bit 5: outOfBounds
  //   bit 6: faultEvent
  //   bit 7: isSecondServe
  let flags = 0;
  if (state.server === 2) flags |= 0x01;
  if (state.isTiebreak) flags |= 0x02;
  if (state.hitEvent) flags |= 0x04;
  if (state.serveEvent) flags |= 0x08;
  if (state.netFault) flags |= 0x10;
  if (state.outOfBounds) flags |= 0x20;
  if (state.faultEvent) flags |= 0x40;
  if (state.isSecondServe) flags |= 0x80;
  view.setUint8(24, flags);

  view.setUint8(25, state.outType);
  view.setUint8(26, state.pointWinner);
  view.setUint8(27, state.announcement);
  view.setUint8(28, state.lastHitter);
  view.setUint8(29, Math.min(255, state.rallyCount));
  view.setUint8(30, state.gameMode);
  // serveTimer: store as serveTimer >> 2 (enough for 600 frames, max 150)
  view.setUint8(31, Math.min(255, state.serveTimer >> 2));

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

  const flags = view.getUint8(24);

  return {
    p1x: view.getUint16(1, true),
    p1y: view.getUint16(3, true),
    p2x: view.getUint16(5, true),
    p2y: view.getUint16(7, true),
    ballX: view.getUint16(9, true) / 10,
    ballY: view.getUint16(11, true) / 10,
    ballVX: view.getInt16(13, true) / 100,
    ballVY: view.getInt16(15, true) / 100,
    ballHeight: view.getUint8(17) / 255,
    p1Points: view.getUint8(18),
    p2Points: view.getUint8(19),
    p1Games: view.getUint8(20),
    p2Games: view.getUint8(21),
    phase: view.getUint8(22),
    countdown: view.getUint8(23),
    server: (flags & 0x01) !== 0 ? 2 : 1,
    isTiebreak: (flags & 0x02) !== 0,
    hitEvent: (flags & 0x04) !== 0,
    serveEvent: (flags & 0x08) !== 0,
    netFault: (flags & 0x10) !== 0,
    outOfBounds: (flags & 0x20) !== 0,
    faultEvent: (flags & 0x40) !== 0,
    isSecondServe: (flags & 0x80) !== 0,
    outType: view.getUint8(25),
    pointWinner: view.getUint8(26),
    announcement: view.getUint8(27),
    lastHitter: view.getUint8(28),
    rallyCount: view.getUint8(29),
    gameMode: view.getUint8(30),
    serveTimer: view.getUint8(31) << 2,
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
 * Layout: [type(1)][p1Games(1)][p2Games(1)][winner(1)][gameMode(1)][flags(1)]
 * Total: 6 bytes
 * @param {number} p1Games
 * @param {number} p2Games
 * @param {number} winner - 1 or 2
 * @param {number} gameMode - GAME_MODE enum
 * @param {boolean} wasTiebreak
 * @returns {ArrayBuffer}
 */
export function encodeGameEnd(p1Games, p2Games, winner, gameMode, wasTiebreak) {
  const buf = new ArrayBuffer(GAME_END_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, MSG_TYPE.GAME_END);
  view.setUint8(1, p1Games);
  view.setUint8(2, p2Games);
  view.setUint8(3, winner);
  view.setUint8(4, gameMode);
  view.setUint8(5, wasTiebreak ? 1 : 0);
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
    p1Games: view.getUint8(1),
    p2Games: view.getUint8(2),
    winner: view.getUint8(3),
    gameMode: view.getUint8(4),
    wasTiebreak: view.getUint8(5) === 1,
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
