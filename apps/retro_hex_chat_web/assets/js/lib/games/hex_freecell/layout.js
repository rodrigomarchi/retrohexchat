/**
 * Where everything on the FreeCell table is drawn, and what a point of the
 * canvas lands on: the four free cells and the four foundations along the
 * top, the eight columns below. Pure functions of the table.
 *
 * @module games/hex_freecell/layout
 */

import { cardPlace, columnX, hitColumns, layColumns } from "../core/card_table/piles.js";
import { contains } from "../core/pointer.js";
import { CELLS, GEOMETRY } from "./protocol.js";

/** The table a game is laid out on: its own, or lying down when it names none. */
export const geometryOf = (table) => table.geometry ?? GEOMETRY.LANDSCAPE;

/** Every pile's place and every card's, in the canvas's pixels. */
export function layout(table) {
  const geo = geometryOf(table);
  const place = (x, y) => cardPlace(x, y, geo.card);
  const cells = table.cells.map((card, i) => ({ card, ...place(columnX(geo, i), geo.top) }));
  const foundations = table.foundations.map((pile, suit) =>
    place(columnX(geo, CELLS + suit), geo.top),
  );
  // Every card lies face up: a column is all run.
  const columns = layColumns(
    table.columns.map((up) => ({ down: [], up })),
    { ...geo, downOffset: 0 },
    geo.view.height - geo.bottom - geo.columnsTop - geo.card.height,
  );
  return { cells, foundations, columns };
}

/** Where the top card a move or a drag takes from `from` is drawn. */
export function sourcePlace(places, from) {
  if (from.pile === "cell") return places.cells[from.cell];
  if (from.pile === "foundation") return places.foundations[from.suit];
  return places.columns[from.col].cards[from.index];
}

/**
 * What a point of the canvas lands on: `{ pile: "cell", cell }`,
 * `{ pile: "foundation", suit }`, a card `{ pile: "column", col, index }`,
 * an empty column's place `{ pile: "slot", col }`, or null.
 */
export function hitTest(table, x, y) {
  const places = layout(table);
  const cell = places.cells.findIndex((r) => contains(r, x, y));
  if (cell >= 0) return { pile: "cell", cell };
  const suit = places.foundations.findIndex((r) => contains(r, x, y));
  if (suit >= 0) return { pile: "foundation", suit };
  return hitColumns(places.columns, x, y, "column");
}
