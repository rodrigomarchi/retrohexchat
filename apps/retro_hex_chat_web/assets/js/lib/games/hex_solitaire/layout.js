/**
 * Where everything on the table is drawn, and what a point of the canvas
 * lands on. The renderer draws what `layout` places; a press reads
 * `hitTest`. Both are pure functions of the table.
 *
 * @module games/hex_solitaire/layout
 */

import { CARD, COLUMNS, TABLE, TOP_ROW, VIEW } from "./protocol.js";

const columnX = (col) => TABLE.left + col * (CARD.width + TABLE.gap);
const place = (x, y) => ({ x, y, w: CARD.width, h: CARD.height });
const contains = (r, x, y) => x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h;

/** How far apart a column's cards stand, squeezed to keep the last one on the canvas. */
function offsets(down, up) {
  const room = VIEW.height - TABLE.bottom - TABLE.columnsTop - CARD.height;
  const upGaps = Math.max(0, up - 1);
  const downGaps = up > 0 ? down : Math.max(0, down - 1);
  let downOffset = TABLE.downOffset;
  let upOffset = TABLE.upOffset;
  if (downGaps * downOffset + upGaps * upOffset > room && upGaps > 0) {
    upOffset = Math.max(TABLE.minOffset, Math.floor((room - downGaps * downOffset) / upGaps));
  }
  if (downGaps * downOffset + upGaps * upOffset > room && downGaps > 0) {
    downOffset = Math.max(TABLE.minOffset, Math.floor((room - upGaps * upOffset) / downGaps));
  }
  return { downOffset, upOffset };
}

/**
 * Every pile's place and every card's, in the canvas's pixels. A column's
 * cards run from its bottom card to its top one; each says whether it lies
 * face up and, if so, its index in the column's face-up run.
 */
export function layout(state) {
  const stock = place(columnX(TOP_ROW.stock), TABLE.top);
  const wasteSlot = place(columnX(TOP_ROW.waste), TABLE.top);
  const showing = state.waste.slice(-Math.max(state.fan, state.waste.length ? 1 : 0));
  const waste = showing.map((card, i) => ({
    card,
    ...place(wasteSlot.x + i * TABLE.fanOffset, TABLE.top),
  }));
  const foundations = TOP_ROW.foundations.map((col) => place(columnX(col), TABLE.top));

  const columns = state.tableau.slice(0, COLUMNS).map((column, col) => {
    const slot = place(columnX(col), TABLE.columnsTop);
    const { downOffset, upOffset } = offsets(column.down.length, column.up.length);
    const cards = [];
    let y = slot.y;
    column.down.forEach((card) => {
      cards.push({ card, faceUp: false, index: null, ...place(slot.x, y) });
      y += downOffset;
    });
    column.up.forEach((card, index) => {
      cards.push({ card, faceUp: true, index, ...place(slot.x, y) });
      y += upOffset;
    });
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
