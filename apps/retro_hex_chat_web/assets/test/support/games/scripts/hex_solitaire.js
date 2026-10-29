import { tapAt } from "./keys.js";

// The stock's middle, and each column's first card (the deal's top card in
// the first column, a face-down card's strip in the others, where a tap does
// nothing until it has turned).
const STOCK = [80, 72];
const COLUMN = (col) => [48 + col * 80 + 20, 132 + col * 6 + 12];

/**
 * Turn the stock over and over, tapping each column's top on the way: cards
 * go up, onto the table, and the stock comes back round.
 */
export const hexSolitaireScript = () => {
  const presses = [];
  let at = 1000;
  for (let round = 0; round < 40; round++) {
    presses.push(...tapAt(at, ...STOCK));
    at += 300;
    presses.push(...tapAt(at, 48 + 80 + 20, 72));
    at += 300;
    for (let col = 0; col < 7; col++) {
      presses.push(...tapAt(at, ...COLUMN(col)));
      at += 200;
    }
  }
  return presses;
};

/** To the end: turn the stock once, and let the hour's safety clock run out. */
export const hexSolitaireEndScript = () => tapAt(1000, ...STOCK);
