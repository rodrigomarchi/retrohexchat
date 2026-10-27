/**
 * Hex Spider's picture: the felt, the ten columns, the suits completed and
 * the stock's deals along the bottom, what is moving over them, and the
 * score and the time above (`core/card_table/render.js`). Two cards alike
 * show the same face (`faceOf`).
 *
 * @module games/hex_spider/renderer
 */

import { faceOf } from "../core/cards.js";
import {
  drawFelt,
  drawHud,
  drawMoving,
  drawSlot,
  tablePainter,
} from "../core/card_table/render.js";
import { geometryOf, layout } from "./layout.js";

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
  const scene = { fx, drag, atlas, now, back, face: faceOf };
  const { away, one } = tablePainter(ctx, scene);

  drawFelt(ctx, geo.view, colors, felt);

  for (const column of places.columns) {
    if (!column.cards.length) drawSlot(ctx, column.slot, colors, { card: geo.card });
    for (const c of column.cards) if (!away.has(c.card)) one(c.card, c.x, c.y, c.faceUp);
  }
  // The suits completed, each showing its king.
  if (!table.foundations.length) drawSlot(ctx, places.next, colors, { suit: 0, card: geo.card });
  table.foundations.forEach((suit, i) => {
    if (!away.has(suit[0])) one(suit[0], places.foundations[i].x, places.foundations[i].y);
  });
  // A back for each deal left in the stock.
  if (!places.stock.length) drawSlot(ctx, places.stockSlot, colors, { card: geo.card });
  // The rightmost is the next deal: its back is the stock's last card.
  places.stock.forEach((place, i) => {
    const card = table.stock.at(-1 - (places.stock.length - 1 - i) * 10);
    if (!away.has(card)) one(card, place.x, place.y, false);
  });

  drawMoving(ctx, { ...scene, colors, run: geo.upOffset, trail });
  drawHud(ctx, geo.view, { score: state.score, ticks: state.clock.ticks }, colors);
}
