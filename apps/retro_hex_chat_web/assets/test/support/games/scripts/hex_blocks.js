/** A key held from `at` ms for `ms`. */
const hold = (at, key, ms = 40) => [
  { at, key, down: true },
  { at: at + ms, key, down: false },
];

/** How long to hold a move for `steps` columns: one at the press, the next after the delay, then every two ticks. */
const heldFor = (steps) => (steps <= 1 ? 40 : 170 + (steps - 2) * 34);

/**
 * Once the count is over, piece after piece spread across the well: turned
 * now and then, walked to a column of its own (held long enough to repeat),
 * let fall a little held down, then dropped; one in seven put aside first.
 */
export const hexBlocksScript = () => {
  const presses = [];
  const spots = [-5, 4, -3, 2, -1, 5, -4, 3, -2, 1, 0];
  let at = 3200;
  for (let n = 0; n < 40; n++) {
    if (n % 7 === 6) presses.push(...hold(at, "c"));
    if (n % 3 === 1) presses.push(...hold(at + 60, n % 2 ? "ArrowUp" : "z"));
    const spot = spots[n % spots.length];
    if (spot !== 0) {
      presses.push(
        ...hold(at + 120, spot < 0 ? "ArrowLeft" : "ArrowRight", heldFor(Math.abs(spot))),
      );
    }
    presses.push(...hold(at + 520, "ArrowDown", 100));
    presses.push(...hold(at + 680, " "));
    at += 820;
  }
  return presses;
};

/** To the end: nothing pressed, the pieces piling up in the middle until they top out. */
export const hexBlocksEndScript = () => [];
