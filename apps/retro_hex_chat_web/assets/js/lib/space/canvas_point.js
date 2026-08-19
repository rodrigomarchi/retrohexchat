/**
 * Mapping a pointer event to a point in the space canvas' pixel space — pure.
 *
 * The hook reads the canvas rect and looks up the participant; the coordinate
 * transform from client pixels to backing-store pixels is decided here, so it
 * can be tested without a canvas.
 *
 * @module space/canvas_point
 */

/**
 * @param {{clientX: number, clientY: number}} event
 * @param {{left: number, top: number, width: number, height: number}} rect
 * @param {number} canvasWidth backing-store width
 * @param {number} canvasHeight backing-store height
 * @returns {{x: number, y: number}|null} null when the rect has no area
 */
export function canvasPointFromEvent(event, rect, canvasWidth, canvasHeight) {
  if (rect.width <= 0 || rect.height <= 0) return null;

  return {
    x: ((event.clientX - rect.left) * canvasWidth) / rect.width,
    y: ((event.clientY - rect.top) * canvasHeight) / rect.height,
  };
}
