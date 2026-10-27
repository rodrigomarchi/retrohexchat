import { describe, expect, it } from "vitest";
import { bestDestination, interpret } from "../../../../js/lib/games/hex_freecell/gestures.js";
import { layout } from "../../../../js/lib/games/hex_freecell/layout.js";

const S = 0;
const H = 1;
const C = 3;
const card = (rank, suit) => suit * 13 + rank - 1;
function table({ columns = [], cells = [], foundations = [] } = {}) {
  return {
    columns: Array.from({ length: 8 }, (_, i) => columns[i] ?? [card(13, S)]),
    cells: Array.from({ length: 4 }, (_, i) => cells[i] ?? null),
    foundations: Array.from({ length: 4 }, (_, i) => foundations[i] ?? []),
  };
}
const centre = (r) => ({ x: r.x + 10, y: r.y + 10 });
const tap = (t, r) => interpret(t, null, { type: "tap", ...centre(r) }).action;

describe("a tap on the FreeCell table", () => {
  it("sends an ace to its foundation", () => {
    const t = table({ columns: [[card(9, H), card(1, C)]] });
    expect(tap(t, layout(t).columns[0].cards[1])).toEqual({
      type: "move",
      move: { from: { pile: "column", col: 0, index: 1 }, to: { pile: "foundation", suit: C } },
    });
  });

  it("prefers a column with cards to an empty one, and an empty one to a cell", () => {
    const onto = table({ columns: [[card(5, H)], [], [card(6, S)]] });
    expect(bestDestination(onto, { pile: "column", col: 0, index: 0 }).to).toEqual({
      pile: "column",
      col: 2,
    });
    const empty = table({ columns: [[card(9, H), card(5, H)], []] });
    expect(bestDestination(empty, { pile: "column", col: 0, index: 1 }).to).toEqual({
      pile: "column",
      col: 1,
    });
    const none = table({ columns: [[card(9, H), card(5, H)]] });
    expect(bestDestination(none, { pile: "column", col: 0, index: 1 }).to).toEqual({
      pile: "cell",
      cell: 0,
    });
  });

  it("leaves a whole column where it is rather than in another empty one", () => {
    const t = table({
      columns: [[card(5, H)], []],
      cells: [card(2, S), card(3, S), card(4, S), card(6, S)],
    });
    expect(bestDestination(t, { pile: "column", col: 0, index: 0 })).toBeNull();
  });

  it("shakes a card with nowhere to go", () => {
    const t = table({
      columns: [[card(9, H), card(5, H)]],
      cells: [card(2, S), card(3, S), card(4, S), card(6, S)],
    });
    expect(tap(t, layout(t).columns[0].cards[1]).type).toBe("refuse");
  });
});

describe("a drag on the FreeCell table", () => {
  it("carries a run onto a column that takes it", () => {
    const t = table({ columns: [[card(9, S), card(8, H), card(7, S)], [card(9, C)]] });
    const places = layout(t);
    const { drag } = interpret(t, null, {
      type: "dragStart",
      ...centre(places.columns[0].cards[1]),
    });
    expect(drag.cards).toEqual([card(8, H), card(7, S)]);
    const target = places.columns[1].cards[0];
    const { action } = interpret(t, drag, { type: "drop", x: target.x + 10, y: target.y + 10 });
    expect(action).toEqual({
      type: "move",
      move: { from: { pile: "column", col: 0, index: 1 }, to: { pile: "column", col: 1 } },
    });
  });

  it("will not pick up a stretch that is not a run, and sends a run too long back", () => {
    const t = table({ columns: [[card(9, S), card(8, S)]] });
    expect(
      interpret(t, null, { type: "dragStart", ...centre(layout(t).columns[0].cards[0]) }).drag,
    ).toBeNull();

    const full = [card(2, S), card(3, S), card(4, S), card(6, S)];
    const long = table({
      columns: [[card(8, H), card(7, S), card(6, H)], [card(9, S)]],
      cells: full,
    });
    const places = layout(long);
    const { drag } = interpret(long, null, {
      type: "dragStart",
      ...centre(places.columns[0].cards[0]),
    });
    const target = places.columns[1].cards[0];
    expect(
      interpret(long, drag, { type: "drop", x: target.x + 10, y: target.y + 10 }).action.type,
    ).toBe("return");
  });
});
