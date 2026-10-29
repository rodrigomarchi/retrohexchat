/**
 * What each change on the Klondike table draws, from the card table's
 * effects (`core/card_table/effects.js`): the deal out of the stock, the
 * cards turned from the stock flying to the waste, a move's flight, a card
 * turning over, a foundation's sparks, and the cascade off the foundations.
 *
 * @module games/hex_solitaire/effects
 */

import {
  FX,
  addFlight,
  dealEffects as deal,
  foundationCascade,
  playedEffects,
} from "../core/card_table/effects.js";
import { easeOutCubic } from "../core/tween.js";
import { cardsFrom, geometryOf, layout, sourcePlace } from "./layout.js";

/** The deal, as Klondike deals: in rounds, every card flying out from the stock. */
export function dealEffects(fx, table, now) {
  const places = layout(table);
  deal(fx, places.columns, places.stock, now);
}

/** The table's places, as the card table's effects read them. */
const PLACES = Object.freeze({
  layout,
  cardsFrom,
  sourcePlace,
  // Where a move's cards land.
  landing: (places, to, count) =>
    to.pile === "foundation"
      ? places.foundations[to.suit]
      : places.columns[to.col].cards.at(-count),
  turned: (places, from) =>
    from.pile === "tableau" ? places.columns[from.col].cards.at(-1) : null,
});

/**
 * The effects of one action from the table (`gestures.js`), from the table
 * before it to the table after, and the events it raised: besides every
 * table's, the cards turned from the stock flying to the waste.
 * @param {object} fx
 * @param {{ before: object, after: object, action: object, events: number, now: number,
 *   drag?: object | null, random: () => number }} played
 */
export function actionEffects(fx, played) {
  const { was, is } = playedEffects(fx, played, PLACES);
  const { before, after, action, now } = played;
  if (action.type === "draw") {
    const turned = after.waste.length - before.waste.length;
    is.waste.slice(-turned).forEach((place, i) => {
      addFlight(fx, [place.card], was.stock, place, now + i * 2, FX.draw, easeOutCubic);
    });
  }
}

/**
 * A win: the cards leave the foundations, kings first, and bounce along the
 * felt until they are off it.
 */
export const cascadeEffects = foundationCascade({ layout, geometryOf });

/** The card the finish sent up between two tables, as a move. */
export function autoMove(before, after) {
  const suit = after.foundations.findIndex((pile, i) => pile.length > before.foundations[i].length);
  const card = after.foundations[suit].at(-1);
  const col = before.tableau.findIndex((column) => column.up.at(-1) === card);
  return {
    type: "move",
    move: {
      from: { pile: "tableau", col, index: before.tableau[col].up.length - 1 },
      to: { pile: "foundation", suit },
    },
  };
}
