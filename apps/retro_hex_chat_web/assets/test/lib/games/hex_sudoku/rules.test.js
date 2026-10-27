import { describe, expect, it } from "vitest";
import { bit, parseGrid } from "../../../../js/lib/games/hex_sudoku/grid.js";
import {
  completedUnits,
  createBoard,
  erase,
  hintSquare,
  isWrong,
  keepHints,
  left,
  place,
  reveal,
  toggleNote,
  won,
} from "../../../../js/lib/games/hex_sudoku/rules.js";

const SOLUTION = parseGrid(
  "534678912672195348198342567859761423426853791713924856961537284287419635345286179",
);
// The solution with squares 2, 3 and 10 left empty, and the whole of row 8 but its last.
const PUZZLE = SOLUTION.map((v, i) => ([2, 3, 10].includes(i) || (i >= 72 && i < 80) ? 0 : v));
const fresh = () => createBoard({ puzzle: PUZZLE, solution: SOLUTION });

describe("a new board", () => {
  it("holds the puzzle's digits as given, nothing noted, nothing hinted", () => {
    const board = fresh();
    expect(board.values).toEqual(PUZZLE);
    expect(board.given[0]).toBe(true);
    expect(board.given[2]).toBe(false);
    expect(board.notes.every((n) => n === 0)).toBe(true);
    expect(won(board)).toBe(false);
  });
});

describe("placing a digit", () => {
  it("fills an empty square, and says whether it is wrong", () => {
    const right = place(fresh(), 2, 4);
    expect(right.board.values[2]).toBe(4);
    expect(right.wrong).toBe(false);
    const wrong = place(fresh(), 2, 9);
    expect(wrong.wrong).toBe(true);
    expect(isWrong(wrong.board, 2)).toBe(true);
    expect(isWrong(right.board, 2)).toBe(false);
  });

  it("never changes a given square, nor puts again the digit already there", () => {
    const board = fresh();
    expect(place(board, 0, 7).board).toBe(board);
    const placed = place(board, 2, 4).board;
    expect(place(placed, 2, 4).board).toBe(placed);
  });

  it("clears the square's notes, and a right digit leaves its peers' notes", () => {
    let board = toggleNote(fresh(), 2, 4);
    board = toggleNote(board, 3, 4);
    board = toggleNote(board, 3, 6);
    board = toggleNote(board, 75, 4);
    const after = place(board, 2, 4).board;
    expect(after.notes[2]).toBe(0);
    expect(after.notes[3]).toBe(bit(6));
    // Square 75 is in another row, column and box: its note stays.
    expect(after.notes[75]).toBe(bit(4));
  });

  it("leaves the peers' notes alone when the digit is wrong", () => {
    const board = toggleNote(fresh(), 3, 9);
    expect(place(board, 2, 9).board.notes[3]).toBe(bit(9));
  });

  it("replaces a wrong digit with another", () => {
    const wrong = place(fresh(), 2, 9).board;
    const right = place(wrong, 2, 4);
    expect(right.board.values[2]).toBe(4);
    expect(right.wrong).toBe(false);
  });
});

describe("notes", () => {
  it("go on and off an empty square, never on a filled one", () => {
    const on = toggleNote(fresh(), 2, 4);
    expect(on.notes[2]).toBe(bit(4));
    expect(toggleNote(on, 2, 4).notes[2]).toBe(0);
    const given = fresh();
    expect(toggleNote(given, 0, 4)).toBe(given);
    const filled = place(fresh(), 2, 4).board;
    expect(toggleNote(filled, 2, 1)).toBe(filled);
  });
});

describe("erasing", () => {
  it("takes the digit or the notes off a square, never a given or hinted one", () => {
    const placed = place(fresh(), 2, 9).board;
    expect(erase(placed, 2).values[2]).toBe(0);
    const noted = toggleNote(fresh(), 2, 4);
    expect(erase(noted, 2).notes[2]).toBe(0);
    const given = fresh();
    expect(erase(given, 0)).toBe(given);
    const hinted = reveal(fresh(), 2);
    expect(erase(hinted, 2)).toBe(hinted);
    const empty = fresh();
    expect(erase(empty, 2)).toBe(empty);
  });
});

describe("a hint", () => {
  it("reveals a square's digit for good, and it leaves its peers' notes", () => {
    const board = reveal(toggleNote(fresh(), 3, 4), 2);
    expect(board.values[2]).toBe(4);
    expect(board.hinted[2]).toBe(true);
    expect(board.notes[3]).toBe(0);
    expect(place(board, 2, 1).board).toBe(board);
  });

  it("goes to the chosen square when it is empty or wrong, else to one at random", () => {
    const board = place(fresh(), 3, 1).board;
    expect(hintSquare(board, 2, () => 0)).toBe(2);
    expect(hintSquare(board, 3, () => 0)).toBe(3);
    // A given square chosen: one of the squares still to fill, by the draw.
    const open = [2, 3, 10, 72, 73, 74, 75, 76, 77, 78, 79];
    expect(hintSquare(board, 0, () => 0)).toBe(open[0]);
    expect(hintSquare(board, null, () => 0.999)).toBe(open.at(-1));
    expect(hintSquare(createBoard({ puzzle: SOLUTION, solution: SOLUTION }), null, () => 0)).toBe(
      null,
    );
  });

  it("survives an undo: the board before it gets the revealed square back", () => {
    const before = toggleNote(fresh(), 3, 4);
    const now = reveal(place(before, 10, 7).board, 2);
    const undone = keepHints(before, now);
    expect(undone.values[2]).toBe(4);
    expect(undone.hinted[2]).toBe(true);
    expect(undone.values[10]).toBe(0);
    expect(undone.notes[3]).toBe(0);
  });
});

describe("the end", () => {
  it("is won when every square holds the solution's digit", () => {
    let board = fresh();
    for (const i of [2, 3, 10, 72, 73, 74, 75, 76, 77, 78]) {
      board = place(board, i, SOLUTION[i]).board;
    }
    expect(won(board)).toBe(false);
    board = place(board, 79, 9).board;
    expect(won(board)).toBe(false);
    board = place(board, 79, SOLUTION[79]).board;
    expect(won(board)).toBe(true);
  });

  it("tells the units a right digit completed, for the wave the picture draws", () => {
    let board = fresh();
    for (const i of [72, 73, 74, 75, 76, 77, 78]) board = place(board, i, SOLUTION[i]).board;
    // Column 6 was waiting only for square 78; its row and box still lack square 79.
    expect(completedUnits(board, 78)).toEqual([15]);
    board = place(board, 79, SOLUTION[79]).board;
    // Row 8, column 7 and box 8, all waiting for square 79.
    expect(completedUnits(board, 79)).toEqual([8, 16, 26]);
  });

  it("counts how many of each digit are still to place, wrong ones not counted", () => {
    const board = place(fresh(), 2, 9).board;
    // The wrong 9 sits where a 4 goes: two 4s still to place, no 9.
    expect(left(board, 4)).toBe(2);
    expect(left(board, 9)).toBe(0);
    expect(left(board, 1)).toBe(1);
  });
});
