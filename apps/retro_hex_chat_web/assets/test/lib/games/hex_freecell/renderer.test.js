import { describe, expect, it } from "vitest";
import { createEffects } from "../../../../js/lib/games/core/card_table/effects.js";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { createInitialState } from "../../../../js/lib/games/hex_freecell/physics.js";
import { GEOMETRY } from "../../../../js/lib/games/hex_freecell/protocol.js";
import { render } from "../../../../js/lib/games/hex_freecell/renderer.js";
import { drawnTable, expectMinis, images } from "../../../support/games/card_tables.js";

/** The canvas log of a fresh deal drawn on `geometry`'s table, its cards `size`. */
function drawn(geometry, size, scene = {}) {
  const state = createInitialState(createRng(3).next, geometry);
  return drawnTable(render, geometry.view, { state, fx: createEffects({ size }), ...scene });
}

describe("Hex FreeCell's picture", () => {
  it("draws the 52 cards of the deal and the eight empty cells and foundations", () => {
    const log = drawn(GEOMETRY.LANDSCAPE, "full");
    expect(images(log)).toHaveLength(52);
    expect(log.filter(([op]) => op === "strokeRect")).toHaveLength(8);
  });

  it("draws the minis, at their size, on the table standing up", () => {
    const cards = images(drawn(GEOMETRY.PORTRAIT, "mini"));
    expect(cards).toHaveLength(52);
    expectMinis(cards);
  });

  it("draws a held card at the table's size, a mini on the table standing up", () => {
    const state = createInitialState(createRng(3).next, GEOMETRY.PORTRAIT);
    const card = state.table.columns[0].at(-1);
    const log = drawn(GEOMETRY.PORTRAIT, "mini", {
      drag: { from: { pile: "column", col: 0, index: 6 }, cards: [card], x: 100, y: 300 },
    });
    const held = images(log).at(-1);
    expect(held.slice(6)).toEqual([100, 298, 44, 62]);
    expect(held[3]).toBe(1000);
  });

  it("puts every card on a whole pixel", () => {
    for (const call of images(drawn(GEOMETRY.LANDSCAPE, "full"))) {
      expect(Number.isInteger(call[6]) && Number.isInteger(call[7])).toBe(true);
    }
  });
});
