/**
 * What a tap or a drag on the table means, as an action for the match to
 * play: turn the stock (`draw`), turn the waste back (`recycle`), a `move`
 * (`rules.js`), a `refuse` (a tapped card with nowhere to go) or a `return`
 * (a dragged card going back where it came from). A drag in progress is
 * `{ from, cards, x, y, grabX, grabY }`: the run held, and where its bottom
 * card is drawn. Pure functions of the table, the drag and the gesture
 * (`core/pointer.js`).
 *
 * @module games/hex_solitaire/gestures
 */

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
  const toFoundation = {
    from,
    to: { pile: "foundation", suit: Math.floor(cardsFrom(state, from)[0] / 13) },
  };
  if (canMove(state, toFoundation)) return toFoundation;
  for (let col = 0; col < COLUMNS; col++) {
    const move = { from, to: { pile: "tableau", col } };
    if (canMove(state, move)) return move;
  }
  return null;
}

const overlap = (a, b) =>
  Math.max(0, Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x)) *
  Math.max(0, Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y));

/** The pile a held run covers most, as a move's `to`, or null over the bare felt. */
function dropTarget(state, drag) {
  const held = { x: drag.x, y: drag.y, w: CARD.width, h: CARD.height };
  const places = layout(state);
  const targets = [
    ...places.foundations.map((r, suit) => ({ r, to: { pile: "foundation", suit } })),
    ...places.columns.map((column, col) => ({
      r: column.cards.at(-1) ?? column.slot,
      to: { pile: "tableau", col },
    })),
  ];
  let best = null;
  for (const target of targets) {
    const area = overlap(held, target.r);
    if (area > 0 && (!best || area > best.area)) best = { area, to: target.to };
  }
  return best?.to ?? null;
}

/**
 * The drag that follows a gesture, and the action it makes.
 * @param {object} state - the table
 * @param {object | null} drag - the drag in progress
 * @param {{ type: string, x?: number, y?: number }} gesture
 * @returns {{ drag: object | null, action: object | null }}
 */
export function interpret(state, drag, gesture) {
  switch (gesture.type) {
    case "tap": {
      const hit = hitTest(state, gesture.x, gesture.y);
      if (hit?.pile === "stock") {
        if (state.stock.length) return { drag: null, action: { type: "draw" } };
        return { drag: null, action: state.waste.length ? { type: "recycle" } : null };
      }
      const from = pickable(state, hit);
      if (!from) return { drag: null, action: null };
      const move = bestDestination(state, from);
      return { drag: null, action: move ? { type: "move", move } : { type: "refuse", from } };
    }
    case "dragStart": {
      const from = pickable(state, hitTest(state, gesture.x, gesture.y));
      if (!from) return { drag: null, action: null };
      const place = sourcePlace(layout(state), from);
      return {
        drag: {
          from,
          cards: cardsFrom(state, from),
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
      if (move && canMove(state, move)) return { drag: null, action: { type: "move", move } };
      return { drag: null, action: { type: "return", from: drag.from } };
    }
    case "dragCancel":
      return { drag: null, action: drag ? { type: "return", from: drag.from } : null };
    default:
      return { drag, action: null };
  }
}
