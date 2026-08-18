/**
 * Pure row-selection logic for RetroTable — no DOM, no state.
 *
 * The controller resolves rows to elements and focuses them; where the cursor
 * lands and which rows end up selected is decided here, against plain ids.
 *
 * @module ui/retro_table_selection
 */

/**
 * The row index a navigation key lands on, or null when the key is not one.
 *
 * @param {string} key the KeyboardEvent key
 * @param {number} cursorIndex current cursor row index, or -1 when none
 * @param {number} rowCount
 * @param {number} rowsPerPage rows a PageUp/PageDown moves by
 * @returns {number|null}
 */
export function nextRowIndex(key, cursorIndex, rowCount, rowsPerPage) {
  if (rowCount === 0) return null;

  const last = rowCount - 1;
  const from = cursorIndex < 0 ? 0 : cursorIndex;

  switch (key) {
    case "ArrowDown":
      return Math.min(last, from + 1);
    case "ArrowUp":
      return Math.max(0, from - 1);
    case "PageDown":
      return Math.min(last, from + rowsPerPage);
    case "PageUp":
      return Math.max(0, from - rowsPerPage);
    case "Home":
      return 0;
    case "End":
      return last;
    default:
      return null;
  }
}

/**
 * The selection, anchor and cursor after moving to a row.
 *
 * Shift extends from the anchor; Ctrl/Cmd toggles the one row and re-anchors;
 * a plain move selects only the target. Mirrors the three ways a Windows list
 * view responds to a click.
 *
 * @param {object} params
 * @param {string[]} params.rowIds all row ids in display order
 * @param {Set<string>} params.selection current selection
 * @param {string|null} params.anchor current range anchor
 * @param {string} params.rowId the row being moved to
 * @param {boolean} params.extend shift-click
 * @param {boolean} params.toggle ctrl/cmd-click
 * @returns {{selection: Set<string>, anchor: string, cursor: string}|null}
 *   null when the row is not present
 */
export function nextSelection({ rowIds, selection, anchor, rowId, extend, toggle }) {
  if (!rowIds.includes(rowId)) return null;

  if (extend && anchor) {
    const from = rowIds.indexOf(anchor);
    const to = rowIds.indexOf(rowId);
    const range = rowIds.slice(Math.min(from, to), Math.max(from, to) + 1);
    return { selection: new Set(range), anchor, cursor: rowId };
  }

  if (toggle) {
    const next = new Set(selection);
    if (next.has(rowId)) {
      next.delete(rowId);
    } else {
      next.add(rowId);
    }
    return { selection: next, anchor: rowId, cursor: rowId };
  }

  return { selection: new Set([rowId]), anchor: rowId, cursor: rowId };
}

/**
 * Drop from the selection any id no longer present in the listing.
 *
 * @param {Set<string>} selection
 * @param {Set<string>} presentIds
 * @returns {Set<string>} a new set with only present ids
 */
export function pruneSelection(selection, presentIds) {
  const next = new Set();
  for (const id of selection) {
    if (presentIds.has(id)) next.add(id);
  }
  return next;
}

/**
 * The selected rows as tab-separated text, headings included.
 *
 * @param {string[]} headings visible heading labels
 * @param {string[][]} rows one array of cell texts per selected row, column-aligned
 * @returns {string}
 */
export function toTSV(headings, rows) {
  const lines = [headings.join("\t")];
  for (const row of rows) {
    lines.push(row.join("\t"));
  }
  return lines.join("\n");
}
