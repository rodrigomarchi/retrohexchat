import { describe, expect, it } from "vitest";
import { CARD, MODE, VIEW } from "../../../../js/lib/games/hex_solitaire/protocol.js";
import { hitTest, layout } from "../../../../js/lib/games/hex_solitaire/layout.js";

const card = (rank, suit) => suit * 13 + rank - 1;

function table({ stock = [], waste = [], fan, foundations = [[], [], [], []], columns = [] } = {}) {
  const tableau = Array.from({ length: 7 }, (_, i) => ({
    down: columns[i]?.down ?? [],
    up: columns[i]?.up ?? [],
  }));
  return {
    mode: MODE.DRAW3,
    stock,
    waste,
    fan: fan ?? Math.min(1, waste.length),
    foundations,
    tableau,
  };
}

const overlaps = (a, b) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
const inside = (r) => r.x >= 0 && r.y >= 0 && r.x + r.w <= VIEW.width && r.y + r.h <= VIEW.height;

describe("layout", () => {
  it("places the stock, the waste, four foundations and seven columns inside the canvas, apart", () => {
    const places = layout(table());
    const piles = [
      places.stock,
      places.wasteSlot,
      ...places.foundations,
      ...places.columns.map((c) => c.slot),
    ];

    expect(places.foundations).toHaveLength(4);
    expect(places.columns).toHaveLength(7);
    expect(piles.every(inside)).toBe(true);
    for (const [i, a] of piles.entries()) {
      for (const b of piles.slice(i + 1)) expect(overlaps(a, b)).toBe(false);
    }
    expect([places.stock.w, places.stock.h]).toEqual([CARD.width, CARD.height]);
  });

  it("fans the waste's showing cards, the last turned on top and furthest right", () => {
    const places = layout(table({ waste: [card(1, 0), card(2, 0), card(3, 0)], fan: 3 }));
    expect(places.waste.map((c) => c.card)).toEqual([card(1, 0), card(2, 0), card(3, 0)]);
    const xs = places.waste.map((c) => c.x);
    expect(xs[0] < xs[1] && xs[1] < xs[2]).toBe(true);
  });

  it("fits the longest column a deal can make inside the canvas, every card still reachable", () => {
    const down = [0, 1, 2, 3, 4, 5].map((r) => card(r + 1, 3));
    const up = Array.from({ length: 13 }, (_, i) => card(13 - i, i % 2 ? 1 : 0));
    const places = layout(table({ columns: [{}, {}, {}, {}, {}, {}, { down, up }] }));
    const cards = places.columns[6].cards;

    expect(cards).toHaveLength(19);
    expect(inside(cards.at(-1))).toBe(true);
    // Each card under another still shows a strip one can press.
    for (const [i, c] of cards.slice(0, -1).entries()) {
      expect(cards[i + 1].y - c.y).toBeGreaterThanOrEqual(4);
    }
  });

  it("squeezes a column that would run off the canvas", () => {
    const up = Array.from({ length: 13 }, (_, i) => card(13 - i, i % 2 ? 1 : 0));
    const down = Array.from({ length: 12 }, (_, i) => card(1, i % 4));
    const places = layout(table({ columns: [{ down, up }] }));
    expect(inside(places.columns[0].cards.at(-1))).toBe(true);
  });
});

describe("hitTest", () => {
  const state = table({
    stock: [card(9, 0)],
    waste: [card(1, 1), card(2, 1), card(3, 1)],
    fan: 3,
    foundations: [[card(1, 0)], [], [], []],
    columns: [{ down: [card(5, 2)], up: [card(7, 0), card(6, 1)] }],
  });
  const places = layout(state);
  const centre = (r) => ({ x: r.x + Math.floor(r.w / 2), y: r.y + Math.floor(r.h / 2) });
  const at = (r, dy = 0) => hitTest(state, r.x + 4, r.y + dy + 4);

  it("finds the stock, the top of the waste and a foundation", () => {
    const stock = centre(places.stock);
    expect(hitTest(state, stock.x, stock.y)).toEqual({ pile: "stock" });
    expect(at(places.waste.at(-1))).toEqual({ pile: "waste" });
    expect(at(places.foundations[0])).toEqual({ pile: "foundation", suit: 0 });
  });

  it("finds a card in the middle of a column by the strip that shows", () => {
    const [, seven, six] = places.columns[0].cards;
    expect(at(seven)).toEqual({ pile: "tableau", col: 0, index: 0 });
    expect(at(six)).toEqual({ pile: "tableau", col: 0, index: 1 });
  });

  it("names an empty column's place, and a face-down card as nothing to pick up", () => {
    const [hidden] = places.columns[0].cards;
    expect(at(places.columns[3].slot)).toEqual({ pile: "slot", col: 3 });
    expect(at(hidden, -4)).toEqual({ pile: "hidden", col: 0 });
  });

  it("finds nothing on the bare felt, nor a waste card another covers", () => {
    expect(hitTest(state, 2, VIEW.height - 2)).toBeNull();
    expect(at(places.waste[0])).toBeNull();
  });
});
