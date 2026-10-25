/**
 * Binary protocol for Hex Boxing game state over WebRTC DataChannel.
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * @module games/hex_boxing_protocol
 */

// Message types (shared with game_engine.js 0x80+ range)
import { schema, bits, u8, u16 } from "../core/codec.js";
import { GAME_MSG as MSG_TYPE } from "../core/messages.js";

export { MSG_TYPE };

// Shared by every game: the readiness ping and reading a message's type.
export { encodeGameReady, getMessageType } from "../net_protocol.js";

// Game phase enum
export const PHASE = {
  WAITING: 0,
  COUNTDOWN: 1,
  SPAWNING: 2,
  FIGHTING: 3,
  ROUND_OVER: 4,
  MATCH_OVER: 5,
};

// Punch state enum
export const PUNCH_STATE = {
  IDLE: 0,
  PUNCHING: 1,
  COOLDOWN: 2,
};

/** One boxer: position, facing, the punch (state and arm in one byte), its timer. */
const boxer = (b) => [
  u16(`${b}x`, { round: true }),
  u16(`${b}y`, { round: true }),
  u8(`${b}dir`),
  bits([
    [`${b}punchState`, 2],
    [`${b}arm`, 1],
  ]),
  u8(`${b}punchTimer`),
];

/** The host's snapshot of the fight, sent every step. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  ...boxer("b1"),
  ...boxer("b2"),
  u8("score1"),
  u8("score2"),
  u8("phase"),
  u8("countdown"),
  u8("round"),
  u8("roundWins1"),
  u8("roundWins2"),
  u16("roundTimer"),
  u8("lastHitPlayer"),
  u8("lastHitPoints"),
]);

/** How the match ended. */
export const GAME_END = schema(MSG_TYPE.GAME_END, [
  u8("score1"),
  u8("score2"),
  u8("winner"),
  u8("roundWins1"),
  u8("roundWins2"),
]);
