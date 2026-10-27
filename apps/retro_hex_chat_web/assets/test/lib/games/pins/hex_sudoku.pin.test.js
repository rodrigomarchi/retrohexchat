import { pinGame } from "../../../support/games/pins.js";
import { hexSudokuEndScript, hexSudokuScript } from "../../../support/games/scripts/hex_sudoku.js";

pinGame("hex_sudoku", {
  soloOnly: true,
  script: hexSudokuScript,
  endScript: hexSudokuEndScript,
  // The three hours' safety clock, and the second and a half before it starts.
  endMs: 181 * 60_000,
});
