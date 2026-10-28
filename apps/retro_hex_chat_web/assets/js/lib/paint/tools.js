/**
 * What each Hex Paint tool paints, as points: the controller asks a tool for
 * the pixels between where a press began and where the pointer is, and paints
 * them in one step. The tools know nothing of canvases or events, so each is
 * tested by the pixels it answers.
 *
 * @module paint/tools
 */
import { CLEAR, colourAt, inside, paint } from "./document.js";

/** The tools, in the order the toolbar shows them, each with its key. */
export const TOOLS = Object.freeze([
  { id: "pencil", key: "p" },
  { id: "line", key: "l" },
  { id: "rect", key: "r" },
  { id: "rect_fill", key: "shift+r" },
  { id: "ellipse", key: "e" },
  { id: "ellipse_fill", key: "shift+e" },
  { id: "bucket", key: "b" },
  { id: "eraser", key: "x" },
  { id: "picker", key: "i" },
]);

/** The pixels of a straight line from `a` to `b`, both ends included (Bresenham). */
export function line([x0, y0], [x1, y1]) {
  const points = [];
  const dx = Math.abs(x1 - x0);
  const dy = -Math.abs(y1 - y0);
  const sx = x0 < x1 ? 1 : -1;
  const sy = y0 < y1 ? 1 : -1;
  let err = dx + dy;
  let x = x0;
  let y = y0;
  for (;;) {
    points.push([x, y]);
    if (x === x1 && y === y1) return points;
    const e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y += sy;
    }
  }
}

const box = ([x0, y0], [x1, y1]) => ({
  left: Math.min(x0, x1),
  top: Math.min(y0, y1),
  right: Math.max(x0, x1),
  bottom: Math.max(y0, y1),
});

/** The pixels of the rectangle between two corners: its edge, or all of it when `filled`. */
export function rect(a, b, filled = false) {
  const { left, top, right, bottom } = box(a, b);
  const points = [];
  for (let y = top; y <= bottom; y++) {
    for (let x = left; x <= right; x++) {
      if (filled || y === top || y === bottom || x === left || x === right) points.push([x, y]);
    }
  }
  return points;
}

/**
 * The pixels of the ellipse inside the box between two corners: all of it
 * when `filled`, else its edge — the pixels of it with a side on the outside,
 * which leaves no gap however flat or thin the ellipse is.
 */
export function ellipse(a, b, filled = false) {
  const { left, top, right, bottom } = box(a, b);
  const cx = (left + right) / 2;
  const cy = (top + bottom) / 2;
  const rx = (right - left) / 2 + 0.5;
  const ry = (bottom - top) / 2 + 0.5;
  const within = (x, y) => ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1;
  const points = [];
  for (let y = top; y <= bottom; y++) {
    for (let x = left; x <= right; x++) {
      if (!within(x, y)) continue;
      const edge = !within(x - 1, y) || !within(x + 1, y) || !within(x, y - 1) || !within(x, y + 1);
      if (filled || edge) points.push([x, y]);
    }
  }
  return points;
}

/** The pixels a bucket fills from `start`: every pixel of its colour it reaches across edges. */
export function fill(drawing, [x, y]) {
  if (!inside(drawing, x, y)) return [];
  const target = colourAt(drawing, x, y);
  const seen = new Uint8Array(drawing.size * drawing.size);
  const points = [];
  const stack = [[x, y]];
  while (stack.length) {
    const [px, py] = stack.pop();
    if (!inside(drawing, px, py)) continue;
    const i = py * drawing.size + px;
    if (seen[i] || drawing.pixels[i] !== target) continue;
    seen[i] = 1;
    points.push([px, py]);
    stack.push([px + 1, py], [px - 1, py], [px, py + 1], [px, py - 1]);
  }
  return points;
}

/** The points reflected across the drawing's middle, beside the points themselves. */
export function mirrored(drawing, points) {
  return points.flatMap(([x, y]) => [
    [x, y],
    [drawing.size - 1 - x, y],
  ]);
}

/**
 * The pixels a press of `tool` paints from `from` to `to`, with what it paints
 * them. A pencil or an eraser is a run of short lines, one each time the
 * pointer moves (`from` is then where it was); a shape is the shape between
 * the press and the pointer.
 * @returns {{ points: Array<[number, number]>, colour: number }}
 */
export function stroke(drawing, { tool, from, to, colour, mirror = false }) {
  const shaped = (points) => (mirror ? mirrored(drawing, points) : points);
  switch (tool) {
    case "pencil":
      return { points: shaped(line(from, to)), colour };
    case "eraser":
      return { points: shaped(line(from, to)), colour: CLEAR };
    case "line":
      return { points: shaped(line(from, to)), colour };
    case "rect":
    case "rect_fill":
      return { points: shaped(rect(from, to, tool === "rect_fill")), colour };
    case "ellipse":
    case "ellipse_fill":
      return { points: shaped(ellipse(from, to, tool === "ellipse_fill")), colour };
    case "bucket":
      return { points: shaped(fill(drawing, to)), colour };
    default:
      return { points: [], colour };
  }
}

/** The drawing with a tool's stroke painted on it. */
export const apply = (drawing, options) => {
  const { points, colour } = stroke(drawing, options);
  return paint(drawing, points, colour);
};

/** Whether a tool draws a shape from the press to the pointer, shown while it is held. */
export const shapeTool = (tool) =>
  ["line", "rect", "rect_fill", "ellipse", "ellipse_fill"].includes(tool);
