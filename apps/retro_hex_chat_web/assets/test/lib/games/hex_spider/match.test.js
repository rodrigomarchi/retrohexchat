import { describe, expect, it } from "vitest";
import { PHASE } from "../../../../js/lib/games/core/card_table/table.js";
import { faceOf, suitOf } from "../../../../js/lib/games/core/cards.js";
import HexSpider from "../../../../js/lib/games/hex_spider/index.js";
import { layout } from "../../../../js/lib/games/hex_spider/layout.js";
import { GEOMETRY } from "../../../../js/lib/games/hex_spider/protocol.js";
import {
  itEndsEarly,
  itReplays,
  soloMatches,
  underway,
} from "../../../support/games/solo_tests.js";
import { S, card, itStandsUpWithMinis } from "../../../support/games/card_tables.js";

const suitRun = (copy) => Array.from({ length: 13 }, (_, i) => card(13 - i, S, copy));
/** A tap a little inside a place. */
const tapOn = (match, r) => match.tap(r.x + 10, r.y + 10);

describe("a match of Hex Spider", () => {
  const solo = soloMatches(HexSpider, "hex_spider", { left: 0, top: 0, width: 720, height: 540 });

  it("begins dealt, and a tap on the stock deals a row for a point", async () => {
    const { match, host } = await underway(solo);
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
    const { match, host } = await underway(solo);
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
    const { match, host } = await underway(solo);
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

  itStandsUpWithMinis(solo, GEOMETRY);

  itEndsEarly("ends early with the points it holds", solo, { points: 500 });

  itReplays(solo, async () => {
    const dealt = await solo();
    const stock = layout(dealt.engines.host.gameState.table).stock.at(-1);
    dealt.stop();
    dealt.restore();
    return [300, 900].map((at) => [at, stock.x + 10, stock.y + 10]);
  });
});
