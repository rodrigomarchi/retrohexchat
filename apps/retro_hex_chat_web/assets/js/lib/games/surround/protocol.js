/**
 * Binary protocol for Light Trails game state over WebRTC DataChannel.
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * @module games/surround_protocol
 */

import { schema, struct, u8 } from "../core/codec.js";
import { MSG_TYPE, phases } from "../core/protocol_base.js";

export * from "../core/protocol_base.js";

/** The match's phases, by their value on the wire. */
export const PHASE = phases("PLAYING", "ROUND_OVER", "MATCH_OVER");

// Direction enum
export const DIR = {
  UP: 0,
  DOWN: 1,
  LEFT: 2,
  RIGHT: 3,
};

// Input key enum (same values as DIR for this game)
export const INPUT_KEY = {
  UP: 0,
  DOWN: 1,
  LEFT: 2,
  RIGHT: 3,
};

// Grid constants
export const GRID_W = 60;
export const GRID_H = 40;
export const WINS_NEEDED = 3;

/** A light cycle: its head and the way it is heading. */
const cycle = (p) => struct(p, [u8("x"), u8("y"), u8("dir")], { flat: true });

/** The host's snapshot of the arena, sent every step. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  cycle("p1"),
  cycle("p2"),
  u8("score1"),
  u8("score2"),
  u8("phase"),
  u8("countdown"),
  u8("round"),
]);

/** How the match ended. */
export const GAME_END = schema(MSG_TYPE.GAME_END, [u8("score1"), u8("score2"), u8("winner")]);
