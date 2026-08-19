/**
 * Placement decision for the autocomplete dropdown.
 *
 * The panel renders above the composer. When the input sits near the top of the
 * viewport the panel can overflow past the top edge; in that case it is capped
 * to the height still visible below the edge so it never runs off-screen. Below
 * a floor it is left alone — a sliver of panel is worse than none.
 */

// Do not cap the panel to anything shorter than this; a tiny panel is unusable.
export const MIN_DROPDOWN_HEIGHT = 60;

/**
 * @param {{top: number, bottom: number}} rect - the dropdown's bounding rect
 * @returns {number|null} pixel max-height to apply, or null to leave unchanged
 */
export function dropdownMaxHeight(rect) {
  if (rect.top < 0 && rect.bottom > MIN_DROPDOWN_HEIGHT) {
    return rect.bottom;
  }
  return null;
}
