/**
 * Hex FreeCell's picture: the felt, the free cells and the foundations along
 * the top, the eight columns, what is moving over them, and the score and
 * the time above (`core/card_table/render.js`).
 *
 * @module games/hex_freecell/renderer
 */

import { drawColumns, drawSlot, tableRenderer } from "../core/card_table/render.js";
import { geometryOf, layout } from "./layout.js";

// An empty free cell's mark: a hexagon, the platform's.
const CELL_MARK = ["..###..", ".#...#.", "#.....#", "#.....#", "#.....#", ".#...#.", "..###.."];

/** The whole picture (`core/card_table/render.js` `drawTable` reads the scene). */
export const render = tableRenderer(
  { layout, geometryOf },
  (ctx, { table, places, geo, colors, painter }) => {
    const { away, one } = painter;
    places.cells.forEach((place) => {
      if (place.card === null || away.has(place.card)) {
        drawSlot(ctx, place, colors, { mark: CELL_MARK, card: geo.card });
      } else one(place.card, place.x, place.y);
    });
    places.foundations.forEach((place, suit) => {
      const shown = [...table.foundations[suit]].reverse().find((card) => !away.has(card));
      if (shown === undefined) drawSlot(ctx, place, colors, { suit, card: geo.card });
      else one(shown, place.x, place.y);
    });
    drawColumns(ctx, places.columns, colors, geo.card, painter);
  },
);
