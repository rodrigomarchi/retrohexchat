import { describe, expect, it } from "vitest";
import { GEOMETRY, cellPlace, layout } from "../../../../js/lib/games/hex_blocks/layout.js";
import { COLS, HIDDEN, PREVIEW, ROWS } from "../../../../js/lib/games/hex_blocks/protocol.js";
import { expectLaidApart } from "../../../support/games/places.js";

describe.each(["LANDSCAPE", "PORTRAIT"])("the table lying %s", (side) => {
  const laid = layout(GEOMETRY[side]);
  const { view, well } = laid;
  const boxes = [well, laid.hold, laid.next, laid.stats];

  it("fits the well and the boxes in the view, none over another", () => {
    expectLaidApart(boxes, view);
  });

  it("holds every column and every row in sight in the well", () => {
    const { w, h, step } = laid.cell;
    expect(well.w).toBe((COLS - 1) * step + w);
    expect(well.h).toBe((ROWS - HIDDEN) * h + h / 2);
    expect(cellPlace(laid, 0, HIDDEN)).toEqual({ x: well.x, y: well.y, w, h });
    expect(cellPlace(laid, 1, HIDDEN).y).toBe(well.y + h / 2);
    // The last column reaches the right side, the last odd one (half a hexagon lower) the floor.
    const right = cellPlace(laid, COLS - 1, ROWS - 1);
    expect(right.x + right.w).toBe(well.x + well.w);
    const low = cellPlace(laid, COLS - 2, ROWS - 1);
    expect(low.y + low.h).toBe(well.y + well.h);
  });

  it("draws the art on whole half pixels", () => {
    expect((laid.scale * 2) % 1).toBe(0);
    expect((laid.mini * 2) % 1).toBe(0);
  });

  it("leaves a slot for each piece coming, inside its box", () => {
    expect(laid.slots).toHaveLength(PREVIEW);
    for (const slot of laid.slots) {
      expect(slot.x >= laid.next.x && slot.x + slot.w <= laid.next.x + laid.next.w).toBe(true);
      expect(slot.y >= laid.next.y && slot.y + slot.h <= laid.next.y + laid.next.h).toBe(true);
    }
  });
});

describe("the table standing on a phone", () => {
  it("is the well and the boxes over it, the pad being the page's", () => {
    const laid = layout(GEOMETRY.PORTRAIT);
    expect(laid.well.y).toBeGreaterThan(laid.hold.y + laid.hold.h);
    expect(laid.view.height - (laid.well.y + laid.well.h)).toBeLessThanOrEqual(12);
  });
});
