/**
 * The message types every game shares, and dispatch by type.
 *
 * The values are the ones the games have always sent, so a browser still
 * holding an older chunk keeps talking to a newer one. Game-specific messages
 * live in 0x80–0x8D; the base input transport reserves 0x8E and up.
 *
 * @module games/core/messages
 */

import { BASE_MSG } from "../net_protocol.js";

/** The messages a game's own protocol sends; each game exports them as its MSG_TYPE. */
export const GAME_MSG = Object.freeze({
  GAME_STATE: 0x80,
  GAME_START: 0x82,
  GAME_END: 0x83,
  GAME_READY: 0x84,
});

export const MSG = Object.freeze({
  ...GAME_MSG,
  INPUT_STATE: BASE_MSG.INPUT_STATE,
  INPUT_EDGE: BASE_MSG.INPUT_EDGE,
});

/**
 * A function that hands a binary message to the handler for its type byte.
 * @param {Record<number, (buf: ArrayBuffer) => void>} handlers
 * @returns {(buf: unknown) => boolean} whether a handler took the message
 */
export function dispatcher(handlers) {
  return (buf) => {
    if (!(buf instanceof ArrayBuffer) || buf.byteLength < 1) return false;
    const handler = handlers[new DataView(buf).getUint8(0)];
    if (!handler) return false;
    handler(buf);
    return true;
  };
}
