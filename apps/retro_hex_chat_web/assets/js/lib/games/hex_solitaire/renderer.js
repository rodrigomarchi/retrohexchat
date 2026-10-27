/**
 * Hex Solitaire's picture: the felt, the stock, the waste, the foundations
 * and the columns with their cards, what is moving over them, and the score
 * and the time above (`core/card_table/render.js`).
 *
 * @module games/hex_solitaire/renderer
 */

import { drawColumns, drawSlot, drawTable } from "../core/card_table/render.js";
import { geometryOf, layout } from "./layout.js";
import { CARD, TABLE } from "./protocol.js";

/**
 * The whole picture.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ state: object, drag: object | null, fx: object, atlas: object | null,
 *   colors: object, now: number, back: number, trail?: object | null,
 *   felt?: CanvasPattern | null }} scene - `felt` is the felt's weave, when the
 *   page could make one; the felt is plain without it
 */
export function render(ctx, scene) {
  const { table } = scene.state;
  const places = layout(table);
  const geo = geometryOf(table);
  const { colors } = scene;
  // How far apart the cards of a run held or flying stand, as in a column.
  const run = geo.upOffset ?? TABLE.upOffset;

  drawTable(ctx, scene, { view: geo.view, run }, (painter) => {
    const { away, one } = painter;
    // The stock, the waste and the foundations.
    if (table.stock.length) one(table.stock.at(-1), places.stock.x, places.stock.y, false);
    else drawSlot(ctx, places.stock, colors);
    if (!places.waste.length) drawSlot(ctx, places.wasteSlot, colors);
    else if (table.waste.length > places.waste.length) {
      // The card under the fan shows while the fan's top flies.
      const under = table.waste[table.waste.length - places.waste.length - 1];
      if (!away.has(under)) one(under, places.wasteSlot.x, places.wasteSlot.y);
    }
    for (const place of places.waste) if (!away.has(place.card)) one(place.card, place.x, place.y);
    places.foundations.forEach((place, suit) => {
      const shown = [...table.foundations[suit]].reverse().find((card) => !away.has(card));
      if (shown === undefined) drawSlot(ctx, place, colors, { suit });
      else one(shown, place.x, place.y);
    });
    drawColumns(ctx, places.columns, colors, CARD, painter);
  });
}
