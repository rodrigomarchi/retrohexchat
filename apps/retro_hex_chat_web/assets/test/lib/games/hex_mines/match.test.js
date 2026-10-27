import { afterEach, describe, expect, it } from "vitest";
import { PHASE } from "../../../../js/lib/games/core/solo/phases.js";
import HexMines from "../../../../js/lib/games/hex_mines/index.js";
import { boardPlace } from "../../../../js/lib/games/hex_mines/layout.js";
import { CELL } from "../../../../js/lib/games/hex_mines/rules.js";
import { playMatch } from "../../../support/games/harness.js";

const rect = { left: 0, top: 0, width: 640, height: 480 };
const solo = (options = {}) =>
  playMatch({
    EngineClass: HexMines,
    gameId: "hex_mines",
    mode: "solo",
    matchSeed: 42,
    rect,
    ...options,
  });
const centre = (host, i) => {
  const at = boardPlace(host.laid, i);
  return [at.x + at.w / 2, at.y + at.h / 2];
};
const click = (match, [x, y], button) => {
  match.pointer("down", x, y, button === undefined ? undefined : { button });
  match.pointer("up", x, y, button === undefined ? undefined : { button });
};
/** The host's board replaced: mines where `rows` has `*`, nothing open, the clock running. */
function setBoard(host, rows) {
  const mine = rows
    .join("")
    .split("")
    .map((c) => c === "*");
  host.gameState = {
    ...host.gameState,
    board: {
      ...host.gameState.board,
      mines: mine.filter(Boolean).length,
      mine,
      cell: mine.map(() => CELL.CLOSED),
    },
    clock: { started: true, ticks: 0 },
  };
}

describe("a match of Hex Mines", () => {
  let match;

  afterEach(() => {
    match?.stop();
    match?.restore();
    match = null;
  });

  it("lays the mines at the first click, away from it, opens it and starts the clock", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    expect(host.gameState.phase).toBe(PHASE.PLAYING);
    click(match, centre(host, 40));
    match.advance(100);
    const { board, clock } = host.gameState;
    expect(board.mine.filter(Boolean)).toHaveLength(10);
    expect(board.mine[40]).toBe(false);
    expect(board.cell[40]).toBe(CELL.OPEN);
    expect(clock.started).toBe(true);
  });

  it("flags with a right click, and with a long press", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    click(match, centre(host, 0), 2);
    match.advance(50);
    expect(host.gameState.board.cell[0]).toBe(CELL.FLAG);

    const [x, y] = centre(host, 8);
    match.pointer("down", x, y);
    match.advance(600);
    expect(host.gameState.board.cell[8]).toBe(CELL.FLAG);
    match.pointer("up", x, y);
    match.advance(50);
    expect(host.gameState.board.cell[8]).toBe(CELL.FLAG);
    expect(host.gameState.board.mine).toBeNull();
  });

  it("opens, never flags, a square a mouse holds down", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    const [x, y] = centre(host, 40);
    match.pointer("down", x, y, { pointerType: "mouse" });
    match.advance(600);
    match.pointer("up", x, y, { pointerType: "mouse" });
    match.advance(50);
    expect(host.gameState.board.cell[40]).toBe(CELL.OPEN);
  });

  it("flags with a tap once a phone is switched to flags", async () => {
    match = await solo({ rect: { left: 0, top: 0, width: 360, height: 600 } });
    match.advance(100);
    const { host } = match.engines;
    const scale = 360 / host.view.width;
    const top = (600 - host.view.height * scale) / 2;
    const page = ([x, y]) => [x * scale, top + y * scale];
    const mode = host.laid.mode;
    click(match, page([mode.x + mode.w / 2, mode.y + mode.h / 2]));
    match.advance(50);
    expect(host.gameState.mode).toBe("flag");
    click(match, page(centre(host, 10)));
    match.advance(50);
    expect(host.gameState.board.cell[10]).toBe(CELL.FLAG);
  });

  it("ends on a mine with nothing scored, once the board has shown it", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    setBoard(host, ["*........", ...Array.from({ length: 8 }, () => ".........")]);
    click(match, centre(host, 0));
    match.advance(100);
    expect(host.gameState.lost).toBe(true);
    expect(match.results.host).toEqual([]);
    expect(match.runUntil(() => match.over(), 5_000)).toBe(true);
    expect(match.results.host).toEqual([{ score: { p1: 0, p2: 0 }, winner: 0 }]);
  });

  it("wins with the last square, scoring its time", async () => {
    match = await solo();
    match.advance(100);
    const { host } = match.engines;
    setBoard(host, ["*........", ...Array.from({ length: 8 }, () => ".........")]);
    host.gameState = { ...host.gameState, clock: { started: true, ticks: 600 } };
    // One click floods every square but the mine's.
    click(match, centre(host, 80));
    expect(match.runUntil(() => match.over(), 5_000)).toBe(true);
    expect(host.gameState.won).toBe(true);
    expect(host.gameState.board.cell[0]).toBe(CELL.FLAG);
    expect(match.results.host[0].score.p1).toBeGreaterThan(900);
    expect(match.results.host[0].score.p1).toBeLessThanOrEqual(1000);
  });

  it("ends early with nothing scored", async () => {
    match = await solo();
    match.advance(500);
    match.engines.host.quit();
    expect(match.results.host).toEqual([{ score: { p1: 0, p2: 0 }, ended_early: true }]);
  });

  it("plays the same match for the same seed and the same presses", async () => {
    const final = async () => {
      const m = await solo();
      m.advance(100);
      const [x, y] = centre(m.engines.host, 40);
      m.pointer("down", x, y);
      m.pointer("up", x, y);
      m.advance(500);
      const state = JSON.stringify(m.engines.host.gameState);
      m.stop();
      m.restore();
      return state;
    };
    expect(await final()).toBe(await final());
  });
});
