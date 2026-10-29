import { describe, expect, it } from "vitest";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { hitTest, layout } from "../../../../js/lib/games/hex_spider/layout.js";
import { GEOMETRY } from "../../../../js/lib/games/hex_spider/protocol.js";
import { deal } from "../../../../js/lib/games/hex_spider/rules.js";
import { expectLaidApart } from "../../../support/games/places.js";

describe.each(Object.entries(GEOMETRY))("the Spider table lying %s", (name, geometry) => {
  const table = { ...deal(createRng(1).next, 4), geometry };
  const { view, card } = geometry;

  it("fits the ten columns, the stock and the suits' place in the view, apart", () => {
    const places = layout(table);
    const piles = [...places.columns.map((c) => c.slot), places.stockSlot, places.next];
    expectLaidApart(piles, view);
    for (const r of piles) expect([r.w, r.h]).toEqual([card.width, card.height]);
    expect(places.stock).toHaveLength(5);
  });

  it("squeezes a column of 25 cards and keeps its foot above the bottom row", () => {
    const long = { down: [0, 1, 2, 3, 4], up: Array.from({ length: 20 }, (_, i) => 100 + i) };
    const longest = { ...table, columns: [long, ...table.columns.slice(1)] };
    const places = layout(longest);
    const foot = places.columns[0].cards.at(-1);
    expect(foot.y + card.height).toBeLessThanOrEqual(places.stockSlot.y);
    expect(hitTest(longest, foot.x + 2, foot.y + card.height - 2)).toEqual({
      pile: "column",
      col: 0,
      index: 19,
    });
  });

  it("finds the stock, a face-up card, a face-down one and an empty column", () => {
    const empty = { ...table, columns: [{ down: [], up: [] }, ...table.columns.slice(1)] };
    const places = layout(empty);
    const at = (r) => hitTest(empty, r.x + 2, r.y + 2);
    expect(at(places.stock.at(-1))).toEqual({ pile: "stock" });
    expect(at(places.columns[0].slot)).toEqual({ pile: "slot", col: 0 });
    expect(at(places.columns[1].cards[0])).toEqual({ pile: "hidden", col: 1 });
    expect(at(places.columns[1].cards.at(-1))).toEqual({ pile: "column", col: 1, index: 0 });
  });
});
