/**
 * What each change on the Spider table draws, from the card table's effects
 * (`core/card_table/effects.js`): the deal out of the stock, a row dealt, a
 * move's flight, a card turning over, a whole suit flying to its place with
 * sparks, and the cascade off the suits.
 *
 * @module games/hex_spider/effects
 */

import {
  FX,
  addFlight,
  cascadeFrom,
  dealEffects as deal,
  playedEffects,
  sparks,
} from "../core/card_table/effects.js";
import { easeOutBack, easeOutCubic } from "../core/tween.js";
import { geometryOf, layout, sourcePlace } from "./layout.js";

/** The deal: in rounds across the ten columns, every card flying out of the stock. */
export function dealEffects(fx, table, now) {
  const places = layout(table);
  deal(fx, places.columns, places.stock.at(-1) ?? places.stockSlot, now);
}

/** The table's places, as the card table's effects read them; the stock is refused as a whole. */
const PLACES = Object.freeze({
  layout,
  cardsFrom: (table, from) =>
    from.pile === "stock" ? [table.stock.at(-1)] : table.columns[from.col].up.slice(from.index),
  sourcePlace: (places, from) =>
    from.pile === "stock" ? places.stock.at(-1) : sourcePlace(places, from),
  landing: (places, to, count) => places.columns[to.col].cards.at(-count),
  turned: (places, from) => places.columns[from.col].cards.at(-1),
});

/** A row dealt: one card from the stock to each column, one after another. */
function rowEffects(fx, { before, now }, was, is) {
  is.columns.forEach((column, col) => {
    const card = before.stock.at(-1 - col);
    const place = column.cards.find((c) => c.card === card);
    if (place) addFlight(fx, [card], was.stock.at(-1), place, now + col * 2, FX.draw, easeOutCubic);
  });
}

/**
 * Whole suits put away: each of their cards flies down to its suit's place
 * from where it lay (or where the run that finished it was let go), and
 * sparks go off as the last lands; a card left on top face up turns over.
 */
function suitEffects(fx, { before, action, now, drag, random }, was, is, suits) {
  const at = new Map(was.columns.flatMap((column) => column.cards.map((c) => [c.card, c])));
  if (action.type === "move") {
    const { from } = action.move;
    const start = drag ? { x: drag.x, y: drag.y } : sourcePlace(was, from);
    const run = geometryOf(before).upOffset;
    before.columns[from.col].up
      .slice(from.index)
      .forEach((card, i) => at.set(card, { x: start.x, y: start.y + i * run }));
  }
  suits.forEach((suit, s) => {
    const home = is.foundations[before.foundations.length + s];
    suit.forEach((card, i) => {
      addFlight(fx, [card], at.get(card) ?? home, home, now + i, FX.flight, easeOutBack);
    });
    sparks(fx, home, now + (fx.reduced ? 0 : FX.flight + suit.length), random);
  });
  if (fx.reduced) return;
  for (const column of is.columns) {
    const top = column.cards.at(-1);
    if (top?.faceUp && at.get(top.card)?.faceUp === false) {
      fx.list.push({ kind: "flip", card: top.card, at: top, start: now, ticks: FX.flip });
    }
  }
}

/**
 * The effects of one action from the table (`gestures.js`), from the table
 * before it to the table after, and the events it raised.
 */
export function actionEffects(fx, played) {
  const { before, after, action } = played;
  const suits = after.foundations.slice(before.foundations.length);
  if (suits.length) {
    const was = layout(before);
    const is = layout(after);
    if (action.type === "deal") rowEffects(fx, played, was, is);
    suitEffects(fx, played, was, is, suits);
    return;
  }
  const { was, is } = playedEffects(fx, played, PLACES);
  if (action.type === "deal") rowEffects(fx, played, was, is);
}

/** A win: the suits leave their places, kings first, and bounce off the felt. */
export function cascadeEffects(fx, table, now, random) {
  // A suit lies king first: turned over, its king is on top and leaves first.
  const piles = table.foundations.map((suit) => [...suit].reverse());
  cascadeFrom(fx, layout(table).foundations, piles, geometryOf(table).view, now, random);
}

/** Nothing moves by itself on Spider's table: a move is always the player's. */
export const autoMove = () => ({ type: "none" });
