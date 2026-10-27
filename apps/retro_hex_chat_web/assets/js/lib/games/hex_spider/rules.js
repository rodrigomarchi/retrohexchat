/**
 * Spider's rules, as pure functions of the table.
 *
 * The table is `{ columns, stock, foundations }`: ten columns, each
 * `{ down, up }` — its face-down cards and the face-up cards on them, the
 * last of `up` on top; the stock, its last card dealt first; and the suits
 * completed, each king to ace. Cards are numbered past 51 (`core/cards.js`
 * `faceOf`): two cards alike are still two cards.
 *
 * A move is `{ from: { pile: "column", col, index }, to: { pile: "column", col } }`:
 * the cards from `up[index]` to the top. Nothing here changes the table it is given.
 *
 * @module games/hex_spider/rules
 */

import { faceOf, rankOf, shuffle, spiderDeck, suitOf } from "../core/cards.js";
import { DEALT, FOUNDATIONS, SUIT_LENGTH } from "./protocol.js";

const rank = (card) => rankOf(faceOf(card));
const suit = (card) => suitOf(faceOf(card));

/**
 * A new table: the two decks of the variant shuffled, six cards to each of
 * the first four columns and five to the others, the last of each face up,
 * the fifty left in the stock.
 * @param {() => number} random - the match's generator
 * @param {1 | 2 | 4} suits
 */
export function deal(random, suits) {
  const deck = shuffle(spiderDeck(suits), random);
  const columns = DEALT.map((count) => {
    const cards = deck.splice(0, count);
    return { down: cards.slice(0, -1), up: cards.slice(-1) };
  });
  return { columns, stock: deck, foundations: [] };
}

/** Whether `cards` run down by one rank in one suit. */
const sameSuitRun = (cards) =>
  cards.every(
    (card, i) =>
      i === 0 || (rank(card) === rank(cards[i - 1]) - 1 && suit(card) === suit(cards[0])),
  );

/** Whether the cards from `from` may be picked up: a run of one suit to the top of its column. */
export function canPick(table, from) {
  const column = table.columns[from?.col];
  if (from?.pile !== "column" || !column || !(from.index >= 0 && from.index < column.up.length)) {
    return false;
  }
  return sameSuitRun(column.up.slice(from.index));
}

/** Whether the rules allow `move` on this table. */
export function canMove(table, { from, to }) {
  if (!canPick(table, from) || to?.pile !== "column" || to.col === from.col) return false;
  const target = table.columns[to.col];
  if (!target) return false;
  const top = target.up.at(-1);
  if (top === undefined) return target.down.length === 0;
  return rank(table.columns[from.col].up[from.index]) === rank(top) - 1;
}

/** A column with its top card turned over when nothing face up is left on it. */
function turned(column) {
  if (column.up.length || !column.down.length) return { column, flipped: false };
  return { column: { down: column.down.slice(0, -1), up: column.down.slice(-1) }, flipped: true };
}

/**
 * The columns after every whole suit lying king to ace at a column's top has
 * gone up, and the card each uncovered turned over.
 */
function complete(table) {
  let completed = false;
  let flipped = false;
  const foundations = [...table.foundations];
  const columns = table.columns.map((column) => {
    const tail = column.up.slice(-SUIT_LENGTH);
    if (tail.length < SUIT_LENGTH || rank(tail[0]) !== SUIT_LENGTH || !sameSuitRun(tail))
      {return column;}
    completed = true;
    foundations.push(tail);
    const after = turned({ down: column.down, up: column.up.slice(0, -SUIT_LENGTH) });
    flipped ||= after.flipped;
    return after.column;
  });
  return { state: { ...table, columns, foundations }, completed, flipped };
}

/**
 * The table after `move`, the uncovered card turned and any whole suit gone
 * up; null when the rules do not allow it.
 * @returns {{ state: object, flipped: boolean, completed: boolean } | null}
 */
export function applyMove(table, move) {
  if (!canMove(table, move)) return null;
  const { from, to } = move;
  const cards = table.columns[from.col].up.slice(from.index);
  let flipped = false;
  const columns = table.columns.map((column, col) => {
    if (col === from.col) {
      const after = turned({ down: column.down, up: column.up.slice(0, from.index) });
      flipped = after.flipped;
      return after.column;
    }
    if (col === to.col) return { down: column.down, up: [...column.up, ...cards] };
    return column;
  });
  const done = complete({ ...table, columns });
  return { state: done.state, flipped: flipped || done.flipped, completed: done.completed };
}

/**
 * The table after the stock deals a card face up to every column, any whole
 * suit it finished gone up; null while a column is empty or the stock is.
 * @returns {{ state: object, flipped: boolean, completed: boolean } | null}
 */
export function dealRow(table) {
  const empty = table.columns.some((column) => column.up.length === 0 && column.down.length === 0);
  if (empty || table.stock.length < table.columns.length) return null;
  const stock = [...table.stock];
  const columns = table.columns.map((column) => ({
    down: column.down,
    up: [...column.up, stock.pop()],
  }));
  return complete({ ...table, columns, stock });
}

/** Whether the eight suits are up. */
export const won = (table) => table.foundations.length === FOUNDATIONS;

/** Whether anything is left to do: the stock to deal, or a move. */
export function hasMove(table) {
  if (table.stock.length) return true;
  return table.columns.some((column, col) =>
    column.up.some((card, index) =>
      table.columns.some((other, target) =>
        canMove(table, {
          from: { pile: "column", col, index },
          to: { pile: "column", col: target },
        }),
      ),
    ),
  );
}
