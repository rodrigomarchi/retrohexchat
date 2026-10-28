/**
 * A drawing as a picture: painted onto a canvas pixel for pixel, or grown to
 * a whole-number scale for a PNG that the chat shows at a size somebody can
 * see. Pixel art is only ever scaled by whole numbers, so every pixel stays a
 * square.
 *
 * @module paint/export
 */
import { CLEAR } from "./document.js";

/** The size the chat gets a drawing at: the smallest whole scale of at least this many pixels. */
export const POSTED_SIZE = 256;

/** The whole-number scale a drawing is posted at. */
export const postedScale = (drawing) => Math.max(1, Math.ceil(POSTED_SIZE / drawing.size));

/**
 * The drawing's pixels as RGBA bytes, at one pixel each.
 * @param {{ size: number, pixels: Uint8Array }} drawing
 * @param {Array<[number, number, number]>} palette - each colour's red, green and blue
 */
export function rgba(drawing, palette) {
  const bytes = new Uint8ClampedArray(drawing.pixels.length * 4);
  drawing.pixels.forEach((p, i) => {
    if (p === CLEAR || !palette[p]) return;
    const [r, g, b] = palette[p];
    bytes.set([r, g, b, 255], i * 4);
  });
  return bytes;
}

/**
 * Paints the drawing onto `canvas` at `scale`, without smoothing.
 * @param {HTMLCanvasElement} canvas
 * @param {(width: number, height: number) => HTMLCanvasElement} createCanvas
 */
export function drawOnto(canvas, drawing, palette, scale, createCanvas) {
  const one = createCanvas(drawing.size, drawing.size);
  const oneCtx = one.getContext("2d");
  if (!oneCtx) return false;
  oneCtx.putImageData(new ImageData(rgba(drawing, palette), drawing.size, drawing.size), 0, 0);
  canvas.width = drawing.size * scale;
  canvas.height = drawing.size * scale;
  const ctx = canvas.getContext("2d");
  if (!ctx) return false;
  ctx.imageSmoothingEnabled = false;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(one, 0, 0, canvas.width, canvas.height);
  return true;
}

/**
 * The drawing as a PNG at `scale`, or null where the page cannot make one.
 * @returns {Promise<Blob | null>}
 */
export function toPng(drawing, palette, scale, createCanvas) {
  const canvas = createCanvas(1, 1);
  if (!drawOnto(canvas, drawing, palette, scale, createCanvas)) return Promise.resolve(null);
  return new Promise((resolve) => canvas.toBlob((blob) => resolve(blob ?? null), "image/png"));
}

/** Reads a CSS colour (`rgb(…)`/`rgba(…)`) as red, green and blue, or null. */
export function parseRgb(css) {
  const match = /rgba?\(\s*(\d+)[\s,]+(\d+)[\s,]+(\d+)/.exec(String(css ?? ""));
  return match ? [Number(match[1]), Number(match[2]), Number(match[3])] : null;
}
