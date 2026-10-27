/**
 * What each change on the FreeCell table draws, from the card table's
 * effects (`core/card_table/effects.js`): the deal rising from below the
 * table, a move's flight, a foundation's sparks, and the cascade off the
 * foundations.
 *
 * @module games/hex_freecell/effects
 */

import { cascadeFrom, dealEffects as deal, playedEffects } from "../core/card_table/effects.js";
import { suitOf } from "../core/cards.js";
import { geometryOf, layout, sourcePlace } from "./layout.js";
import { picked } from "./rules.js";

/** The deal, in rounds across the eight columns, every card rising from below the table's middle. */
export function dealEffects(fx, table, now) {
  const { view, card } = geometryOf(table);
  deal(fx, layout(table).columns, { x: (view.width - card.width) / 2, y: view.height }, now);
}

/** The table's places, as the card table's effects read them. */
const PLACES = Object.freeze({
  layout,
  cardsFrom: picked,
  sourcePlace,
  // Where a move's cards land.
  landing: (places, to, count) => {
    if (to.pile === "foundation") return places.foundations[to.suit];
    if (to.pile === "cell") return places.cells[to.cell];
    return places.columns[to.col].cards.at(-count);
  },
});

/**
 * The effects of one action from the table (`gestures.js`), or of a card
 * going up by itself, from the table before it to the table after.
 */
export function actionEffects(fx, played) {
  playedEffects(fx, played, PLACES);
}

/** A win: the cards leave the foundations, kings first, and bounce off the felt. */
export function cascadeEffects(fx, table, now, random) {
  cascadeFrom(
    fx,
    layout(table).foundations,
    table.foundations,
    geometryOf(table).view,
    now,
    random,
  );
}

/** The card that went up by itself between two tables, as a move. */
export function autoMove(before, after) {
  const suit = after.foundations.findIndex((pile, i) => pile.length > before.foundations[i].length);
  const card = after.foundations[suit].at(-1);
  const cell = before.cells.indexOf(card);
  const col = before.columns.findIndex((column) => column.at(-1) === card);
  const from =
    cell >= 0
      ? { pile: "cell", cell }
      : { pile: "column", col, index: before.columns[col].length - 1 };
  return { type: "move", move: { from, to: { pile: "foundation", suit: suitOf(card) } } };
}
