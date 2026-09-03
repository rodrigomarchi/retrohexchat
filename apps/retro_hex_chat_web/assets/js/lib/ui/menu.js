/**
 * Menu navigation and repositioning logic.
 */

/**
 * Reposition a menu element so it doesn't overflow the viewport.
 *
 * @param {HTMLElement} el
 */
export function repositionMenu(el) {
  const rect = el.getBoundingClientRect();
  const vw = window.innerWidth;
  const vh = window.innerHeight;

  // Flip left if overflows right
  if (rect.right > vw) {
    const overflow = rect.right - vw;
    const currentLeft = parseInt(el.style.left, 10) || rect.left;
    el.style.left = Math.max(0, currentLeft - overflow - 4) + "px";
  }

  // Flip up if overflows bottom
  if (rect.bottom > vh) {
    const overflow = rect.bottom - vh;
    const currentTop = parseInt(el.style.top, 10) || rect.top;
    el.style.top = Math.max(0, currentTop - overflow - 4) + "px";
  }
}
