/**
 * Hex Skiing — Binary protocol for WebRTC DataChannel.
 *
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * Message types share the 0x80+ range with the base GameEngine.
 */

// ── Message types ──────────────────────────────────────────────
import { schema, bool, f32, i16, list, u8, u16, u32 } from "../core/codec.js";

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
  RACING: 2,
  ROUND_END: 3,
  FINISHED: 4,
};

export const GAME_MODE = {
  ALPINE_RACE: 0,
  AVALANCHE_ESCAPE: 1,
  CLEAN_RUN: 2,
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

// ── Fixed limits ───────────────────────────────────────────────
const MAX_GATES = 8;
const MAX_ITEMS = 4;

// ── Schemas ────────────────────────────────────────────────────

/** A skier: position, sideways speed, state, run time, timers and distance. */
const skier = (p) => [
  i16(`${p}X`, { round: true }),
  i16(`${p}VelX`, { scale: 100 }),
  u8(`${p}State`),
  f32(`${p}Timer`),
  u8(`${p}BoostTimer`),
  u8(`${p}IceTimer`),
  u8(`${p}StunTimer`),
  f32(`${p}Distance`),
];

/** The host's snapshot of the slope, sent every step. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  u8("phase"),
  u8("mode"),
  u8("round"),
  u8("countdown"),
  u32("seed"),
  f32("scrollY"),
  f32("avalancheY"),
  u16("avalancheSpeed", { scale: 100 }),
  bool("blizzardActive"),
  u16("blizzardTimer"),
  ...skier("p1"),
  ...skier("p2"),
  u8("events"),
  u8("p1RoundWins"),
  u8("p2RoundWins"),
  list("gates", { capacity: MAX_GATES, count: "gateCount" }, [
    i16("x", { round: true }),
    f32("y"),
    u8("width", { round: true }),
    bool("clearedP1"),
    bool("clearedP2"),
  ]),
  list("items", { capacity: MAX_ITEMS, count: "itemCount" }, [
    u8("type"),
    i16("x", { round: true }),
    f32("y"),
    u8("collected"),
  ]),
]);

/** How the run ended. */
export const GAME_END = schema(MSG_TYPE.GAME_END, [u16("score1"), u16("score2"), u8("winner")]);
