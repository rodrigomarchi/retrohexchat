/**
 * The classic scoring: what each move pays, what time costs, and the bonus
 * a fast win earns. Pure functions; the score never falls below zero.
 *
 * @module games/hex_solitaire/scoring
 */

import {
  BONUS_MIN_SECONDS,
  BONUS_NUMERATOR,
  PENALTY_TICKS,
  POINTS,
  SAFETY_TICKS,
} from "./protocol.js";

/**
 * The points of a move (`rules.js`), and of the card it turned over.
 * @param {{ from: { pile: string }, to: { pile: string } }} move
 * @param {boolean} flipped
 * @returns {number}
 */
export function scoreMove(move, flipped) {
  const flip = flipped ? POINTS.FLIP : 0;
  if (move.to.pile === "foundation") return POINTS.TO_FOUNDATION + flip;
  if (move.from.pile === "waste") return POINTS.WASTE_TO_TABLEAU + flip;
  if (move.from.pile === "foundation") return POINTS.FOUNDATION_TO_TABLEAU + flip;
  return flip;
}

/** What turning the waste back into the stock costs. */
export const recyclePoints = (mode) => POINTS.RECYCLE[mode];

/** The score after `points`, never below zero. */
export const addPoints = (score, points) => Math.max(0, score + points);

/** The clock, running from now on; the same clock when it already runs. */
export const startClock = (clock) => (clock.started ? clock : { ...clock, started: true });

/**
 * One tick of the clock: it counts only once started, every ten seconds of
 * play cost points, and an hour calls time.
 * @param {{ started: boolean, ticks: number }} clock
 * @returns {{ clock: { started: boolean, ticks: number }, points: number, timeUp: boolean }}
 */
export function tickClock(clock) {
  if (!clock.started) return { clock, points: 0, timeUp: false };
  const ticks = clock.ticks + 1;
  return {
    clock: { ...clock, ticks },
    points: ticks % PENALTY_TICKS === 0 ? POINTS.TIME_PENALTY : 0,
    timeUp: ticks >= SAFETY_TICKS,
  };
}

/** The bonus of a win that took `ticks` of play. */
export function timeBonus(ticks) {
  const seconds = Math.floor(ticks / 60);
  return seconds >= BONUS_MIN_SECONDS ? Math.floor(BONUS_NUMERATOR / seconds) : 0;
}
