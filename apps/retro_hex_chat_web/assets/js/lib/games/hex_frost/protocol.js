/**
 * Hex Frost — Binary protocol for WebRTC DataChannel.
 *
 * All messages use DataView with little-endian byte order.
 * Message types share the 0x80+ range with the base GameEngine.
 */

import { schema, bool, i8, i16, list, u8, u16, u32 } from "../core/codec.js";

// ── Message types ──────────────────────────────────────────────
export const MSG_TYPE = {
  GAME_STATE: 0x80,
  GAME_END: 0x83,
  GAME_READY: 0x84,
};

// Shared by every game: the readiness ping and reading a message's type.
export { encodeGameReady, getMessageType } from "../net_protocol.js";

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

// ── Schemas ────────────────────────────────────────────────────

/** One player's fields, flat on the snapshot as `p1X`, `p2Lives`… */
const player = (p) => [
  i16(`${p}X`, { scale: 10 }),
  u8(`${p}Row`),
  u8(`${p}Facing`),
  u8(`${p}State`),
  u8(`${p}JumpProgress`, { scale: 255 }),
  u8(`${p}JumpFromRow`),
  u8(`${p}JumpToRow`),
  u8(`${p}Lives`),
  u16(`${p}Score`),
  u8(`${p}IglooPieces`),
  bool(`${p}IglooComplete`),
  u8(`${p}RoundWins`),
];

/** A row of floes: its drift, then its blocks. */
const row = (r) => [
  i8(`row${r}Direction`, { or: 1 }),
  i16(`row${r}Offset`, { scale: 10 }),
  list(`row${r}Blocks`, { capacity: MAX_BLOCKS_PER_ROW, count: `row${r}BlockCount` }, [
    i16("x", { scale: 10 }),
    u8("state"),
  ]),
];

/** The host's snapshot, flat as `packState` lays it out. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  u8("phase"),
  u8("mode"),
  u8("round"),
  u8("countdown"),
  u32("seed"),
  u16("temperature", { scale: 100 }),
  ...player("p1"),
  ...player("p2"),
  u16("events"),
  ...Array.from({ length: NUM_ROWS }, (_, r) => row(r)).flat(),
  list("enemies", { capacity: MAX_ENEMIES, count: "enemyCount" }, [
    u8("type"),
    i16("x", { round: true }),
    u8("row"),
    u8("state"),
    u8("timer"),
  ]),
  list("fish", { capacity: MAX_FISH, count: "fishCount" }, [
    i16("x", { round: true }),
    u8("row"),
    u8("collected"),
  ]),
]);

/** How the match ended. */
export const GAME_END = schema(MSG_TYPE.GAME_END, [u16("score1"), u16("score2"), u8("winner")]);
