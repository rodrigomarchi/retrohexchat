import { describe, expect, it } from "vitest";
import { PHASE } from "../../../../js/lib/games/core/card_table/table.js";
import HexFreeCell from "../../../../js/lib/games/hex_freecell/index.js";
import { layout } from "../../../../js/lib/games/hex_freecell/layout.js";
import { GEOMETRY } from "../../../../js/lib/games/hex_freecell/protocol.js";
import {
  itEndsEarly,
  itReplays,
  soloMatches,
  underway,
} from "../../../support/games/solo_tests.js";
import { C, D, H, S, card, itStandsUpWithMinis } from "../../../support/games/card_tables.js";
import { table as freeCell } from "./tables.js";

const upTo = (rank, suit) => Array.from({ length: rank }, (_, r) => card(r + 1, suit));
/** A tap a little inside a place. */
const tapOn = (match, r) => match.tap(r.x + 10, r.y + 10);
/** The host's table replaced by the one given, the clock running. */
function setTable(host, table) {
  host.gameState = {
    ...host.gameState,
    table: { ...host.gameState.table, ...freeCell(table) },
    clock: { started: true, ticks: 0 },
  };
}

describe("a match of Hex FreeCell", () => {
  const solo = soloMatches(HexFreeCell, "hex_freecell");

  it("begins with the whole deck face up, and a tap sends a card on and starts the clock", async () => {
    const { match, host } = await underway(solo);
    expect(host.gameState.phase).toBe(PHASE.PLAYING);
    expect(host.gameState.table.columns.flat()).toHaveLength(52);

    const foot = layout(host.gameState.table).columns[7].cards.at(-1);
    tapOn(match, foot);
    match.advance(100);
    expect(host.gameState.table.columns[7]).toHaveLength(5);
    expect(host.gameState.clock.started).toBe(true);
  });

  it("sends the cards no one can want up by themselves, one after another", async () => {
    const { match, host } = await underway(solo);
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
    const { match, host } = await underway(solo);
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
    const { match, host } = await underway(solo);
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
    const { match, host } = await underway(solo);
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

  itStandsUpWithMinis(solo, GEOMETRY);

  itEndsEarly("ends early with the points it holds", solo, { points: 0 });

  itReplays(
    solo,
    [300, 600, 900].map((at, i) => [at, 29 + i * 74 + 10, 132 + 6 * 18 + 10]),
  );
});
