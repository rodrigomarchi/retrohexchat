/**
 * Hex Spider's picture: the felt, the ten columns, the suits completed and
 * the stock's deals along the bottom, what is moving over them, and the
 * score and the time above (`core/card_table/render.js`). Two cards alike
 * show the same face (`faceOf`).
 *
 * @module games/hex_spider/renderer
 */

import { faceOf } from "../core/cards.js";
import { drawColumns, drawSlot, tableRenderer } from "../core/card_table/render.js";
import { geometryOf, layout } from "./layout.js";

/** The whole picture (`core/card_table/render.js` `drawTable` reads the scene). */
export const render = tableRenderer(
  { layout, geometryOf, face: faceOf },
  (ctx, { table, places, geo, colors, painter }) => {
    const { away, one } = painter;
    drawColumns(ctx, places.columns, colors, geo.card, painter);
    // The suits completed, each showing its king.
    if (!table.foundations.length) drawSlot(ctx, places.next, colors, { suit: 0, card: geo.card });
    table.foundations.forEach((suit, i) => {
      if (!away.has(suit[0])) one(suit[0], places.foundations[i].x, places.foundations[i].y);
    });
    // A back for each deal left; the rightmost is the next deal, its back the stock's last card.
    if (!places.stock.length) drawSlot(ctx, places.stockSlot, colors, { card: geo.card });
    places.stock.forEach((place, i) => {
      const card = table.stock.at(-1 - (places.stock.length - 1 - i) * 10);
      if (!away.has(card)) one(card, place.x, place.y, false);
    });
  },
);
