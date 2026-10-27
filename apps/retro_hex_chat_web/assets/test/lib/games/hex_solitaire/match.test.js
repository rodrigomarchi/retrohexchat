import { afterEach, describe, expect, it } from "vitest";
import HexSolitaire from "../../../../js/lib/games/hex_solitaire/index.js";
import { layout } from "../../../../js/lib/games/hex_solitaire/layout.js";
import { MODE, PHASE } from "../../../../js/lib/games/hex_solitaire/protocol.js";
import { playMatch } from "../../../support/games/harness.js";

const card = (rank, suit) => suit * 13 + rank - 1;
const full = (suit, upTo = 13) => Array.from({ length: upTo }, (_, r) => card(r + 1, suit));
// The canvas has twice the game's pixels; the page lays it out at the game's size.
const rect = { left: 0, top: 0, width: 640, height: 480 };
const solo = (options = {}) =>
  playMatch({
    EngineClass: HexSolitaire,
    gameId: "hex_solitaire",
    mode: "solo",
    matchSeed: 42,
    rect,
    ...options,
  });
const centre = (r) => [r.x + 20, r.y + 20];

describe("a match of Hex Solitaire", () => {
  let match;

  afterEach(() => {
    match?.stop();
    match?.restore();
    match = null;
  });

  it("begins dealt, and a tap on the stock turns a card and starts the clock", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    expect(host.gameState.phase).toBe(PHASE.PLAYING);
    expect(host.gameState.table.mode).toBe(MODE.DRAW1);

    const [x, y] = centre(layout(host.gameState.table).stock);
    match.pointer("down", x, y);
    match.pointer("up", x, y);
    match.advance(100);
    expect(host.gameState.table.waste).toHaveLength(1);
    expect(host.gameState.clock.started).toBe(true);
  });

  it("plays draw three for its mode", async () => {
    match = await solo({ gameId: "hex_solitaire_draw3" });
    expect(match.engines.host.gameState.table.mode).toBe(MODE.DRAW3);
  });

  it("wins a table one move from the end, reporting the score with its time bonus once", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    const tableau = Array.from({ length: 7 }, (_, i) => ({
      down: [],
      up: i === 0 ? [card(13, 3)] : [],
    }));
    host.gameState = {
      ...host.gameState,
      table: {
        ...host.gameState.table,
        stock: [],
        waste: [],
        fan: 0,
        tableau,
        foundations: [full(0), full(1), full(2), full(3, 12)],
      },
      score: 100,
      clock: { started: true, ticks: 0 },
    };
    const [x, y] = centre(layout(host.gameState.table).columns[0].cards[0]);
    match.pointer("down", x, y);
    match.pointer("up", x, y);
    match.advance(2000);

    expect(host.gameState.phase).toBe(PHASE.FINISHED);
    expect(match.results.host).toHaveLength(1);
    expect(match.results.host[0].score.p1).toBe(110);
  });

  it("drags a card onto a column that takes it", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
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

  it("ends early with the points it holds", async () => {
    match = await solo();
    match.advance(500);
    match.engines.host.quit();
    expect(match.results.host).toEqual([{ score: { p1: 0, p2: 0 }, ended_early: true }]);
  });

  it("plays the same match for the same seed and the same presses", async () => {
    const script = [
      { at: 300, side: "host", pointer: "down", x: 70, y: 70 },
      { at: 330, side: "host", pointer: "up", x: 70, y: 70 },
      { at: 600, side: "host", pointer: "down", x: 70, y: 70 },
      { at: 630, side: "host", pointer: "up", x: 70, y: 70 },
    ];
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
