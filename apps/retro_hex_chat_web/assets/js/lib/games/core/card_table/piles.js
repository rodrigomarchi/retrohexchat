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
