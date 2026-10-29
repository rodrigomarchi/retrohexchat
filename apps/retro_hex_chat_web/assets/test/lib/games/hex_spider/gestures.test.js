import { describe, expect, it } from "vitest";
import { bestDestination, interpret } from "../../../../js/lib/games/hex_spider/gestures.js";
import { layout } from "../../../../js/lib/games/hex_spider/layout.js";
import { H, S, card } from "../../../support/games/card_tables.js";

const full = () => ({ down: [card(13, H, 7)], up: [card(13, S, 7)] });
function table({ columns = [], stock = [] } = {}) {
  return {
    columns: Array.from({ length: 10 }, (_, i) =>
      columns[i] ? { down: [], ...columns[i] } : full(),
    ),
    stock,
    foundations: [],
  };
}
const centre = (r) => ({ x: r.x + 10, y: r.y + 10 });

describe("a tap on the Spider table", () => {
  it("sends a run onto the column that continues its suit before any other", () => {
    const t = table({
      columns: [{ up: [card(6, S)] }, { up: [card(7, H)] }, { up: [card(7, S)] }],
    });
    expect(bestDestination(t, { pile: "column", col: 0, index: 0 }).to).toEqual({
      pile: "column",
      col: 2,
    });
    const mixed = table({ columns: [{ up: [card(6, S)] }, { up: [card(7, H)] }] });
    expect(bestDestination(mixed, { pile: "column", col: 0, index: 0 }).to).toEqual({
      pile: "column",
      col: 1,
    });
  });

  it("deals a row from the stock, and shakes it while a column is empty", () => {
    const stock = Array.from({ length: 10 }, (_, i) => card(2, S, i % 8));
    const t = table({ stock });
    const tap = (tb) =>
      interpret(tb, null, { type: "tap", ...centre(layout(tb).stock.at(-1)) }).action;
    expect(tap(t)).toEqual({ type: "deal" });
    const empty = table({ stock, columns: [{ down: [], up: [] }] });
    expect(tap(empty)).toEqual({ type: "refuse", from: { pile: "stock" } });
  });
});

describe("a drag on the Spider table", () => {
  it("picks up only a run of one suit", () => {
    const t = table({ columns: [{ up: [card(9, S), card(8, H), card(7, H)] }] });
    const places = layout(t).columns[0].cards;
    expect(interpret(t, null, { type: "dragStart", ...centre(places[0]) }).drag).toBeNull();
    expect(interpret(t, null, { type: "dragStart", ...centre(places[1]) }).drag.cards).toEqual([
      card(8, H),
      card(7, H),
    ]);
  });
});
