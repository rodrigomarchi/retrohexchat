/**
 * Where the board and the bar above it are drawn, and what square a point of
 * the canvas lands on. Pure functions of the level and the table it is laid
 * on.
 *
 * A square's art is 16 pixels, drawn at the biggest scale in half steps (the
 * canvas has twice the game's pixels, so a half pixel is still a whole one)
 * that fits the board under the bar. Standing up on a phone, the expert
 * board turns: its 30 columns run down the screen.
 *
 * @module games/hex_mines/layout
 */

import { TILE } from "./protocol.js";

const BAR = 44;
const MARGIN = 8;
const LANDSCAPE = Object.freeze({ view: Object.freeze({ width: 640, height: 480 }) });
const WIDE = Object.freeze({ view: Object.freeze({ width: 800, height: 480 }) });
const PORTRAIT = Object.freeze({ view: Object.freeze({ width: 464, height: 760 }) });
// The expert board turned is thirty squares down: a taller table.
const TALL = Object.freeze({ view: Object.freeze({ width: 464, height: 780 }) });

/** The tables a level is laid on: the expert board lies on a wider one, and stands on a taller one. */
export const geometryFor = (gameId) =>
  gameId === "hex_mines_expert" ? { LANDSCAPE: WIDE, PORTRAIT: TALL } : { LANDSCAPE, PORTRAIT };

const standing = (geometry) => geometry.view.height > geometry.view.width;

/**
 * Everything's place for a level (`{ cols, rows }`) on a table: the board,
 * its scale and square, whether it is turned, and the bar's counter, face,
 * clock and — standing up — the dig/flag switch.
 */
export function layout(level, geometry) {
  const { width, height } = geometry.view;
  const turned = standing(geometry) && level.cols > level.rows;
  const across = turned ? level.rows : level.cols;
  const down = turned ? level.cols : level.rows;
  const room = { w: width - 2 * MARGIN, h: height - BAR - MARGIN };
  const fit = Math.min(room.w / (across * TILE), room.h / (down * TILE));
  // Squeezed to fit exactly when even a whole half step does not.
  const scale = fit >= 1 ? Math.floor(fit * 2) / 2 : fit;
  const cell = TILE * scale;
  const board = {
    x: Math.round((width - across * cell) / 2),
    y: BAR + Math.floor((height - BAR - down * cell) / 2),
    w: across * cell,
    h: down * cell,
  };
  const piece = (x, w, h = w) => ({ x, y: Math.round((BAR - h) / 2), w, h });
  return {
    level,
    view: geometry.view,
    turned,
    scale,
    cell,
    across,
    board,
    bar: { x: 0, y: 0, w: width, h: BAR },
    counter: piece(8, 3 * 22 + 3, 34),
    face: piece(Math.round(width / 2 - 18), 36),
    clock: piece(width - 8 - (3 * 22 + 3), 3 * 22 + 3, 34),
    mode: standing(geometry) ? piece(Math.round(width / 2 + 30), 36) : null,
  };
}

/** Where square `i` of the board is drawn. */
export function boardPlace(laid, i) {
  const x = i % laid.level.cols;
  const y = Math.floor(i / laid.level.cols);
  const [col, row] = laid.turned ? [y, x] : [x, y];
  return {
    x: laid.board.x + col * laid.cell,
    y: laid.board.y + row * laid.cell,
    w: laid.cell,
    h: laid.cell,
  };
}

/** The square under a point of the canvas, or null off the board. */
export function cellAt(laid, x, y) {
  const col = Math.floor((x - laid.board.x) / laid.cell);
  const row = Math.floor((y - laid.board.y) / laid.cell);
  if (x < laid.board.x || y < laid.board.y || col >= laid.across) return null;
  const [bx, by] = laid.turned ? [row, col] : [col, row];
  if (bx >= laid.level.cols || by >= laid.level.rows) return null;
  return by * laid.level.cols + bx;
}

/** Whether a point lands on a place. */
export const on = (r, x, y) => r !== null && x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h;
