/**
 * Hex Frost — Binary protocol for WebRTC DataChannel.
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
  BUILDING: 2,
  ROUND_END: 3,
  FINISHED: 4,
};

export const GAME_MODE = {
  ARCTIC_RACE: 0,
  BLIZZARD: 1,
  PEACEFUL: 2,
};

export const INPUT_KEY = {
  LEFT: 0,
  RIGHT: 1,
  UP: 2,
  DOWN: 3,
};

export const BLOCK_STATE = {
  WHITE: 0,
  BLUE_P1: 1,
  BLUE_P2: 2,
};

export const BAILEY_STATE = {
  IDLE: 0,
  WALKING: 1,
  JUMPING: 2,
  FALLING: 3,
  DEAD: 4,
  ENTERING_IGLOO: 5,
};

export const ENEMY_TYPE = {
  BEAR: 0,
  CRAB: 1,
  GOOSE: 2,
  CLAM: 3,
};

// Bitmask flags for audio event triggers (16-bit, sent once per frame).
export const EVENT = {
  BLOCK_CLAIM: 1 << 0,
  BLOCK_STEAL: 1 << 1,
  BLOCK_UNDO: 1 << 2,
  JUMP: 1 << 3,
  LAND: 1 << 4,
  SPLASH: 1 << 5,
  FISH_COLLECT: 1 << 6,
  ENEMY_HIT: 1 << 7,
  IGLOO_PIECE: 1 << 8,
  IGLOO_LOSE: 1 << 9,
  IGLOO_COMPLETE: 1 << 10,
  IGLOO_ENTER: 1 << 11,
  TEMP_LOW: 1 << 12,
  TEMP_ZERO: 1 << 13,
  BEAR_NEAR: 1 << 14,
  CLAM_SNAP: 1 << 15,
};

// ── Fixed limits ───────────────────────────────────────────────
const MAX_BLOCKS_PER_ROW = 10;
const MAX_ENEMIES = 16;
const MAX_FISH = 4;
const NUM_ROWS = 4;

// ── Header size (fixed portion before variable arrays) ─────────
// type(1) + phase(1) + mode(1) + round(1) + countdown(1) + seed(4)
// + temperature(2)
// + p1: x(2) + row(1) + facing(1) + state(1) + jumpProgress(1)
//       + jumpFromRow(1) + jumpToRow(1) + lives(1) + score(2)
//       + iglooPieces(1) + iglooComplete(1) + roundWins(1)  = 14
// + p2: same = 14
// + events(2)
const HEADER_SIZE = 1 + 1 + 1 + 1 + 1 + 4 + 2 + 14 + 14 + 2;
// = 41 bytes

// Per block: x(2, scaled ×10) + state(1) = 3 bytes
const BLOCK_ENTRY = 3;
// Per row header: direction(1) + offset(2, scaled ×10) + blockCount(1) = 4 bytes
const ROW_HEADER = 4;
// Per enemy: type(1) + x(2) + row(1) + state(1) + timer(1) = 6 bytes
const ENEMY_ENTRY = 6;
// Per fish: x(2) + row(1) + collected(1) = 4 bytes
const FISH_ENTRY = 4;

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
 * @param {object} s - flat state object from packState
 * @returns {ArrayBuffer}
 */
export function encodeGameState(s) {
  // Calculate total block entries
  let totalBlocks = 0;
  for (let r = 0; r < NUM_ROWS; r++) {
    totalBlocks += Math.min(s[`row${r}BlockCount`] || 0, MAX_BLOCKS_PER_ROW);
  }

  const enemyCount = Math.min(s.enemyCount || 0, MAX_ENEMIES);
  const fishCount = Math.min(s.fishCount || 0, MAX_FISH);

  const size =
    HEADER_SIZE +
    NUM_ROWS * ROW_HEADER +
    totalBlocks * BLOCK_ENTRY +
    1 +
    enemyCount * ENEMY_ENTRY +
    1 +
    fishCount * FISH_ENTRY;

  const buf = new ArrayBuffer(size);
  const v = new DataView(buf);
  let o = 0;

  // Header
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
  v.setUint16(o, Math.round(s.temperature * 100), true);
  o += 2;

  // Player 1
  v.setInt16(o, Math.round(s.p1X * 10), true);
  o += 2;
  v.setUint8(o, s.p1Row);
  o += 1;
  v.setUint8(o, s.p1Facing);
  o += 1;
  v.setUint8(o, s.p1State);
  o += 1;
  v.setUint8(o, Math.round(s.p1JumpProgress * 255));
  o += 1;
  v.setUint8(o, s.p1JumpFromRow);
  o += 1;
  v.setUint8(o, s.p1JumpToRow);
  o += 1;
  v.setUint8(o, s.p1Lives);
  o += 1;
  v.setUint16(o, s.p1Score, true);
  o += 2;
  v.setUint8(o, s.p1IglooPieces);
  o += 1;
  v.setUint8(o, s.p1IglooComplete ? 1 : 0);
  o += 1;
  v.setUint8(o, s.p1RoundWins);
  o += 1;

  // Player 2
  v.setInt16(o, Math.round(s.p2X * 10), true);
  o += 2;
  v.setUint8(o, s.p2Row);
  o += 1;
  v.setUint8(o, s.p2Facing);
  o += 1;
  v.setUint8(o, s.p2State);
  o += 1;
  v.setUint8(o, Math.round(s.p2JumpProgress * 255));
  o += 1;
  v.setUint8(o, s.p2JumpFromRow);
  o += 1;
  v.setUint8(o, s.p2JumpToRow);
  o += 1;
  v.setUint8(o, s.p2Lives);
  o += 1;
  v.setUint16(o, s.p2Score, true);
  o += 2;
  v.setUint8(o, s.p2IglooPieces);
  o += 1;
  v.setUint8(o, s.p2IglooComplete ? 1 : 0);
  o += 1;
  v.setUint8(o, s.p2RoundWins);
  o += 1;

  // Events (16-bit)
  v.setUint16(o, s.events, true);
  o += 2;

  // Block rows
  for (let r = 0; r < NUM_ROWS; r++) {
    const dir = s[`row${r}Direction`] || 1;
    const offset = s[`row${r}Offset`] || 0;
    const count = Math.min(s[`row${r}BlockCount`] || 0, MAX_BLOCKS_PER_ROW);

    v.setInt8(o, dir);
    o += 1;
    v.setInt16(o, Math.round(offset * 10), true);
    o += 2;
    v.setUint8(o, count);
    o += 1;

    for (let b = 0; b < count; b++) {
      const block = s[`row${r}Blocks`][b];
      v.setInt16(o, Math.round(block.x * 10), true);
      o += 2;
      v.setUint8(o, block.state);
      o += 1;
    }
  }

  // Enemies
  v.setUint8(o, enemyCount);
  o += 1;
  for (let i = 0; i < enemyCount; i++) {
    const e = s.enemies[i];
    v.setUint8(o, e.type);
    o += 1;
    v.setInt16(o, Math.round(e.x), true);
    o += 2;
    v.setUint8(o, e.row);
    o += 1;
    v.setUint8(o, e.state);
    o += 1;
    v.setUint8(o, e.timer);
    o += 1;
  }

  // Fish
  v.setUint8(o, fishCount);
  o += 1;
  for (let i = 0; i < fishCount; i++) {
    const f = s.fish[i];
    v.setInt16(o, Math.round(f.x), true);
    o += 2;
    v.setUint8(o, f.row);
    o += 1;
    v.setUint8(o, f.collected);
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
  if (buf.byteLength < HEADER_SIZE) return null;
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
  s.temperature = v.getUint16(o, true) / 100;
  o += 2;

  // Player 1
  s.p1X = v.getInt16(o, true) / 10;
  o += 2;
  s.p1Row = v.getUint8(o);
  o += 1;
  s.p1Facing = v.getUint8(o);
  o += 1;
  s.p1State = v.getUint8(o);
  o += 1;
  s.p1JumpProgress = v.getUint8(o) / 255;
  o += 1;
  s.p1JumpFromRow = v.getUint8(o);
  o += 1;
  s.p1JumpToRow = v.getUint8(o);
  o += 1;
  s.p1Lives = v.getUint8(o);
  o += 1;
  s.p1Score = v.getUint16(o, true);
  o += 2;
  s.p1IglooPieces = v.getUint8(o);
  o += 1;
  s.p1IglooComplete = v.getUint8(o) === 1;
  o += 1;
  s.p1RoundWins = v.getUint8(o);
  o += 1;

  // Player 2
  s.p2X = v.getInt16(o, true) / 10;
  o += 2;
  s.p2Row = v.getUint8(o);
  o += 1;
  s.p2Facing = v.getUint8(o);
  o += 1;
  s.p2State = v.getUint8(o);
  o += 1;
  s.p2JumpProgress = v.getUint8(o) / 255;
  o += 1;
  s.p2JumpFromRow = v.getUint8(o);
  o += 1;
  s.p2JumpToRow = v.getUint8(o);
  o += 1;
  s.p2Lives = v.getUint8(o);
  o += 1;
  s.p2Score = v.getUint16(o, true);
  o += 2;
  s.p2IglooPieces = v.getUint8(o);
  o += 1;
  s.p2IglooComplete = v.getUint8(o) === 1;
  o += 1;
  s.p2RoundWins = v.getUint8(o);
  o += 1;

  // Events
  s.events = v.getUint16(o, true);
  o += 2;

  // Block rows
  for (let r = 0; r < NUM_ROWS; r++) {
    if (o + ROW_HEADER > buf.byteLength) return null;
    s[`row${r}Direction`] = v.getInt8(o);
    o += 1;
    s[`row${r}Offset`] = v.getInt16(o, true) / 10;
    o += 2;
    const count = v.getUint8(o);
    o += 1;
    if (count > MAX_BLOCKS_PER_ROW) return null;
    if (o + count * BLOCK_ENTRY > buf.byteLength) return null;
    s[`row${r}BlockCount`] = count;
    s[`row${r}Blocks`] = [];
    for (let b = 0; b < count; b++) {
      s[`row${r}Blocks`].push({
        x: v.getInt16(o, true) / 10,
        state: v.getUint8(o + 2),
      });
      o += BLOCK_ENTRY;
    }
  }

  // Enemies
  if (o + 1 > buf.byteLength) return null;
  const enemyCount = v.getUint8(o);
  o += 1;
  if (enemyCount > MAX_ENEMIES) return null;
  if (o + enemyCount * ENEMY_ENTRY > buf.byteLength) return null;
  s.enemyCount = enemyCount;
  s.enemies = [];
  for (let i = 0; i < enemyCount; i++) {
    s.enemies.push({
      type: v.getUint8(o),
      x: v.getInt16(o + 1, true),
      row: v.getUint8(o + 3),
      state: v.getUint8(o + 4),
      timer: v.getUint8(o + 5),
    });
    o += ENEMY_ENTRY;
  }

  // Fish
  if (o + 1 > buf.byteLength) return null;
  const fishCount = v.getUint8(o);
  o += 1;
  if (fishCount > MAX_FISH) return null;
  if (o + fishCount * FISH_ENTRY > buf.byteLength) return null;
  s.fishCount = fishCount;
  s.fish = [];
  for (let i = 0; i < fishCount; i++) {
    s.fish.push({
      x: v.getInt16(o, true),
      row: v.getUint8(o + 2),
      collected: v.getUint8(o + 3),
    });
    o += FISH_ENTRY;
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
