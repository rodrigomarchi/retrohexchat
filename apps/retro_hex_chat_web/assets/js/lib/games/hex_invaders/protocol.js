/**
 * Binary protocol for Hex Invaders game state over WebRTC DataChannel.
 * All messages use DataView for zero-JSON binary encoding.
 * @module games/hex_invaders_protocol
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
  WAVE_CLEAR: 3,
  WAVE_START: 4,
  FINISHED: 5,
};

// Input key enum
export const INPUT_KEY = {
  LEFT: 0,
  RIGHT: 1,
  FIRE: 2,
};

// Game mode enum
export const GAME_MODE = {
  INVASION_WAR: 0,
  COOP: 1,
  BLITZ: 2,
};

// Alien type enum
export const ALIEN_TYPE = {
  NONE: 0,
  BASE: 1,
  MID: 2,
  TOP: 3,
  REINFORCEMENT: 4,
  ARMORED: 5,
};

// --- Entity limits ---
export const MAX_ALIENS = 36; // 30 grid + 6 reinforcement buffer per side
export const MAX_BOMBS = 8;
export const MAX_DROPS = 6;

// --- Sizes ---
// Header: [type(1)][phase(1)][wave(1)][countdown(1)][mode(1)][seed(4)] = 9
// Scores: [score1(2)][score2(2)][lives1(1)][lives2(1)][combo1(1)][combo2(1)] = 8
// Cannons: [x1(2)][x2(2)] = 4
// Missiles: [m1x(2)][m1y(2)][m1active(1)][m2x(2)][m2y(2)][m2active(1)] = 10
// Aliens P1: MAX_ALIENS × [type(1)][x(2)][y(2)] = 5 × 36 = 180
// Aliens P2: MAX_ALIENS × [type(1)][x(2)][y(2)] = 5 × 36 = 180
// Alien counts: [count1(1)][count2(1)] = 2
// Alien directions: [dir1(1)][dir2(1)] = 2
// Bombs: MAX_BOMBS × [side(1)][x(2)][y(2)] = 5 × 8 = 40
// Bomb count: [bombCount(1)] = 1
// Shields: [s1(1)][s2(1)][s3(1)][s4(1)] = 4
// UFO: [x(2)][active(1)][dir(1)] = 4
// Drops: [dropCount(1)] + MAX_DROPS × [type(1)][targetSide(1)][timer(1)] = 1 + 3 × 6 = 19
// Total: 9 + 8 + 4 + 10 + 180 + 180 + 2 + 2 + 40 + 1 + 4 + 4 + 19 = 463
const GAME_STATE_SIZE = 463;
const PLAYER_INPUT_SIZE = 3;
const GAME_END_SIZE = 6;
const GAME_READY_SIZE = 1;

/**
 * Encode full game state for host → peer transmission.
 * @param {object} state
 * @returns {ArrayBuffer}
 */
export function encodeGameState(state) {
  const buf = new ArrayBuffer(GAME_STATE_SIZE);
  const view = new DataView(buf);
  let o = 0;

  // Header
  view.setUint8(o, MSG_TYPE.GAME_STATE);
  o += 1;
  view.setUint8(o, state.phase & 0xff);
  o += 1;
  view.setUint8(o, state.wave & 0xff);
  o += 1;
  view.setUint8(o, state.countdown & 0xff);
  o += 1;
  view.setUint8(o, state.mode & 0xff);
  o += 1;
  view.setUint32(o, state.seed >>> 0, true);
  o += 4;

  // Scores
  view.setUint16(o, state.score1 & 0xffff, true);
  o += 2;
  view.setUint16(o, state.score2 & 0xffff, true);
  o += 2;
  view.setUint8(o, state.lives1 & 0xff);
  o += 1;
  view.setUint8(o, state.lives2 & 0xff);
  o += 1;
  view.setUint8(o, state.combo1Count & 0xff);
  o += 1;
  view.setUint8(o, state.combo2Count & 0xff);
  o += 1;

  // Cannons
  view.setUint16(o, Math.round(state.cannon1X) & 0xffff, true);
  o += 2;
  view.setUint16(o, Math.round(state.cannon2X) & 0xffff, true);
  o += 2;

  // Missiles
  view.setUint16(o, Math.round(state.m1X) & 0xffff, true);
  o += 2;
  view.setUint16(o, Math.round(state.m1Y) & 0xffff, true);
  o += 2;
  view.setUint8(o, state.m1Active ? 1 : 0);
  o += 1;
  view.setUint16(o, Math.round(state.m2X) & 0xffff, true);
  o += 2;
  view.setUint16(o, Math.round(state.m2Y) & 0xffff, true);
  o += 2;
  view.setUint8(o, state.m2Active ? 1 : 0);
  o += 1;

  // Aliens P1
  const ac1 = Math.min(state.alien1Count || 0, MAX_ALIENS);
  for (let i = 0; i < MAX_ALIENS; i++) {
    if (i < ac1 && state.aliens1[i]) {
      const a = state.aliens1[i];
      view.setUint8(o, a.type & 0xff);
      view.setUint16(o + 1, Math.round(a.x) & 0xffff, true);
      view.setUint16(o + 3, Math.round(a.y) & 0xffff, true);
    } else {
      view.setUint8(o, 0);
      view.setUint16(o + 1, 0, true);
      view.setUint16(o + 3, 0, true);
    }
    o += 5;
  }

  // Aliens P2
  const ac2 = Math.min(state.alien2Count || 0, MAX_ALIENS);
  for (let i = 0; i < MAX_ALIENS; i++) {
    if (i < ac2 && state.aliens2[i]) {
      const a = state.aliens2[i];
      view.setUint8(o, a.type & 0xff);
      view.setUint16(o + 1, Math.round(a.x) & 0xffff, true);
      view.setUint16(o + 3, Math.round(a.y) & 0xffff, true);
    } else {
      view.setUint8(o, 0);
      view.setUint16(o + 1, 0, true);
      view.setUint16(o + 3, 0, true);
    }
    o += 5;
  }

  // Alien counts + directions
  view.setUint8(o, ac1);
  o += 1;
  view.setUint8(o, ac2);
  o += 1;
  view.setUint8(o, state.alien1DirRight ? 1 : 0);
  o += 1;
  view.setUint8(o, state.alien2DirRight ? 1 : 0);
  o += 1;

  // Bombs
  const bc = Math.min(state.bombCount || 0, MAX_BOMBS);
  for (let i = 0; i < MAX_BOMBS; i++) {
    if (i < bc && state.bombs[i]) {
      const b = state.bombs[i];
      view.setUint8(o, b.side & 0xff);
      view.setUint16(o + 1, Math.round(b.x) & 0xffff, true);
      view.setUint16(o + 3, Math.round(b.y) & 0xffff, true);
    } else {
      view.setUint8(o, 0);
      view.setUint16(o + 1, 0, true);
      view.setUint16(o + 3, 0, true);
    }
    o += 5;
  }
  view.setUint8(o, bc);
  o += 1;

  // Shields
  for (let i = 0; i < 4; i++) {
    view.setUint8(o, (state.shields[i] || 0) & 0xff);
    o += 1;
  }

  // UFO
  view.setUint16(o, Math.round(state.ufoX || 0) & 0xffff, true);
  o += 2;
  view.setUint8(o, state.ufoActive ? 1 : 0);
  o += 1;
  view.setUint8(o, state.ufoDir & 0xff);
  o += 1;

  // Drop queue
  const dc = Math.min((state.drops || []).length, MAX_DROPS);
  view.setUint8(o, dc);
  o += 1;
  for (let i = 0; i < MAX_DROPS; i++) {
    if (i < dc && state.drops[i]) {
      const d = state.drops[i];
      view.setUint8(o, d.type & 0xff);
      view.setUint8(o + 1, d.targetSide & 0xff);
      view.setUint8(o + 2, d.timer & 0xff);
    } else {
      view.setUint8(o, 0);
      view.setUint8(o + 1, 0);
      view.setUint8(o + 2, 0);
    }
    o += 3;
  }

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

  let o = 1;

  // Header
  const phase = view.getUint8(o);
  o += 1;
  const wave = view.getUint8(o);
  o += 1;
  const countdown = view.getUint8(o);
  o += 1;
  const mode = view.getUint8(o);
  o += 1;
  const seed = view.getUint32(o, true);
  o += 4;

  // Scores
  const score1 = view.getUint16(o, true);
  o += 2;
  const score2 = view.getUint16(o, true);
  o += 2;
  const lives1 = view.getUint8(o);
  o += 1;
  const lives2 = view.getUint8(o);
  o += 1;
  const combo1Count = view.getUint8(o);
  o += 1;
  const combo2Count = view.getUint8(o);
  o += 1;

  // Cannons
  const cannon1X = view.getUint16(o, true);
  o += 2;
  const cannon2X = view.getUint16(o, true);
  o += 2;

  // Missiles
  const m1X = view.getUint16(o, true);
  o += 2;
  const m1Y = view.getUint16(o, true);
  o += 2;
  const m1Active = view.getUint8(o) === 1;
  o += 1;
  const m2X = view.getUint16(o, true);
  o += 2;
  const m2Y = view.getUint16(o, true);
  o += 2;
  const m2Active = view.getUint8(o) === 1;
  o += 1;

  // Aliens P1
  const aliens1 = [];
  for (let i = 0; i < MAX_ALIENS; i++) {
    aliens1.push({
      type: view.getUint8(o),
      x: view.getUint16(o + 1, true),
      y: view.getUint16(o + 3, true),
    });
    o += 5;
  }

  // Aliens P2
  const aliens2 = [];
  for (let i = 0; i < MAX_ALIENS; i++) {
    aliens2.push({
      type: view.getUint8(o),
      x: view.getUint16(o + 1, true),
      y: view.getUint16(o + 3, true),
    });
    o += 5;
  }

  // Alien counts + directions
  const alien1Count = view.getUint8(o);
  o += 1;
  const alien2Count = view.getUint8(o);
  o += 1;
  const alien1DirRight = view.getUint8(o) === 1;
  o += 1;
  const alien2DirRight = view.getUint8(o) === 1;
  o += 1;

  // Bombs
  const bombs = [];
  for (let i = 0; i < MAX_BOMBS; i++) {
    bombs.push({
      side: view.getUint8(o),
      x: view.getUint16(o + 1, true),
      y: view.getUint16(o + 3, true),
    });
    o += 5;
  }
  const bombCount = view.getUint8(o);
  o += 1;

  // Shields
  const shields = [];
  for (let i = 0; i < 4; i++) {
    shields.push(view.getUint8(o));
    o += 1;
  }

  // UFO
  const ufoX = view.getUint16(o, true);
  o += 2;
  const ufoActive = view.getUint8(o) === 1;
  o += 1;
  const ufoDir = view.getUint8(o);
  o += 1;

  // Drop queue
  const dropCount = view.getUint8(o);
  o += 1;
  const drops = [];
  for (let i = 0; i < MAX_DROPS; i++) {
    drops.push({
      type: view.getUint8(o),
      targetSide: view.getUint8(o + 1),
      timer: view.getUint8(o + 2),
    });
    o += 3;
  }

  return {
    phase,
    wave,
    countdown,
    mode,
    seed,
    score1,
    score2,
    lives1,
    lives2,
    combo1Count,
    combo2Count,
    cannon1X,
    cannon2X,
    m1X,
    m1Y,
    m1Active,
    m2X,
    m2Y,
    m2Active,
    aliens1: aliens1.slice(0, alien1Count),
    aliens2: aliens2.slice(0, alien2Count),
    alien1Count,
    alien2Count,
    alien1DirRight,
    alien2DirRight,
    bombs: bombs.slice(0, bombCount),
    bombCount,
    shields,
    ufoX,
    ufoActive,
    ufoDir,
    drops: drops.slice(0, dropCount),
    dropCount,
  };
}

/**
 * Encode player input for peer → host transmission.
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
 * Encode game end for host → peer transmission.
 * Layout: [type(1)][score1Hi(1)][score1Lo(1)][score2Hi(1)][score2Lo(1)][winner(1)]
 * @param {object} result
 * @returns {ArrayBuffer}
 */
export function encodeGameEnd(result) {
  const buf = new ArrayBuffer(GAME_END_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, MSG_TYPE.GAME_END);
  view.setUint8(1, (result.score1 >> 8) & 0xff);
  view.setUint8(2, result.score1 & 0xff);
  view.setUint8(3, (result.score2 >> 8) & 0xff);
  view.setUint8(4, result.score2 & 0xff);
  view.setUint8(5, result.winner);
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
    score1: (view.getUint8(1) << 8) | view.getUint8(2),
    score2: (view.getUint8(3) << 8) | view.getUint8(4),
    winner: view.getUint8(5),
  };
}

/**
 * Encode game ready signal (peer → host).
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
