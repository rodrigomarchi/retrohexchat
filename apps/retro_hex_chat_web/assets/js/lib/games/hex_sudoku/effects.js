/**
 * What moves on the grid, apart from the match: a digit dropping in with a
 * hop, a wrong one shaking its square, a glow running along a row, column or
 * box the digit completed, and on a win the whole grid lighting from the
 * centre out, with sparks.
 *
 * The match changes in the tick (`physics.js`); these only draw it arriving,
 * on the solo core's effects (`core/solo/effects.js`). Any randomness comes
 * from the match's effects stream (`game.fxRandom`). With motion reduced,
 * nothing hops, shakes or runs.
 *
 * @module games/hex_sudoku/effects
 */

import { gameColor } from "../../game_colors.js";
import { burst } from "../core/render.js";
import { UNITS } from "./grid.js";
import { EVENT } from "./protocol.js";

export {
  active,
  createEffects,
  glowAt,
  hopAt,
  shakeAt,
  stepEffects,
} from "../core/solo/effects.js";

/** How long each effect lasts, and how far apart its steps start, in ticks. */
export const FX = Object.freeze({ hop: 10, shake: 18, step: 3, glow: 24, ring: 6, sparks: 50 });

const SPARKS = ["ffe26e", "fff6c8", "8fb6ff", "ffffff"];

/** How many steps square `a` is from square `b`, along rows, columns or a diagonal. */
const distance = (a, b) =>
  Math.max(Math.abs((a % 9) - (b % 9)), Math.abs(Math.floor(a / 9) - Math.floor(b / 9)));

/** Squares lit one after another, by how far each is from `from`, `step` ticks a step. */
function light(fx, squares, from, now, step) {
  for (const i of squares) {
    fx.list.push({ kind: "glow", i, start: now + distance(i, from) * step, ticks: FX.glow });
  }
}

/**
 * The effects of an action, from the match before it to the match after.
 * @param {object} fx
 * @param {{ before: object, after: object, laid: object, now: number,
 *   random: () => number }} played
 */
export function playedEffects(fx, { before, after, laid, now, random }) {
  const events = after.events & ~before.events;
  const { changed } = after;
  if (!fx.reduced && changed && events & (EVENT.PLACE | EVENT.HINT | EVENT.MISTAKE)) {
    if (events & (EVENT.PLACE | EVENT.HINT)) {
      fx.list.push({ kind: "hop", i: changed.i, start: now, ticks: FX.hop });
    }
    if (events & EVENT.MISTAKE) {
      fx.list.push({ kind: "shake", i: changed.i, start: now, ticks: FX.shake });
    }
    for (const unit of changed.units) light(fx, UNITS[unit], changed.i, now, FX.step);
  }
  if (events & EVENT.WIN) {
    if (!fx.reduced) light(fx, UNITS.slice(0, 9).flat(), 40, now, FX.ring);
    const { grid } = laid;
    const particles = burst(
      grid.x + grid.w / 2,
      grid.y + grid.h / 2,
      fx.reduced ? 10 : 40,
      { speed: [2, 4], extra: (k) => ({ life: 1, color: gameColor(SPARKS[k % SPARKS.length]) }) },
      random,
    );
    fx.list.push({ kind: "sparks", particles, start: now, ticks: FX.sparks });
  }
}
