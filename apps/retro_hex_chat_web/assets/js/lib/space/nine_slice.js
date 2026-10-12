/**
 * Draws a piece of the space's pixel-art UI kit on a canvas.
 *
 * A sliced piece (`t`, `r`, `b`, `l` set) is a nine-slice: its four corners are
 * drawn as they are, and its edges and face are tiled to fill the box — the same
 * `repeat` CSS uses for the kit's DOM frames. Nothing is ever scaled: a tile that
 * does not fit whole is cut short, source and destination the same size, so the
 * art stays 1:1 at any box size. Coordinates are rounded to whole pixels.
 * @module space/nine_slice
 */

/**
 * @param {CanvasRenderingContext2D} ctx
 * @param {{img: CanvasImageSource, x: number, y: number, w: number, h: number,
 *   t: number, r: number, b: number, l: number}} piece from `atlas.uiPiece`
 * @param {number} dx
 * @param {number} dy
 * @param {number} dw at least `l + r`
 * @param {number} dh at least `t + b`
 */
export function drawNineSlice(ctx, piece, dx, dy, dw, dh) {
  const { img, x, y, w, h, t, r, b, l } = piece;
  const x0 = Math.round(dx);
  const y0 = Math.round(dy);
  const width = Math.max(Math.round(dw), l + r);
  const height = Math.max(Math.round(dh), t + b);
  const innerW = width - l - r;
  const innerH = height - t - b;
  const srcW = w - l - r;
  const srcH = h - t - b;

  // Corners.
  blit(ctx, img, x, y, l, t, x0, y0);
  blit(ctx, img, x + w - r, y, r, t, x0 + width - r, y0);
  blit(ctx, img, x, y + h - b, l, b, x0, y0 + height - b);
  blit(ctx, img, x + w - r, y + h - b, r, b, x0 + width - r, y0 + height - b);
  // Edges.
  tile(ctx, img, x + l, y, srcW, t, x0 + l, y0, innerW, t);
  tile(ctx, img, x + l, y + h - b, srcW, b, x0 + l, y0 + height - b, innerW, b);
  tile(ctx, img, x, y + t, l, srcH, x0, y0 + t, l, innerH);
  tile(ctx, img, x + w - r, y + t, r, srcH, x0 + width - r, y0 + t, r, innerH);
  // Face.
  tile(ctx, img, x + l, y + t, srcW, srcH, x0 + l, y0 + t, innerW, innerH);
}

/**
 * Draws a whole piece (a sprite with no slice) with its top-left at (dx, dy),
 * cut to `dw` wide when given — a bar's fill drawn to a fraction of its length.
 */
export function drawPiece(ctx, piece, dx, dy, dw = piece.w) {
  const width = Math.max(0, Math.min(Math.round(dw), piece.w));
  if (width === 0) return;
  ctx.drawImage(
    piece.img,
    piece.x,
    piece.y,
    width,
    piece.h,
    Math.round(dx),
    Math.round(dy),
    width,
    piece.h,
  );
}

// One source rect at its own size; an empty one (a slice of zero) is skipped.
function blit(ctx, img, sx, sy, sw, sh, dx, dy) {
  if (sw > 0 && sh > 0) ctx.drawImage(img, sx, sy, sw, sh, dx, dy, sw, sh);
}

// Repeat a source rect over a destination box, left to right and top to
// bottom, cutting the last tile of each run short instead of scaling it.
function tile(ctx, img, sx, sy, sw, sh, dx, dy, dw, dh) {
  if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0) return;
  for (let oy = 0; oy < dh; oy += sh) {
    const h = Math.min(sh, dh - oy);
    for (let ox = 0; ox < dw; ox += sw) {
      const w = Math.min(sw, dw - ox);
      ctx.drawImage(img, sx, sy, w, h, dx + ox, dy + oy, w, h);
    }
  }
}
