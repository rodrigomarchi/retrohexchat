/**
 * FreeCell's rules, as pure functions of the table.
 *
 * The table is `{ columns, cells, foundations }`: eight columns, each an
 * array of cards whose last is on top (every card face up); four cells, each
 * a card or null; `foundations[suit]` climbing from the ace.
 *
 * A move is `{ from, to }`: `from` is `{ pile: "column", col, index }` (the
 * run from `columns[col][index]` to the foot), `{ pile: "cell", cell }` or
 * `{ pile: "foundation", suit }`; `to` is `{ pile: "column", col }`,
 * `{ pile: "cell", cell }` or `{ pile: "foundation", suit }`. Nothing here
 * changes the table it is given.
 *
 * @module games/hex_freecell/rules
 */

import { DECK, isRed, rankOf, shuffle, suitOf } from "../core/cards.js";
import { CELLS, COLUMNS } from "./protocol.js";

/**
 * A new table: the deck shuffled and dealt across the eight columns, a card
 * to each in turn — seven to the four on the left, six to the others.
 * @param {() => number} random - the match's generator
 */
export function deal(random) {
  const deck = shuffle(DECK, random);
  const columns = Array.from({ length: COLUMNS }, () => []);
  deck.forEach((card, i) => columns[i % COLUMNS].push(card));
  return {
    columns,
    cells: Array.from({ length: CELLS }, () => null),
    foundations: [[], [], [], []],
  };
}

/** Whether a card may lie on another in a column: one rank lower, the other colour. */
const stacks = (card, on) => rankOf(card) === rankOf(on) - 1 && isRed(card) !== isRed(on);

/** Whether `cards` (top-down) run down in alternating colours. */
export const isRun = (cards) => cards.every((card, i) => i === 0 || stacks(card, cards[i - 1]));

const emptyColumns = (table) => table.columns.filter((column) => column.length === 0).length;
const freeCells = (table) => table.cells.filter((card) => card === null).length;

/**
 * How many cards a run may carry at once, moved through the free cells and
 * the empty columns: (free cells + 1) × 2 ^ (empty columns), the column it
 * goes to not counting when it is empty.
 * @param {object} table
 * @param {boolean} toEmpty
 */
export const capacity = (table, toEmpty) =>
  (freeCells(table) + 1) * 2 ** Math.max(0, emptyColumns(table) - (toEmpty ? 1 : 0));

/** The cards a move picks up, top-down, or null when there is nothing to pick up. */
export function picked(table, from) {
  switch (from.pile) {
    case "cell": {
      const card = table.cells[from.cell];
      return card === null || card === undefined ? null : [card];
    }
    case "foundation": {
      const pile = table.foundations[from.suit];
      return pile?.length ? [pile.at(-1)] : null;
    }
    case "column": {
      const column = table.columns[from.col];
      if (!column || !(from.index >= 0 && from.index < column.length)) return null;
      return column.slice(from.index);
    }
    default:
      return null;
  }
}

/** Whether the rules allow `move` on this table. */
export function canMove(table, { from, to }) {
  const cards = picked(table, from);
  if (!cards || !isRun(cards)) return false;
  const [card] = cards;
  switch (to.pile) {
    case "foundation": {
      const pile = table.foundations[to.suit];
      return (
        cards.length === 1 &&
        from.pile !== "foundation" &&
        suitOf(card) === to.suit &&
        rankOf(card) === (pile?.length ?? -1) + 1
      );
    }
    case "cell":
      return cards.length === 1 && from.pile !== "cell" && table.cells[to.cell] === null;
    case "column": {
      const column = table.columns[to.col];
      if (!column || (from.pile === "column" && from.col === to.col)) return false;
      if (column.length === 0) return cards.length <= capacity(table, true);
      return stacks(card, column.at(-1)) && cards.length <= capacity(table, false);
    }
    default:
      return false;
  }
}

/** The table after `move`, or null when the rules do not allow it. */
export function applyMove(table, move) {
  if (!canMove(table, move)) return null;
  const { from, to } = move;
  const cards = picked(table, from);
  const columns = table.columns.map((column, col) => {
    let next = column;
    if (from.pile === "column" && from.col === col) next = next.slice(0, from.index);
    if (to.pile === "column" && to.col === col) next = [...next, ...cards];
    return next;
  });
  const cells = table.cells.map((card, i) => {
    if (from.pile === "cell" && from.cell === i) return null;
    if (to.pile === "cell" && to.cell === i) return cards[0];
    return card;
  });
  const foundations = table.foundations.map((pile, suit) => {
    if (from.pile === "foundation" && from.suit === suit) return pile.slice(0, -1);
    if (to.pile === "foundation" && to.suit === suit) return [...pile, cards[0]];
    return pile;
  });
  return { ...table, columns, cells, foundations };
}

/** Every card that could go up now, from the cells first, then the columns' feet. */
function upMoves(table) {
  const moves = [];
  table.cells.forEach((card, cell) => {
    if (card !== null) moves.push({ card, from: { pile: "cell", cell } });
  });
  table.columns.forEach((column, col) => {
    if (column.length) {
      moves.push({ card: column.at(-1), from: { pile: "column", col, index: column.length - 1 } });
    }
  });
  return moves
    .map(({ card, from }) => ({
      card,
      move: { from, to: { pile: "foundation", suit: suitOf(card) } },
    }))
    .filter(({ move }) => canMove(table, move));
}

/** Whether a card going up can no longer be wanted on the table: no lower card of the other colour needs it. */
function safe(table, card) {
  const rank = rankOf(card);
  if (rank <= 2) return true;
  return [0, 1, 2, 3]
    .filter((suit) => isRed(suit * 13) !== isRed(card))
    .every((suit) => table.foundations[suit].length >= rank - 1);
}

/** The next card that goes up by itself after a move, as the move, or null. */
export function nextSafeMove(table) {
  return upMoves(table).find(({ card }) => safe(table, card))?.move ?? null;
}

/** Whether nothing is left in disorder: every column runs down, so the rest can go up by itself. */
export const autoFinishReady = (table) =>
  table.columns.every((column) =>
    column.every((card, i) => i === 0 || rankOf(card) < rankOf(column[i - 1])),
  );

/** While finishing, the lowest card that can go up, as the move, or null. */
export function nextAutoMove(table) {
  const moves = upMoves(table);
  if (!moves.length) return null;
  return moves.reduce((low, next) => (rankOf(next.card) < rankOf(low.card) ? next : low)).move;
}

/** Whether the 52 cards are up. */
export const won = (table) => table.foundations.every((pile) => pile.length === 13);

/** Every move the table allows, from the cards that can be picked up to every pile. */
function* moves(table) {
  const sources = [
    ...table.cells.map((card, cell) => ({ pile: "cell", cell })),
    ...table.columns.flatMap((column, col) =>
      column.map((card, index) => ({ pile: "column", col, index })),
    ),
  ];
  const targets = [
    ...table.foundations.map((pile, suit) => ({ pile: "foundation", suit })),
    ...table.cells.map((card, cell) => ({ pile: "cell", cell })),
    ...table.columns.map((column, col) => ({ pile: "column", col })),
  ];
  for (const from of sources) {
    for (const to of targets) {
      const move = { from, to };
      if (canMove(table, move)) yield move;
    }
  }
}

/** Whether any move is left. */
export const hasMove = (table) => !moves(table).next().done;
