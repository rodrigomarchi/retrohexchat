/**
 * Where everything is drawn, and what a point of the canvas lands on: pure
 * functions of the table the game is laid on.
 *
 * Lying on a desktop, the grid stands on the left and the keypad — three rows
 * of three — with the tools under it on the right. Standing on a phone, the
 * nine keys run in one row under the grid, the tools under them. The art is
 * drawn at half steps (the canvas has twice the game's pixels, so a half
 * pixel is still a whole one): a square's 16 pixels, a key's and a tool's 24.
 *
 * @module games/hex_sudoku/layout
 */

const BAR = 44;

/** The tools, in the order they stand. */
export const TOOLS = Object.freeze(["undo", "eraser", "pencil", "hint"]);

/** The two tables: the view each draws, and the sizes on it. */
export const GEOMETRY = Object.freeze({
  LANDSCAPE: Object.freeze({
    view: Object.freeze({ width: 640, height: 480 }),
    standing: false,
    cell: 40,
    key: 60,
    keyGap: 12,
    tool: 48,
  }),
  PORTRAIT: Object.freeze({
    view: Object.freeze({ width: 448, height: 632 }),
    standing: true,
    cell: 48,
    key: 48,
    keyGap: 0,
    tool: 60,
  }),
});

const place = (x, y, w, h = w) => ({ x, y, w, h });

/** The top bar's three counts: the mistakes on the left, the clock in the middle, the hints on the right. */
function barOf(width) {
  const digit = { w: 21, h: 34, y: 5 };
  return {
    mistakes: { mark: place(10, 14, 16), digits: place(30, digit.y, 2 * 22, digit.h) },
    clock: place(Math.round(width / 2 - 49), digit.y, 98, digit.h),
    hints: { mark: place(width - 76, 14, 16), digits: place(width - 54, digit.y, 2 * 22, digit.h) },
  };
}

/** Everything's place on a table (`GEOMETRY.LANDSCAPE` or `GEOMETRY.PORTRAIT`). */
export function layout(geometry) {
  const { view, cell, key, keyGap, tool } = geometry;
  const side = 9 * cell;
  let grid;
  let keys;
  let tools;
  if (geometry.standing) {
    grid = place((view.width - side) / 2, BAR + 8, side);
    const row = 9 * key + 8 * keyGap;
    const keysY = grid.y + side + 12;
    keys = Array.from({ length: 9 }, (_, n) =>
      place((view.width - row) / 2 + n * (key + keyGap), keysY, key),
    );
    const gap = 24;
    const toolsX = (view.width - (4 * tool + 3 * gap)) / 2;
    tools = TOOLS.map((_, n) => place(toolsX + n * (tool + gap), keysY + key + 14, tool));
  } else {
    const room = view.height - BAR;
    grid = place(24, BAR + (room - side) / 2, side);
    const pad = 3 * key + 2 * keyGap;
    const column = grid.x + side + (view.width - grid.x - side - pad) / 2;
    const block = pad + 20 + tool;
    const top = BAR + (room - block) / 2;
    keys = Array.from({ length: 9 }, (_, n) =>
      place(column + (n % 3) * (key + keyGap), top + Math.floor(n / 3) * (key + keyGap), key),
    );
    const gap = (pad - 4 * tool) / 3;
    tools = TOOLS.map((_, n) => place(column + n * (tool + gap), top + pad + 20, tool));
  }
  return {
    view,
    cell,
    grid,
    keys,
    tools: Object.fromEntries(TOOLS.map((name, n) => [name, tools[n]])),
    bar: { ...place(0, 0, view.width, BAR), ...barOf(view.width) },
  };
}

/** Where square `i` is drawn. */
export const squarePlace = (laid, i) =>
  place(laid.grid.x + (i % 9) * laid.cell, laid.grid.y + Math.floor(i / 9) * laid.cell, laid.cell);

/** Whether a point lands on a place. */
const on = (r, x, y) => x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h;

/**
 * What a point of the canvas lands on: a square `{ type: "square", i }`, a
 * key `{ type: "key", d }`, a tool `{ type: "tool", name }`, or null.
 */
export function hitAt(laid, x, y) {
  if (on(laid.grid, x, y)) {
    const col = Math.floor((x - laid.grid.x) / laid.cell);
    const row = Math.floor((y - laid.grid.y) / laid.cell);
    return { type: "square", i: row * 9 + col };
  }
  const key = laid.keys.findIndex((r) => on(r, x, y));
  if (key >= 0) return { type: "key", d: key + 1 };
  const tool = TOOLS.find((name) => on(laid.tools[name], x, y));
  return tool ? { type: "tool", name: tool } : null;
}
