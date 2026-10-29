import { describe, expect, it } from "vitest";
import HexSolitaire from "../../../../js/lib/games/hex_solitaire/index.js";
import { layout } from "../../../../js/lib/games/hex_solitaire/layout.js";
import { GEOMETRY, MODE, PHASE } from "../../../../js/lib/games/hex_solitaire/protocol.js";
import { card } from "../../../support/games/card_tables.js";
import {
  itEndsEarly,
  itReplays,
  soloMatches,
  underway,
} from "../../../support/games/solo_tests.js";

const full = (suit, upTo = 13) => Array.from({ length: upTo }, (_, r) => card(r + 1, suit));
const centre = (r) => [r.x + 20, r.y + 20];
/** A tap on the stock, and a tenth of a second for it to play. */
function tapStock(match, host) {
  match.tap(...centre(layout(host.gameState.table).stock));
  match.advance(100);
}

/** The host's table one move from a win: the king of clubs alone in the first column. */
function oneMoveFromWin(host) {
  const tableau = Array.from({ length: 7 }, (_, i) => ({
    down: [],
    up: i === 0 ? [card(13, 3)] : [],
  }));
  return {
    ...host.gameState,
    table: {
      ...host.gameState.table,
      stock: [],
      waste: [],
      fan: 0,
      tableau,
      foundations: [full(0), full(1), full(2), full(3, 12)],
    },
  };
}

describe("a match of Hex Solitaire", () => {
  // The canvas has twice the game's pixels; the page lays it out at the game's size.
  const solo = soloMatches(HexSolitaire, "hex_solitaire");

  it("begins dealt, and a tap on the stock turns a card and starts the clock", async () => {
    const { match, host } = await underway(solo);
    expect(host.gameState.phase).toBe(PHASE.PLAYING);
    expect(host.gameState.table.mode).toBe(MODE.DRAW1);

    tapStock(match, host);
    expect(host.gameState.table.waste).toHaveLength(1);
    expect(host.gameState.clock.started).toBe(true);
  });

  it("turns the back of the cards with a tap on the stock before the match begins", async () => {
    const { match, host } = await underway(solo, { begin: false });
    const back = host.back;
    tapStock(match, host);

    expect(host.back).toBe((back + 1) % 4);
    expect(host.gameState.phase).toBe(PHASE.WAITING);
    expect(host.gameState.table.waste).toEqual([]);
  });

  it("draws the table at rest once the deal has landed, not its last moment in the air", async () => {
    const match = await solo();
    const { canvas } = match.engines.host;
    match.advance(1000);
    canvas.recording = true;
    canvas.clearLog();
    match.advance(3000);
    const log = canvas.log;
    const lastFrame = log.slice(
      log.findLastIndex(
        ([op, ...a]) => op === "fillRect" && a[0] === 0 && a[1] === 0 && a[2] === 640,
      ),
    );
    // A card in the air casts a shadow; at rest none does.
    expect(
      lastFrame.some(([op, , value]) => op === "fillStyle" && value === "rgba(0,0,0,0.35)"),
    ).toBe(false);
    expect(lastFrame.length).toBeGreaterThan(0);
  });

  it("stands the table up in a box taller than wide, as on a phone held upright", async () => {
    const { match, host } = await underway(solo, {
      rect: { left: 0, top: 0, width: 360, height: 560 },
    });
    expect(host.view).toEqual(GEOMETRY.PORTRAIT.view);
    expect(host.gameState.table.geometry).toBe(GEOMETRY.PORTRAIT);

    // A tap on the stock, where the standing table has it on the screen.
    const stock = layout(host.gameState.table).stock;
    const scale = 360 / GEOMETRY.PORTRAIT.view.width;
    const top = (560 - GEOMETRY.PORTRAIT.view.height * scale) / 2;
    const x = (stock.x + 20) * scale;
    const y = top + (stock.y + 20) * scale;
    match.tap(x, y);
    match.advance(100);
    expect(host.gameState.table.waste).toHaveLength(1);
  });

  it("lies the table down in a box wider than tall", async () => {
    const match = await solo();
    expect(match.engines.host.view).toEqual(GEOMETRY.LANDSCAPE.view);
    expect(match.engines.host.gameState.table.geometry).toBe(GEOMETRY.LANDSCAPE);
  });

  it("plays draw three for its mode", async () => {
    const match = await solo({ gameId: "hex_solitaire_draw3" });
    expect(match.engines.host.gameState.table.mode).toBe(MODE.DRAW3);
  });

  it("wins a table one move from the end, reporting the score with its time bonus once", async () => {
    const { match, host } = await underway(solo);
    host.gameState = { ...oneMoveFromWin(host), score: 100, clock: { started: true, ticks: 0 } };
    const [x, y] = centre(layout(host.gameState.table).columns[0].cards[0]);
    match.tap(x, y);
    match.advance(200);

    // The cascade plays before the result is told, so the page still shows it.
    expect(host.gameState.phase).toBe(PHASE.CELEBRATING);
    expect(match.results.host).toEqual([]);
    expect(match.runUntil(() => match.over(), 15_000)).toBe(true);
    expect(host.gameState.phase).toBe(PHASE.FINISHED);
    expect(match.results.host).toHaveLength(1);
    expect(match.results.host[0].score.p1).toBe(110);
  });

  it("ends the celebration at a tap", async () => {
    const { match, host } = await underway(solo);
    host.gameState = oneMoveFromWin(host);
    const [x, y] = centre(layout(host.gameState.table).columns[0].cards[0]);
    match.tap(x, y);
    match.advance(300);
    match.tap(300, 300);
    match.advance(100);

    expect(host.gameState.phase).toBe(PHASE.FINISHED);
    expect(match.results.host).toHaveLength(1);
  });

  it("drags a card onto a column that takes it", async () => {
    const { match, host } = await underway(solo);
    const tableau = Array.from({ length: 7 }, (_, i) => ({
      down: [],
      up: i === 0 ? [card(7, 0)] : i === 1 ? [card(6, 1)] : [],
    }));
    host.gameState = { ...host.gameState, table: { ...host.gameState.table, tableau } };
    const places = layout(host.gameState.table);
    const six = places.columns[1].cards[0];
    const seven = places.columns[0].cards[0];
    match.pointer("down", six.x + 10, six.y + 10);
    match.pointer("move", six.x + 30, six.y + 30);
    match.pointer("move", seven.x + 10, seven.y + 28);
    match.pointer("up", seven.x + 10, seven.y + 28);
    match.advance(200);

    expect(host.gameState.table.tableau[0].up).toEqual([card(7, 0), card(6, 1)]);
    expect(host.drag).toBeNull();
  });

  itEndsEarly("ends early with the points it holds", solo);

  itReplays(solo, [
    [300, 70, 70],
    [600, 70, 70],
  ]);
});
