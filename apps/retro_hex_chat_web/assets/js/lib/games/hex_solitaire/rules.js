/**
 * Klondike's rules, as pure functions of the table.
 *
 * The table is `{ mode, stock, waste, fan, foundations, tableau }`. The stock
 * and the waste are arrays whose last card is the one on top; `fan` is how
 * many cards of the waste show, the last turned on top (only that one plays).
 * `foundations[suit]` climbs from the ace; each of the seven columns is
 * `{ down, up }`, its face-down cards and the face-up run on them, the last
 * card of `up` on top.
 *
 * A move is `{ from, to }`: `from` is `{ pile: "waste" }`,
 * `{ pile: "tableau", col, index }` (the run from `up[index]` to the top) or
 * `{ pile: "foundation", suit }`; `to` is `{ pile: "tableau", col }` or
 * `{ pile: "foundation", suit }`. Nothing here changes the table it is given.
 *
 * @module games/hex_solitaire/rules
 */

import { DECK, isRed, rankOf, shuffle, suitOf } from "../core/cards.js";
import { COLUMNS } from "./protocol.js";

/**
 * A new table: the deck shuffled, one to seven cards to each column with the
 * last face up, the rest in the stock.
 * @param {() => number} random - the match's generator
 * @param {number} mode - `MODE.DRAW1` or `MODE.DRAW3`
 */
export function deal(random, mode) {
  const deck = shuffle(DECK, random);
  const tableau = [];
  for (let col = 0; col < COLUMNS; col++) {
    const cards = deck.splice(0, col + 1);
    tableau.push({ down: cards.slice(0, -1), up: cards.slice(-1) });
  }
  return { mode, stock: deck, waste: [], fan: 0, foundations: [[], [], [], []], tableau };
}

/** The cards a move picks up, bottom first, or null when there is nothing to pick up. */
function picked(state, from) {
  switch (from.pile) {
    case "waste":
      return state.waste.length ? [state.waste.at(-1)] : null;
    case "foundation": {
      const pile = state.foundations[from.suit];
      return pile?.length ? [pile.at(-1)] : null;
    }
    case "tableau": {
      const column = state.tableau[from.col];
      if (!column || !(from.index >= 0 && from.index < column.up.length)) return null;
      return column.up.slice(from.index);
    }
    default:
      return null;
  }
}

/** Whether the rules allow `move` on this table. */
export function canMove(state, move) {
  const cards = picked(state, move.from);
  if (!cards) return false;
  const [bottom] = cards;

  if (move.to.pile === "foundation") {
    if (cards.length !== 1 || move.from.pile === "foundation") return false;
    if (suitOf(bottom) !== move.to.suit) return false;
    return rankOf(bottom) === state.foundations[move.to.suit].length + 1;
  }

  if (move.to.pile !== "tableau") return false;
  if (move.from.pile === "tableau" && move.from.col === move.to.col) return false;
  const column = state.tableau[move.to.col];
  if (!column) return false;
  const top = column.up.at(-1);
  if (top === undefined) return column.down.length === 0 && rankOf(bottom) === 13;
  return rankOf(bottom) === rankOf(top) - 1 && isRed(bottom) !== isRed(top);
}

/**
 * The table after `move`, and whether it turned a face-down card over; null
 * for a move the rules refuse.
 * @returns {{ state: object, flipped: boolean } | null}
 */
export function applyMove(state, move) {
  if (!canMove(state, move)) return null;
  const cards = picked(state, move.from);
  const next = copy(state);
  let flipped = false;

  if (move.from.pile === "waste") {
    next.waste.pop();
    next.fan = next.waste.length ? Math.max(1, next.fan - 1) : 0;
  } else if (move.from.pile === "foundation") {
    next.foundations[move.from.suit].pop();
  } else {
    const column = next.tableau[move.from.col];
    column.up.splice(move.from.index);
    if (column.up.length === 0 && column.down.length > 0) {
      column.up.push(column.down.pop());
      flipped = true;
    }
  }

  if (move.to.pile === "foundation") next.foundations[move.to.suit].push(...cards);
  else next.tableau[move.to.col].up.push(...cards);

  return { state: next, flipped };
}

/** The table with the stock's next one or three cards turned onto the waste; null with an empty stock. */
export function draw(state) {
  if (state.stock.length === 0) return null;
  const next = copy(state);
  const turned = next.stock.splice(-Math.min(state.mode, next.stock.length)).reverse();
  next.waste.push(...turned);
  next.fan = turned.length;
  return next;
}

/** The waste turned back into the stock, in the order it was drawn; null unless the stock is empty and the waste is not. */
export function recycle(state) {
  if (state.stock.length > 0 || state.waste.length === 0) return null;
  const next = copy(state);
  next.stock = [...next.waste].reverse();
  next.waste = [];
  next.fan = 0;
  return next;
}

/** Every card on the foundations. */
export const won = (state) => state.foundations.every((pile) => pile.length === 13);

/** Nothing left hidden: stock and waste empty, every card on the table face up. */
export const autoFinishReady = (state) =>
  state.stock.length === 0 &&
  state.waste.length === 0 &&
  state.tableau.every((column) => column.down.length === 0);

/** The move that sends the lowest card that can go up to its foundation, or null. */
export function nextAutoMove(state) {
  let best = null;
  state.tableau.forEach((column, col) => {
    const top = column.up.at(-1);
    if (top === undefined) return;
    const move = {
      from: { pile: "tableau", col, index: column.up.length - 1 },
      to: { pile: "foundation", suit: suitOf(top) },
    };
    if (canMove(state, move) && (!best || rankOf(top) < best.rank)) {
      best = { move, rank: rankOf(top) };
    }
  });
  return best?.move ?? null;
}

function copy(state) {
  return {
    ...state,
    stock: [...state.stock],
    waste: [...state.waste],
    foundations: state.foundations.map((pile) => [...pile]),
    tableau: state.tableau.map((column) => ({ down: [...column.down], up: [...column.up] })),
  };
}
