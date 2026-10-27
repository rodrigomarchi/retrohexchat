import { afterEach, describe, expect, it } from "vitest";
import { PHASE } from "../../../../js/lib/games/core/card_table/table.js";
import HexFreeCell from "../../../../js/lib/games/hex_freecell/index.js";
import { layout } from "../../../../js/lib/games/hex_freecell/layout.js";
import { GEOMETRY } from "../../../../js/lib/games/hex_freecell/protocol.js";
import { playMatch } from "../../../support/games/harness.js";

const S = 0;
const H = 1;
const D = 2;
const C = 3;
const card = (rank, suit) => suit * 13 + rank - 1;
const upTo = (rank, suit) => Array.from({ length: rank }, (_, r) => card(r + 1, suit));
const rect = { left: 0, top: 0, width: 640, height: 480 };
const solo = (options = {}) =>
  playMatch({
    EngineClass: HexFreeCell,
    gameId: "hex_freecell",
    mode: "solo",
    matchSeed: 42,
    rect,
    ...options,
  });
const tapOn = (match, r) => {
  match.pointer("down", r.x + 10, r.y + 10);
  match.pointer("up", r.x + 10, r.y + 10);
};
/** The host's table replaced by the one given, the clock running. */
function setTable(host, table) {
  host.gameState = {
    ...host.gameState,
    table: {
      ...host.gameState.table,
      columns: Array.from({ length: 8 }, (_, i) => table.columns?.[i] ?? []),
      cells: Array.from({ length: 4 }, (_, i) => table.cells?.[i] ?? null),
      foundations: Array.from({ length: 4 }, (_, i) => table.foundations?.[i] ?? []),
    },
    clock: { started: true, ticks: 0 },
  };
}

describe("a match of Hex FreeCell", () => {
  let match;

  afterEach(() => {
    match?.stop();
    match?.restore();
    match = null;
  });

  it("begins with the whole deck face up, and a tap sends a card on and starts the clock", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    expect(host.gameState.phase).toBe(PHASE.PLAYING);
    expect(host.gameState.table.columns.flat()).toHaveLength(52);

    const foot = layout(host.gameState.table).columns[7].cards.at(-1);
    tapOn(match, foot);
    match.advance(100);
    expect(host.gameState.table.columns[7]).toHaveLength(5);
    expect(host.gameState.clock.started).toBe(true);
  });

  it("sends the cards no one can want up by themselves, one after another", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    setTable(host, {
      columns: [
        [card(13, S), card(2, H)],
        [card(13, H), card(1, H)],
        [card(12, D), card(9, C)],
      ],
    });
    match.advance(1000);
    expect(host.gameState.table.foundations[H]).toEqual([card(1, H), card(2, H)]);
    expect(host.gameState.score).toBe(20);
  });

  it("sends nothing up from under the player's hand while they hold it", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    setTable(host, {
      columns: [[card(13, S), card(1, H)], [card(13, H)], [card(12, D), card(9, C)]],
    });
    const ace = layout(host.gameState.table).columns[0].cards[1];
    match.pointer("down", ace.x + 10, ace.y + 10);
    match.pointer("move", ace.x + 40, ace.y + 60);
    match.advance(1000);
    expect(host.gameState.table.foundations[H]).toEqual([]);
    expect(host.drag.cards).toEqual([card(1, H)]);

    match.pointer("up", ace.x + 40, ace.y + 60);
    match.advance(1000);
    expect(host.gameState.table.foundations[H]).toEqual([card(1, H)]);
  });

  it("finishes by itself, celebrates and reports the score with its time bonus once", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    setTable(host, {
      columns: [[card(13, C)], [card(12, C)]],
      foundations: [upTo(13, S), upTo(13, H), upTo(13, D), upTo(11, C)],
    });
    host.gameState = { ...host.gameState, score: 100 };
    // The queen goes onto the king; every column runs down: the rest goes up.
    tapOn(match, layout(host.gameState.table).columns[1].cards[0]);
    expect(match.runUntil(() => match.over(), 20_000)).toBe(true);
    expect(host.gameState.won).toBe(true);
    expect(match.results.host).toHaveLength(1);
    expect(match.results.host[0].score.p1).toBe(120);
  });

  it("ends a table left with no move, with the points it holds", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    const tops = [5, 5, 5, 5, 9, 9, 9, 9].map((rank, i) => [card(rank, i % 4)]);
    setTable(host, {
      columns: [[card(13, S), card(6, H)], ...tops.slice(1)],
      cells: [card(13, H), card(13, D), card(13, C), null],
    });
    host.gameState = { ...host.gameState, score: 40 };
    // The six into the last cell: nothing can move after it.
    tapOn(match, layout(host.gameState.table).columns[0].cards[1]);
    match.advance(300);
    expect(host.gameState.stuck).toBe(true);
    expect(match.results.host).toEqual([{ score: { p1: 40, p2: 0 }, winner: 0 }]);
  });

  it("stands the table up with the minis in a box taller than wide", async () => {
    match = await solo({ rect: { left: 0, top: 0, width: 360, height: 600 } });
    match.advance(100);
    const { host } = match.engines;
    expect(host.view).toEqual(GEOMETRY.PORTRAIT.view);
    expect(host.fx.card).toEqual({ width: 44, height: 62 });
  });

  it("ends early with the points it holds", async () => {
    match = await solo();
    match.advance(500);
    match.engines.host.quit();
    expect(match.results.host).toEqual([{ score: { p1: 0, p2: 0 }, ended_early: true }]);
  });

  it("plays the same match for the same seed and the same presses", async () => {
    const script = [300, 600, 900].flatMap((at, i) => [
      { at, side: "host", pointer: "down", x: 29 + i * 74 + 10, y: 132 + 6 * 18 + 10 },
      { at: at + 30, side: "host", pointer: "up", x: 29 + i * 74 + 10, y: 132 + 6 * 18 + 10 },
    ]);
    const finalState = async () => {
      const m = await solo({ script });
      m.advance(2000);
      const state = JSON.stringify(m.engines.host.gameState);
      m.stop();
      m.restore();
      return state;
    };
    expect(await finalState()).toBe(await finalState());
  });
});
