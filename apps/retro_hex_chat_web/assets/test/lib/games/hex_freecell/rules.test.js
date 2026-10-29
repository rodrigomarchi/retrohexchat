import { describe, expect, it } from "vitest";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import {
  applyMove,
  autoFinishReady,
  canMove,
  capacity,
  deal,
  hasMove,
  nextAutoMove,
  nextSafeMove,
  won,
} from "../../../../js/lib/games/hex_freecell/rules.js";
import { C, D, H, S, card } from "../../../support/games/card_tables.js";
import { table } from "./tables.js";

const column = (col, index) => ({ pile: "column", col, index });
const cell = (n) => ({ pile: "cell", cell: n });
const toColumn = (col) => ({ pile: "column", col });
const toCell = (n) => ({ pile: "cell", cell: n });
const toFoundation = (suit) => ({ pile: "foundation", suit });

const upTo = (rank, suit) => Array.from({ length: rank }, (_, i) => card(i + 1, suit));

describe("the deal", () => {
  it("lays the whole deck face up: seven cards in the four left columns, six in the others", () => {
    const dealt = deal(createRng(1).next);
    expect(dealt.columns.map((c) => c.length)).toEqual([7, 7, 7, 7, 6, 6, 6, 6]);
    expect(new Set(dealt.columns.flat()).size).toBe(52);
    expect(dealt.cells).toEqual([null, null, null, null]);
    expect(dealt.foundations).toEqual([[], [], [], []]);
  });

  it("deals the same table for the same seed, another for another", () => {
    expect(deal(createRng(5).next)).toEqual(deal(createRng(5).next));
    expect(deal(createRng(5).next)).not.toEqual(deal(createRng(6).next));
  });
});

describe("the free cells", () => {
  const t = table({ columns: [[card(9, S), card(4, H)]], cells: [null, card(2, C)] });

  it("take one card from the foot of a column, into an empty cell only", () => {
    expect(canMove(t, { from: column(0, 1), to: toCell(0) })).toBe(true);
    expect(canMove(t, { from: column(0, 1), to: toCell(1) })).toBe(false);
    expect(canMove(t, { from: column(0, 0), to: toCell(0) })).toBe(false);
    const after = applyMove(t, { from: column(0, 1), to: toCell(0) });
    expect(after.cells[0]).toBe(card(4, H));
    expect(after.columns[0]).toEqual([card(9, S)]);
  });

  it("give their card back to a column that takes it", () => {
    const back = table({ columns: [[card(3, H)]], cells: [card(2, C)] });
    expect(canMove(back, { from: cell(0), to: toColumn(0) })).toBe(true);
    expect(applyMove(back, { from: cell(0), to: toColumn(0) }).cells[0]).toBeNull();
  });
});

describe("the columns", () => {
  it("take the next card down in the other colour, and any card when empty", () => {
    const t = table({ columns: [[card(7, S)], [card(7, D)], [card(6, H)], []] });
    expect(canMove(t, { from: column(2, 0), to: toColumn(0) })).toBe(true);
    expect(canMove(t, { from: column(2, 0), to: toColumn(1) })).toBe(false);
    expect(canMove(t, { from: column(0, 0), to: toColumn(3) })).toBe(true);
  });

  it("move a run as far as the free cells and empty columns allow", () => {
    const run = [
      card(9, S),
      card(8, H),
      card(7, C),
      card(6, D),
      card(5, S),
      card(4, H),
      card(3, C),
    ];
    const base = {
      columns: [run, [card(10, H)], [card(1, S)], [card(1, H)], [card(1, D)], [card(1, C)]],
    };
    // Two cells and one empty column (of the three left) free: (2 + 1) × 2 = 6 cards.
    const t = table({
      ...base,
      columns: [...base.columns, [card(2, S)], []],
      cells: [card(13, S), card(13, H)],
    });
    expect(capacity(t, false)).toBe(6);
    expect(capacity(t, true)).toBe(3);
    expect(canMove(t, { from: column(0, 1), to: toColumn(1) })).toBe(false);
    expect(canMove(t, { from: column(0, 0), to: toColumn(1) })).toBe(false);
    const shorter = { ...t, columns: t.columns.map((c, i) => (i === 0 ? run.slice(0, 6) : c)) };
    expect(canMove(shorter, { from: column(0, 0), to: toColumn(1) })).toBe(true);
    expect(canMove(shorter, { from: column(0, 3), to: toColumn(7) })).toBe(true);
    expect(canMove(shorter, { from: column(0, 2), to: toColumn(7) })).toBe(false);
  });

  it("never move a stretch that is not a run", () => {
    const t = table({ columns: [[card(9, S), card(8, S)], [card(10, H)]] });
    expect(canMove(t, { from: column(0, 0), to: toColumn(1) })).toBe(false);
  });
});

describe("the foundations", () => {
  it("climb from the ace, suit by suit, one card at a time, and give a card back", () => {
    const t = table({ columns: [[card(2, S)], [card(1, S)], [card(2, H)]], foundations: [[], []] });
    expect(canMove(t, { from: column(1, 0), to: toFoundation(S) })).toBe(true);
    expect(canMove(t, { from: column(0, 0), to: toFoundation(S) })).toBe(false);
    const up = applyMove(t, { from: column(1, 0), to: toFoundation(S) });
    expect(canMove(up, { from: column(0, 0), to: toFoundation(S) })).toBe(true);
    expect(canMove(up, { from: column(2, 0), to: toFoundation(S) })).toBe(false);
    const fromFoundation = { pile: "foundation", suit: S };
    const back = table({ columns: [[card(2, H)]], foundations: [[card(1, S)]] });
    expect(canMove(back, { from: fromFoundation, to: toColumn(0) })).toBe(true);
  });
});

describe("the cards that go up by themselves", () => {
  it("are the aces and twos, and a card no lower card of the other colour still needs", () => {
    const aces = table({ columns: [[card(5, C), card(1, D)]] });
    expect(nextSafeMove(aces)).toEqual({ from: column(0, 1), to: toFoundation(D) });

    // The 3♥ waits while the 2♠ and the 2♣ are still on the table: they may need it.
    const waiting = table({
      columns: [[card(3, H)], [card(2, S)], [card(2, C)]],
      foundations: [[card(1, S)], upTo(2, H), [], [card(1, C)]],
    });
    expect(nextSafeMove(waiting)).toEqual({ from: column(1, 0), to: toFoundation(S) });
    const blocked = table({
      columns: [[card(3, H)], [card(9, D), card(2, S)], [card(9, H), card(2, C)]],
      foundations: [[card(1, S)], upTo(2, H), [], [card(1, C)]],
    });
    const twos = applyMove(
      applyMove(blocked, nextSafeMove(blocked)),
      nextSafeMove(applyMove(blocked, nextSafeMove(blocked))),
    );
    expect(twos.foundations[S]).toHaveLength(2);
    expect(twos.foundations[C]).toHaveLength(2);
    expect(nextSafeMove(twos)).toEqual({ from: column(0, 0), to: toFoundation(H) });
    expect(
      nextSafeMove(table({ columns: [[card(3, H)]], foundations: [[], upTo(2, H)] })),
    ).toBeNull();
  });

  it("come from the cells too", () => {
    expect(nextSafeMove(table({ cells: [null, card(1, H)] }))).toEqual({
      from: cell(1),
      to: toFoundation(H),
    });
  });
});

describe("the end", () => {
  it("finishes by itself once every column runs down, the lowest card first", () => {
    const sorted = table({
      columns: [[card(13, S), card(9, H), card(3, C)], [card(5, D)]],
      cells: [card(2, C)],
      foundations: [[], [], [], [card(1, C)]],
    });
    expect(autoFinishReady(sorted)).toBe(true);
    expect(nextAutoMove(sorted)).toEqual({ from: cell(0), to: toFoundation(C) });
    const unsorted = table({ columns: [[card(3, C), card(9, H)]] });
    expect(autoFinishReady(unsorted)).toBe(false);
  });

  it("is a win with the 52 cards up", () => {
    expect(won(table({ foundations: [0, 1, 2, 3].map((s) => upTo(13, s)) }))).toBe(true);
    expect(won(table({ foundations: [upTo(12, S), upTo(13, H), upTo(13, D), upTo(13, C)] }))).toBe(
      false,
    );
  });

  it("knows a table with no move left", () => {
    const stuck = table({
      columns: [
        [card(5, S)],
        [card(5, C)],
        [card(5, H)],
        [card(5, D)],
        [card(9, S)],
        [card(9, C)],
        [card(9, H)],
        [card(9, D)],
      ],
      cells: [card(13, S), card(13, H), card(13, D), card(13, C)],
    });
    expect(hasMove(stuck)).toBe(false);
    expect(hasMove({ ...stuck, cells: [null, ...stuck.cells.slice(1)] })).toBe(true);
    const oneMove = {
      ...stuck,
      columns: stuck.columns.map((c, i) => (i === 4 ? [card(6, H)] : c)),
    };
    expect(hasMove(oneMove)).toBe(true);
  });
});
