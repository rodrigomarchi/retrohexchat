/**
 * A card match's clock and score: the clock runs from the first move, every
 * ten seconds of play may cost points, an hour calls time, and a fast win
 * earns a bonus. The score never falls below zero.
 *
 * @module games/core/card_table/clock
 */

/** Ten seconds of play, each costing `TIME_PENALTY` where time costs. */
export const PENALTY_TICKS = 600;
export const TIME_PENALTY = -2;

/** An hour: a game still open then ends with the points it has. */
export const SAFETY_TICKS = 60 * 60 * 60;

/** A win in `BONUS_MIN_SECONDS` or more pays `BONUS_NUMERATOR` / seconds. */
export const BONUS_NUMERATOR = 700_000;
export const BONUS_MIN_SECONDS = 30;

/** The score after `points`, never below zero. */
export const addPoints = (score, points) => Math.max(0, score + points);

/** The clock, running from now on; the same clock when it already runs. */
export const startClock = (clock) => (clock.started ? clock : { ...clock, started: true });

/**
 * One tick of the clock: it counts only once started, every ten seconds of
 * play cost `penalty` points, and an hour calls time.
 * @param {{ started: boolean, ticks: number }} clock
 * @param {number} [penalty] - 0 where time costs nothing
 * @returns {{ clock: { started: boolean, ticks: number }, points: number, timeUp: boolean }}
 */
export function tickClock(clock, penalty = TIME_PENALTY) {
  if (!clock.started) return { clock, points: 0, timeUp: false };
  const ticks = clock.ticks + 1;
  return {
    clock: { ...clock, ticks },
    points: ticks % PENALTY_TICKS === 0 ? penalty : 0,
    timeUp: ticks >= SAFETY_TICKS,
  };
}

/** The bonus of a win that took `ticks` of play. */
export function timeBonus(ticks) {
  const seconds = Math.floor(ticks / 60);
  return seconds >= BONUS_MIN_SECONDS ? Math.floor(BONUS_NUMERATOR / seconds) : 0;
}
