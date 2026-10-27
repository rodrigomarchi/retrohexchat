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
  cascadeEffects as cascade,
  dealEffects as deal,
  moveEffects,
  returnEffects,
  shakeEffects,
  sparks,
} from "../core/card_table/effects.js";
import { easeOutBack, easeOutCubic } from "../core/tween.js";
import { geometryOf, layout, sourcePlace } from "./layout.js";
import { EVENT } from "./protocol.js";

/** The deal: in rounds across the ten columns, every card flying out of the stock. */
export function dealEffects(fx, table, now) {
  const places = layout(table);
  deal(fx, places.columns, places.stock.at(-1) ?? places.stockSlot, now);
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
  const completed =
    after.foundations.length > before.foundations.length ? after.foundations.at(-1) : null;
  // Where each card on the table was, to fly a completed suit from.
  const at = new Map(was.columns.flatMap((column) => column.cards.map((c) => [c.card, c])));

  if (action.type === "deal") {
    const from = was.stock.at(-1);
    is.columns.forEach((column, col) => {
      const card = before.stock.at(-1 - col);
      const place = column.cards.find((c) => c.card === card);
      if (place) addFlight(fx, [card], from, place, now + col * 2, FX.draw, easeOutCubic);
    });
  }
  if (action.type === "move") {
    const { from, to } = action.move;
    const cards = before.columns[from.col].up.slice(from.index);
    const start = drag ? { x: drag.x, y: drag.y } : sourcePlace(was, from);
    if (!completed) {
      moveEffects(fx, {
        cards,
        from: start,
        to: is.columns[to.col].cards.at(-cards.length),
        dropped: Boolean(drag),
        now,
        turned: events & EVENT.FLIP ? is.columns[from.col].cards.at(-1) : null,
        random,
      });
    } else {
      const run = geometryOf(before).upOffset;
      cards.forEach((card, i) => at.set(card, { x: start.x, y: start.y + i * run }));
    }
  }
  if (completed) {
    // The whole suit flies down to its place, from where each of its cards lay.
    const home = is.foundations.at(-1);
    completed.forEach((card, i) => {
      addFlight(fx, [card], at.get(card) ?? home, home, now + i, FX.flight, easeOutBack);
    });
    const turned = is.columns.find(
      (column, col) => column.cards.length < was.columns[col].cards.length,
    );
    if (events & EVENT.FLIP && turned?.cards.length && !fx.reduced) {
      const top = turned.cards.at(-1);
      fx.list.push({ kind: "flip", card: top.card, at: top, start: now, ticks: FX.flip });
    }
    sparks(fx, home, now + (fx.reduced ? 0 : FX.flight + completed.length), random);
  }
  if (action.type === "return" && drag) returnEffects(fx, drag, sourcePlace(was, action.from), now);
  if (action.type === "refuse") {
    if (action.from.pile === "stock") {
      const top = was.stock.at(-1);
      if (top) shakeEffects(fx, before.stock.at(-1), top, now);
    } else {
      const place = sourcePlace(was, action.from);
      shakeEffects(fx, place.card, place, now);
    }
  }
}

/** A win: the suits leave their places, kings first, and bounce off the felt. */
export function cascadeEffects(fx, table, now, random) {
  const places = layout(table);
  // A suit lies king first: turned over, its king is on top and leaves first.
  const piles = table.foundations.map((suit, i) => ({
    place: places.foundations[i],
    cards: [...suit].reverse(),
  }));
  cascade(fx, piles, geometryOf(table).view, now, random);
}

/** Nothing moves by itself on Spider's table: a move is always the player's. */
export const autoMove = () => ({ type: "none" });
