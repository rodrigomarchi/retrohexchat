import { expect } from "vitest";

/**
 * Places on a game's table, `{ x, y, w, h }` in the canvas's pixels, as the
 * layout tests read them.
 */

/** Whether a place lies whole inside the view. */
export const within = (r, view) =>
  r.x >= 0 && r.y >= 0 && r.x + r.w <= view.width && r.y + r.h <= view.height;

/** Whether two places cover nothing of each other. */
export const apart = (a, b) =>
  a.x + a.w <= b.x || b.x + b.w <= a.x || a.y + a.h <= b.y || b.y + b.h <= a.y;

/** Every place inside the view, and none over another. */
export function expectLaidApart(places, view) {
  for (const r of places) expect(within(r, view)).toBe(true);
  places.forEach((a, n) => {
    for (const b of places.slice(n + 1)) expect(apart(a, b)).toBe(true);
  });
}
