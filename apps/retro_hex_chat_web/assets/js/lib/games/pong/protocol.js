/**
 * Binary protocol for Hex Pong game state over WebRTC DataChannel.
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * @module games/pong_protocol
 */

// ex_dna:disable-for-lines:7 this game's own protocol header: its imports and phases
import { schema, f32, u8, u16 } from "../core/codec.js";
import { MSG_TYPE, phases } from "../core/protocol_base.js";

export * from "../core/protocol_base.js";

/** The match's phases, by their value on the wire. */
export const PHASE = phases("SERVING", "PLAYING", "SCORED", "FINISHED");

/** The host's snapshot of the match, sent every step. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  f32("ballX"),
  f32("ballY"),
  f32("ballVX"),
  f32("ballVY"),
  u16("paddle1Y", { round: true }),
  u16("paddle2Y", { round: true }),
  u8("score1"),
  u8("score2"),
  u8("phase"),
  u8("countdown"),
]);

/** How the match ended. */
export const GAME_END = schema(MSG_TYPE.GAME_END, [u8("score1"), u8("score2"), u8("winner")]);
