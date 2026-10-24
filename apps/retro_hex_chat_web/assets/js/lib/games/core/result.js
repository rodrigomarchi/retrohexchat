/**
 * The one spelling a match result is reported in, for every game: a nested
 * score and a numeric winner — 1 or 2 for a side, 0 for a draw (or a co-op
 * pair's win), -1 for a co-op pair's loss. `Games.Result` on the server
 * reads it, and still reads the older spellings browsers with an older
 * chunk may send.
 *
 * @module games/core/result
 */

/**
 * @param {number} p1 - player one's score
 * @param {number} p2 - player two's score
 * @param {number} winner
 * @returns {{ score: { p1: number, p2: number }, winner: number }}
 */
export function matchResult(p1, p2, winner) {
  return { score: { p1, p2 }, winner };
}
