import { describe, expect, it } from "vitest";

import { canvasPointFromEvent } from "../../../js/lib/space/canvas_point.js";

describe("canvasPointFromEvent", () => {
  it("is null for a rect with no area", () => {
    expect(
      canvasPointFromEvent(
        { clientX: 5, clientY: 5 },
        { left: 0, top: 0, width: 0, height: 10 },
        100,
        100,
      ),
    ).toBeNull();
    expect(
      canvasPointFromEvent(
        { clientX: 5, clientY: 5 },
        { left: 0, top: 0, width: 10, height: 0 },
        100,
        100,
      ),
    ).toBeNull();
  });

  it("maps client pixels to backing-store pixels 1:1 when they match", () => {
    const p = canvasPointFromEvent(
      { clientX: 30, clientY: 40 },
      { left: 0, top: 0, width: 100, height: 100 },
      100,
      100,
    );
    expect(p).toEqual({ x: 30, y: 40 });
  });

  it("scales when the backing store is larger than the displayed rect", () => {
    // rect 200x100 on screen, backing store 400x200 → 2x scale
    const p = canvasPointFromEvent(
      { clientX: 50, clientY: 25 },
      { left: 0, top: 0, width: 200, height: 100 },
      400,
      200,
    );
    expect(p).toEqual({ x: 100, y: 50 });
  });

  it("accounts for the rect offset", () => {
    const p = canvasPointFromEvent(
      { clientX: 60, clientY: 60 },
      { left: 10, top: 20, width: 100, height: 100 },
      100,
      100,
    );
    expect(p).toEqual({ x: 50, y: 40 });
  });
});
