/**
 * Hex FreeCell's picture: the felt, the free cells and the foundations along
 * the top, the eight columns, what is moving over them, and the score and
 * the time above (`core/card_table/render.js`).
 *
 * @module games/hex_freecell/renderer
 */

import {
  drawFelt,
  drawHud,
  drawMoving,
  drawSlot,
  tablePainter,
} from "../core/card_table/render.js";
import { geometryOf, layout } from "./layout.js";

// An empty free cell's mark: a hexagon, the platform's.
const CELL_MARK = ["..###..", ".#...#.", "#.....#", "#.....#", "#.....#", ".#...#.", "..###.."];

/**
 * The whole picture.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ state: object, drag: object | null, fx: object, atlas: object | null,
 *   colors: object, now: number, back: number, trail?: object | null,
 *   felt?: CanvasPattern | null }} scene
 */
export function render(
  ctx,
  { state, drag, fx, atlas, colors, now, back, trail = null, felt = null },
) {
  const { table } = state;
  const places = layout(table);
  const geo = geometryOf(table);
  const { away, one } = tablePainter(ctx, { fx, drag, atlas, now, back });

  drawFelt(ctx, geo.view, colors, felt);

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
  for (const column of places.columns) {
    if (!column.cards.length) drawSlot(ctx, column.slot, colors, { card: geo.card });
    for (const c of column.cards) if (!away.has(c.card)) one(c.card, c.x, c.y);
  }

  drawMoving(ctx, { fx, drag, atlas, now, back, colors, run: geo.upOffset, trail });
  drawHud(ctx, geo.view, { score: state.score, ticks: state.clock.ticks }, colors);
}
