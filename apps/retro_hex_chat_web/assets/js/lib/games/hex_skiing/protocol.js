/**
 * Hex Skiing — Binary protocol for WebRTC DataChannel.
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
  RACING: 2,
  ROUND_END: 3,
  FINISHED: 4,
};

export const GAME_MODE = {
  ALPINE_RACE: 0,
  AVALANCHE_ESCAPE: 1,
  CLEAN_RUN: 2,
};

export const INPUT_KEY = {
  LEFT: 0,
  RIGHT: 1,
};

export const SKIER_STATE = {
  SKIING: 0,
  CRASHED: 1,
  BOOSTED: 2,
};

// Bitmask flags for audio event triggers (sent once per frame).
export const EVENT = {
  COLLISION_TREE: 1 << 0,
  COLLISION_ROCK: 1 << 1,
  GATE_CLEARED: 1 << 2,
  SPEED_BOOST: 1 << 3,
  ICE_PATCH: 1 << 4,
  BLIZZARD_START: 1 << 5,
  BLIZZARD_END: 1 << 6,
  ENGULFED: 1 << 7,
};

// ── Fixed limits (for array packing) ───────────────────────────
const MAX_GATES = 8;
const MAX_ITEMS = 4;

// ── Header size (fixed portion before variable arrays) ─────────
// type(1) + phase(1) + mode(1) + round(1) + countdown(1) + seed(4)
// + scrollY(4) + avalancheY(4) + avalancheSpeed(2)
// + blizzardActive(1) + blizzardTimer(2)
// + p1: x(2) + velX(2) + state(1) + timer(4) + boostTimer(1) + iceTimer(1) + stunTimer(1) + distance(4)
// + p2: same (16)
// + events(1) + p1RoundWins(1) + p2RoundWins(1)
const HEADER_SIZE = 1 + 1 + 1 + 1 + 1 + 4 + 4 + 4 + 2 + 1 + 2 + 16 + 16 + 1 + 1 + 1;
// = 57 bytes

// Per gate: x(2) + y(4) + width(1) + clearedP1(1) + clearedP2(1) = 9 bytes
const GATE_ENTRY = 9;
// Per item: type(1) + x(2) + y(4) + collected(1) = 8 bytes
const ITEM_ENTRY = 8;

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
 * Encode game state into a binary ArrayBuffer.
 * @param {object} s - flat state object
 * @returns {ArrayBuffer}
 */
export function encodeGameState(s) {
  const gateCount = Math.min(s.gateCount || 0, MAX_GATES);
  const itemCount = Math.min(s.itemCount || 0, MAX_ITEMS);
  const size = HEADER_SIZE + 1 + gateCount * GATE_ENTRY + 1 + itemCount * ITEM_ENTRY;
  const buf = new ArrayBuffer(size);
  const v = new DataView(buf);
  let o = 0;

  v.setUint8(o, MSG_TYPE.GAME_STATE);
  o += 1;
  v.setUint8(o, s.phase);
  o += 1;
  v.setUint8(o, s.mode);
  o += 1;
  v.setUint8(o, s.round);
  o += 1;
  v.setUint8(o, s.countdown);
  o += 1;
  v.setUint32(o, s.seed, true);
  o += 4;
  v.setFloat32(o, s.scrollY, true);
  o += 4;
  v.setFloat32(o, s.avalancheY, true);
  o += 4;
  v.setUint16(o, Math.round(s.avalancheSpeed * 100), true);
  o += 2;
  v.setUint8(o, s.blizzardActive ? 1 : 0);
  o += 1;
  v.setUint16(o, s.blizzardTimer, true);
  o += 2;

  // Player 1
  v.setInt16(o, Math.round(s.p1X), true);
  o += 2;
  v.setInt16(o, Math.round(s.p1VelX * 100), true);
  o += 2;
  v.setUint8(o, s.p1State);
  o += 1;
  v.setFloat32(o, s.p1Timer, true);
  o += 4;
  v.setUint8(o, s.p1BoostTimer);
  o += 1;
  v.setUint8(o, s.p1IceTimer);
  o += 1;
  v.setUint8(o, s.p1StunTimer);
  o += 1;
  v.setFloat32(o, s.p1Distance, true);
  o += 4;

  // Player 2
  v.setInt16(o, Math.round(s.p2X), true);
  o += 2;
  v.setInt16(o, Math.round(s.p2VelX * 100), true);
  o += 2;
  v.setUint8(o, s.p2State);
  o += 1;
  v.setFloat32(o, s.p2Timer, true);
  o += 4;
  v.setUint8(o, s.p2BoostTimer);
  o += 1;
  v.setUint8(o, s.p2IceTimer);
  o += 1;
  v.setUint8(o, s.p2StunTimer);
  o += 1;
  v.setFloat32(o, s.p2Distance, true);
  o += 4;

  // Events + round wins
  v.setUint8(o, s.events);
  o += 1;
  v.setUint8(o, s.p1RoundWins);
  o += 1;
  v.setUint8(o, s.p2RoundWins);
  o += 1;

  // Gates
  v.setUint8(o, gateCount);
  o += 1;
  for (let i = 0; i < gateCount; i++) {
    const g = s.gates[i];
    v.setInt16(o, Math.round(g.x), true);
    o += 2;
    v.setFloat32(o, g.y, true);
    o += 4;
    v.setUint8(o, Math.round(g.width));
    o += 1;
    v.setUint8(o, g.clearedP1 ? 1 : 0);
    o += 1;
    v.setUint8(o, g.clearedP2 ? 1 : 0);
    o += 1;
  }

  // Items
  v.setUint8(o, itemCount);
  o += 1;
  for (let i = 0; i < itemCount; i++) {
    const it = s.items[i];
    v.setUint8(o, it.type);
    o += 1;
    v.setInt16(o, Math.round(it.x), true);
    o += 2;
    v.setFloat32(o, it.y, true);
    o += 4;
    v.setUint8(o, it.collected);
    o += 1;
  }

  return buf;
}

/**
 * Decode a GAME_STATE ArrayBuffer into a flat state object.
 * @param {ArrayBuffer} buf
 * @returns {object|null}
 */
export function decodeGameState(buf) {
  if (buf.byteLength < HEADER_SIZE + 2) return null;
  const v = new DataView(buf);
  if (v.getUint8(0) !== MSG_TYPE.GAME_STATE) return null;

  let o = 1;
  const s = {};

  s.phase = v.getUint8(o);
  o += 1;
  s.mode = v.getUint8(o);
  o += 1;
  s.round = v.getUint8(o);
  o += 1;
  s.countdown = v.getUint8(o);
  o += 1;
  s.seed = v.getUint32(o, true);
  o += 4;
  s.scrollY = v.getFloat32(o, true);
  o += 4;
  s.avalancheY = v.getFloat32(o, true);
  o += 4;
  s.avalancheSpeed = v.getUint16(o, true) / 100;
  o += 2;
  s.blizzardActive = v.getUint8(o) === 1;
  o += 1;
  s.blizzardTimer = v.getUint16(o, true);
  o += 2;

  // Player 1
  s.p1X = v.getInt16(o, true);
  o += 2;
  s.p1VelX = v.getInt16(o, true) / 100;
  o += 2;
  s.p1State = v.getUint8(o);
  o += 1;
  s.p1Timer = v.getFloat32(o, true);
  o += 4;
  s.p1BoostTimer = v.getUint8(o);
  o += 1;
  s.p1IceTimer = v.getUint8(o);
  o += 1;
  s.p1StunTimer = v.getUint8(o);
  o += 1;
  s.p1Distance = v.getFloat32(o, true);
  o += 4;

  // Player 2
  s.p2X = v.getInt16(o, true);
  o += 2;
  s.p2VelX = v.getInt16(o, true) / 100;
  o += 2;
  s.p2State = v.getUint8(o);
  o += 1;
  s.p2Timer = v.getFloat32(o, true);
  o += 4;
  s.p2BoostTimer = v.getUint8(o);
  o += 1;
  s.p2IceTimer = v.getUint8(o);
  o += 1;
  s.p2StunTimer = v.getUint8(o);
  o += 1;
  s.p2Distance = v.getFloat32(o, true);
  o += 4;

  s.events = v.getUint8(o);
  o += 1;
  s.p1RoundWins = v.getUint8(o);
  o += 1;
  s.p2RoundWins = v.getUint8(o);
  o += 1;

  // Gates
  const gateCount = v.getUint8(o);
  o += 1;
  if (gateCount > MAX_GATES) return null;
  if (buf.byteLength < o + gateCount * GATE_ENTRY + 1) return null;
  s.gateCount = gateCount;
  s.gates = [];
  for (let i = 0; i < gateCount; i++) {
    s.gates.push({
      x: v.getInt16(o, true),
      y: v.getFloat32(o + 2, true),
      width: v.getUint8(o + 6),
      clearedP1: v.getUint8(o + 7) === 1,
      clearedP2: v.getUint8(o + 8) === 1,
    });
    o += GATE_ENTRY;
  }

  // Items
  const itemCount = v.getUint8(o);
  o += 1;
  if (itemCount > MAX_ITEMS) return null;
  if (buf.byteLength < o + itemCount * ITEM_ENTRY) return null;
  s.itemCount = itemCount;
  s.items = [];
  for (let i = 0; i < itemCount; i++) {
    s.items.push({
      type: v.getUint8(o),
      x: v.getInt16(o + 1, true),
      y: v.getFloat32(o + 3, true),
      collected: v.getUint8(o + 7),
    });
    o += ITEM_ENTRY;
  }

  return s;
}

// ── PLAYER_INPUT ───────────────────────────────────────────────

/**
 * Encode a player input event (3 bytes).
 * @param {number} keyCode - INPUT_KEY enum value
 * @param {boolean} pressed
 * @returns {ArrayBuffer}
 */
export function encodePlayerInput(keyCode, pressed) {
  const buf = new ArrayBuffer(3);
  const v = new DataView(buf);
  v.setUint8(0, MSG_TYPE.PLAYER_INPUT);
  v.setUint8(1, keyCode);
  v.setUint8(2, pressed ? 1 : 0);
  return buf;
}

/**
 * Decode a PLAYER_INPUT message.
 * @param {ArrayBuffer} buf
 * @returns {{keyCode: number, pressed: boolean}|null}
 */
export function decodePlayerInput(buf) {
  if (buf.byteLength < 3) return null;
  const v = new DataView(buf);
  if (v.getUint8(0) !== MSG_TYPE.PLAYER_INPUT) return null;
  return { keyCode: v.getUint8(1), pressed: v.getUint8(2) === 1 };
}

// ── GAME_END ───────────────────────────────────────────────────

/**
 * Encode the game-end result (6 bytes).
 * @param {{score1: number, score2: number, winner: number}} result
 * @returns {ArrayBuffer}
 */
export function encodeGameEnd(result) {
  const buf = new ArrayBuffer(6);
  const v = new DataView(buf);
  v.setUint8(0, MSG_TYPE.GAME_END);
  v.setUint16(1, result.score1, true);
  v.setUint16(3, result.score2, true);
  v.setUint8(5, result.winner);
  return buf;
}

/**
 * Decode a GAME_END message.
 * @param {ArrayBuffer} buf
 * @returns {{score1: number, score2: number, winner: number}|null}
 */
export function decodeGameEnd(buf) {
  if (buf.byteLength < 6) return null;
  const v = new DataView(buf);
  if (v.getUint8(0) !== MSG_TYPE.GAME_END) return null;
  return {
    score1: v.getUint16(1, true),
    score2: v.getUint16(3, true),
    winner: v.getUint8(5),
  };
}

// ── GAME_READY ─────────────────────────────────────────────────

/**
 * Encode a GAME_READY handshake (1 byte).
 * @returns {ArrayBuffer}
 */
export function encodeGameReady() {
  const buf = new ArrayBuffer(1);
  new DataView(buf).setUint8(0, MSG_TYPE.GAME_READY);
  return buf;
}
