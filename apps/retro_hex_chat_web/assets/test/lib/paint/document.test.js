import { describe, expect, it } from "vitest";
import {
  CLEAR,
  blank,
  colourAt,
  createDrawing,
  decode,
  encode,
  paint,
} from "../../../js/lib/paint/document.js";

describe("a drawing", () => {
  it("starts clear, in one of its sizes", () => {
    const drawing = createDrawing(32);
    expect(drawing.pixels).toHaveLength(32 * 32);
    expect(blank(drawing)).toBe(true);
    expect(() => createDrawing(33)).toThrow(RangeError);
  });

  it("is painted into a new drawing, and the same one when nothing changes", () => {
    const drawing = createDrawing(32);
    const painted = paint(
      drawing,
      [
        [1, 2],
        [40, 0],
      ],
      4,
    );
    expect(colourAt(painted, 1, 2)).toBe(4);
    expect(colourAt(drawing, 1, 2)).toBe(CLEAR);
    expect(paint(painted, [[1, 2]], 4)).toBe(painted);
    expect(colourAt(painted, 40, 0)).toBe(CLEAR);
  });

  it("is kept as text and read back, and text that is not one reads as nothing", () => {
    const drawing = paint(
      createDrawing(32),
      [
        [0, 0],
        [31, 31],
      ],
      15,
    );
    expect(decode(encode(drawing))).toEqual(drawing);
    expect(decode("32:zz")).toBeNull();
    expect(decode(null)).toBeNull();
  });
});
