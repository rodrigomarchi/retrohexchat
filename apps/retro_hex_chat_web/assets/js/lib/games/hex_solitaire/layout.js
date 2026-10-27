/**
 * Where everything on the table is drawn, and what a point of the canvas
 * lands on. The renderer draws what `layout` places; a press reads
 * `hitTest`. Both are pure functions of the table.
 *
 * @module games/hex_solitaire/layout
 */

import { cardPlace, columnCards, contains, fanOffsets } from "../core/card_table/piles.js";
import { CARD, COLUMNS, GEOMETRY, TABLE, TOP_ROW } from "./protocol.js";

/** The table a game is laid out on: its own, or lying down when it names none. */
export const geometryOf = (state) => state.geometry ?? GEOMETRY.LANDSCAPE;

const columnX = (geo, col) => geo.left + col * (CARD.width + geo.gap);
const place = (x, y) => cardPlace(x, y, CARD);

/** How far apart a column's cards stand, squeezed to keep the last one on the canvas. */
const offsets = (geo, down, up) =>
  fanOffsets({
    room: geo.view.height - TABLE.bottom - geo.columnsTop - CARD.height,
    down,
    up,
    downOffset: geo.downOffset ?? TABLE.downOffset,
    upOffset: geo.upOffset ?? TABLE.upOffset,
    min: TABLE.minOffset,
  });

/**
 * Every pile's place and every card's, in the canvas's pixels. A column's
 * cards run from its bottom card to its top one; each says whether it lies
 * face up and, if so, its index in the column's face-up run.
 */
export function layout(state) {
  const geo = geometryOf(state);
  const stock = place(columnX(geo, TOP_ROW.stock), geo.top);
  const wasteSlot = place(columnX(geo, TOP_ROW.waste), geo.top);
  const showing = state.waste.slice(-Math.max(state.fan, state.waste.length ? 1 : 0));
  const waste = showing.map((card, i) => ({
    card,
    ...place(wasteSlot.x + i * TABLE.fanOffset, geo.top),
  }));
  const foundations = TOP_ROW.foundations.map((col) => place(columnX(geo, col), geo.top));

  const columns = state.tableau.slice(0, COLUMNS).map((column, col) => {
    const slot = place(columnX(geo, col), geo.columnsTop);
    const spacing = offsets(geo, column.down.length, column.up.length);
    const cards = columnCards(slot, column.down, column.up, spacing, CARD);
    return { slot, cards };
  });

  return { stock, wasteSlot, waste, foundations, columns };
}

/** Where the bottom card a move or a drag takes from `from` is drawn. */
export function sourcePlace(places, from) {
  if (from.pile === "waste") return places.waste.at(-1);
  if (from.pile === "foundation") return places.foundations[from.suit];
  return places.columns[from.col].cards.find((c) => c.faceUp && c.index === from.index);
}

/** The cards taken from `from` (`rules.js`), bottom first. */
export function cardsFrom(table, from) {
  if (from.pile === "waste") return [table.waste.at(-1)];
  if (from.pile === "foundation") return [table.foundations[from.suit].at(-1)];
  return table.tableau[from.col].up.slice(from.index);
}

/**
 * What a point of the canvas lands on: `{ pile: "stock" }`, `{ pile: "waste" }`
 * (its top card only), `{ pile: "foundation", suit }`, a face-up card
 * `{ pile: "tableau", col, index }`, a face-down one `{ pile: "hidden", col }`,
 * an empty column's place `{ pile: "slot", col }`, or null.
 */
export function hitTest(state, x, y) {
  const places = layout(state);
  const top = places.waste.at(-1);
  if (top && contains(top, x, y)) return { pile: "waste" };
  if (places.waste.some((card) => contains(card, x, y))) return null;
  if (contains(places.stock, x, y)) return { pile: "stock" };
  const suit = places.foundations.findIndex((r) => contains(r, x, y));
  if (suit >= 0) return { pile: "foundation", suit };

  for (const [col, column] of places.columns.entries()) {
    for (let i = column.cards.length - 1; i >= 0; i--) {
      const card = column.cards[i];
      if (!contains(card, x, y)) continue;
      return card.faceUp ? { pile: "tableau", col, index: card.index } : { pile: "hidden", col };
    }
    if (column.cards.length === 0 && contains(column.slot, x, y)) return { pile: "slot", col };
  }
  return null;
}
