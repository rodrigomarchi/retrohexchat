import { describe, expect, it } from "vitest";
import { faceOf, rankOf, suitOf } from "../../../../js/lib/games/core/cards.js";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import {
  applyMove,
  canMove,
  canPick,
  deal,
  dealRow,
  hasMove,
  won,
} from "../../../../js/lib/games/hex_spider/rules.js";

const S = 0;
const H = 1;
// A card of the two decks: `copy` tells apart two that look alike.
const card = (rank, suit, copy = 0) => copy * 52 + suit * 13 + rank - 1;
const at = (col, index) => ({ pile: "column", col, index });
const to = (col) => ({ pile: "column", col });
/** A table with the columns given (face-up runs over face-down cards), the rest empty. */
function table({ columns = [], stock = [], foundations = [] } = {}) {
  return {
    columns: Array.from({ length: 10 }, (_, i) => ({
      down: columns[i]?.down ?? [],
      up: columns[i]?.up ?? [],
    })),
    stock,
    foundations,
  };
}
const run = (from, downTo, suit, copy = 0) =>
  Array.from({ length: from - downTo + 1 }, (_, i) => card(from - i, suit, copy));

describe("the deal", () => {
  it("lays 54 cards in ten columns, only the last of each face up, and keeps 50 in the stock", () => {
    const dealt = deal(createRng(1).next, 1);
    expect(dealt.columns.map((c) => c.down.length + c.up.length)).toEqual([
      6, 6, 6, 6, 5, 5, 5, 5, 5, 5,
    ]);
    expect(dealt.columns.every((c) => c.up.length === 1)).toBe(true);
    expect(dealt.stock).toHaveLength(50);
    const all = [...dealt.columns.flatMap((c) => [...c.down, ...c.up]), ...dealt.stock];
    expect(new Set(all).size).toBe(104);
    expect(dealt.foundations).toEqual([]);
  });

  it("deals the suits of its variant, and the same table for the same seed", () => {
    for (const suits of [1, 2, 4]) {
      const dealt = deal(createRng(2).next, suits);
      const cards = [...dealt.columns.flatMap((c) => [...c.down, ...c.up]), ...dealt.stock];
      expect(new Set(cards.map((c) => suitOf(faceOf(c)))).size).toBe(suits);
    }
    expect(deal(createRng(3).next, 2)).toEqual(deal(createRng(3).next, 2));
  });
});

describe("moves", () => {
  it("lay a card on any card one rank higher, whatever its suit, and anything on an empty column", () => {
    const t = table({
      columns: [{ up: [card(8, S)] }, { up: [card(7, H)] }, { up: [card(9, S)] }],
    });
    expect(canMove(t, { from: at(1, 0), to: to(0) })).toBe(true);
    expect(canMove(t, { from: at(1, 0), to: to(2) })).toBe(false);
    expect(canMove(t, { from: at(1, 0), to: to(5) })).toBe(true);
  });

  it("carry only runs of one suit", () => {
    const t = table({
      columns: [
        { up: [card(9, S), card(8, S), card(7, S)] },
        { up: [card(9, S), card(8, H), card(7, S)] },
      ],
    });
    expect(canPick(t, at(0, 0))).toBe(true);
    expect(canPick(t, at(1, 2))).toBe(true);
    expect(canPick(t, at(1, 1))).toBe(false);
    expect(canMove(t, { from: at(1, 1), to: to(4) })).toBe(false);
  });

  it("turn over the card a move uncovers", () => {
    const t = table({ columns: [{ down: [card(2, H)], up: [card(5, S)] }, { up: [card(6, H)] }] });
    const { state, flipped } = applyMove(t, { from: at(0, 0), to: to(1) });
    expect(flipped).toBe(true);
    expect(state.columns[0]).toEqual({ down: [], up: [card(2, H)] });
    expect(state.columns[1].up).toEqual([card(6, H), card(5, S)]);
  });

  it("send a whole suit, king to ace, to the foundations by itself", () => {
    const t = table({
      columns: [{ down: [card(4, H)], up: run(13, 2, S) }, { up: [card(1, S, 3)] }],
    });
    const { state, completed, flipped } = applyMove(t, { from: at(1, 0), to: to(0) });
    expect(completed).toBe(1);
    expect(flipped).toBe(true);
    expect(state.foundations).toEqual([[...run(13, 2, S), card(1, S, 3)]]);
    expect(state.columns[0]).toEqual({ down: [], up: [card(4, H)] });
  });

  it("leave a king-to-ace of mixed suits where it is", () => {
    const mixed = [...run(13, 3, S), card(2, H)];
    const t = table({ columns: [{ up: mixed }, { up: [card(1, H)] }] });
    const { completed, state } = applyMove(t, { from: at(1, 0), to: to(0) });
    expect(completed).toBe(0);
    expect(state.columns[0].up.map((c) => rankOf(faceOf(c))).at(-1)).toBe(1);
  });
});

describe("the stock", () => {
  const full = Array.from({ length: 10 }, (_, i) => ({ up: [card(5, S, i % 8)] }));

  it("deals one card face up to every column", () => {
    const stock = run(13, 4, H);
    const { state } = dealRow(table({ columns: full, stock }));
    expect(state.stock).toEqual([]);
    expect(state.columns.map((c) => c.up.at(-1))).toEqual([...stock].reverse());
  });

  it("will not deal while a column is empty, or once it is empty itself", () => {
    expect(dealRow(table({ columns: full.slice(0, 9), stock: run(13, 4, H) }))).toBeNull();
    expect(dealRow(table({ columns: full, stock: [] }))).toBeNull();
  });

  it("completes every suit a row finishes, and says how many", () => {
    const columns = full.map((c, i) => (i < 2 ? { up: run(13, 2, S, i) } : c));
    const stock = [...run(13, 6, H), card(1, S, 5), card(1, S, 4)];
    const { state, completed } = dealRow(table({ columns, stock }));
    expect(completed).toBe(2);
    expect(state.foundations).toHaveLength(2);
  });

  it("completes a suit a dealt card finishes", () => {
    const columns = full.map((c, i) => (i === 0 ? { up: run(13, 2, S) } : c));
    const stock = [...run(13, 5, H), card(1, S, 4)];
    const { state, completed } = dealRow(table({ columns, stock }));
    expect(completed).toBe(1);
    expect(state.foundations).toHaveLength(1);
  });
});

describe("the end", () => {
  it("is a win with the eight suits up", () => {
    expect(won(table({ foundations: Array.from({ length: 8 }, (_, i) => run(13, 1, S, i)) }))).toBe(
      true,
    );
    expect(won(table({ foundations: Array.from({ length: 7 }, (_, i) => run(13, 1, S, i)) }))).toBe(
      false,
    );
  });

  it("is stuck only with the stock gone and no move left", () => {
    const stuck = Array.from({ length: 10 }, (_, i) => ({ up: [card(13, S, i % 8)] }));
    expect(hasMove(table({ columns: stuck }))).toBe(false);
    expect(hasMove(table({ columns: stuck, stock: run(13, 4, H) }))).toBe(true);
    const open = stuck.map((c, i) => (i === 3 ? { up: [card(12, H)] } : c));
    expect(hasMove(table({ columns: open }))).toBe(true);
  });
});
