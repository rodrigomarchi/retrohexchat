/**
 * Readings of a recording canvas's log (`recording_canvas.js`): what a
 * picture drew, without knowing how.
 */

/** How many rectangles were filled in `colour`. */
export function filledWith(log, colour) {
  let fill = null;
  let n = 0;
  for (const [op, , value] of log) {
    if (op === "fillStyle") fill = value;
    if (op === "fillRect" && fill === colour) n++;
  }
  return n;
}

/** How many times the picture at `region` (its `x` on the atlas) was cut. */
export const cutsOf = (log, region) =>
  log.filter(([op, , sx]) => op === "drawImage" && sx === region.x).length;
