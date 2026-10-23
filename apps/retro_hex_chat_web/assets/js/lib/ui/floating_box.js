/**
 * Keeping a floating box — a tooltip, a hover card, a taskbar menu — inside
 * the viewport. Shared by the chat and the window manager, which is why it
 * lives here and not with either.
 *
 * @module ui/floating_box
 */

/**
 * Reposition coordinates so that a box of the given size stays within the viewport.
 *
 * @param {number} x - Desired left position
 * @param {number} y - Desired top position
 * @param {number} width - Box width
 * @param {number} height - Box height
 * @param {number} [margin=4] - Minimum distance from viewport edges
 * @returns {{ x: number, y: number }}
 */
export function repositionWithinViewport(x, y, width, height, margin = 4) {
  const vw = window.innerWidth;
  const vh = window.innerHeight;

  let finalX = x;
  let finalY = y;

  if (finalX + width + margin > vw) {
    finalX = vw - width - margin;
  }
  if (finalX < margin) {
    finalX = margin;
  }
  if (finalY + height + margin > vh) {
    finalY = vh - height - margin;
  }
  if (finalY < margin) {
    finalY = margin;
  }

  return { x: finalX, y: finalY };
}
