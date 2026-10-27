/**
 * A one-player match's phases and how a move ends a match: every solo game
 * on the pointer core's, so their states speak the same words. A module of
 * its own, light enough for a game's pure functions.
 *
 * @module games/core/solo/phases
 */

/**
 * The phases. A win is celebrated — the cascade bounces across the table —
 * before the match is over and its result told, so the page still shows it.
 */
export const PHASE = Object.freeze({
  WAITING: 0,
  PLAYING: 1,
  AUTO_FINISH: 2,
  FINISHED: 3,
  CELEBRATING: 4,
});

/** The longest a celebration lasts; a tap ends it sooner. */
export const CELEBRATION_TICKS = 600;

/** How far a press may move and still be a tap. */
export const TAP_SLOP = 6;

/** The bit of a tick's events that says the match was won: every solo game's `EVENT.WIN`. */
export const WIN_EVENT = 256;

/**
 * The state after a move, with the end it brings: a win is celebrated, a
 * table left to finish by itself does so, a table with no move left is over.
 * @param {object} next - the state the move left
 * @param {{ won: boolean, finish?: boolean, stuck?: boolean }} end
 * @returns {object}
 */
export function ending(next, { won, finish = false, stuck = false }) {
  if (won) return { ...next, phase: PHASE.CELEBRATING, won: true, events: next.events | WIN_EVENT };
  if (finish) return { ...next, phase: PHASE.AUTO_FINISH, autoTicks: 0 };
  if (stuck) return { ...next, phase: PHASE.FINISHED, stuck: true };
  return next;
}
