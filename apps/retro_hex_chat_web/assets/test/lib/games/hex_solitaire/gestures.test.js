import { describe, expect, it } from "vitest";
import { MODE } from "../../../../js/lib/games/hex_solitaire/protocol.js";
import { layout } from "../../../../js/lib/games/hex_solitaire/layout.js";
import { bestDestination, interpret } from "../../../../js/lib/games/hex_solitaire/gestures.js";

const S = 0;
const H = 1;
const D = 2;
const C = 3;
const card = (rank, suit) => suit * 13 + rank - 1;

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
  return { mode, stock, waste, fan: fan ?? Math.min(1, waste.length), foundations, tableau };
}

const tapOn = (state, r) => interpret(state, null, { type: "tap", x: r.x + 4, y: r.y + 4 });

describe("a tap", () => {
  it("on the stock turns it, and on the empty stock turns the waste back", () => {
    const withStock = table({ stock: [card(1, S)] });
    expect(tapOn(withStock, layout(withStock).stock).action).toEqual({ type: "draw" });
    const empty = table({ waste: [card(1, S)] });
    expect(tapOn(empty, layout(empty).stock).action).toEqual({ type: "recycle" });
    expect(tapOn(table(), layout(table()).stock).action).toBeNull();
  });

  it("sends a card to its foundation first", () => {
    const state = table({ waste: [card(1, H)], columns: [{ up: [card(2, S)] }] });
    expect(tapOn(state, layout(state).waste[0]).action).toEqual({
      type: "move",
      move: { from: { pile: "waste" }, to: { pile: "foundation", suit: H } },
    });
  });

  it("otherwise to the first column from the left that takes it", () => {
    const state = table({
      waste: [card(6, H)],
      columns: [
        { up: [card(9, S)] },
        { up: [card(7, D)] },
        { up: [card(7, C)] },
        { up: [card(7, S)] },
      ],
    });
    expect(tapOn(state, layout(state).waste[0]).action.move.to).toEqual({
      pile: "tableau",
      col: 2,
    });
  });

  it("is refused for a card with nowhere to go, and changes nothing", () => {
    const state = table({ waste: [card(5, H)], columns: [{ up: [card(9, S)] }] });
    expect(tapOn(state, layout(state).waste[0]).action).toEqual({
      type: "refuse",
      from: { pile: "waste" },
    });
  });

  it("moves a whole run from the card tapped", () => {
    const state = table({
      columns: [{ down: [card(2, C)], up: [card(7, S), card(6, H)] }, { up: [card(8, D)] }],
    });
    const seven = layout(state).columns[0].cards[1];
    expect(tapOn(state, seven).action.move).toEqual({
      from: { pile: "tableau", col: 0, index: 0 },
      to: { pile: "tableau", col: 1 },
    });
  });

  it("does nothing on a face-down card, an empty place or the felt", () => {
    const state = table({ columns: [{ down: [card(2, C)], up: [card(7, S)] }] });
    const places = layout(state);
    expect(
      interpret(state, null, {
        type: "tap",
        x: places.columns[0].cards[0].x + 4,
        y: places.columns[0].cards[0].y + 2,
      }).action,
    ).toBeNull();
    expect(tapOn(state, places.columns[4].slot).action).toBeNull();
    expect(interpret(state, null, { type: "tap", x: 2, y: 470 }).action).toBeNull();
  });
});

describe("a drag", () => {
  const state = table({
    waste: [card(3, D)],
    columns: [
      { down: [card(2, C)], up: [card(7, S), card(6, H)] },
      { up: [card(8, H)] },
      { up: [card(8, D)] },
    ],
  });
  const places = layout(state);
  const seven = places.columns[0].cards[1];

  /** Pick up at a card, move by (dx, dy), drop: the action the drop makes. */
  function dragBy(from, dx, dy, s = state) {
    let { drag } = interpret(s, null, { type: "dragStart", x: from.x + 10, y: from.y + 5 });
    ({ drag } = interpret(s, drag, { type: "dragMove", x: from.x + 10 + dx, y: from.y + 5 + dy }));
    return {
      held: drag,
      ...interpret(s, drag, { type: "drop", x: from.x + 10 + dx, y: from.y + 5 + dy }),
    };
  }

  it("picks up a face-up card with what lies on it, held where the finger took it", () => {
    const { drag } = interpret(state, null, { type: "dragStart", x: seven.x + 10, y: seven.y + 5 });
    expect(drag.from).toEqual({ pile: "tableau", col: 0, index: 0 });
    expect(drag.cards).toEqual([card(7, S), card(6, H)]);
    const moved = interpret(state, drag, {
      type: "dragMove",
      x: seven.x + 50,
      y: seven.y + 45,
    }).drag;
    expect([moved.x, moved.y]).toEqual([seven.x + 40, seven.y + 40]);
  });

  it("moves the run onto the pile it is dropped on", () => {
    const target = places.columns[1].cards[0];
    const { action, drag } = dragBy(seven, target.x - seven.x, target.y + 18 - seven.y);
    expect(action).toEqual({
      type: "move",
      move: { from: { pile: "tableau", col: 0, index: 0 }, to: { pile: "tableau", col: 1 } },
    });
    expect(drag).toBeNull();
  });

  it("picks the pile it covers most when it lands over two", () => {
    const one = places.columns[1].cards[0];
    // Two thirds over column 2, one third over column 1.
    const { action } = dragBy(seven, one.x + 54 - seven.x, one.y + 18 - seven.y);
    expect(action.move.to).toEqual({ pile: "tableau", col: 2 });
  });

  it("goes back when dropped on the felt or on a pile that does not take it", () => {
    expect(dragBy(seven, 300, 250).action).toEqual({
      type: "return",
      from: { pile: "tableau", col: 0, index: 0 },
    });
    const waste = places.waste[0];
    const wrong = places.columns[1].cards[0];
    expect(dragBy(waste, wrong.x - waste.x, wrong.y + 18 - waste.y).action.type).toBe("return");
  });

  it("goes back when the browser takes the press away", () => {
    const { drag } = interpret(state, null, { type: "dragStart", x: seven.x + 10, y: seven.y + 5 });
    expect(interpret(state, drag, { type: "dragCancel" })).toEqual({
      drag: null,
      action: { type: "return", from: { pile: "tableau", col: 0, index: 0 } },
    });
  });

  it("picks up nothing face down, nor a waste card another covers", () => {
    const hidden = places.columns[0].cards[0];
    expect(
      interpret(state, null, { type: "dragStart", x: hidden.x + 4, y: hidden.y + 2 }).drag,
    ).toBeNull();
    const fanned = table({ mode: MODE.DRAW3, waste: [card(1, S), card(2, S), card(3, S)], fan: 3 });
    const covered = layout(fanned).waste[0];
    expect(
      interpret(fanned, null, { type: "dragStart", x: covered.x + 2, y: covered.y + 40 }).drag,
    ).toBeNull();
  });
});

describe("bestDestination", () => {
  it("answers nothing for a foundation card with no column to take it", () => {
    const state = table({ foundations: [[card(1, S)], [], [], []] });
    expect(bestDestination(state, { pile: "foundation", suit: S })).toBeNull();
  });
});
