/**
 * A tap at a point of the board, at `at` ms: a press and its release; a
 * right click when `button` is 2.
 * @returns {Array<{at: number, pointer: string, x: number, y: number}>}
 */
const tapAt = (at, x, y, button) => [
  { at, pointer: "down", x, y, ...(button ? { button } : {}) },
  { at: at + 40, pointer: "up", x, y, ...(button ? { button } : {}) },
];

// The beginner board lying down: 9 squares of 40 pixels from (140, 82).
const SQUARE = (col, row) => [140 + col * 40 + 20, 82 + row * 40 + 20];

/**
 * Open the middle, then sweep the board: flag the corners with a right click
 * and open every other square, until the match ends one way or the other.
 */
export const hexMinesScript = () => {
  const presses = [...tapAt(1000, ...SQUARE(4, 4))];
  let at = 1400;
  for (const [col, row] of [
    [0, 0],
    [8, 0],
    [0, 8],
    [8, 8],
  ]) {
    presses.push(...tapAt(at, ...SQUARE(col, row), 2));
    at += 200;
  }
  for (let row = 0; row < 9; row++) {
    for (let col = 0; col < 9; col++) {
      if ((col + row) % 2 === 0) continue;
      presses.push(...tapAt(at, ...SQUARE(col, row)));
      at += 150;
    }
  }
  return presses;
};

/** To the end: one square opened, and the hour's safety clock. */
export const hexMinesEndScript = () => tapAt(1000, ...SQUARE(4, 4));
