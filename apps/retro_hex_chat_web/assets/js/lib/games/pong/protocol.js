/**
 * Binary protocol for Hex Pong game state over WebRTC DataChannel.
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * @module games/pong_protocol
 */

import { schema, f32, u8, u16 } from "../core/codec.js";
import { GAME_MSG as MSG_TYPE } from "../core/messages.js";

// Message types (shared with game_engine.js 0x80+ range)
export { MSG_TYPE };

// Shared by every game: the readiness ping and reading a message's type.
export { encodeGameReady, getMessageType } from "../net_protocol.js";

// Game phase enum
export const PHASE = {
  WAITING: 0,
  COUNTDOWN: 1,
  SERVING: 2,
  PLAYING: 3,
  SCORED: 4,
  FINISHED: 5,
};

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
