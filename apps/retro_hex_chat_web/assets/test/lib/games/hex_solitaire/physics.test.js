import { describe, expect, it } from "vitest";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import {
  AUTO_TICKS,
  EVENT,
  MODE,
  PHASE,
  SAFETY_TICKS,
} from "../../../../js/lib/games/hex_solitaire/protocol.js";
import {
  act,
  createInitialState,
  finalScore,
  step,
} from "../../../../js/lib/games/hex_solitaire/physics.js";

const S = 0;
const H = 1;
const card = (rank, suit) => suit * 13 + rank - 1;
const full = (suit, upTo = 13) => Array.from({ length: upTo }, (_, r) => card(r + 1, suit));

function playing(table, extra = {}) {
  const tableau = Array.from({ length: 7 }, (_, i) => ({
    down: table.columns?.[i]?.down ?? [],
    up: table.columns?.[i]?.up ?? [],
  }));
  return {
    ...createInitialState(createRng(1).next, MODE.DRAW1),
    phase: PHASE.PLAYING,
    table: {
      mode: table.mode ?? MODE.DRAW1,
      stock: table.stock ?? [],
      waste: table.waste ?? [],
      fan: table.fan ?? (table.waste?.length ? 1 : 0),
      foundations: table.foundations ?? [[], [], [], []],
      tableau,
    },
    ...extra,
  };
}

const move = (from, to) => ({ type: "move", move: { from, to } });
const waste = { pile: "waste" };
const foundation = (suit) => ({ pile: "foundation", suit });
const column = (col, index = 0) => ({ pile: "tableau", col, index });

describe("a new match", () => {
  it("is dealt, waiting, at no points, with the clock stopped", () => {
    const state = createInitialState(createRng(5).next, MODE.DRAW3);
    expect(state.phase).toBe(PHASE.WAITING);
    expect(state.table.mode).toBe(MODE.DRAW3);
    expect(state.table.stock).toHaveLength(24);
    expect(state.score).toBe(0);
    expect(state.clock).toEqual({ started: false, ticks: 0 });
    expect(state.events).toBe(EVENT.DEAL);
  });
});

describe("act", () => {
  it("turns the stock, starts the clock and says so", () => {
    const after = act(playing({ stock: [card(5, S)] }), { type: "draw" });
    expect(after.table.waste).toEqual([card(5, S)]);
    expect(after.clock.started).toBe(true);
    expect(after.events & EVENT.DRAW).toBeTruthy();
  });

  it("pays a move and the card it turns over", () => {
    const state = playing({ columns: [{ down: [card(9, S)], up: [card(1, H)] }] });
    const after = act(state, move(column(0), foundation(H)));
    expect(after.score).toBe(15);
    expect(after.events & EVENT.FOUNDATION).toBeTruthy();
    expect(after.events & EVENT.FLIP).toBeTruthy();
  });

  it("charges for turning the waste back, never below zero", () => {
    const state = playing({ waste: [card(3, S)] }, { score: 40 });
    const after = act(state, { type: "recycle" });
    expect(after.score).toBe(0);
    expect(after.events & EVENT.RECYCLE).toBeTruthy();
  });

  it("changes nothing but the events for a refusal or a card going back", () => {
    const state = playing({ waste: [card(3, S)] });
    for (const [action, bit] of [
      [{ type: "refuse", from: waste }, EVENT.REFUSE],
      [{ type: "return", from: waste }, EVENT.RETURN],
    ]) {
      const after = act(state, action);
      expect(after.table).toEqual(state.table);
      expect(after.clock.started).toBe(false);
      expect(after.events & bit).toBeTruthy();
    }
  });

  it("ignores a move the rules refuse", () => {
    const state = playing({ waste: [card(3, S)] });
    expect(act(state, move(waste, foundation(S))).table).toEqual(state.table);
  });

  it("celebrates the last card up: the match is won", () => {
    const state = playing({
      foundations: [full(0), full(1), full(2), full(3, 12)],
      columns: [{ up: [card(13, 3)] }],
    });
    const after = act(state, move(column(0), foundation(3)));
    expect(after.phase).toBe(PHASE.CELEBRATING);
    expect(after.won).toBe(true);
    expect(after.events & EVENT.WIN).toBeTruthy();
  });

  it("finishes by itself once nothing is left hidden", () => {
    const state = playing({
      columns: [{ down: [card(2, S)], up: [card(1, S)] }, { up: [card(1, H)] }],
    });
    const after = act(state, move(column(0), foundation(S)));
    expect(after.phase).toBe(PHASE.AUTO_FINISH);
  });
});

describe("step", () => {
  it("counts the clock only once it started, two points off every ten seconds", () => {
    let state = playing({ stock: [card(1, S)] }, { score: 10 });
    for (let i = 0; i < 600; i++) state = step(state);
    expect(state.clock.ticks).toBe(0);

    state = act(state, { type: "draw" });
    for (let i = 0; i < 600; i++) state = step(state);
    expect(state.clock.ticks).toBe(600);
    expect(state.score).toBe(8);
  });

  it("clears the tick's events", () => {
    const state = act(playing({ stock: [card(1, S)] }), { type: "draw" });
    expect(step(state).events).toBe(0);
  });

  it("ends the match when the safety clock runs out", () => {
    const state = playing({}, { clock: { started: true, ticks: SAFETY_TICKS - 1 } });
    expect(step(state).phase).toBe(PHASE.FINISHED);
    expect(step(state).won).toBe(false);
  });

  it("sends a card up every few ticks while finishing, and wins with the last", () => {
    let state = playing({
      foundations: [full(0, 12), full(1, 12), full(2, 12), full(3, 12)],
      columns: [0, 1, 2, 3].map((suit) => ({ up: [card(13, suit)] })),
    });
    state = { ...state, phase: PHASE.AUTO_FINISH, clock: { started: true, ticks: 0 } };
    for (let i = 0; i < AUTO_TICKS; i++) state = step(state);
    expect(state.table.foundations.map((pile) => pile.length)).toEqual([13, 12, 12, 12]);
    for (let i = 0; i < 3 * AUTO_TICKS; i++) state = step(state);
    expect(state.phase).toBe(PHASE.CELEBRATING);
    expect(state.won).toBe(true);
    expect(state.score).toBe(40);
  });

  it("stops the clock while the cards go up by themselves", () => {
    let state = playing({ columns: [{ down: [], up: [card(2, S)] }, { up: [card(1, S)] }] });
    state = { ...state, phase: PHASE.AUTO_FINISH, clock: { started: true, ticks: 590 }, score: 10 };
    for (let i = 0; i < 3; i++) state = step(state);
    expect(state.clock.ticks).toBe(590);
  });
});

describe("finalScore", () => {
  it("adds the time bonus to a win and nothing to a game left unfinished", () => {
    const base = playing({}, { score: 500, clock: { started: true, ticks: 100 * 60 } });
    expect(finalScore({ ...base, won: true })).toBe(7_500);
    expect(finalScore({ ...base, won: false })).toBe(500);
  });
});
