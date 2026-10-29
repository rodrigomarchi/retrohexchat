/**
 * Binary protocol for Hex Boxing game state over WebRTC DataChannel.
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * @module games/hex_boxing_protocol
 */

import { schema, bits, u8, u16 } from "../core/codec.js";
import { MSG_TYPE, ROUND_STANDING_FIELDS, ROUNDS_GAME_END, phases } from "../core/protocol_base.js";

export * from "../core/protocol_base.js";

/** The match's phases, by their value on the wire. */
export const PHASE = phases("SPAWNING", "FIGHTING", "ROUND_OVER", "MATCH_OVER");

// Punch state enum: a punch winds up (the arm drawn back, where everyone can
// see it coming), flies, then the arm recovers.
export const PUNCH_STATE = {
  IDLE: 0,
  PUNCHING: 1,
  COOLDOWN: 2,
  WINDUP: 3,
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
  ...ROUND_STANDING_FIELDS,
  u16("roundTimer"),
  u8("lastHitPlayer"),
  u8("lastHitPoints"),
]);

/** How the match ended: the rounds' end of every match played in rounds. */
export const GAME_END = ROUNDS_GAME_END;
