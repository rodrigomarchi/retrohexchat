import { describe, expect, it } from "vitest";
import { createInterpreter } from "../../../../../js/lib/games/core/card_table/gestures.js";

// A table of two piles side by side, each a single card: what is under the
// point is the pile it lands on; a card may go only to the other pile.
const CARD = { width: 10, height: 10 };
const places = [
  { x: 0, y: 0, w: 10, h: 10 },
  { x: 20, y: 0, w: 10, h: 10 },
];
const rules = (overrides = {}) =>
  createInterpreter({
    card: CARD,
    hitTest: (state, x, y) => {
      const pile = places.findIndex((r) => x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h);
      return pile >= 0 ? { pile } : null;
    },
    pick: (state, hit) => (hit && state.piles[hit.pile].length ? hit : null),
    bestDestination: (state, from) => (state.open ? { from, to: { pile: 1 - from.pile } } : null),
    canMove: (state, move) => state.open && move.to.pile !== move.from.pile,
    cardsFrom: (state, from) => state.piles[from.pile],
    sourcePlace: (state, from) => places[from.pile],
    targets: () => places.map((r, pile) => ({ r, to: { pile } })),
    ...overrides,
  });
const state = { open: true, piles: [[5], []] };

describe("a card table's gestures", () => {
  it("sends a tapped card where the table says, and refuses when nowhere takes it", () => {
    const interpret = rules();
    expect(interpret(state, null, { type: "tap", x: 2, y: 2 }).action).toEqual({
      type: "move",
      move: { from: { pile: 0 }, to: { pile: 1 } },
    });
    expect(interpret({ ...state, open: false }, null, { type: "tap", x: 2, y: 2 }).action).toEqual({
      type: "refuse",
      from: { pile: 0 },
    });
    expect(interpret(state, null, { type: "tap", x: 15, y: 2 }).action).toBeNull();
  });

  it("lets the table answer a tap itself, and keeps a card a tap may not move", () => {
    const own = rules({ tap: (s, hit) => (hit?.pile === 1 ? { type: "draw" } : undefined) });
    expect(own(state, null, { type: "tap", x: 22, y: 2 }).action).toEqual({ type: "draw" });
    expect(own(state, null, { type: "tap", x: 2, y: 2 }).action.type).toBe("move");
    const kept = rules({ tapMoves: () => false });
    expect(kept(state, null, { type: "tap", x: 2, y: 2 }).action).toBeNull();
  });

  it("holds a dragged run under the finger and drops it on the pile it covers most", () => {
    const interpret = rules();
    const { drag } = interpret(state, null, { type: "dragStart", x: 3, y: 4 });
    expect(drag).toEqual({ from: { pile: 0 }, cards: [5], x: 0, y: 0, grabX: 3, grabY: 4 });
    const moved = interpret(state, drag, { type: "dragMove", x: 13, y: 4 }).drag;
    expect(moved).toMatchObject({ x: 10, y: 0 });
    // 9 of its pixels over the second pile, none over the first: it goes there.
    expect(interpret(state, moved, { type: "drop", x: 22, y: 4 }).action).toEqual({
      type: "move",
      move: { from: { pile: 0 }, to: { pile: 1 } },
    });
  });

  it("sends a run back when it is dropped on the felt, refused, or the press is taken away", () => {
    const interpret = rules();
    const { drag } = interpret(state, null, { type: "dragStart", x: 3, y: 4 });
    const back = { type: "return", from: { pile: 0 } };
    expect(interpret(state, drag, { type: "drop", x: 3, y: 60 }).action).toEqual(back);
    expect(interpret(state, drag, { type: "drop", x: 3, y: 4 }).action).toEqual(back);
    expect(interpret(state, drag, { type: "dragCancel" })).toEqual({ drag: null, action: back });
    expect(interpret(state, null, { type: "dragStart", x: 22, y: 2 }).drag).toBeNull();
  });
});
