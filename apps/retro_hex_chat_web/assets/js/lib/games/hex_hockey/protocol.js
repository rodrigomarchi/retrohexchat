/**
 * Hex Hockey — Binary protocol for WebRTC DataChannel.
 *
 * All messages use DataView with little-endian byte order.
 * Message types share the 0x80+ range with the base GameEngine.
 */

// ── Message types ──────────────────────────────────────────────
export const MSG_TYPE = {
  GAME_STATE: 0x80,
  PLAYER_INPUT: 0x81,
  GAME_END: 0x83,
  GAME_READY: 0x84,
};

// ── Enums ──────────────────────────────────────────────────────
export const PHASE = {
  WAITING: 0,
  COUNTDOWN: 1,
  FACE_OFF: 2,
  PLAYING: 3,
  GOAL_CELEBRATION: 4,
  PERIOD_BREAK: 5,
  SUDDEN_DEATH: 6,
  FINISHED: 7,
};

export const GAME_MODE = {
  CLASSIC: 0,
  BLITZ: 1,
  SHOWDOWN: 2,
};

export const INPUT_KEY = {
  LEFT: 0,
  RIGHT: 1,
  UP: 2,
  DOWN: 3,
  ACTION: 4,
};

// Bitmask flags for audio event triggers (16-bit, sent once per frame).
export const EVENT = {
  GOAL_P1: 1 << 0,
  GOAL_P2: 1 << 1,
  TACKLE_SUCCESS: 1 << 2,
  TACKLE_FAIL: 1 << 3,
  PERIOD_END: 1 << 4,
  FACE_OFF: 1 << 5,
  SUDDEN_DEATH: 1 << 6,
  SHOT: 1 << 7,
  WALL_BOUNCE: 1 << 8,
  GOALIE_BLOCK: 1 << 9,
  CAPTURE: 1 << 10,
  WHISTLE: 1 << 11,
};

// ── Fixed-size state layout ────────────────────────────────────
// type(1) + phase(1) + mode(1) + eventFlags(2)
// + p1: x(2) + y(2) + facing(1) + flags(1) + stunTimer(1)     = 7
// + p2: x(2) + y(2) + facing(1) + flags(1) + stunTimer(1)     = 7
// + g1y(2) + g2y(2)                                            = 4
// + puck: x(2) + y(2) + vx(2) + vy(2) + possessedBy(1)        = 9
// + scoreP1(1) + scoreP2(1) + period(1) + timerFrames(2)       = 5
// + countdownValue(1) + sidesSwapped(1)                        = 2
// Total = 1 + 1 + 1 + 2 + 7 + 7 + 4 + 9 + 5 + 2 = 39 bytes
const STATE_SIZE = 39;

// ── Helpers ────────────────────────────────────────────────────

/**
 * Read the message type byte from an ArrayBuffer.
 * @param {ArrayBuffer} buf
 * @returns {number|null}
 */
export function getMessageType(buf) {
  if (!buf || buf.byteLength < 1) return null;
  return new DataView(buf).getUint8(0);
}

// ── GAME_STATE ─────────────────────────────────────────────────

/**
 * Encode packed game state into an ArrayBuffer.
 * @param {object} packed - Output from physics.packState()
 * @returns {ArrayBuffer}
 */
export function encodeGameState(packed) {
  const buf = new ArrayBuffer(STATE_SIZE);
  const dv = new DataView(buf);
  let o = 0;

  dv.setUint8(o, MSG_TYPE.GAME_STATE);
  o += 1;
  dv.setUint8(o, packed.phase);
  o += 1;
  dv.setUint8(o, packed.mode);
  o += 1;
  dv.setUint16(o, packed.eventFlags & 0xffff, true);
  o += 2;

  // Player 1
  dv.setUint16(o, packed.p1x & 0xffff, true);
  o += 2;
  dv.setUint16(o, packed.p1y & 0xffff, true);
  o += 2;
  dv.setUint8(o, packed.p1facing & 0xff);
  o += 1;
  const p1flags = (packed.p1hasPuck ? 1 : 0) | (packed.p1stunned ? 2 : 0);
  dv.setUint8(o, p1flags);
  o += 1;
  dv.setUint8(o, packed.stunTimerP1 & 0xff);
  o += 1;

  // Player 2
  dv.setUint16(o, packed.p2x & 0xffff, true);
  o += 2;
  dv.setUint16(o, packed.p2y & 0xffff, true);
  o += 2;
  dv.setUint8(o, packed.p2facing & 0xff);
  o += 1;
  const p2flags = (packed.p2hasPuck ? 1 : 0) | (packed.p2stunned ? 2 : 0);
  dv.setUint8(o, p2flags);
  o += 1;
  dv.setUint8(o, packed.stunTimerP2 & 0xff);
  o += 1;

  // Goalies
  dv.setUint16(o, packed.g1y & 0xffff, true);
  o += 2;
  dv.setUint16(o, packed.g2y & 0xffff, true);
  o += 2;

  // Puck
  dv.setUint16(o, packed.puckX & 0xffff, true);
  o += 2;
  dv.setUint16(o, packed.puckY & 0xffff, true);
  o += 2;
  // velocity × 100 for precision, as signed int16
  dv.setInt16(o, Math.round(packed.puckVx * 100), true);
  o += 2;
  dv.setInt16(o, Math.round(packed.puckVy * 100), true);
  o += 2;
  dv.setUint8(o, packed.puckPossessedBy);
  o += 1;

  // Scoring
  dv.setUint8(o, packed.scoreP1);
  o += 1;
  dv.setUint8(o, packed.scoreP2);
  o += 1;
  dv.setUint8(o, packed.period);
  o += 1;
  dv.setUint16(o, packed.timerFrames & 0xffff, true);
  o += 2;

  // Flow
  dv.setUint8(o, packed.countdownValue);
  dv.setUint8(o + 1, packed.sidesSwapped ? 1 : 0);

  return buf;
}

/**
 * Decode an ArrayBuffer into a packed game state.
 * @param {ArrayBuffer} buf
 * @returns {object} Packed state compatible with physics.unpackState()
 */
export function decodeGameState(buf) {
  if (!buf || buf.byteLength < STATE_SIZE) return null;
  const dv = new DataView(buf);
  let o = 1; // skip msg type

  const phase = dv.getUint8(o);
  o += 1;
  const mode = dv.getUint8(o);
  o += 1;
  const eventFlags = dv.getUint16(o, true);
  o += 2;

  // Player 1
  const p1x = dv.getUint16(o, true);
  o += 2;
  const p1y = dv.getUint16(o, true);
  o += 2;
  const p1facing = dv.getUint8(o);
  o += 1;
  const p1f = dv.getUint8(o);
  o += 1;
  const stunTimerP1 = dv.getUint8(o);
  o += 1;

  // Player 2
  const p2x = dv.getUint16(o, true);
  o += 2;
  const p2y = dv.getUint16(o, true);
  o += 2;
  const p2facing = dv.getUint8(o);
  o += 1;
  const p2f = dv.getUint8(o);
  o += 1;
  const stunTimerP2 = dv.getUint8(o);
  o += 1;

  // Goalies
  const g1y = dv.getUint16(o, true);
  o += 2;
  const g2y = dv.getUint16(o, true);
  o += 2;

  // Puck
  const puckX = dv.getUint16(o, true);
  o += 2;
  const puckY = dv.getUint16(o, true);
  o += 2;
  const puckVx = dv.getInt16(o, true) / 100;
  o += 2;
  const puckVy = dv.getInt16(o, true) / 100;
  o += 2;
  const puckPossessedBy = dv.getUint8(o);
  o += 1;

  // Scoring
  const scoreP1 = dv.getUint8(o);
  o += 1;
  const scoreP2 = dv.getUint8(o);
  o += 1;
  const period = dv.getUint8(o);
  o += 1;
  const timerFrames = dv.getUint16(o, true);
  o += 2;

  // Flow
  const countdownValue = dv.getUint8(o);
  const sidesSwapped = dv.getUint8(o + 1) === 1;

  return {
    phase,
    mode,
    eventFlags,
    p1x,
    p1y,
    p1facing,
    p1hasPuck: !!(p1f & 1),
    p1stunned: !!(p1f & 2),
    p2x,
    p2y,
    p2facing,
    p2hasPuck: !!(p2f & 1),
    p2stunned: !!(p2f & 2),
    stunTimerP1,
    stunTimerP2,
    g1y,
    g2y,
    puckX,
    puckY,
    puckVx,
    puckVy,
    puckPossessedBy,
    scoreP1,
    scoreP2,
    period,
    timerFrames,
    countdownValue,
    sidesSwapped,
  };
}

// ── PLAYER_INPUT ───────────────────────────────────────────────

/**
 * Encode a player input event (key press/release).
 * @param {number} key - INPUT_KEY enum
 * @param {boolean} pressed
 * @returns {ArrayBuffer}
 */
export function encodePlayerInput(key, pressed) {
  const buf = new ArrayBuffer(3);
  const dv = new DataView(buf);
  dv.setUint8(0, MSG_TYPE.PLAYER_INPUT);
  dv.setUint8(1, key);
  dv.setUint8(2, pressed ? 1 : 0);
  return buf;
}

/**
 * Decode a player input message.
 * @param {ArrayBuffer} buf
 * @returns {{ key: number, pressed: boolean }}
 */
export function decodePlayerInput(buf) {
  if (!buf || buf.byteLength < 3) return null;
  const dv = new DataView(buf);
  return {
    key: dv.getUint8(1),
    pressed: dv.getUint8(2) === 1,
  };
}

// ── GAME_END ───────────────────────────────────────────────────

/**
 * Encode game end result.
 * @param {object} result - { winner, score_p1, score_p2 }
 * @returns {ArrayBuffer}
 */
export function encodeGameEnd(result) {
  const buf = new ArrayBuffer(4);
  const dv = new DataView(buf);
  dv.setUint8(0, MSG_TYPE.GAME_END);
  // winner: 0=draw, 1=p1, 2=p2
  const w = result.winner === "p1" ? 1 : result.winner === "p2" ? 2 : 0;
  dv.setUint8(1, w);
  dv.setUint8(2, result.score_p1);
  dv.setUint8(3, result.score_p2);
  return buf;
}

/**
 * Decode game end result.
 * @param {ArrayBuffer} buf
 * @returns {object}
 */
export function decodeGameEnd(buf) {
  if (!buf || buf.byteLength < 4) return null;
  const dv = new DataView(buf);
  const w = dv.getUint8(1);
  return {
    winner: w === 1 ? "p1" : w === 2 ? "p2" : "draw",
    score_p1: dv.getUint8(2),
    score_p2: dv.getUint8(3),
  };
}

// ── GAME_READY ─────────────────────────────────────────────────

/**
 * Encode game ready signal.
 * @returns {ArrayBuffer}
 */
export function encodeGameReady() {
  const buf = new ArrayBuffer(1);
  new DataView(buf).setUint8(0, MSG_TYPE.GAME_READY);
  return buf;
}
