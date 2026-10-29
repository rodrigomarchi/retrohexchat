/**
 * Binary protocol for Block Breakers game state over WebRTC DataChannel.
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * @module games/breakout_protocol
 */

// ex_dna:disable-for-lines:7 this game's own protocol header: its imports and phases
import { schema, bitmap, bool, f32, u8, u16 } from "../core/codec.js";
import { MSG_TYPE, phases } from "../core/protocol_base.js";

export * from "../core/protocol_base.js";

/** The match's phases, by their value on the wire. */
export const PHASE = phases("SERVING", "PLAYING", "LIFE_LOST", "FINISHED");

// Block grid dimensions
export const BLOCK_ROWS = 5;
export const BLOCK_COLS = 10;
export const TOTAL_BLOCKS = BLOCK_ROWS * BLOCK_COLS;
/** The host's snapshot of the board, sent every step. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  f32("ballX"),
  f32("ballY"),
  f32("ballVX"),
  f32("ballVY"),
  u16("paddle1X", { round: true }),
  u16("paddle2X", { round: true }),
  u16("score"),
  u8("lives"),
  u8("phase"),
  u8("countdown"),
  u8("blocksRemaining"),
  bitmap("blocks", TOTAL_BLOCKS, { key: "alive", as: "blocksAlive" }),
]);

/** How the match ended: the shared score, and whether the board was cleared. */
export const GAME_END = schema(MSG_TYPE.GAME_END, [u16("score"), bool("won")]);
