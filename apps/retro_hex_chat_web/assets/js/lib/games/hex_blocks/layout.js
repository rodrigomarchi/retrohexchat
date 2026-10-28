/**
 * Where everything is drawn: pure functions of the table the game is laid on.
 *
 * Lying on a desktop (or a tablet held sideways), the well stands in the
 * middle, the piece held and the counts on its left, the pieces coming on
 * its right. Standing on a phone, the piece held, the counts and the pieces
 * coming (half size) run along the top, the well under them. The buttons a
 * finger plays with are the page's pad under the game, not the picture's.
 * The art is drawn at half steps (the canvas has twice the game's pixels, so
 * a half pixel is still a whole one): a hexagon's 24x20.
 *
 * @module games/hex_blocks/layout
 */

import { COLS, HIDDEN, PREVIEW, ROWS } from "./protocol.js";

/** The hexagon's art: its box and the step from one column to the next. */
const HEX = Object.freeze({ w: 24, h: 20, step: 18 });

/** The two tables: the view each draws, and the sizes on it. */
export const GEOMETRY = Object.freeze({
  LANDSCAPE: Object.freeze({
    view: Object.freeze({ width: 640, height: 480 }),
    standing: false,
    scale: 1,
    mini: 1,
  }),
  PORTRAIT: Object.freeze({
    view: Object.freeze({ width: 400, height: 484 }),
    standing: true,
    scale: 1,
    mini: 0.5,
  }),
});

const place = (x, y, w, h = w) => ({ x, y, w, h });

/** The counts in their box: the score (or a Sprint's time) on top, the level and the rows under it. */
function countsIn(box) {
  const digit = { w: 11, h: 17 };
  const left = box.x + 10;
  return {
    score: place(left, box.y + 10, box.w - 20, digit.h),
    level: { mark: place(left, box.y + 40 + 4, 8), digits: place(left + 14, box.y + 40, 23, 17) },
    lines: {
      mark: place(left + 50, box.y + 40 + 4, 8),
      digits: place(left + 64, box.y + 40, 35, 17),
    },
  };
}

/** Everything's place on a table (`GEOMETRY.LANDSCAPE` or `GEOMETRY.PORTRAIT`). */
export function layout(geometry) {
  const { view, scale, mini } = geometry;
  const cell = { w: HEX.w * scale, h: HEX.h * scale, step: HEX.step * scale };
  const wellW = (COLS - 1) * cell.step + cell.w;
  const wellH = (ROWS - HIDDEN) * cell.h + cell.h / 2;
  let well;
  let hold;
  let next;
  let stats;
  let slots;
  if (geometry.standing) {
    hold = place(8, 6, 72, 72);
    stats = place(88, 6, 136, 72);
    next = place(232, 6, 160, 72);
    slots = Array.from({ length: PREVIEW }, (_, n) =>
      place(next.x + 2 + n * 52, next.y + 4, 52, 64),
    );
    well = place((view.width - wellW) / 2, 84, wellW, wellH);
  } else {
    well = place((view.width - wellW) / 2, (view.height - wellH) / 2, wellW, wellH);
    const column = 176;
    const leftX = well.x - 18 - column;
    const rightX = well.x + well.w + 18;
    hold = place(leftX, well.y, column, 92);
    stats = place(leftX, hold.y + hold.h + 10, column, 80);
    next = place(rightX, well.y, column, 3 * 70);
    slots = Array.from({ length: PREVIEW }, (_, n) =>
      place(next.x + 8, next.y + n * 70, column - 16, 70),
    );
  }
  return { view, scale, mini, cell, well, hold, next, slots, stats, counts: countsIn(stats) };
}

/** Where the well's square at column `c`, row `r` is drawn (rows counted from the hidden ones). */
export function cellPlace(laid, c, r) {
  const { w, h, step } = laid.cell;
  return {
    x: laid.well.x + c * step,
    y: laid.well.y + (r - HIDDEN) * h + (c & 1 ? h / 2 : 0),
    w,
    h,
  };
}
