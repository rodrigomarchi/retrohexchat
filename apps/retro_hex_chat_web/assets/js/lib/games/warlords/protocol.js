/**
 * Binary protocol for Hex Warlords game state over WebRTC DataChannel.
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * @module games/warlords_protocol
 */

// Message types (shared with game_engine.js 0x80+ range)
import { schema, bitmap, f32, u8, u16 } from "../core/codec.js";

export const MSG_TYPE = {
  GAME_STATE: 0x80,
  GAME_START: 0x82,
  GAME_END: 0x83,
  GAME_READY: 0x84,
};

// Shared by every game: the readiness ping and reading a message's type.
export { encodeGameReady, getMessageType } from "../net_protocol.js";

// Game phase enum
export const PHASE = {
  WAITING: 0,
  COUNTDOWN: 1,
  PLAYING: 2,
  KING_HIT: 3,
  FINISHED: 4,
};

// Castle constants
export const BRICKS_ROWS = 6;
export const BRICKS_COLS = 4;
export const BRICKS_PER_CASTLE = BRICKS_ROWS * BRICKS_COLS; // 24
export const INITIAL_LIVES = 3;

/** The host's snapshot of the battle, sent every step. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  f32("fireballX"),
  f32("fireballY"),
  f32("fireballVX"),
  f32("fireballVY"),
  u16("shield1Y", { round: true }),
  u16("shield2Y", { round: true }),
  bitmap("p1Bricks", BRICKS_PER_CASTLE, { key: "alive", as: "p1BricksAlive" }),
  bitmap("p2Bricks", BRICKS_PER_CASTLE, { key: "alive", as: "p2BricksAlive" }),
  u8("p1Lives"),
  u8("p2Lives"),
  u8("phase"),
  u8("countdown"),
  u8("round"),
  u8("caughtBy"),
]);

/** How the match ended. */
export const GAME_END = schema(MSG_TYPE.GAME_END, [u8("p1Lives"), u8("p2Lives"), u8("winner")]);
