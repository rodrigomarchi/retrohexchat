/**
 * Binary protocol for Hex Outlaw game state over WebRTC DataChannel.
 * All messages use DataView for zero-JSON binary encoding.
 * @module games/hex_outlaw_protocol
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
  HIT_PAUSE: 4,
  ROUND_OVER: 5,
  MATCH_OVER: 6,
};

// Input key enum
export const INPUT_KEY = {
  UP: 0,
  DOWN: 1,
  LEFT: 2,
  RIGHT: 3,
  FIRE: 4,
};

// Game mode enum
export const GAME_MODE = {
  QUICK_DRAW: 0,
  RICOCHET: 1,
  STAGECOACH: 2,
  NO_MANS_LAND: 3,
};

// --- Sizes ---
// Layout:
// [type:1]
// P1: [x:2][y:2][flags:1] = 5
// P2: [x:2][y:2][flags:1] = 5
// Bullet1: [x:2][y:2][vx_sign_vy:2][active:1] = 7
// Bullet2: [x:2][y:2][vx_sign_vy:2][active:1] = 7
// Obstacle: [y:2][dir:1] = 3
// Scores: [score1:1][score2:1] = 2
// Meta: [phase:1][countdown:1][round:1][roundWins1:1][roundWins2:1][gameMode:1][hitPauseTimer:1] = 7
// Events: [lastHitPlayer:1] = 1
// Total: 1 + 5 + 5 + 7 + 7 + 3 + 2 + 7 + 1 = 38
const GAME_STATE_SIZE = 38;
const PLAYER_INPUT_SIZE = 3;
const GAME_END_SIZE = 6;
const GAME_READY_SIZE = 1;

/**
 * Encode bullet velocity components into 2 bytes.
 * Stores sign of vx (1 bit), abs vy as uint15 (scaled by 10 for precision).
 * Since vx magnitude is constant (BULLET_SPEED_X), we only need its sign.
 * vy range: [-10..10] px/frame → stored as int scaled by 100 for precision.
 * @param {number} vx
 * @param {number} vy
 * @param {boolean} bounced
 * @returns {number} 16-bit packed value
 */
function packBulletVel(vx, vy, bounced) {
  // bit 15: vx sign (0=positive/right, 1=negative/left)
  // bit 14: bounced flag
  // bits 13-0: vy as signed value + 8192 offset (14-bit range)
  const vxSign = vx < 0 ? 1 : 0;
  const bouncedBit = bounced ? 1 : 0;
  const vyScaled = Math.round(vy * 100) + 8192;
  const clamped = Math.max(0, Math.min(16383, vyScaled));
  return (vxSign << 15) | (bouncedBit << 14) | (clamped & 0x3fff);
}

/**
 * Unpack bullet velocity from 2-byte packed value.
 * @param {number} packed
 * @param {number} bulletSpeedX - absolute bullet speed X
 * @returns {{ vxSign: number, vy: number, bounced: boolean }}
 */
function unpackBulletVel(packed, bulletSpeedX) {
  const vxSign = (packed >> 15) & 1;
  const bounced = ((packed >> 14) & 1) === 1;
  const vyRaw = packed & 0x3fff;
  const vy = (vyRaw - 8192) / 100;
  const vx = vxSign === 1 ? -bulletSpeedX : bulletSpeedX;
  return { vx, vy, bounced };
}

/**
 * Encode full game state for host -> peer transmission.
 * @param {object} state
 * @param {number} bulletSpeedX - absolute bullet speed (for encoding reference)
 * @returns {ArrayBuffer}
 */
export function encodeGameState(state, _bulletSpeedX) {
  const buf = new ArrayBuffer(GAME_STATE_SIZE);
  const view = new DataView(buf);
  let offset = 0;

  view.setUint8(offset, MSG_TYPE.GAME_STATE);
  offset += 1;

  // Player 1
  view.setUint16(offset, Math.round(state.p1x) & 0xffff, true);
  offset += 2;
  view.setUint16(offset, Math.round(state.p1y) & 0xffff, true);
  offset += 2;
  view.setUint8(offset, state.p1shooting ? 1 : 0);
  offset += 1;

  // Player 2
  view.setUint16(offset, Math.round(state.p2x) & 0xffff, true);
  offset += 2;
  view.setUint16(offset, Math.round(state.p2y) & 0xffff, true);
  offset += 2;
  view.setUint8(offset, state.p2shooting ? 1 : 0);
  offset += 1;

  // Bullet 1
  view.setUint16(offset, Math.round(Math.max(0, state.b1x)) & 0xffff, true);
  offset += 2;
  view.setUint16(offset, Math.round(Math.max(0, state.b1y)) & 0xffff, true);
  offset += 2;
  view.setUint16(offset, packBulletVel(state.b1vx, state.b1vy, state.b1bounced), true);
  offset += 2;
  view.setUint8(offset, state.b1active ? 1 : 0);
  offset += 1;

  // Bullet 2
  view.setUint16(offset, Math.round(Math.max(0, state.b2x)) & 0xffff, true);
  offset += 2;
  view.setUint16(offset, Math.round(Math.max(0, state.b2y)) & 0xffff, true);
  offset += 2;
  view.setUint16(offset, packBulletVel(state.b2vx, state.b2vy, state.b2bounced), true);
  offset += 2;
  view.setUint8(offset, state.b2active ? 1 : 0);
  offset += 1;

  // Obstacle
  view.setUint16(offset, Math.round(state.obsY) & 0xffff, true);
  offset += 2;
  view.setUint8(offset, state.obsDir);
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
  view.setUint8(offset, state.gameMode);
  offset += 1;
  view.setUint8(offset, state.hitPauseTimer);
  offset += 1;

  // Events
  view.setUint8(offset, state.lastHitPlayer);

  return buf;
}

/**
 * Decode game state from binary buffer.
 * @param {ArrayBuffer} buf
 * @param {number} bulletSpeedX - absolute bullet speed for velocity reconstruction
 * @returns {object|null}
 */
export function decodeGameState(buf, bulletSpeedX) {
  if (buf.byteLength < GAME_STATE_SIZE) return null;
  const view = new DataView(buf);
  if (view.getUint8(0) !== MSG_TYPE.GAME_STATE) return null;

  let offset = 1;

  // Player 1
  const p1x = view.getUint16(offset, true);
  offset += 2;
  const p1y = view.getUint16(offset, true);
  offset += 2;
  const p1shooting = view.getUint8(offset) === 1;
  offset += 1;

  // Player 2
  const p2x = view.getUint16(offset, true);
  offset += 2;
  const p2y = view.getUint16(offset, true);
  offset += 2;
  const p2shooting = view.getUint8(offset) === 1;
  offset += 1;

  // Bullet 1
  const b1x = view.getUint16(offset, true);
  offset += 2;
  const b1y = view.getUint16(offset, true);
  offset += 2;
  const b1vel = unpackBulletVel(view.getUint16(offset, true), bulletSpeedX);
  offset += 2;
  const b1active = view.getUint8(offset) === 1;
  offset += 1;

  // Bullet 2
  const b2x = view.getUint16(offset, true);
  offset += 2;
  const b2y = view.getUint16(offset, true);
  offset += 2;
  const b2vel = unpackBulletVel(view.getUint16(offset, true), bulletSpeedX);
  offset += 2;
  const b2active = view.getUint8(offset) === 1;
  offset += 1;

  // Obstacle
  const obsY = view.getUint16(offset, true);
  offset += 2;
  const obsDir = view.getUint8(offset);
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
  const gameMode = view.getUint8(offset);
  offset += 1;
  const hitPauseTimer = view.getUint8(offset);
  offset += 1;

  // Events
  const lastHitPlayer = view.getUint8(offset);

  return {
    p1x,
    p1y,
    p1shooting,
    p2x,
    p2y,
    p2shooting,
    b1x,
    b1y,
    b1vx: b1vel.vx,
    b1vy: b1vel.vy,
    b1bounced: b1vel.bounced,
    b1active,
    b2x,
    b2y,
    b2vx: b2vel.vx,
    b2vy: b2vel.vy,
    b2bounced: b2vel.bounced,
    b2active,
    obsY,
    obsDir,
    score1,
    score2,
    phase,
    countdown,
    round,
    roundWins1,
    roundWins2,
    gameMode,
    hitPauseTimer,
    lastHitPlayer,
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
