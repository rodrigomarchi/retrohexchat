/**
 * What every game's protocol module carries besides its own messages: the
 * message-type table (the 0x80+ range shared with game_engine.js), the
 * readiness ping and reading a message's type. A protocol re-exports this
 * whole module, so its callers keep importing everything from the one place.
 * Also here: the phase enum's shape, and the wire pieces several games share.
 * @module games/core/protocol_base
 */

import { bool, schema, u8, u16, u32 } from "./codec.js";
import { GAME_MSG } from "./messages.js";

export { GAME_MSG as MSG_TYPE } from "./messages.js";
export { encodeGameReady, getMessageType } from "../net_protocol.js";

/**
 * A game's phase enum, as it goes on the wire: WAITING is 0 and COUNTDOWN 1
 * in every game, and the game's own phases follow from 2 in the order named.
 * @param {...string} names
 * @returns {Record<string, number>}
 */
export function phases(...names) {
  return Object.fromEntries(["WAITING", "COUNTDOWN", ...names].map((name, value) => [name, value]));
}

/** Where a match played in rounds stands: the points, the phase, the countdown, the round and the rounds each side took. */
export const ROUND_STANDING_FIELDS = Object.freeze([
  u8("score1"),
  u8("score2"),
  u8("phase"),
  u8("countdown"),
  u8("round"),
  u8("roundWins1"),
  u8("roundWins2"),
]);

/** How a match played in rounds ended: the points, the winner and the rounds each side took. */
export const ROUNDS_GAME_END = schema(GAME_MSG.GAME_END, [
  u8("score1"),
  u8("score2"),
  u8("winner"),
  u8("roundWins1"),
  u8("roundWins2"),
]);

/**
 * A missile on the wire: `${m}X`, `${m}Y` and whether it is in flight.
 * @param {string} m - the missile's field prefix, e.g. "m1"
 */
export const missileFields = (m) => [
  u16(`${m}X`, { round: true }),
  u16(`${m}Y`, { round: true }),
  bool(`${m}Active`),
];

/** The head of a seeded match's snapshot: the phase, mode, round, countdown and seed. */
export const SEEDED_MATCH_HEADER = Object.freeze([
  u8("phase"),
  u8("mode"),
  u8("round"),
  u8("countdown"),
  u32("seed"),
]);
