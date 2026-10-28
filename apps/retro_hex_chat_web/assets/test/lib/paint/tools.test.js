import { describe, expect, it } from "vitest";
import { CLEAR, colourAt, createDrawing, paint } from "../../../js/lib/paint/document.js";
import { apply, ellipse, fill, line, rect } from "../../../js/lib/paint/tools.js";

const keys = (points) => new Set(points.map(([x, y]) => `${x},${y}`));

describe("the shapes", () => {
  it("draws a line through every pixel between its ends", () => {
    expect(line([0, 0], [3, 1])).toEqual([
      [0, 0],
      [1, 0],
      [2, 1],
      [3, 1],
    ]);
    expect(line([2, 2], [2, 2])).toEqual([[2, 2]]);
  });

  it("draws a rectangle's edge, or all of it, from either pair of corners", () => {
    expect(rect([2, 2], [0, 0])).toHaveLength(8);
    expect(rect([0, 0], [2, 2], true)).toHaveLength(9);
  });

  it("draws an ellipse's edge without gaps, inside its fill", () => {
    const edge = keys(ellipse([0, 0], [9, 5]));
    const all = keys(ellipse([0, 0], [9, 5], true));
    for (const p of edge) expect(all.has(p)).toBe(true);
    // Every edge pixel touches another, sideways or diagonally: the line is unbroken.
    for (const p of edge) {
      const [x, y] = p.split(",").map(Number);
      const touching = [-1, 0, 1].some((dx) =>
        [-1, 0, 1].some((dy) => (dx || dy) && edge.has(`${x + dx},${y + dy}`)),
      );
      expect(touching).toBe(true);
    }
    expect(edge.has("0,2") && edge.has("9,2")).toBe(true);
  });
});

describe("the tools", () => {
  it("fills the region of one colour a bucket lands on, and stops at its edge", () => {
    const walled = paint(createDrawing(32), line([5, 0], [5, 31]), 1);
    const region = fill(walled, [0, 0]);
    expect(region).toHaveLength(5 * 32);
    const filled = apply(walled, { tool: "bucket", from: [0, 0], to: [0, 0], colour: 4 });
    expect(colourAt(filled, 4, 31)).toBe(4);
    expect(colourAt(filled, 6, 0)).toBe(CLEAR);
  });

  it("erases to clear, and mirrors across the middle when asked", () => {
    const drawn = apply(createDrawing(32), {
      tool: "pencil",
      from: [1, 1],
      to: [1, 1],
      colour: 3,
      mirror: true,
    });
    expect(colourAt(drawn, 1, 1)).toBe(3);
    expect(colourAt(drawn, 30, 1)).toBe(3);
    const erased = apply(drawn, { tool: "eraser", from: [1, 1], to: [1, 1], colour: 3 });
    expect(colourAt(erased, 1, 1)).toBe(CLEAR);
  });
});
