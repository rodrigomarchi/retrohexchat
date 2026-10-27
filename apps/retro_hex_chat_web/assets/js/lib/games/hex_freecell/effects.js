/**
 * What each change on the FreeCell table draws, from the card table's
 * effects (`core/card_table/effects.js`): the deal rising from below the
 * table, a move's flight, a foundation's sparks, and the cascade off the
 * foundations.
 *
 * @module games/hex_freecell/effects
 */

import {
  cascadeEffects as cascade,
  dealEffects as deal,
  moveEffects,
  returnEffects,
  shakeEffects,
} from "../core/card_table/effects.js";
import { suitOf } from "../core/cards.js";
import { geometryOf, layout, sourcePlace } from "./layout.js";
import { EVENT } from "./protocol.js";
import { picked } from "./rules.js";

/** The deal, in rounds across the eight columns, every card rising from below the table's middle. */
export function dealEffects(fx, table, now) {
  const { view, card } = geometryOf(table);
  deal(fx, layout(table).columns, { x: (view.width - card.width) / 2, y: view.height }, now);
}

/** Where a move's cards land. */
function landing(places, to, count) {
  if (to.pile === "foundation") return places.foundations[to.suit];
  if (to.pile === "cell") return places.cells[to.cell];
  return places.columns[to.col].cards.at(-count);
}

/**
 * The effects of one action from the table (`gestures.js`), or of a card
 * going up by itself, from the table before it to the table after.
 * @param {object} fx
 * @param {{ before: object, after: object, action: object, events: number, now: number,
 *   drag?: object | null, random: () => number }} played
 */
export function actionEffects(fx, { before, after, action, events, now, drag = null, random }) {
  const was = layout(before);
  const is = layout(after);
  if (action.type === "move") {
    const { from, to } = action.move;
    const cards = picked(before, from);
    moveEffects(fx, {
      cards,
      from: drag ? { x: drag.x, y: drag.y } : sourcePlace(was, from),
      to: landing(is, to, cards.length),
      dropped: Boolean(drag),
      now,
      sparksAt: events & EVENT.FOUNDATION ? landing(is, to, 1) : null,
      random,
    });
  }
  if (action.type === "return" && drag) returnEffects(fx, drag, sourcePlace(was, action.from), now);
  if (action.type === "refuse") {
    shakeEffects(fx, picked(before, action.from)[0], sourcePlace(was, action.from), now);
  }
}

/** A win: the cards leave the foundations, kings first, and bounce off the felt. */
export function cascadeEffects(fx, table, now, random) {
  const places = layout(table);
  const piles = places.foundations.map((place, suit) => ({
    place,
    cards: table.foundations[suit],
  }));
  cascade(fx, piles, geometryOf(table).view, now, random);
}

/** The card that went up by itself between two tables, as a move. */
export function autoMove(before, after) {
  const suit = after.foundations.findIndex((pile, i) => pile.length > before.foundations[i].length);
  const card = after.foundations[suit].at(-1);
  const cell = before.cells.indexOf(card);
  const from =
    cell >= 0
      ? { pile: "cell", cell }
      : (() => {
          const col = before.columns.findIndex((column) => column.at(-1) === card);
          return { pile: "column", col, index: before.columns[col].length - 1 };
        })();
  return { type: "move", move: { from, to: { pile: "foundation", suit: suitOf(card) } } };
}
