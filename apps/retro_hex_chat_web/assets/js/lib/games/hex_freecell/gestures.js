/**
 * What a tap or a drag on the FreeCell table means (`core/card_table/gestures.js`).
 * A tap sends a card, or the run under it, to its foundation, else to a
 * column that takes it — one with cards before an empty one — else, a single
 * card, to a free cell.
 *
 * @module games/hex_freecell/gestures
 */

import { suitOf } from "../core/cards.js";
import { createInterpreter } from "../core/card_table/gestures.js";
import { geometryOf, hitTest, layout, sourcePlace } from "./layout.js";
import { canMove, isRun, picked } from "./rules.js";

/** What a hit picks up: a cell's card, a foundation's top, or a run to a column's foot. */
function pick(table, hit) {
  if (!hit) return null;
  if (hit.pile === "cell") return table.cells[hit.cell] === null ? null : hit;
  if (hit.pile === "foundation") return table.foundations[hit.suit].length ? hit : null;
  if (hit.pile === "column") return isRun(picked(table, hit)) ? hit : null;
  return null;
}

/** Where a tap sends the cards at `from`, or null when nowhere takes them. */
export function bestDestination(table, from) {
  const cards = picked(table, from);
  const moves = [
    { from, to: { pile: "foundation", suit: suitOf(cards[0]) } },
    ...table.columns
      .map((column, col) => ({ col, empty: column.length === 0 }))
      .sort((a, b) => a.empty - b.empty)
      .map(({ col }) => ({ from, to: { pile: "column", col } })),
    ...table.cells.map((card, cell) => ({ from, to: { pile: "cell", cell } })),
  ];
  // A whole column gains nothing in another empty one.
  const alone = from.pile === "column" && from.index === 0;
  return (
    moves.find(
      (move) =>
        canMove(table, move) &&
        !(alone && move.to.pile === "column" && table.columns[move.to.col].length === 0),
    ) ?? null
  );
}

/** Where a held run may be dropped: the cells, the foundations, then each column. */
function targets(table) {
  const places = layout(table);
  return [
    ...places.cells.map((r, cell) => ({ r, to: { pile: "cell", cell } })),
    ...places.foundations.map((r, suit) => ({ r, to: { pile: "foundation", suit } })),
    ...places.columns.map((column, col) => ({
      r: column.cards.at(-1) ?? column.slot,
      to: { pile: "column", col },
    })),
  ];
}

/**
 * The drag that follows a gesture on `table`, and the action it makes.
 * @returns {{ drag: object | null, action: object | null }}
 */
export const interpret = createInterpreter({
  card: (table) => geometryOf(table).card,
  hitTest,
  pick,
  // A tap never takes a card back from a foundation; a drag still can.
  tapMoves: (from) => from.pile !== "foundation",
  bestDestination,
  canMove,
  cardsFrom: (table, from) => picked(table, from),
  sourcePlace: (table, from) => sourcePlace(layout(table), from),
  targets,
});
