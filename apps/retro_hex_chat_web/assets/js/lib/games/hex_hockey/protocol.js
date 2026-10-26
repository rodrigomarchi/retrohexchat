/**
 * Hex Hockey — Binary protocol for WebRTC DataChannel.
 *
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * Message types share the 0x80+ range with the base GameEngine.
 */

// ── Message types ──────────────────────────────────────────────
import { schema, bool, flags, i16, u8, u16 } from "../core/codec.js";
import { MSG_TYPE } from "../core/protocol_base.js";

export * from "../core/protocol_base.js";

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

// ── Schemas ────────────────────────────────────────────────────

/** A skater: position, facing, puck and stun flags, stun timer. */
const skater = (p, stunTimer) => [
  u16(`${p}x`),
  u16(`${p}y`),
  u8(`${p}facing`),
  flags([`${p}hasPuck`, `${p}stunned`]),
  u8(stunTimer),
];

/** The host's snapshot of the rink, packed by `packState`, sent every step. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  u8("phase"),
  u8("mode"),
  u16("eventFlags"),
  ...skater("p1", "stunTimerP1"),
  ...skater("p2", "stunTimerP2"),
  u16("g1y"),
  u16("g2y"),
  u16("puckX"),
  u16("puckY"),
  i16("puckVx", { scale: 100 }),
  i16("puckVy", { scale: 100 }),
  u8("puckPossessedBy"),
  u8("scoreP1"),
  u8("scoreP2"),
  u8("period"),
  u16("timerFrames"),
  u8("countdownValue"),
  bool("sidesSwapped"),
]);

/** How the match ended: the winner travels as 1, 2 or 0 for a draw. */
export const GAME_END = schema(MSG_TYPE.GAME_END, [
  u8("winner", {
    encode: (w) => (w === "p1" ? 1 : w === "p2" ? 2 : 0),
    decode: (raw) => (raw === 1 ? "p1" : raw === 2 ? "p2" : "draw"),
  }),
  u8("score_p1"),
  u8("score_p2"),
]);
