/**
 * A picture kept off the screen: a canvas the size of the game's, drawn on in
 * the game's own pixels and copied onto the screen whole.
 *
 * A board that hardly changes — a card table, its felt and the piles nobody
 * is touching — is drawn into a layer once and copied each frame, so a frame
 * that animates one card costs that card. A layer that is never cleared keeps
 * what was drawn on it, which is how a trail is made. A module of its own, so
 * the games that redraw everything do not load it.
 *
 * @module games/core/layers
 */

/**
 * @param {number} width - the game's width, in its own pixels
 * @param {number} height
 * @param {number} [resolution] - canvas pixels to a game pixel, as on the screen
 * @param {{ createCanvas?: (width: number, height: number) => HTMLCanvasElement }} [io]
 * @returns {{ canvas: HTMLCanvasElement, ctx: CanvasRenderingContext2D | null, clear: () => void,
 *   drawTo: (screen: CanvasRenderingContext2D) => void }} - `ctx` is null where the page
 *   cannot draw off the screen; the game then draws without the layer
 */
export function createLayer(width, height, resolution = 1, { createCanvas = newCanvas } = {}) {
  const canvas = createCanvas(width * resolution, height * resolution);
  const ctx = canvas.getContext("2d");
  const reset = () => {
    ctx?.setTransform(resolution, 0, 0, resolution, 0, 0);
    if (ctx) ctx.imageSmoothingEnabled = false;
  };
  reset();

  return {
    canvas,
    ctx,
    clear() {
      reset();
      ctx?.clearRect(0, 0, width, height);
    },
    drawTo(screen) {
      screen.drawImage(canvas, 0, 0, width, height);
    },
  };
}

function newCanvas(width, height) {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  return canvas;
}
