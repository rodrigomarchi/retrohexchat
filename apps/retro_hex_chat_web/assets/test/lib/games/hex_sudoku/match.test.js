import { describe, expect, it } from "vitest";
import { PHASE } from "../../../../js/lib/games/core/solo/phases.js";
import HexSudoku from "../../../../js/lib/games/hex_sudoku/index.js";
import { squarePlace } from "../../../../js/lib/games/hex_sudoku/layout.js";
import { LEVEL, PENALTY } from "../../../../js/lib/games/hex_sudoku/protocol.js";
import { solveLogically } from "../../../../js/lib/games/hex_sudoku/solver.js";
import { winPoints } from "../../../../js/lib/games/hex_sudoku/scoring.js";
import { itEndsEarly, soloMatches } from "../../../support/games/solo_tests.js";

const solo = soloMatches(HexSudoku, "hex_sudoku");
const centre = (r) => [r.x + r.w / 2, r.y + r.h / 2];
/** A tap in the middle of a place. */
const tapOn = (match, place) => match.tap(...centre(place));
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
/** The first empty square given a wrong digit from the keypad, and shown it. */
async function wrongDigitIn() {
  const chosen = await choosingEmpty();
  const { match, host, i, wrong } = chosen;
  tapOn(match, host.laid.keys[wrong - 1]);
  match.advance(20);
  expect(host.gameState.board.values[i]).toBe(wrong);
  return chosen;
}

/** A match with its grid made and its first empty square chosen: the match, its host and that square. */
async function choosingEmpty() {
  const match = await ready();
  const { host } = match.engines;
  const square = emptySquare(host.gameState.board);
  tapOn(match, squarePlace(host.laid, square.i));
  return { match, host, ...square };
}

describe("a match of Hex Sudoku", () => {
  it("makes an easy grid at the start, the clock stopped until the first move", async () => {
    const match = await ready();
    const { host } = match.engines;
    const { board, clock, phase } = host.gameState;
    expect(phase).toBe(PHASE.PLAYING);
    const given = board.given.filter(Boolean).length;
    expect(given).toBeGreaterThanOrEqual(LEVEL.hex_sudoku.givens[0]);
    expect(solveLogically(board.values, 1).solved).toBe(true);
    expect(clock.started).toBe(false);
  });

  it("puts a digit tapped on the keypad into the square tapped, and starts the clock", async () => {
    const { match, host, i, right } = await choosingEmpty();
    tapOn(match, host.laid.keys[right - 1]);
    match.advance(50);
    expect(host.gameState.board.values[i]).toBe(right);
    expect(host.gameState.mistakes).toBe(0);
    expect(host.gameState.clock.started).toBe(true);
  });

  it("counts a wrong digit as a mistake, half a minute on the clock", async () => {
    const { host } = await wrongDigitIn();
    expect(host.gameState.mistakes).toBe(1);
    expect(host.gameState.clock.ticks).toBeGreaterThanOrEqual(PENALTY.MISTAKE);
  });

  it("pencils notes in with the pencil on, and undoes them", async () => {
    const { match, host, i } = await choosingEmpty();
    tapOn(match, host.laid.tools.pencil);
    tapOn(match, host.laid.keys[1]);
    tapOn(match, host.laid.keys[4]);
    match.advance(50);
    expect(host.gameState.pencil).toBe(true);
    expect(host.gameState.board.notes[i]).toBe(0b10010);
    tapOn(match, host.laid.tools.undo);
    match.advance(50);
    expect(host.gameState.board.notes[i]).toBe(0b10);
  });

  it("plays from the keyboard: arrows, digits, the pencil, erasing", async () => {
    const match = await ready();
    const { host } = match.engines;
    const board = host.gameState.board;
    // From the centre, one square left.
    match.key("host", "ArrowUp");
    match.key("host", "ArrowLeft");
    match.advance(50);
    expect(host.gameState.selected).toBe(39);
    tapOn(match, squarePlace(host.laid, emptySquare(board).i));
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
    const { match, host, i } = await wrongDigitIn();
    tapOn(match, host.laid.tools.eraser);
    match.advance(20);
    expect(host.gameState.board.values[i]).toBe(0);
  });

  it("wins when an undo brings back the last digit the grid lacked", async () => {
    const match = await ready();
    const { host } = match.engines;
    const { board } = host.gameState;
    const [last, mine] = board.values.flatMap((v, i) => (v ? [] : [i]));
    const values = board.values.map((v, i) => (i === last ? 0 : board.solution[i]));
    host.gameState = { ...host.gameState, board: { ...board, values } };
    // Erase a digit of one's own, have the last square revealed, then undo the erase.
    tapOn(match, squarePlace(host.laid, mine));
    tapOn(match, host.laid.tools.eraser);
    tapOn(match, squarePlace(host.laid, last));
    tapOn(match, host.laid.tools.hint);
    tapOn(match, host.laid.tools.undo);
    expect(match.runUntil(() => match.over(), 5_000)).toBe(true);
    expect(host.gameState.won).toBe(true);
  });

  it("reveals the chosen square with a hint, a minute on the clock", async () => {
    const { match, host, i, right } = await choosingEmpty();
    tapOn(match, host.laid.tools.hint);
    match.advance(20);
    expect(host.gameState.board.values[i]).toBe(right);
    expect(host.gameState.board.hinted[i]).toBe(true);
    expect(host.gameState.hints).toBe(1);
    expect(host.gameState.clock.ticks).toBeGreaterThanOrEqual(PENALTY.HINT);
  });

  it("wins with the last digit, scoring its time", async () => {
    const match = await ready();
    const { host } = match.engines;
    const { board } = host.gameState;
    const last = board.values.indexOf(0);
    const values = board.values.map((v, i) => (i === last ? 0 : board.solution[i]));
    host.gameState = {
      ...host.gameState,
      board: { ...board, values },
      clock: { started: true, ticks: 36_000 },
    };
    tapOn(match, squarePlace(host.laid, last));
    tapOn(match, host.laid.keys[board.solution[last] - 1]);
    expect(match.runUntil(() => match.over(), 5_000)).toBe(true);
    expect(host.gameState.won).toBe(true);
    const score = match.results.host[0].score.p1;
    expect(score).toBeLessThanOrEqual(winPoints(36_000));
    expect(score).toBeGreaterThan(winPoints(36_000) - 5);
  });

  itEndsEarly("ends early with nothing scored", ready, { after: 0 });

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
    const match = await ready({ rect: { left: 0, top: 0, width: 360, height: 600 } });
    const { laid } = match.engines.host;
    expect(laid.keys[0].y).toBeGreaterThan(laid.grid.y + laid.grid.h);
  });
});
