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
  cascadeEffects as cascade,
  dealEffects as deal,
  moveEffects,
  returnEffects,
  shakeEffects,
} from "../core/card_table/effects.js";
import { easeOutCubic } from "../core/tween.js";
import { cardsFrom, geometryOf, layout, sourcePlace } from "./layout.js";
import { EVENT } from "./protocol.js";

/** The deal, as Klondike deals: in rounds, every card flying out from the stock. */
export function dealEffects(fx, table, now) {
  const places = layout(table);
  deal(fx, places.columns, places.stock, now);
}

/** Where a move's cards land. */
function landing(places, to, count) {
  if (to.pile === "foundation") return places.foundations[to.suit];
  return places.columns[to.col].cards.at(-count);
}

/**
 * The effects of one action from the table (`gestures.js`), from the table
 * before it to the table after, and the events it raised.
 * @param {object} fx
 * @param {{ before: object, after: object, action: object, events: number, now: number,
 *   drag?: object | null, random: () => number }} played
 */
export function actionEffects(fx, { before, after, action, events, now, drag = null, random }) {
  const was = layout(before);
  const is = layout(after);

  if (action.type === "draw") {
    const turned = after.waste.length - before.waste.length;
    is.waste.slice(-turned).forEach((place, i) => {
      addFlight(fx, [place.card], was.stock, place, now + i * 2, FX.draw, easeOutCubic);
    });
  }
  if (action.type === "move") {
    const { from, to } = action.move;
    const cards = cardsFrom(before, from);
    moveEffects(fx, {
      cards,
      from: drag ? { x: drag.x, y: drag.y } : sourcePlace(was, from),
      to: landing(is, to, cards.length),
      dropped: Boolean(drag),
      now,
      turned:
        events & EVENT.FLIP && from.pile === "tableau" ? is.columns[from.col].cards.at(-1) : null,
      sparksAt: events & EVENT.FOUNDATION ? landing(is, to, 1) : null,
      random,
    });
  }
  if (action.type === "return" && drag) returnEffects(fx, drag, sourcePlace(was, action.from), now);
  if (action.type === "refuse") {
    shakeEffects(fx, cardsFrom(before, action.from)[0], sourcePlace(was, action.from), now);
  }
}

/**
 * A win: the cards leave the foundations, kings first, and bounce along the
 * felt until they are off it.
 */
export function cascadeEffects(fx, table, now, random) {
  const places = layout(table);
  const piles = places.foundations.map((place, suit) => ({
    place,
    cards: table.foundations[suit],
  }));
  cascade(fx, piles, geometryOf(table).view, now, random);
}

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
