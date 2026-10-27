/**
 * What a tap or a drag on a card table means, as an action for the match to
 * play: a `move`, a `refuse` (a tapped card with nowhere to go), a `return`
 * (a dragged card going back where it came from), or whatever the table
 * answers itself for a tap (turning the stock). A drag in progress is
 * `{ from, cards, x, y, grabX, grabY }`: the run held, and where its bottom
 * card is drawn.
 *
 * A game hands in its table: what a point lands on, what may be picked up,
 * where a tap sends it and which moves its rules allow. The rest — following
 * the press, the drop on the pile the run covers most — is the same for every
 * card game (`core/pointer.js` tells taps from drags).
 *
 * @module games/core/card_table/gestures
 */

import { overlap } from "./piles.js";

/**
 * @typedef {object} CardTableRules
 * @property {{ width: number, height: number } | ((state: object) => { width: number, height: number })} card -
 *   the size the cards are drawn at, or what it is on a table
 * @property {(state: object, x: number, y: number) => object | null} hitTest
 * @property {(state: object, hit: object | null) => object | null} pick - the `from` a hit picks up
 * @property {(state: object, hit: object | null) => object | null | undefined} [tap] - a tap the
 *   table answers itself: an action, null for nothing, undefined to treat it as a card's
 * @property {(from: object) => boolean} [tapMoves] - whether a tap may send the cards at `from`
 * @property {(state: object, from: object) => object | null} bestDestination - the move a tap makes
 * @property {(state: object, move: object) => boolean} canMove
 * @property {(state: object, from: object) => number[]} cardsFrom - bottom first
 * @property {(state: object, from: object) => { x: number, y: number }} sourcePlace
 * @property {(state: object) => Array<{ r: object, to: object }>} targets - where a run may be
 *   dropped, in the order a tie goes
 */

/**
 * The interpreter of a table's gestures.
 * @param {CardTableRules} table
 * @returns {(state: object, drag: object | null, gesture: { type: string, x?: number, y?: number }) =>
 *   { drag: object | null, action: object | null }}
 */
export function createInterpreter(table) {
  const cardOf = typeof table.card === "function" ? table.card : () => table.card;
  const tapMoves = table.tapMoves ?? (() => true);

  /** The pile a held run covers most, as a move's `to`, or null over the bare felt. */
  function dropTarget(state, drag) {
    const card = cardOf(state);
    const held = { x: drag.x, y: drag.y, w: card.width, h: card.height };
    let best = null;
    for (const target of table.targets(state)) {
      const area = overlap(held, target.r);
      if (area > 0 && (!best || area > best.area)) best = { area, to: target.to };
    }
    return best?.to ?? null;
  }

  return (state, drag, gesture) => {
    switch (gesture.type) {
      case "tap": {
        const hit = table.hitTest(state, gesture.x, gesture.y);
        const own = table.tap?.(state, hit);
        if (own !== undefined) return { drag: null, action: own };
        const from = table.pick(state, hit);
        if (!from || !tapMoves(from)) return { drag: null, action: null };
        const move = table.bestDestination(state, from);
        return { drag: null, action: move ? { type: "move", move } : { type: "refuse", from } };
      }
      case "dragStart": {
        const from = table.pick(state, table.hitTest(state, gesture.x, gesture.y));
        if (!from) return { drag: null, action: null };
        const place = table.sourcePlace(state, from);
        return {
          drag: {
            from,
            cards: table.cardsFrom(state, from),
            x: place.x,
            y: place.y,
            grabX: gesture.x - place.x,
            grabY: gesture.y - place.y,
          },
          action: null,
        };
      }
      case "dragMove":
        if (!drag) return { drag: null, action: null };
        return {
          drag: { ...drag, x: gesture.x - drag.grabX, y: gesture.y - drag.grabY },
          action: null,
        };
      case "drop": {
        if (!drag) return { drag: null, action: null };
        const held = { ...drag, x: gesture.x - drag.grabX, y: gesture.y - drag.grabY };
        const to = dropTarget(state, held);
        const move = to && { from: drag.from, to };
        if (move && table.canMove(state, move)) {
          return { drag: null, action: { type: "move", move } };
        }
        return { drag: null, action: { type: "return", from: drag.from } };
      }
      case "dragCancel":
        return { drag: null, action: drag ? { type: "return", from: drag.from } : null };
      default:
        return { drag, action: null };
    }
  };
}
