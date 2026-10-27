/**
 * What a tap or a drag on the Klondike table means (`core/card_table/gestures.js`):
 * besides moves, a tap on the stock turns it (`draw`) or turns the waste
 * back (`recycle`), and a tap never takes a card back from a foundation —
 * a drag still can.
 *
 * @module games/hex_solitaire/gestures
 */

import { createInterpreter } from "../core/card_table/gestures.js";
import { CARD, COLUMNS } from "./protocol.js";
import { cardsFrom, hitTest, layout, sourcePlace } from "./layout.js";
import { canMove } from "./rules.js";

/** What a hit picks up, or null: a face-up card, the waste's top, a foundation's top. */
function pickable(state, hit) {
  if (!hit) return null;
  if (hit.pile === "waste") return state.waste.length ? hit : null;
  if (hit.pile === "foundation") return state.foundations[hit.suit].length ? hit : null;
  if (hit.pile === "tableau") return hit;
  return null;
}

/**
 * Where a tap sends the cards at `from`: its foundation first, then the first
 * column from the left that takes them; null when nowhere does.
 */
export function bestDestination(state, from) {
  // A run already at the bottom of its column gains nothing in another empty one.
  const alone =
    from.pile === "tableau" && from.index === 0 && state.tableau[from.col].down.length === 0;
  const toFoundation = {
    from,
    to: { pile: "foundation", suit: Math.floor(cardsFrom(state, from)[0] / 13) },
  };
  if (canMove(state, toFoundation)) return toFoundation;
  for (let col = 0; col < COLUMNS; col++) {
    const move = { from, to: { pile: "tableau", col } };
    const empty = state.tableau[col].up.length === 0 && state.tableau[col].down.length === 0;
    if (canMove(state, move) && !(alone && empty)) return move;
  }
  return null;
}

/** Where a held run may be dropped: the foundations, then each column's last card or place. */
function targets(state) {
  const places = layout(state);
  return [
    ...places.foundations.map((r, suit) => ({ r, to: { pile: "foundation", suit } })),
    ...places.columns.map((column, col) => ({
      r: column.cards.at(-1) ?? column.slot,
      to: { pile: "tableau", col },
    })),
  ];
}

/** A tap on the stock turns it, or the waste back once it is empty. */
function tapStock(state, hit) {
  if (hit?.pile !== "stock") return undefined;
  if (state.stock.length) return { type: "draw" };
  return state.waste.length ? { type: "recycle" } : null;
}

/**
 * The drag that follows a gesture, and the action it makes.
 * @param {object} state - the table
 * @param {object | null} drag - the drag in progress
 * @param {{ type: string, x?: number, y?: number }} gesture
 * @returns {{ drag: object | null, action: object | null }}
 */
export const interpret = createInterpreter({
  card: CARD,
  hitTest,
  pick: pickable,
  tap: tapStock,
  tapMoves: (from) => from.pile !== "foundation",
  bestDestination,
  canMove,
  cardsFrom,
  sourcePlace: (state, from) => sourcePlace(layout(state), from),
  targets,
});
