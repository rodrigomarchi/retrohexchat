import { COLS, ROWS } from "../../../../js/lib/games/hex_blocks/protocol.js";
import { cellsOf, landing } from "../../../../js/lib/games/hex_blocks/rules.js";

/** The well with every square of a zigzag row filled but the columns given. */
export function fillRow(well, r, gaps) {
  const cells = [...well.cells];
  for (let c = 0; c < COLS; c++) if (!gaps.includes(c)) cells[r * COLS + c] = 1;
  return { ...well, cells };
}

/**
 * The well with its bottom row filled but where the falling piece will land,
 * so dropping it clears the row.
 */
export function bottomRowForPiece({ well, piece }) {
  const bottom = cellsOf(landing(well, piece))
    .filter(([, row]) => row === ROWS - 1)
    .map(([c]) => c);
  return fillRow(well, ROWS - 1, bottom);
}
