import { describe, expect, it } from "vitest";
import { createEffects } from "../../../../js/lib/games/core/card_table/effects.js";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { createInitialState } from "../../../../js/lib/games/hex_spider/physics.js";
import { GEOMETRY } from "../../../../js/lib/games/hex_spider/protocol.js";
import { render } from "../../../../js/lib/games/hex_spider/renderer.js";
import { drawnTable, expectMinis, images } from "../../../support/games/card_tables.js";

/** A fresh deal of `suits` drawn on `geometry`'s table, its cards `size`, and the cards cut. */
function drawn(geometry, size, suits = 4) {
  const state = createInitialState(createRng(3).next, suits, geometry);
  const log = drawnTable(render, geometry.view, { state, fx: createEffects({ size }) });
  return { state, log: images(log) };
}

describe("Hex Spider's picture", () => {
  it("draws the 54 cards dealt and a back for each of the five deals left", () => {
    expect(drawn(GEOMETRY.LANDSCAPE, "full").log).toHaveLength(59);
  });

  it("cuts each card's face, the same for two cards alike", () => {
    const { state, log } = drawn(GEOMETRY.LANDSCAPE, "full", 1);
    const tops = state.table.columns.map((c) => c.up[0]);
    const faces = log.filter((call) => call[2] < 60 * 66).map((call) => call[2] / 66);
    for (const top of tops) expect(faces).toContain(top % 52);
  });

  it("draws the minis, at their size, on the table standing up", () => {
    expectMinis(drawn(GEOMETRY.PORTRAIT, "mini").log);
  });
});
