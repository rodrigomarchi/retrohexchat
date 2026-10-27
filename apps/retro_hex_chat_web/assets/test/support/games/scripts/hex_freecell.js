/**
 * A tap at a point of the table, at `at` ms: a press and its release.
 * @returns {Array<{at: number, pointer: string, x: number, y: number}>}
 */
const tapAt = (at, x, y) => [
  { at, pointer: "down", x, y },
  { at: at + 40, pointer: "up", x, y },
];

// The foot of each column as dealt (seven cards in the four on the left, six
// in the others, 18 pixels apart), and the cells along the top.
const FOOT = (col) => [29 + col * 74 + 20, 132 + (col < 4 ? 6 : 5) * 18 + 40];
const CELL = (cell) => [29 + cell * 74 + 20, 60];

/**
 * Tap every column's foot over and over, and the cells in between: cards go
 * to the cells, onto the columns and up to the foundations.
 */
export const hexFreeCellScript = () => {
  const presses = [];
  let at = 1000;
  for (let round = 0; round < 30; round++) {
    for (let col = 0; col < 8; col++) {
      presses.push(...tapAt(at, ...FOOT(col)));
      at += 250;
    }
    presses.push(...tapAt(at, ...CELL(round % 4)));
    at += 250;
  }
  return presses;
};

/** To the end: one move, and let the hour's safety clock run out (or the table run out of moves). */
export const hexFreeCellEndScript = () => tapAt(1000, ...FOOT(7));
