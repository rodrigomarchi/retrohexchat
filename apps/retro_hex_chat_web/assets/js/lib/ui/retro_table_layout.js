/**
 * Pure column-layout maths for RetroTable — no DOM, no state.
 *
 * The controller measures the browser's layout and applies the results; the
 * decisions about how those numbers turn into pinned widths and which columns
 * are hidden live here, where they can be tested against arrays.
 *
 * @module ui/retro_table_layout
 */

export const MIN_COLUMN_WIDTH = 32;

/**
 * A stable identity for a set of columns, used to tell one listing from another.
 * Hidden columns are included by the caller so switching a column off is not
 * mistaken for a new listing.
 *
 * @param {string[]} columns column keys in header order
 * @returns {string}
 */
export function columnSignature(columns) {
  return columns.join("|");
}

/**
 * Distribute measured column widths so they add up to what the browser laid out.
 *
 * Rounding each column on its own would not do: the borders are collapsed, so
 * neighbours share one and every column counts it, and the roundings drift the
 * same way. Rounding the running edge instead of the width makes the columns add
 * up to the table exactly, because each one is the distance between two edges
 * that were rounded once.
 *
 * @param {number[]} widths measured widths in header order
 * @param {number} laidOutTotal the width the grid was actually laid out at
 * @param {number} [minWidth]
 * @returns {number[]} distributed integer widths, or [] when nothing to lay out
 */
export function distributeWidths(widths, laidOutTotal, minWidth = MIN_COLUMN_WIDTH) {
  const total = widths.reduce((sum, width) => sum + width, 0);
  if (total === 0) return [];

  const laidOut = laidOutTotal || total;
  let edge = 0;
  let placed = 0;
  const result = [];

  for (const width of widths) {
    edge += (width / total) * laidOut;
    const rounded = Math.round(edge);
    result.push(Math.max(minWidth, rounded - placed));
    placed = rounded;
  }

  return result;
}

/**
 * The hidden-columns set after toggling one column.
 *
 * The last visible column names the rows; hiding it would leave a grid of
 * blanks with no way back except the reset item, so a toggle that would empty
 * the table returns the set unchanged.
 *
 * @param {Set<string>} hidden current hidden columns
 * @param {string} column the column being toggled
 * @param {number} visibleCount how many columns are visible now
 * @returns {Set<string>} a new set, or the same set when the toggle is refused
 */
export function nextHiddenColumns(hidden, column, visibleCount) {
  if (hidden.has(column)) {
    const next = new Set(hidden);
    next.delete(column);
    return next;
  }

  if (visibleCount > 1) {
    const next = new Set(hidden);
    next.add(column);
    return next;
  }

  return hidden;
}
