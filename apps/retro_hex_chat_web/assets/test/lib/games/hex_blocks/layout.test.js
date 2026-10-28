import { describe, expect, it } from "vitest";
import {
  BUTTONS,
  GEOMETRY,
  buttonAt,
  cellPlace,
  layout,
} from "../../../../js/lib/games/hex_blocks/layout.js";
import { COLS, HIDDEN, PREVIEW, ROWS } from "../../../../js/lib/games/hex_blocks/protocol.js";

const within = (r, view) =>
  r.x >= 0 && r.y >= 0 && r.x + r.w <= view.width && r.y + r.h <= view.height;
const apart = (a, b) =>
  a.x + a.w <= b.x || b.x + b.w <= a.x || a.y + a.h <= b.y || b.y + b.h <= a.y;
const centre = (r) => [r.x + r.w / 2, r.y + r.h / 2];

describe.each(["LANDSCAPE", "PORTRAIT"])("the table lying %s", (side) => {
  const laid = layout(GEOMETRY[side]);
  const { view, well } = laid;
  const buttons = BUTTONS.map((name) => laid.buttons[name]);
  const boxes = [well, laid.hold, laid.next, laid.stats];

  it("fits the well, the boxes and the buttons in the view, none over another", () => {
    for (const r of [...boxes, ...buttons]) expect(within(r, view)).toBe(true);
    const all = [...boxes, ...buttons];
    all.forEach((a, n) => {
      for (const b of all.slice(n + 1)) expect(apart(a, b)).toBe(true);
    });
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
    for (const r of buttons) expect(((r.w / 24) * 2) % 1).toBe(0);
  });

  it("leaves a slot for each piece coming, inside its box", () => {
    expect(laid.slots).toHaveLength(PREVIEW);
    for (const slot of laid.slots) {
      expect(slot.x >= laid.next.x && slot.x + slot.w <= laid.next.x + laid.next.w).toBe(true);
      expect(slot.y >= laid.next.y && slot.y + slot.h <= laid.next.y + laid.next.h).toBe(true);
    }
  });

  it("finds the button under a point, and nothing on the well or between buttons", () => {
    for (const name of BUTTONS) expect(buttonAt(laid, ...centre(laid.buttons[name]))).toBe(name);
    expect(buttonAt(laid, ...centre(well))).toBeNull();
    const { left, right } = laid.buttons;
    const between = left.y === right.y ? [(left.x + left.w + right.x) / 2, left.y + 1] : [0, 0];
    expect(buttonAt(laid, ...between)).toBeNull();
  });
});

describe("the table standing on a phone", () => {
  it("gives every button at least 44 CSS pixels on a phone 390 wide", () => {
    const laid = layout(GEOMETRY.PORTRAIT);
    const css = 390 / laid.view.width;
    for (const name of BUTTONS) expect(laid.buttons[name].w * css).toBeGreaterThanOrEqual(44);
  });

  it("puts the buttons under the well", () => {
    const laid = layout(GEOMETRY.PORTRAIT);
    for (const name of BUTTONS) {
      expect(laid.buttons[name].y).toBeGreaterThan(laid.well.y + laid.well.h);
    }
  });
});
