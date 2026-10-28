/**
 * A Hex Paint drawing: a square grid of pixels, each one of the sixteen mIRC
 * colours (0–15) or nothing at all (`CLEAR`). A drawing is a value: every
 * change makes a new one, so the history keeps each step without copying by
 * hand and a tool can never paint over the picture somebody is undoing to.
 *
 * @module paint/document
 */

/** The sizes a drawing is made in, in pixels a side. */
export const SIZES = Object.freeze([32, 64, 128]);

/** A pixel with no colour: the background shows through, and a PNG is transparent there. */
export const CLEAR = 255;

/** The colours a pixel may hold. */
export const COLOURS = 16;

/**
 * @typedef {{ size: number, pixels: Uint8Array }} Drawing
 */

/** A blank drawing of `size` pixels a side. */
export function createDrawing(size = SIZES[0]) {
  if (!SIZES.includes(size)) throw new RangeError(`no drawing of ${size} pixels`);
  return { size, pixels: new Uint8Array(size * size).fill(CLEAR) };
}

/** Whether `x`, `y` is a pixel of the drawing. */
export const inside = (drawing, x, y) =>
  Number.isInteger(x) &&
  Number.isInteger(y) &&
  x >= 0 &&
  y >= 0 &&
  x < drawing.size &&
  y < drawing.size;

/** The colour at `x`, `y`, or `CLEAR` off the drawing. */
export const colourAt = (drawing, x, y) =>
  inside(drawing, x, y) ? drawing.pixels[y * drawing.size + x] : CLEAR;

/**
 * The drawing with `points` painted `colour`: one new drawing for a whole
 * stroke, the same drawing when nothing changed (so a click on a pixel that is
 * already that colour leaves no step in the history).
 * @param {Drawing} drawing
 * @param {Iterable<[number, number]>} points
 * @param {number} colour
 * @returns {Drawing}
 */
export function paint(drawing, points, colour) {
  let pixels = null;
  for (const [x, y] of points) {
    if (!inside(drawing, x, y)) continue;
    const i = y * drawing.size + x;
    if ((pixels ?? drawing.pixels)[i] === colour) continue;
    pixels ??= drawing.pixels.slice();
    pixels[i] = colour;
  }
  return pixels ? { size: drawing.size, pixels } : drawing;
}

/** Whether a drawing has nothing on it. */
export const blank = (drawing) => drawing.pixels.every((p) => p === CLEAR);

/** The drawing as text, for keeping a draft: its size, then a character per pixel. */
export function encode(drawing) {
  let text = "";
  for (const p of drawing.pixels) text += p === CLEAR ? "." : p.toString(16);
  return `${drawing.size}:${text}`;
}

/** A drawing kept with `encode`, or null when the text is not one. */
export function decode(text) {
  const match = /^(\d+):([0-9a-f.]+)$/.exec(String(text ?? ""));
  if (!match) return null;
  const size = Number(match[1]);
  if (!SIZES.includes(size) || match[2].length !== size * size) return null;
  const pixels = Uint8Array.from(match[2], (c) => (c === "." ? CLEAR : parseInt(c, 16)));
  return { size, pixels };
}
