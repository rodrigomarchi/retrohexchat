/**
 * Where everything on the Spider table is drawn, and what a point of the
 * canvas lands on: the ten columns hanging from the top, the suits completed
 * stacked at the bottom left and the stock's deals at the bottom right. Pure
 * functions of the table.
 *
 * @module games/hex_spider/layout
 */

import { cardPlace, columnX, contains, hitColumns, layColumns } from "../core/card_table/piles.js";
import { COLUMNS, GEOMETRY } from "./protocol.js";

/** The table a game is laid out on: its own, or lying down when it names none. */
export const geometryOf = (table) => table.geometry ?? GEOMETRY.LANDSCAPE;

const bottomRow = (geo) => geo.view.height - geo.bottom - geo.card.height;

/** Every pile's place and every card's, in the canvas's pixels. */
export function layout(table) {
  const geo = geometryOf(table);
  const place = (x, y) => cardPlace(x, y, geo.card);
  const room = bottomRow(geo) - geo.bottom - geo.columnsTop - geo.card.height;
  const columns = layColumns(table.columns, geo, room);
  // One back for each deal left, fanned to the left: the rightmost deals next.
  const deals = Math.ceil(table.stock.length / COLUMNS);
  const stockX = columnX(geo, COLUMNS - 1);
  const stock = Array.from({ length: deals }, (_, i) =>
    place(stockX - (deals - 1 - i) * geo.stackOffset, bottomRow(geo)),
  );
  const foundations = table.foundations.map((pile, i) =>
    place(columnX(geo, 0) + i * geo.stackOffset, bottomRow(geo)),
  );
  // Where the next suit completed goes.
  const next = place(columnX(geo, 0) + table.foundations.length * geo.stackOffset, bottomRow(geo));
  return { columns, stock, stockSlot: place(stockX, bottomRow(geo)), foundations, next };
}

/** Where the bottom card a move or a drag takes from `from` is drawn. */
export const sourcePlace = (places, from) =>
  places.columns[from.col].cards.find((c) => c.faceUp && c.index === from.index);

/**
 * What a point of the canvas lands on: `{ pile: "stock" }`, a face-up card
 * `{ pile: "column", col, index }`, a face-down one `{ pile: "hidden", col }`,
 * an empty column's place `{ pile: "slot", col }`, or null.
 */
export function hitTest(table, x, y) {
  const places = layout(table);
  if (places.stock.some((r) => contains(r, x, y))) return { pile: "stock" };
  return hitColumns(places.columns, x, y, "column");
}
