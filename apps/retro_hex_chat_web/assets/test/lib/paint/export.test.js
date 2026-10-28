import { describe, expect, it } from "vitest";
import { createDrawing, paint } from "../../../js/lib/paint/document.js";
import { parseRgb, postedScale, rgba } from "../../../js/lib/paint/export.js";

describe("a drawing as a picture", () => {
  it("is each pixel's colour, clear left transparent", () => {
    const drawing = paint(createDrawing(32), [[1, 0]], 1);
    const bytes = rgba(drawing, [
      [255, 255, 255],
      [10, 20, 30],
    ]);
    expect([...bytes.slice(0, 8)]).toEqual([0, 0, 0, 0, 10, 20, 30, 255]);
  });

  it("is posted at a whole scale big enough to see", () => {
    expect(postedScale(createDrawing(32))).toBe(8);
    expect(postedScale(createDrawing(128))).toBe(2);
  });

  it("reads the colours CSS answers", () => {
    expect(parseRgb("rgb(0, 0, 127)")).toEqual([0, 0, 127]);
    expect(parseRgb("rgba(255 0 0 / 1)")).toEqual([255, 0, 0]);
    expect(parseRgb("red")).toBeNull();
  });
});
