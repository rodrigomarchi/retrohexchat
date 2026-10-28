/**
 * The honeycomb's coordinates. The well is drawn in flat-topped hexagons,
 * each odd column half a hexagon lower ("odd-q"): a square of the well is
 * `[column, row]`, and its row is the zigzag line across the well. A piece's
 * shape is kept in axial coordinates `[q, r]`, where a turn is a rotation of
 * the vector and a step a sum, so a piece never bends out of shape.
 *
 * @module games/hex_blocks/hex
 */

/** The six steps to a neighbour, in axial coordinates, round the hexagon. */
export const NEIGHBOURS = Object.freeze([
  [1, 0],
  [1, -1],
  [0, -1],
  [-1, 0],
  [-1, 1],
  [0, 1],
]);

/** A square of the well `[column, row]` as its axial hexagon. */
export const toAxial = ([c, r]) => [c, r - ((c - (c & 1)) >> 1)];

/** An axial hexagon as the square of the well it is. */
export const toOffset = ([q, r]) => [q, r + ((q - (q & 1)) >> 1)];

/** Two axial vectors summed. */
export const add = ([q, r], [dq, dr]) => [q + dq, r + dr];

/**
 * An axial vector turned a sixth of the way round, `times` times: clockwise
 * for a positive number, the other way for a negative one.
 */
export function turn(cell, times) {
  let [q, r] = cell;
  const steps = ((times % 6) + 6) % 6;
  for (let i = 0; i < steps; i++) [q, r] = [-r, q + r];
  // `+ 0` makes a -0 a 0, so a turned vector compares equal to its own.
  return [q + 0, r + 0];
}

/** The axial step from column `c` to the next column `dir` (-1 or 1) on the same zigzag row. */
export const sideStep = (c, dir) => {
  const [q, r] = toAxial([c, 0]);
  const [q2, r2] = toAxial([c + dir, 0]);
  return [q2 - q, r2 - r];
};
