import { afterEach, describe, expect, it } from "vitest";
import { PHASE } from "../../../../js/lib/games/core/card_table/table.js";
import { faceOf, suitOf } from "../../../../js/lib/games/core/cards.js";
import HexSpider from "../../../../js/lib/games/hex_spider/index.js";
import { layout } from "../../../../js/lib/games/hex_spider/layout.js";
import { GEOMETRY } from "../../../../js/lib/games/hex_spider/protocol.js";
import { playMatch } from "../../../support/games/harness.js";

const S = 0;
const card = (rank, suit, copy = 0) => copy * 52 + suit * 13 + rank - 1;
const suitRun = (copy) => Array.from({ length: 13 }, (_, i) => card(13 - i, S, copy));
const rect = { left: 0, top: 0, width: 720, height: 540 };
const solo = (options = {}) =>
  playMatch({
    EngineClass: HexSpider,
    gameId: "hex_spider",
    mode: "solo",
    matchSeed: 42,
    rect,
    ...options,
  });
const tapOn = (match, r) => {
  match.pointer("down", r.x + 10, r.y + 10);
  match.pointer("up", r.x + 10, r.y + 10);
};

describe("a match of Hex Spider", () => {
  let match;

  afterEach(() => {
    match?.stop();
    match?.restore();
    match = null;
  });

  it("begins dealt, and a tap on the stock deals a row for a point", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    expect(host.gameState.phase).toBe(PHASE.PLAYING);
    expect(host.gameState.score).toBe(500);

    tapOn(match, layout(host.gameState.table).stock.at(-1));
    match.advance(100);
    expect(host.gameState.table.stock).toHaveLength(40);
    expect(host.gameState.score).toBe(499);
    expect(host.gameState.clock.started).toBe(true);
  });

  it("deals the suits of its variant", async () => {
    for (const [gameId, suits] of [
      ["hex_spider_2suits", 2],
      ["hex_spider_4suits", 4],
    ]) {
      const m = await solo({ gameId });
      const { table } = m.engines.host.gameState;
      const all = [...table.columns.flatMap((c) => [...c.down, ...c.up]), ...table.stock];
      expect(new Set(all.map((c) => suitOf(faceOf(c)))).size).toBe(suits);
      m.stop();
      m.restore();
    }
  });

  it("wins with the last suit, celebrates and reports the score once", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    const last = suitRun(7);
    const columns = Array.from({ length: 10 }, (_, i) => ({
      down: [],
      up: i === 0 ? last.slice(0, 12) : i === 1 ? [last[12]] : [],
    }));
    host.gameState = {
      ...host.gameState,
      table: {
        ...host.gameState.table,
        columns,
        stock: [],
        foundations: Array.from({ length: 7 }, (_, i) => suitRun(i)),
      },
      score: 700,
      clock: { started: true, ticks: 0 },
    };
    tapOn(match, layout(host.gameState.table).columns[1].cards[0]);
    match.advance(200);
    expect(host.gameState.phase).toBe(PHASE.CELEBRATING);
    expect(match.runUntil(() => match.over(), 20_000)).toBe(true);
    expect(match.results.host).toHaveLength(1);
    expect(match.results.host[0].score.p1).toBe(799);
  });

  it("pays a hundred for each suit a row puts away, two at once", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    const columns = Array.from({ length: 10 }, (_, i) => ({
      down: [],
      up: i < 2 ? suitRun(i).slice(0, 12) : [card(13, S, i % 8)],
    }));
    const stock = [
      ...Array.from({ length: 8 }, (_, i) => card(13, S, i)),
      card(1, S, 1),
      card(1, S, 0),
    ];
    host.gameState = {
      ...host.gameState,
      table: { ...host.gameState.table, columns, stock, foundations: [] },
      score: 500,
    };
    tapOn(match, layout(host.gameState.table).stock.at(-1));
    match.advance(200);
    expect(host.gameState.table.foundations).toHaveLength(2);
    expect(host.gameState.score).toBe(699);
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
    expect(match.results.host).toEqual([{ score: { p1: 500, p2: 0 }, ended_early: true }]);
  });

  it("plays the same match for the same seed and the same presses", async () => {
    const stock = layout({ ...(await solo()).engines.host.gameState.table }).stock.at(-1);
    const script = [300, 900].flatMap((at) => [
      { at, side: "host", pointer: "down", x: stock.x + 10, y: stock.y + 10 },
      { at: at + 30, side: "host", pointer: "up", x: stock.x + 10, y: stock.y + 10 },
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
