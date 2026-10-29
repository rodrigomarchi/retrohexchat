import { tapAt } from "./keys.js";

// The stock's next deal, at the bottom right of the table lying down, and
// each column's foot as dealt (six cards in the four on the left, five in
// the others, the face-down ones six pixels apart).
const STOCK = [13 + 9 * 70 + 20, 540 - 8 - 88 + 20];
const FOOT = (col) => [13 + col * 70 + 20, 30 + (col < 4 ? 5 : 4) * 6 + 40];

/**
 * Tap every column's foot, then deal a row, over and over: runs move, rows
 * come down, and the stock runs out.
 */
export const hexSpiderScript = () => {
  const presses = [];
  let at = 1000;
  for (let round = 0; round < 8; round++) {
    for (let col = 0; col < 10; col++) {
      presses.push(...tapAt(at, ...FOOT(col)));
      at += 250;
    }
    presses.push(...tapAt(at, ...STOCK));
    at += 400;
  }
  return presses;
};

/** To the end: one deal, and let the hour's safety clock run out. */
export const hexSpiderEndScript = () => tapAt(1000, ...STOCK);
