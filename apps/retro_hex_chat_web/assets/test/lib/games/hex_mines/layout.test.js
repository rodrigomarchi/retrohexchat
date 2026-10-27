import { describe, expect, it } from "vitest";
import {
  boardPlace,
  cellAt,
  geometryFor,
  layout,
} from "../../../../js/lib/games/hex_mines/layout.js";
import { CEILING, LEVEL } from "../../../../js/lib/games/hex_mines/protocol.js";
import { winPoints } from "../../../../js/lib/games/hex_mines/scoring.js";

describe("a win's points", () => {
  it("are more the faster it was, a second at least, and nothing for a loss", () => {
    expect(winPoints(60)).toBe(10_000);
    expect(winPoints(30)).toBe(10_000);
    expect(winPoints(600)).toBe(1_000);
    expect(winPoints(6_000)).toBe(100);
    expect(winPoints(601)).toBe(998);
    expect(CEILING).toBe(10_000);
  });
});

const within = (r, view) =>
  r.x >= 0 && r.y >= 0 && r.x + r.w <= view.width && r.y + r.h <= view.height;

describe.each(Object.entries(LEVEL))("the %s board", (id, level) => {
  describe.each(["LANDSCAPE", "PORTRAIT"])("lying %s", (side) => {
    const geometry = geometryFor(id)[side];
    const laid = layout(level, geometry);

    it("fits whole in the view, below the bar, on a half pixel", () => {
      expect(within(laid.board, geometry.view)).toBe(true);
      expect(laid.board.y).toBeGreaterThanOrEqual(laid.bar.h);
      expect((laid.scale * 2) % 1).toBe(0);
      expect(laid.scale).toBeGreaterThanOrEqual(1.5);
      for (const r of [laid.counter, laid.face, laid.clock])
        {expect(within(r, geometry.view)).toBe(true);}
    });

    it("finds the square under a point, at the corners and nowhere off the board", () => {
      const last = level.cols * level.rows - 1;
      const first = boardPlace(laid, 0);
      const end = boardPlace(laid, last);
      expect(cellAt(laid, first.x + 1, first.y + 1)).toBe(0);
      expect(cellAt(laid, end.x + end.w - 1, end.y + end.h - 1)).toBe(last);
      expect(cellAt(laid, laid.board.x - 1, laid.board.y + 1)).toBeNull();
      expect(cellAt(laid, laid.board.x + 1, laid.board.y + laid.board.h)).toBeNull();
    });
  });
});

describe("the expert board on a phone", () => {
  it("turns, sixteen squares across, and keeps the squares big enough to press", () => {
    const laid = layout(LEVEL.hex_mines_expert, geometryFor("hex_mines_expert").PORTRAIT);
    expect(laid.turned).toBe(true);
    expect(laid.board.w / laid.cell).toBe(16);
    expect(laid.cell).toBeGreaterThanOrEqual(24);
    // Square (x 29, y 0) of the board is drawn at the bottom left once turned.
    const corner = boardPlace(laid, 29);
    expect(corner.x).toBe(laid.board.x);
    expect(corner.y + corner.h).toBe(laid.board.y + laid.board.h);
  });

  it("puts the dig/flag switch on the bar standing up only", () => {
    expect(layout(LEVEL.hex_mines, geometryFor("hex_mines").PORTRAIT).mode).not.toBeNull();
    expect(layout(LEVEL.hex_mines, geometryFor("hex_mines").LANDSCAPE).mode).toBeNull();
  });
});
