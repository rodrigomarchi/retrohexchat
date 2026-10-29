import { describe, expect, it } from "vitest";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { hitTest, layout } from "../../../../js/lib/games/hex_freecell/layout.js";
import { GEOMETRY } from "../../../../js/lib/games/hex_freecell/protocol.js";
import { deal } from "../../../../js/lib/games/hex_freecell/rules.js";
import { expectLaidApart, within } from "../../../support/games/places.js";

describe.each(Object.entries(GEOMETRY))("the table lying %s", (name, geometry) => {
  const table = { ...deal(createRng(1).next), geometry };
  const places = layout(table);
  const { view, card } = geometry;

  it("fits the cells, the foundations and the eight columns in the view, apart", () => {
    const piles = [...places.cells, ...places.foundations, ...places.columns.map((c) => c.slot)];
    expectLaidApart(piles, view);
    for (const r of piles) expect([r.w, r.h]).toEqual([card.width, card.height]);
  });

  it("squeezes the longest column there can be and keeps its foot on the felt", () => {
    const long = Array.from({ length: 19 }, (_, i) => i);
    const longest = { ...table, columns: [long, ...table.columns.slice(1)] };
    const foot = layout(longest).columns[0].cards.at(-1);
    expect(within(foot, view)).toBe(true);
    expect(hitTest(longest, foot.x + 2, foot.y + card.height - 2)).toEqual({
      pile: "column",
      col: 0,
      index: 18,
    });
  });

  it("finds the card under a point, a cell, a foundation, an empty column and nothing", () => {
    const empty = { ...table, columns: [[], ...table.columns.slice(1)] };
    const at = (r) => hitTest(empty, r.x + 2, r.y + 2);
    const at2 = layout(empty);
    expect(at(at2.cells[2])).toEqual({ pile: "cell", cell: 2 });
    expect(at(at2.foundations[1])).toEqual({ pile: "foundation", suit: 1 });
    expect(at(at2.columns[0].slot)).toEqual({ pile: "slot", col: 0 });
    expect(at(at2.columns[3].cards[0])).toEqual({ pile: "column", col: 3, index: 0 });
    expect(hitTest(empty, 1, view.height - 2)).toBeNull();
  });
});

describe("the table standing up", () => {
  it("deals the minis", () => {
    expect(GEOMETRY.PORTRAIT.size).toBe("mini");
    expect(GEOMETRY.LANDSCAPE.size).toBe("full");
  });
});
