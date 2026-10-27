/**
 * A key press and its release, at `at` ms.
 * @returns {Array<{at: number, key: string, down: boolean}>}
 */
const press = (at, key) => [
  { at, key, down: true },
  { at: at + 40, key, down: false },
];

/**
 * Once the grid is made, walk the grid from the centre with the arrows,
 * trying every digit on each square in turn, a note and an erase between,
 * a hint and an undo now and then.
 */
export const hexSudokuScript = () => {
  const presses = [];
  let at = 1500;
  const key = (name) => {
    presses.push(...press(at, name));
    at += 120;
  };
  for (let n = 0; n < 12; n++) {
    key(n % 2 ? "ArrowRight" : "ArrowDown");
    for (let d = 1; d <= 9; d++) key(String(d));
    key("n");
    key(String((n % 9) + 1));
    key("N");
    if (n % 4 === 3) key("h");
    if (n % 5 === 4) key("z");
    if (n % 3 === 2) key("Backspace");
  }
  return presses;
};

/** To the end: one square chosen, and the three hours' safety clock. */
export const hexSudokuEndScript = () => press(1500, "ArrowUp");
