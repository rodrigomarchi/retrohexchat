import { MODE } from "../../../../js/lib/games/hex_solitaire/protocol.js";
import { H, S, card } from "../../../support/games/card_tables.js";

/**
 * A Klondike table built by hand: every pile empty unless given, a column
 * `{ down, up }` with either left out, and the waste showing its top card.
 */
export function table({
  mode = MODE.DRAW1,
  stock = [],
  waste = [],
  fan,
  foundations = [[], [], [], []],
  columns = [],
} = {}) {
  const tableau = Array.from({ length: 7 }, (_, i) => ({
    down: columns[i]?.down ?? [],
    up: columns[i]?.up ?? [],
  }));
  return { mode, stock, waste, fan: fan ?? Math.min(1, waste.length), foundations, tableau };
}

/** Spades up to the two on their foundation, and the three of hearts alone in the first column. */
export const twoOfSpadesUp = () =>
  table({
    foundations: [[card(1, S), card(2, S)], [], [], []],
    columns: [{ up: [card(3, H)] }],
  });
