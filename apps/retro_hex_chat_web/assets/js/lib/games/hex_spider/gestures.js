/**
 * What a tap or a drag on the Spider table means (`core/card_table/gestures.js`).
 * A tap on the stock deals a row — or, with a column empty, shakes it. A tap
 * on a run sends it onto the column whose top continues its suit, else onto
 * any card one higher, else into an empty column.
 *
 * @module games/hex_spider/gestures
 */

import { faceOf, rankOf, suitOf } from "../core/cards.js";
import { createInterpreter } from "../core/card_table/gestures.js";
import { geometryOf, hitTest, layout, sourcePlace } from "./layout.js";
import { canMove, canPick, dealRow } from "./rules.js";

const cardsFrom = (table, from) => table.columns[from.col].up.slice(from.index);

/** What a hit picks up: a run of one suit to the top of its column. */
const pick = (table, hit) => (hit?.pile === "column" && canPick(table, hit) ? hit : null);

/** Where a tap sends the run at `from`, or null when nowhere takes it. */
export function bestDestination(table, from) {
  const [card] = cardsFrom(table, from);
  const moves = table.columns
    .map((column, col) => ({
      col,
      top: column.up.at(-1),
      empty: !column.up.length && !column.down.length,
    }))
    .filter(({ col }) => canMove(table, { from, to: { pile: "column", col } }));
  const sameSuit = moves.find(
    ({ top }) => top !== undefined && suitOf(faceOf(top)) === suitOf(faceOf(card)),
  );
  const any = moves.find(
    ({ top }) => top !== undefined && rankOf(faceOf(top)) === rankOf(faceOf(card)) + 1,
  );
  // A whole column gains nothing in another empty one.
  const alone = from.index === 0 && table.columns[from.col].down.length === 0;
  const empty = alone ? null : moves.find(({ empty }) => empty);
  const best = sameSuit ?? any ?? empty;
  return best ? { from, to: { pile: "column", col: best.col } } : null;
}

/** A tap on the stock deals a row, or is refused while a column is empty. */
function tapStock(table, hit) {
  if (hit?.pile !== "stock") return undefined;
  return dealRow(table) ? { type: "deal" } : { type: "refuse", from: { pile: "stock" } };
}

/** Where a held run may be dropped: each column's top card or place. */
function targets(table) {
  return layout(table).columns.map((column, col) => ({
    r: column.cards.at(-1) ?? column.slot,
    to: { pile: "column", col },
  }));
}

/**
 * The drag that follows a gesture on `table`, and the action it makes.
 * @returns {{ drag: object | null, action: object | null }}
 */
export const interpret = createInterpreter({
  card: (table) => geometryOf(table).card,
  hitTest,
  pick,
  tap: tapStock,
  bestDestination,
  canMove,
  cardsFrom,
  sourcePlace: (table, from) => sourcePlace(layout(table), from),
  targets,
});
