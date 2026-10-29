/**
 * Binary protocol for Pixel Tanks game state over WebRTC DataChannel.
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * @module games/pixel_tanks_protocol
 */

import { schema, f32, flags, u8, u16 } from "../core/codec.js";
import { MSG_TYPE, ROUNDS_GAME_END, phases } from "../core/protocol_base.js";

export * from "../core/protocol_base.js";

/** The match's phases, by their value on the wire. */
export const PHASE = phases("SPAWNING", "PLAYING", "ROUND_OVER", "MATCH_OVER");

// Game mode enum (protocol-ready for future modes)
export const GAME_MODE = {
  CLASSIC: 0,
  MAZE_BATTLE: 1,
  RICOCHET: 2,
  GUIDED: 3,
};

/** A tank: position, heading (radians × 10000) and whether it is alive or shielded. */
const tank = (t) => [
  f32(`${t}X`),
  f32(`${t}Y`),
  u16(`${t}Rot`, { scale: 10000 }),
  flags([`${t}Alive`, `${t}Invuln`]),
];

/** A shell in flight. */
const missile = (m) => [
  f32(`${m}X`),
  f32(`${m}Y`),
  f32(`${m}VX`),
  f32(`${m}VY`),
  flags([`${m}Active`, `${m}Bounced`]),
];

/** The host's snapshot of the battlefield, sent every step. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  ...tank("tank1"),
  ...tank("tank2"),
  ...missile("m1"),
  ...missile("m2"),
  u8("score1"),
  u8("score2"),
  u8("phase"),
  u8("countdown"),
  u8("mode"),
  u8("mazeIndex"),
  u8("round"),
  u8("roundWins1"),
  u8("roundWins2"),
  u16("roundTimer"),
]);

/** How the match ended: the rounds' end of every match played in rounds. */
export const GAME_END = ROUNDS_GAME_END;
