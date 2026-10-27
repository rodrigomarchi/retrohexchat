import { describe, expect, it } from "vitest";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { MODE } from "../../../../js/lib/games/hex_solitaire/protocol.js";
import {
  applyMove,
  autoFinishReady,
  canMove,
  deal,
  draw,
  nextAutoMove,
  recycle,
  won,
} from "../../../../js/lib/games/hex_solitaire/rules.js";

const S = 0; // spades
const H = 1; // hearts
const D = 2; // diamonds
const C = 3; // clubs
/** A card by its rank (1 ace … 13 king) and suit. */
const card = (rank, suit) => suit * 13 + rank - 1;

/** A table built by hand: every pile empty unless given. */
function table({
  mode = MODE.DRAW1,
  stock = [],
  waste = [],
  fan,
  foundations = [[], [], [], []],
  columns = [],
} = {}) {
  const tableau = Array.from({ length: 7 }, (_, i) => ({
    down: columns[i]?.down ?? [],
    up: columns[i]?.up ?? [],
  }));
  return { mode, stock, waste, fan: fan ?? Math.min(waste.length, 1), foundations, tableau };
}

const everyCard = (state) => [
  ...state.stock,
  ...state.waste,
  ...state.foundations.flat(),
  ...state.tableau.flatMap((c) => [...c.down, ...c.up]),
];

const fromWaste = { pile: "waste" };
const fromColumn = (col, index) => ({ pile: "tableau", col, index });
const toColumn = (col) => ({ pile: "tableau", col });
const toFoundation = (suit) => ({ pile: "foundation", suit });

describe("the deal", () => {
  const dealt = deal(createRng(42).next, MODE.DRAW1);

  it("lays seven columns of one to seven cards, only the last face up", () => {
    expect(dealt.tableau.map((c) => c.down.length)).toEqual([0, 1, 2, 3, 4, 5, 6]);
    expect(dealt.tableau.map((c) => c.up.length)).toEqual([1, 1, 1, 1, 1, 1, 1]);
  });

  it("leaves 24 cards in the stock and nothing else anywhere", () => {
    expect(dealt.stock).toHaveLength(24);
    expect(dealt.waste).toEqual([]);
    expect(dealt.foundations).toEqual([[], [], [], []]);
  });

  it("uses every card once", () => {
    expect([...everyCard(dealt)].sort((a, b) => a - b)).toEqual([...Array(52).keys()]);
  });

  it("deals the same hand for the same seed, and another for another", () => {
    expect(deal(createRng(42).next, MODE.DRAW1)).toEqual(dealt);
    expect(deal(createRng(43).next, MODE.DRAW1)).not.toEqual(dealt);
  });

  it("keeps the mode it was dealt in", () => {
    expect(deal(createRng(1).next, MODE.DRAW3).mode).toBe(MODE.DRAW3);
  });
});

describe("moving onto the table", () => {
  const onto = (moving, target) => table({ waste: [moving], columns: [{ up: [target] }] });

  it("takes one rank lower in the other colour", () => {
    expect(canMove(onto(card(6, H), card(7, S)), { from: fromWaste, to: toColumn(0) })).toBe(true);
    expect(canMove(onto(card(6, C), card(7, D)), { from: fromWaste, to: toColumn(0) })).toBe(true);
  });

  it("refuses the same colour, or a rank that does not follow", () => {
    expect(canMove(onto(card(6, H), card(7, D)), { from: fromWaste, to: toColumn(0) })).toBe(false);
    expect(canMove(onto(card(6, H), card(8, S)), { from: fromWaste, to: toColumn(0) })).toBe(false);
    expect(canMove(onto(card(7, H), card(6, S)), { from: fromWaste, to: toColumn(0) })).toBe(false);
  });

  it("fills an empty column only with a king, or a run a king leads", () => {
    const king = table({ waste: [card(13, H)] });
    const queen = table({ waste: [card(12, H)] });
    const run = table({ columns: [{ down: [card(2, C)], up: [card(13, S), card(12, H)] }] });

    expect(canMove(king, { from: fromWaste, to: toColumn(3) })).toBe(true);
    expect(canMove(queen, { from: fromWaste, to: toColumn(3) })).toBe(false);
    expect(canMove(run, { from: fromColumn(0, 0), to: toColumn(3) })).toBe(true);
  });

  it("moves a run with the cards on top of it, and turns the card it leaves", () => {
    const state = table({
      columns: [{ down: [card(1, C)], up: [card(7, S), card(6, H)] }, { up: [card(8, D)] }],
    });
    const { state: after, flipped } = applyMove(state, { from: fromColumn(0, 0), to: toColumn(1) });

    expect(after.tableau[1].up).toEqual([card(8, D), card(7, S), card(6, H)]);
    expect(after.tableau[0]).toEqual({ down: [], up: [card(1, C)] });
    expect(flipped).toBe(true);
    // The table given is left as it was.
    expect(state.tableau[0].up).toEqual([card(7, S), card(6, H)]);
  });

  it("does not turn anything when the column has nothing left face down", () => {
    const state = table({ columns: [{ up: [card(7, S)] }, { up: [card(8, D)] }] });
    const { state: after, flipped } = applyMove(state, { from: fromColumn(0, 0), to: toColumn(1) });

    expect(after.tableau[0]).toEqual({ down: [], up: [] });
    expect(flipped).toBe(false);
  });

  it("refuses to pick up from a face-down card or past the end of a column", () => {
    const state = table({
      columns: [{ down: [card(5, C)], up: [card(7, S)] }, { up: [card(8, D)] }],
    });
    expect(canMove(state, { from: fromColumn(0, 1), to: toColumn(1) })).toBe(false);
    expect(canMove(state, { from: fromColumn(0, -1), to: toColumn(1) })).toBe(false);
  });

  it("refuses a move onto the column it came from", () => {
    const state = table({ columns: [{ up: [card(13, S)] }] });
    expect(canMove(state, { from: fromColumn(0, 0), to: toColumn(0) })).toBe(false);
  });
});

describe("moving to a foundation", () => {
  it("starts a suit's foundation with its ace, then follows the suit up", () => {
    expect(canMove(table({ waste: [card(1, S)] }), { from: fromWaste, to: toFoundation(S) })).toBe(
      true,
    );
    const started = table({ waste: [card(2, S)], foundations: [[card(1, S)], [], [], []] });
    expect(canMove(started, { from: fromWaste, to: toFoundation(S) })).toBe(true);
  });

  it("refuses a card of another suit, out of turn, or more than one at once", () => {
    const started = table({ foundations: [[card(1, S)], [], [], []] });
    expect(
      canMove({ ...started, waste: [card(2, H)] }, { from: fromWaste, to: toFoundation(S) }),
    ).toBe(false);
    expect(
      canMove({ ...started, waste: [card(3, S)] }, { from: fromWaste, to: toFoundation(S) }),
    ).toBe(false);
    expect(canMove(table({ waste: [card(2, S)] }), { from: fromWaste, to: toFoundation(S) })).toBe(
      false,
    );
    const pair = table({
      columns: [{ up: [card(2, S), card(1, H)] }],
      foundations: [[card(1, S)], [], [], []],
    });
    expect(canMove(pair, { from: fromColumn(0, 0), to: toFoundation(S) })).toBe(false);
  });

  it("takes a card back from a foundation onto the table", () => {
    const state = table({
      foundations: [[card(1, S), card(2, S)], [], [], []],
      columns: [{ up: [card(3, H)] }],
    });
    const move = { from: { pile: "foundation", suit: S }, to: toColumn(0) };

    expect(canMove(state, move)).toBe(true);
    expect(applyMove(state, move).state.foundations[S]).toEqual([card(1, S)]);
  });
});

describe("the stock", () => {
  const stock = [card(1, S), card(2, S), card(3, S), card(4, S), card(5, S)];

  it("turns one card at a time when drawing one", () => {
    const after = draw(table({ stock }));
    expect(after.waste).toEqual([card(5, S)]);
    expect(after.stock).toHaveLength(4);
    expect(after.fan).toBe(1);
  });

  it("turns three when drawing three, and only the last one turned plays", () => {
    const after = draw(table({ mode: MODE.DRAW3, stock }));
    expect(after.waste).toEqual([card(5, S), card(4, S), card(3, S)]);
    expect(after.fan).toBe(3);
    expect(canMove(after, { from: fromWaste, to: toFoundation(S) })).toBe(false);
    const ace = draw(table({ mode: MODE.DRAW3, stock: [card(2, H), card(3, H), card(1, S)] }));
    expect(canMove(ace, { from: fromWaste, to: toFoundation(S) })).toBe(false);
    expect(ace.waste.at(-1)).toBe(card(2, H));
  });

  it("turns what is left when fewer than three remain", () => {
    const after = draw(table({ mode: MODE.DRAW3, stock: [card(9, D), card(10, D)] }));
    expect(after.waste).toEqual([card(10, D), card(9, D)]);
    expect(after.fan).toBe(2);
  });

  it("narrows the fan as its top card is played, and the next one under it plays", () => {
    const turned = draw(table({ mode: MODE.DRAW3, stock: [card(1, D), card(1, H), card(1, S)] }));
    expect(turned.waste).toEqual([card(1, S), card(1, H), card(1, D)]);

    const first = applyMove(turned, { from: fromWaste, to: toFoundation(D) }).state;
    expect(first.fan).toBe(2);
    const second = applyMove(first, { from: fromWaste, to: toFoundation(H) }).state;
    expect(second.fan).toBe(1);
    expect(second.waste).toEqual([card(1, S)]);
  });

  it("answers nothing for a move the rules refuse", () => {
    expect(
      applyMove(table({ waste: [card(5, S)] }), { from: fromWaste, to: toFoundation(S) }),
    ).toBeNull();
  });

  it("turns the waste back into the stock, in its order, only once the stock is empty", () => {
    const turned = draw(draw(draw(table({ stock: [card(1, S), card(2, S), card(3, S)] }))));
    const back = recycle(turned);

    expect(back.stock).toEqual([card(1, S), card(2, S), card(3, S)]);
    expect(back.waste).toEqual([]);
    expect(draw(back).waste).toEqual([card(3, S)]);
    expect(recycle(table({ stock: [card(1, S)], waste: [card(2, S)] }))).toBeNull();
    expect(recycle(table())).toBeNull();
  });
});

describe("the end", () => {
  const full = () =>
    [0, 1, 2, 3].map((suit) => Array.from({ length: 13 }, (_, r) => card(r + 1, suit)));

  it("is won with every card on the foundations", () => {
    expect(won(table({ foundations: full() }))).toBe(true);
    const almost = full();
    const king = almost[C].pop();
    expect(won(table({ foundations: almost, columns: [{ up: [king] }] }))).toBe(false);
  });

  it("finishes itself only with nothing left hidden, in the stock or in the waste", () => {
    const open = table({ columns: [{ up: [card(2, S)] }, { up: [card(1, S)] }] });
    expect(autoFinishReady(open)).toBe(true);
    expect(autoFinishReady({ ...open, stock: [card(3, S)] })).toBe(false);
    expect(autoFinishReady({ ...open, waste: [card(3, S)] })).toBe(false);
    const hidden = table({ columns: [{ down: [card(3, S)], up: [card(2, S)] }] });
    expect(autoFinishReady(hidden)).toBe(false);
  });

  it("sends up the lowest card that can go first", () => {
    const state = table({
      foundations: [[card(1, S)], [], [], []],
      columns: [{ up: [card(2, S)] }, { up: [card(1, H)] }],
    });
    expect(nextAutoMove(state)).toEqual({ from: fromColumn(1, 0), to: toFoundation(H) });
    expect(nextAutoMove(table())).toBeNull();
  });
});
