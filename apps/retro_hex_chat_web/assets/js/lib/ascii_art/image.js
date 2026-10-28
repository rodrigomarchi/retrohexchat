/**
 * A picture as text art. Each character is two pixels, one above the other:
 * `▀` drawn in the top pixel's colour on the bottom pixel's, which is how IRC
 * art draws pictures in a font whose characters are twice as tall as wide.
 * A photo's colours become the nearest of the sixteen; a Hex Paint drawing's
 * already are, and a clear pixel stays clear.
 *
 * @module ascii_art/image
 */
import { MAX_COLUMNS, MAX_LINES, cell } from "./cells.js";

const UPPER = "▀";
const LOWER = "▄";
const FULL = "█";

/** The brightness ramp for a picture drawn in characters alone, darkest last. */
export const RAMP = " .:-=+*#%@";

/** The palette index nearest a colour, by squared distance. */
export function nearest(palette, [r, g, b]) {
  let best = 0;
  let distance = Infinity;
  palette.forEach(([pr, pg, pb], i) => {
    const d = (pr - r) ** 2 + (pg - g) ** 2 + (pb - b) ** 2;
    if (d < distance) {
      distance = d;
      best = i;
    }
  });
  return best;
}

/** One character for two pixels, each a colour index or null (clear). */
export function pair(top, bottom) {
  if (top === null && bottom === null) return cell(" ");
  if (top === bottom) return cell(FULL, top);
  if (bottom === null) return cell(UPPER, top);
  if (top === null) return cell(LOWER, bottom);
  return cell(UPPER, top, bottom);
}

/**
 * Pixels as rows of characters, two pixel rows to a line.
 * @param {(x: number, y: number) => number | null} colourAt - an index, or null for clear
 */
function halves(width, height, colourAt) {
  const rows = [];
  for (let y = 0; y < height; y += 2) {
    const row = [];
    for (let x = 0; x < width; x++) {
      row.push(pair(colourAt(x, y), y + 1 < height ? colourAt(x, y + 1) : null));
    }
    rows.push(row);
  }
  return rows;
}

/** The largest step that shrinks `width`×`height` pixels into one message. */
export const stepFor = (width, height) =>
  Math.max(1, Math.ceil(width / MAX_COLUMNS), Math.ceil(height / (MAX_LINES * 2)));

/**
 * A Hex Paint drawing as text art: its own colours, shrunk by whole steps
 * until it fits one message.
 * @param {{ size: number, pixels: Uint8Array }} drawing
 * @param {number} clear - the drawing's value for a clear pixel
 */
export function fromDrawing(drawing, clear) {
  const step = stepFor(drawing.size, drawing.size);
  const size = Math.floor(drawing.size / step);
  return halves(size, size, (x, y) => {
    const p = drawing.pixels[y * step * drawing.size + x * step];
    return p === clear ? null : p;
  });
}

/**
 * A photo (RGBA bytes) as text art `columns` wide: in the nearest of the
 * sixteen colours, or in the brightness ramp's characters alone.
 * @param {{ data: Uint8ClampedArray, width: number, height: number }} image
 * @param {{ columns: number, mode: "colour" | "ramp", palette: Array<[number, number, number]> }} options
 */
export function fromImage(image, { columns, mode, palette }) {
  const across = Math.max(1, Math.min(MAX_COLUMNS, columns, image.width));
  const scale = image.width / across;
  // A character is about twice as tall as wide: the colour mode spends two
  // pixels on it, the ramp one.
  const down = Math.min(
    mode === "ramp" ? MAX_LINES : MAX_LINES * 2,
    Math.max(1, Math.round(image.height / scale / (mode === "ramp" ? 2 : 1))),
  );
  const sample = (x, y) => {
    const sx = Math.min(image.width - 1, Math.floor((x + 0.5) * scale));
    const sy = Math.min(image.height - 1, Math.floor(((y + 0.5) * image.height) / down));
    const i = (sy * image.width + sx) * 4;
    return image.data.slice(i, i + 4);
  };
  if (mode === "ramp") {
    return Array.from({ length: down }, (_, y) =>
      Array.from({ length: across }, (_, x) => {
        const [r, g, b, a] = sample(x, y);
        const light = a < 128 ? 1 : (0.299 * r + 0.587 * g + 0.114 * b) / 255;
        return cell(RAMP[Math.min(RAMP.length - 1, Math.floor((1 - light) * RAMP.length))]);
      }),
    );
  }
  return halves(across, down, (x, y) => {
    const [r, g, b, a] = sample(x, y);
    return a < 128 ? null : nearest(palette, [r, g, b]);
  });
}
