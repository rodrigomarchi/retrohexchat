import { describe, expect, it } from "vitest";
import { createEffects } from "../../../../js/lib/games/hex_sudoku/effects.js";
import { parseGrid } from "../../../../js/lib/games/hex_sudoku/grid.js";
import { GEOMETRY, layout } from "../../../../js/lib/games/hex_sudoku/layout.js";
import { createInitialState } from "../../../../js/lib/games/hex_sudoku/physics.js";
import { render } from "../../../../js/lib/games/hex_sudoku/renderer.js";
import {
  createBoard,
  place,
  reveal,
  toggleNote,
} from "../../../../js/lib/games/hex_sudoku/rules.js";
import { recordingCanvas } from "../../../support/games/recording_canvas.js";

const DIGITS = [1, 2, 3, 4, 5, 6, 7, 8, 9];
const NAMES = ["given", "mine", "wrong", "hint", "note", "key", "spent"]
  .flatMap((kind) => DIGITS.map((n) => `${kind}_${n}`))
  .concat(["pencil", "pencil_on", "eraser", "bulb", "undo", "colon", "cross", "lamp"])
  .concat([..."0123456789"].map((d) => `digit_${d}`));
const regions = Object.fromEntries(
  NAMES.map((name, k) => [name, { x: k * 30, y: 0, w: 16, h: 16 }]),
);
const atlas = { image: { id: "tiles" }, regions };
const colors = Object.fromEntries(
  [
    "back",
    "bar",
    "frame",
    "paper",
    "thin",
    "thick",
    "chosen",
    "peer",
    "same",
    "wrong",
    "glow",
    "key",
  ].map((name) => [name, name]),
);
const cut = (log, name) =>
  log.filter(([op, , sx]) => op === "drawImage" && sx === regions[name].x).length;
const filled = (log, colour) => {
  let fill = null;
  let n = 0;
  for (const [op, , value] of log) {
    if (op === "fillStyle") fill = value;
    if (op === "fillRect" && fill === colour) n++;
  }
  return n;
};

const SOLUTION = parseGrid(
  "534678912672195348198342567859761423426853791713924856961537284287419635345286179",
);
// Every square given but row 0's first four, and the 9s of rows 1 to 8 left out.
const PUZZLE = SOLUTION.map((v, i) => (i < 4 || (i >= 9 && v === 9) ? 0 : v));

function drawn(state, side = "LANDSCAPE") {
  const laid = layout(GEOMETRY[side]);
  const canvas = recordingCanvas(laid.view.width, laid.view.height);
  canvas.clearLog();
  render(canvas.getContext("2d"), { state, laid, fx: createEffects(), atlas, colors, now: 0 });
  return canvas.log;
}

describe("Hex Sudoku's picture", () => {
  it("draws the bar, an empty grid and the keypad while the grid is being made", () => {
    const log = drawn(createInitialState());
    expect(filled(log, "paper")).toBe(81);
    expect(cut(log, "key_1")).toBe(1);
    expect(cut(log, "pencil")).toBe(1);
    expect(cut(log, "cross")).toBe(1);
    expect(cut(log, "colon")).toBe(1);
  });

  it("draws each digit in its ink, the notes, the highlights, and spends a placed-out digit", () => {
    let board = createBoard({ puzzle: PUZZLE, solution: SOLUTION });
    board = place(board, 0, 5).board;
    board = place(board, 1, 9).board;
    board = reveal(board, 2);
    board = toggleNote(board, 3, 6);
    board = toggleNote(board, 3, 7);
    const state = { ...createInitialState(), board, selected: 0, pencil: true };
    const log = drawn(state);
    expect(cut(log, "mine_5")).toBe(1);
    expect(cut(log, "wrong_9")).toBe(1);
    expect(cut(log, "hint_4")).toBe(1);
    expect(cut(log, "note_6") + cut(log, "note_7")).toBe(2);
    expect(cut(log, "given_1")).toBe(9);
    // Every 5 is placed: its key is spent; every 9 is not.
    expect(cut(log, "spent_5")).toBe(1);
    expect(cut(log, "key_9")).toBe(1);
    expect(cut(log, "pencil_on")).toBe(1);
    expect(filled(log, "chosen")).toBe(1);
    expect(filled(log, "wrong")).toBe(1);
    // The other 5s; the twenty squares in row 0, column 0 and the first box, but the wrong one.
    expect(filled(log, "same")).toBe(8);
    expect(filled(log, "peer")).toBe(20 - 1);
  });

  it("stands up with the same pieces on a phone", () => {
    const log = drawn(createInitialState(), "PORTRAIT");
    for (const n of DIGITS) expect(cut(log, `key_${n}`)).toBe(1);
  });
});
