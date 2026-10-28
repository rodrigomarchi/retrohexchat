/**
 * Undo and redo for a drawing: each step is a whole drawing, which costs a
 * few kilobytes at most and makes going back a matter of picking one up.
 *
 * @module paint/history
 */

/** How many steps back a drawing can go. */
export const LIMIT = 50;

/**
 * @template T
 * @param {T} first
 * @returns {{ now: T, past: T[], future: T[] }}
 */
export const createHistory = (first) => ({ now: first, past: [], future: [] });

/** The history with `next` as the step after now; nothing changes when it is the same drawing. */
export function record(history, next) {
  if (next === history.now) return history;
  const past = [...history.past, history.now].slice(-LIMIT);
  return { now: next, past, future: [] };
}

/** The history one step back, or as it was with nothing to undo. */
export function undo(history) {
  if (!history.past.length) return history;
  return {
    now: history.past.at(-1),
    past: history.past.slice(0, -1),
    future: [history.now, ...history.future],
  };
}

/** The history one step forward again, or as it was with nothing to redo. */
export function redo(history) {
  if (!history.future.length) return history;
  return {
    now: history.future[0],
    past: [...history.past, history.now],
    future: history.future.slice(1),
  };
}
