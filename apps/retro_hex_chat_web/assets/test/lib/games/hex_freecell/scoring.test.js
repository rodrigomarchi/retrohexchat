import { describe, expect, it } from "vitest";
import { CEILING, POINTS } from "../../../../js/lib/games/hex_freecell/protocol.js";
import { scoreMove } from "../../../../js/lib/games/hex_freecell/scoring.js";
import { timeBonus } from "../../../../js/lib/games/core/solo/clock.js";

const column = { pile: "column", col: 0, index: 0 };
const cell = { pile: "cell", cell: 0 };
const foundation = { pile: "foundation", suit: 0 };

describe("Hex FreeCell's points", () => {
  it("pay ten for a card up, from a column or a cell, and cost fifteen to take one back", () => {
    expect(scoreMove({ from: column, to: foundation })).toBe(10);
    expect(scoreMove({ from: cell, to: foundation })).toBe(10);
    expect(scoreMove({ from: foundation, to: { pile: "column", col: 1 } })).toBe(-15);
    expect(scoreMove({ from: foundation, to: { pile: "cell", cell: 1 } })).toBe(-15);
    expect(scoreMove({ from: column, to: { pile: "cell", cell: 1 } })).toBe(0);
  });

  it("gain nothing from a card going up and down again", () => {
    expect(POINTS.TO_FOUNDATION + POINTS.FOUNDATION_BACK).toBe(-5);
  });

  it("top out at every card up and a win in thirty seconds", () => {
    expect(CEILING).toBe(52 * POINTS.TO_FOUNDATION + timeBonus(30 * 60));
    expect(CEILING).toBe(23_853);
  });
});
