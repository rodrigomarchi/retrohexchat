/**
 * The geometry every card table shares: a card's place, whether a point lands
 * on it, how much two places cover each other, and how far apart a column's
 * cards stand when it grows longer than the felt below it.
 *
 * @module games/core/card_table/piles
 */

/** A card's place at `x`, `y`, the size of `card` (`{ width, height }`). */
export const cardPlace = (x, y, card) => ({ x, y, w: card.width, h: card.height });

/** Whether `x`, `y` lands on the place `r`. */
export const contains = (r, x, y) => x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h;

/** How many pixels two places cover of each other. */
export const overlap = (a, b) =>
  Math.max(0, Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x)) *
  Math.max(0, Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y));

/**
 * How far apart a column's cards stand — `down` face down, then `up` face
 * up — squeezed, the face-up ones first, so the last card ends within `room`
 * pixels below the first; never closer than `min`.
 * @param {{ room: number, down: number, up: number, downOffset: number, upOffset: number,
 *   min: number }} column
 * @returns {{ downOffset: number, upOffset: number }}
 */
export function fanOffsets({ room, down, up, downOffset, upOffset, min }) {
  const upGaps = Math.max(0, up - 1);
  const downGaps = up > 0 ? down : Math.max(0, down - 1);
  if (downGaps * downOffset + upGaps * upOffset > room && upGaps > 0) {
    upOffset = Math.max(min, Math.floor((room - downGaps * downOffset) / upGaps));
  }
  if (downGaps * downOffset + upGaps * upOffset > room && downGaps > 0) {
    downOffset = Math.max(min, Math.floor((room - upGaps * upOffset) / downGaps));
  }
  return { downOffset, upOffset };
}

/**
 * A column's cards laid from `slot` down: `down` face down, then `up` face up,
 * each face-up one with its index in the run.
 * @returns {Array<{ card: number, faceUp: boolean, index: number | null, x: number, y: number,
 *   w: number, h: number }>}
 */
export function columnCards(slot, down, up, { downOffset, upOffset }, card) {
  const cards = [];
  let y = slot.y;
  down.forEach((id) => {
    cards.push({ card: id, faceUp: false, index: null, ...cardPlace(slot.x, y, card) });
    y += downOffset;
  });
  up.forEach((id, index) => {
    cards.push({ card: id, faceUp: true, index, ...cardPlace(slot.x, y, card) });
    y += upOffset;
  });
  return cards;
}

/** The left edge of column `col` on a table laid out by `geo` (`left`, `gap`, `card`). */
export const columnX = (geo, col) => geo.left + col * (geo.card.width + geo.gap);

/**
 * A table's columns laid out by its geometry: each at `columnX` below
 * `columnsTop`, its cards fanned (`downOffset`, `upOffset`) and squeezed into
 * `room` (`fanOffsets`, never closer than `minOffset`).
 * @param {Array<{ down: number[], up: number[] }>} columns
 * @param {{ left: number, gap: number, columnsTop: number, downOffset: number, upOffset: number,
 *   minOffset: number, card: { width: number, height: number } }} geo
 * @param {number} room
 * @returns {Array<{ slot: object, cards: object[] }>}
 */
export function layColumns(columns, geo, room) {
  return columns.map(({ down, up }, col) => {
    const slot = cardPlace(columnX(geo, col), geo.columnsTop, geo.card);
    const spacing = fanOffsets({
      room,
      down: down.length,
      up: up.length,
      downOffset: geo.downOffset,
      upOffset: geo.upOffset,
      min: geo.minOffset,
    });
    return { slot, cards: columnCards(slot, down, up, spacing, geo.card) };
  });
}

/**
 * What a point lands on among laid columns: a face-up card
 * `{ pile, col, index }` (`pile` as the game names its columns), a face-down
 * one `{ pile: "hidden", col }`, an empty column's place `{ pile: "slot", col }`,
 * or null.
 */
export function hitColumns(columns, x, y, pile) {
  for (const [col, column] of columns.entries()) {
    for (let i = column.cards.length - 1; i >= 0; i--) {
      const card = column.cards[i];
      if (!contains(card, x, y)) continue;
      return card.faceUp ? { pile, col, index: card.index } : { pile: "hidden", col };
    }
    if (column.cards.length === 0 && contains(column.slot, x, y)) return { pile: "slot", col };
  }
  return null;
}
