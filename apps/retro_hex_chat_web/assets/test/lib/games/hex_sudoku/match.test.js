import { afterEach, describe, expect, it } from "vitest";
import { PHASE } from "../../../../js/lib/games/core/solo/phases.js";
import HexSudoku from "../../../../js/lib/games/hex_sudoku/index.js";
import { squarePlace } from "../../../../js/lib/games/hex_sudoku/layout.js";
import { LEVEL, PENALTY } from "../../../../js/lib/games/hex_sudoku/protocol.js";
import { solveLogically } from "../../../../js/lib/games/hex_sudoku/solver.js";
import { winPoints } from "../../../../js/lib/games/hex_sudoku/scoring.js";
import { playMatch } from "../../../support/games/harness.js";

const rect = { left: 0, top: 0, width: 640, height: 480 };
const solo = (options = {}) =>
  playMatch({
    EngineClass: HexSudoku,
    gameId: "hex_sudoku",
    mode: "solo",
    matchSeed: 42,
    rect,
    ...options,
  });
const centre = (r) => [r.x + r.w / 2, r.y + r.h / 2];
const tap = (match, [x, y]) => {
  match.pointer("down", x, y);
  match.pointer("up", x, y);
};
/** A match with its grid made. */
async function ready(options) {
  const match = await solo(options);
  expect(match.runUntil(() => match.engines.host.gameState.board !== null, 5_000)).toBe(true);
  return match;
}
/** The first empty square, the digit it takes and one it does not. */
function emptySquare(board) {
  const i = board.values.indexOf(0);
  const right = board.solution[i];
  return { i, right, wrong: (right % 9) + 1 };
}

describe("a match of Hex Sudoku", () => {
  let match;

  afterEach(() => {
    match?.stop();
    match?.restore();
    match = null;
  });

  it("makes an easy grid at the start, the clock stopped until the first move", async () => {
    match = await ready();
    const { host } = match.engines;
    const { board, clock, phase } = host.gameState;
    expect(phase).toBe(PHASE.PLAYING);
    const given = board.given.filter(Boolean).length;
    expect(given).toBeGreaterThanOrEqual(LEVEL.hex_sudoku.givens[0]);
    expect(solveLogically(board.values, 1).solved).toBe(true);
    expect(clock.started).toBe(false);
  });

  it("puts a digit tapped on the keypad into the square tapped, and starts the clock", async () => {
    match = await ready();
    const { host } = match.engines;
    const { i, right } = emptySquare(host.gameState.board);
    tap(match, centre(squarePlace(host.laid, i)));
    tap(match, centre(host.laid.keys[right - 1]));
    match.advance(50);
    expect(host.gameState.board.values[i]).toBe(right);
    expect(host.gameState.mistakes).toBe(0);
    expect(host.gameState.clock.started).toBe(true);
  });

  it("counts a wrong digit as a mistake, half a minute on the clock", async () => {
    match = await ready();
    const { host } = match.engines;
    const { i, wrong } = emptySquare(host.gameState.board);
    tap(match, centre(squarePlace(host.laid, i)));
    tap(match, centre(host.laid.keys[wrong - 1]));
    match.advance(20);
    expect(host.gameState.board.values[i]).toBe(wrong);
    expect(host.gameState.mistakes).toBe(1);
    expect(host.gameState.clock.ticks).toBeGreaterThanOrEqual(PENALTY.MISTAKE);
  });

  it("pencils notes in with the pencil on, and undoes them", async () => {
    match = await ready();
    const { host } = match.engines;
    const { i } = emptySquare(host.gameState.board);
    tap(match, centre(squarePlace(host.laid, i)));
    tap(match, centre(host.laid.tools.pencil));
    tap(match, centre(host.laid.keys[1]));
    tap(match, centre(host.laid.keys[4]));
    match.advance(50);
    expect(host.gameState.pencil).toBe(true);
    expect(host.gameState.board.notes[i]).toBe(0b10010);
    tap(match, centre(host.laid.tools.undo));
    match.advance(50);
    expect(host.gameState.board.notes[i]).toBe(0b10);
  });

  it("plays from the keyboard: arrows, digits, the pencil, erasing", async () => {
    match = await ready();
    const { host } = match.engines;
    const board = host.gameState.board;
    // From the centre, one square left.
    match.key("host", "ArrowUp");
    match.key("host", "ArrowLeft");
    match.advance(50);
    expect(host.gameState.selected).toBe(39);
    tap(match, centre(squarePlace(host.laid, emptySquare(board).i)));
    match.advance(20);
    const { i, right } = emptySquare(board);
    match.key("host", "n");
    match.key("host", String(right));
    match.advance(50);
    expect(host.gameState.board.notes[i]).toBe(1 << (right - 1));
    match.key("host", "N");
    match.key("host", String(right));
    match.advance(50);
    expect(host.gameState.board.values[i]).toBe(right);
    match.key("host", "Backspace");
    match.advance(50);
    expect(host.gameState.board.values[i]).toBe(0);
  });

  it("erases the chosen square with the eraser on the screen", async () => {
    match = await ready();
    const { host } = match.engines;
    const { i, wrong } = emptySquare(host.gameState.board);
    tap(match, centre(squarePlace(host.laid, i)));
    tap(match, centre(host.laid.keys[wrong - 1]));
    match.advance(20);
    expect(host.gameState.board.values[i]).toBe(wrong);
    tap(match, centre(host.laid.tools.eraser));
    match.advance(20);
    expect(host.gameState.board.values[i]).toBe(0);
  });

  it("wins when an undo brings back the last digit the grid lacked", async () => {
    match = await ready();
    const { host } = match.engines;
    const { board } = host.gameState;
    const [last, mine] = board.values.flatMap((v, i) => (v ? [] : [i]));
    const values = board.values.map((v, i) => (i === last ? 0 : board.solution[i]));
    host.gameState = { ...host.gameState, board: { ...board, values } };
    // Erase a digit of one's own, have the last square revealed, then undo the erase.
    tap(match, centre(squarePlace(host.laid, mine)));
    tap(match, centre(host.laid.tools.eraser));
    tap(match, centre(squarePlace(host.laid, last)));
    tap(match, centre(host.laid.tools.hint));
    tap(match, centre(host.laid.tools.undo));
    expect(match.runUntil(() => match.over(), 5_000)).toBe(true);
    expect(host.gameState.won).toBe(true);
  });

  it("reveals the chosen square with a hint, a minute on the clock", async () => {
    match = await ready();
    const { host } = match.engines;
    const { i, right } = emptySquare(host.gameState.board);
    tap(match, centre(squarePlace(host.laid, i)));
    tap(match, centre(host.laid.tools.hint));
    match.advance(20);
    expect(host.gameState.board.values[i]).toBe(right);
    expect(host.gameState.board.hinted[i]).toBe(true);
    expect(host.gameState.hints).toBe(1);
    expect(host.gameState.clock.ticks).toBeGreaterThanOrEqual(PENALTY.HINT);
  });

  it("wins with the last digit, scoring its time", async () => {
    match = await ready();
    const { host } = match.engines;
    const { board } = host.gameState;
    const last = board.values.indexOf(0);
    const values = board.values.map((v, i) => (i === last ? 0 : board.solution[i]));
    host.gameState = {
      ...host.gameState,
      board: { ...board, values },
      clock: { started: true, ticks: 36_000 },
    };
    tap(match, centre(squarePlace(host.laid, last)));
    tap(match, centre(host.laid.keys[board.solution[last] - 1]));
    expect(match.runUntil(() => match.over(), 5_000)).toBe(true);
    expect(host.gameState.won).toBe(true);
    const score = match.results.host[0].score.p1;
    expect(score).toBeLessThanOrEqual(winPoints(36_000));
    expect(score).toBeGreaterThan(winPoints(36_000) - 5);
  });

  it("ends early with nothing scored", async () => {
    match = await ready();
    match.engines.host.quit();
    expect(match.results.host).toEqual([{ score: { p1: 0, p2: 0 }, ended_early: true }]);
  });

  it("makes the same grid for the same seed, a hard one for the hard level", async () => {
    const grid = async (options) => {
      const m = await ready(options);
      const { values } = m.engines.host.gameState.board;
      m.stop();
      m.restore();
      return values;
    };
    expect(await grid()).toEqual(await grid());
    expect(await grid()).not.toEqual(await grid({ matchSeed: 43 }));
    const hard = await grid({ gameId: "hex_sudoku_hard" });
    expect(solveLogically(hard, 2).solved).toBe(false);
    expect(solveLogically(hard, 3).solved).toBe(true);
  });

  it("stands the keypad under the grid on a phone held upright", async () => {
    match = await ready({ rect: { left: 0, top: 0, width: 360, height: 600 } });
    const { laid } = match.engines.host;
    expect(laid.keys[0].y).toBeGreaterThan(laid.grid.y + laid.grid.h);
  });
});
