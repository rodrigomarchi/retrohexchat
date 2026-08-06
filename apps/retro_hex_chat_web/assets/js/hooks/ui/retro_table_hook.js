/**
 * The browser's half of the RetroTable component.
 *
 * Column width, column visibility and the selection change nothing about the
 * data, so they never leave the browser — routing a drag through the server
 * would put a round-trip inside every pointermove. Ordering and pagination do
 * change which rows exist, so those stay server events and arrive back here as
 * a fresh header and fresh rows.
 *
 * That split is the reason for `sync()`. The server re-renders without knowing
 * that a column is 70px wide, hidden, or that row 12 is selected, so the hook
 * re-asserts all three after every patch — the same arrangement the window
 * manager uses for window geometry.
 *
 * Widths are read from the first paint and then pinned, which is what stops a
 * refresh whose longest value changed from shifting every column under the
 * reader. They are pinned onto the header cells rather than into a <colgroup>:
 * hiding a column removes its cells, and column elements would then line up
 * against the wrong ones.
 */
import { log } from "../../lib/logger";
import { repositionMenu } from "../../lib/ui/menu";

const MIN_COLUMN_WIDTH = 32;

// Widths are handed to the stylesheet as data rather than written as layout:
// what a width *does* — which element it applies to, whether the table is fixed
// at all — is decided in retro-table.css, the same way the memory bar takes its
// share as a property.
const COLUMN_WIDTH = "--retro-table-column-width";
const TABLE_WIDTH = "--retro-table-width";

const RetroTableHook = {
  mounted() {
    this.widths = new Map();
    this.hiddenColumns = new Set();
    this.selection = new Set();
    this.anchorRow = null;
    this.cursorRow = null;
    this.drag = null;
    this.suppressClick = false;

    this.bind();
    this.sync();
  },

  updated() {
    this.closeMenu();
    this.sync();
  },

  destroyed() {
    this.unbind();
  },

  // ── Element lookups ──────────────────────────────────────

  grid() {
    return this.el.querySelector("[data-retro-table-grid]");
  },

  menu() {
    return this.el.querySelector("[data-retro-table-menu]");
  },

  headings() {
    return Array.from(this.el.querySelectorAll(".retro-table__head"));
  },

  rows() {
    return Array.from(this.el.querySelectorAll(".retro-table__row"));
  },

  visibleHeadings() {
    return this.headings().filter((th) => !this.hiddenColumns.has(th.dataset.column));
  },

  // ── Re-asserting client state over a server render ───────

  sync() {
    const grid = this.grid();
    if (!grid) {
      // An empty listing or the preformatted fallback: nothing to lay out, and
      // the widths are kept in case the same rows come back.
      delete this.el.dataset.layout;
      return;
    }

    this.forgetColumnsIfReplaced();
    this.applyHidden();
    this.applyWidths();
    this.applySelection();
  },

  /**
   * Drop everything measured when the listing is replaced by a different one.
   *
   * One window can show unrelated listings in turn — the database window runs
   * whichever report is chosen, and each report brings its own columns. A width
   * measured for the previous report describes a column this one does not have,
   * and keeping it is worse than useless: the table would be pinned to the sum
   * of the few keys that happened to survive, leaving every genuinely new
   * column with no width at all and nothing to see.
   *
   * The signature covers every heading, hidden ones included, so switching a
   * column off is not mistaken for a new listing.
   */
  forgetColumnsIfReplaced() {
    const signature = this.headings()
      .map((th) => th.dataset.column)
      .join("|");

    if (signature === this.columnSignature) return;
    this.columnSignature = signature;

    // The headings LiveView reused still carry the old inline widths, and the
    // fixed layout still holds. Both have to go before anything is measured,
    // or the fresh measurement just reads the stale numbers back.
    for (const th of this.headings()) th.style.removeProperty(COLUMN_WIDTH);
    this.grid()?.style.removeProperty(TABLE_WIDTH);
    delete this.el.dataset.layout;

    this.widths.clear();
    this.hiddenColumns.clear();
  },

  applyHidden() {
    for (const cell of this.el.querySelectorAll("[data-column]")) {
      if (this.hiddenColumns.has(cell.dataset.column)) {
        cell.dataset.hidden = "true";
      } else {
        delete cell.dataset.hidden;
      }
    }

    for (const item of this.el.querySelectorAll("[data-retro-table-column]")) {
      const hidden = this.hiddenColumns.has(item.dataset.retroTableColumn);
      item.setAttribute("aria-checked", hidden ? "false" : "true");
    }
  },

  applyWidths() {
    const headings = this.visibleHeadings();
    if (headings.length === 0) return;

    // A window that has never been shown measures as zero. Leaving the table
    // unpinned is right: the next sync after it opens reads real numbers.
    if (this.widths.size === 0) {
      if (this.el.getBoundingClientRect().width === 0) return;
      this.measure(headings);
    }

    this.pinWidths();
  },

  /**
   * Read the widths the browser just laid out, adding up to what it laid out.
   *
   * Rounding each column on its own would not do: the borders are collapsed, so
   * neighbours share one and every column counts it, and the roundings drift
   * the same way. Three pixels of that is enough to push the table past its
   * pane and put a scrollbar under a listing that was fitting perfectly.
   *
   * Rounding the running edge instead of the width makes the columns add up to
   * the table exactly, because each one is the distance between two edges that
   * were rounded once.
   */
  measure(headings) {
    const total = headings.reduce((sum, th) => sum + th.getBoundingClientRect().width, 0);
    if (total === 0) return;

    const laidOut = this.grid().getBoundingClientRect().width || total;
    let edge = 0;
    let placed = 0;

    for (const th of headings) {
      edge += (th.getBoundingClientRect().width / total) * laidOut;
      const rounded = Math.round(edge);
      this.widths.set(th.dataset.column, Math.max(MIN_COLUMN_WIDTH, rounded - placed));
      placed = rounded;
    }
  },

  pinWidths() {
    const grid = this.grid();
    if (!grid) return;

    let total = 0;
    for (const th of this.visibleHeadings()) {
      const width = this.widths.get(th.dataset.column);
      if (!width) continue;
      th.style.setProperty(COLUMN_WIDTH, `${width}px`);
      total += width;
    }

    // The table is exactly as wide as its columns. Space left over in the pane
    // stays empty rather than being handed to the last column, so dragging one
    // column never resizes another.
    if (total > 0) {
      grid.style.setProperty(TABLE_WIDTH, `${total}px`);
      this.el.dataset.layout = "fixed";
    }
  },

  applySelection() {
    const rows = this.rows();
    const present = new Set(rows.map((row) => row.dataset.rowId));

    for (const id of this.selection) {
      if (!present.has(id)) this.selection.delete(id);
    }
    if (!present.has(this.cursorRow)) this.cursorRow = null;
    if (!present.has(this.anchorRow)) this.anchorRow = null;

    for (const row of rows) {
      const selected = this.selection.has(row.dataset.rowId);
      row.setAttribute("aria-selected", selected ? "true" : "false");
      row.tabIndex = row.dataset.rowId === this.cursorRow ? 0 : -1;
    }

    // Something has to be reachable by Tab, or the grid cannot be entered from
    // the keyboard at all.
    if (!this.cursorRow && rows.length > 0) rows[0].tabIndex = 0;
  },

  // ── Event wiring ─────────────────────────────────────────

  bind() {
    this._onPointerDown = (e) => this.onPointerDown(e);
    this._onPointerMove = (e) => this.onPointerMove(e);
    this._onPointerUp = (e) => this.onPointerUp(e);
    this._onDoubleClick = (e) => this.onDoubleClick(e);
    this._onClickCapture = (e) => this.onClickCapture(e);
    this._onClick = (e) => this.onClick(e);
    this._onContextMenu = (e) => this.onContextMenu(e);
    this._onKeyDown = (e) => this.onKeyDown(e);
    this._onDocumentPointerDown = (e) => this.onDocumentPointerDown(e);
    this._onDocumentKeyDown = (e) => this.onDocumentKeyDown(e);

    this.el.addEventListener("pointerdown", this._onPointerDown);
    this.el.addEventListener("pointermove", this._onPointerMove);
    this.el.addEventListener("pointerup", this._onPointerUp);
    this.el.addEventListener("pointercancel", this._onPointerUp);
    this.el.addEventListener("dblclick", this._onDoubleClick);
    this.el.addEventListener("click", this._onClickCapture, true);
    this.el.addEventListener("click", this._onClick);
    this.el.addEventListener("contextmenu", this._onContextMenu);
    this.el.addEventListener("keydown", this._onKeyDown);
    document.addEventListener("pointerdown", this._onDocumentPointerDown);
    document.addEventListener("keydown", this._onDocumentKeyDown);

    // A window that has never been shown measures as zero, so the first paint
    // inside a closed window pins nothing. This is what notices it opening.
    if (typeof ResizeObserver === "function") {
      this.observer = new ResizeObserver(() => {
        if (this.widths.size === 0) this.applyWidths();
      });
      this.observer.observe(this.el);
    }
  },

  unbind() {
    document.removeEventListener("pointerdown", this._onDocumentPointerDown);
    document.removeEventListener("keydown", this._onDocumentKeyDown);
    this.observer?.disconnect();
  },

  // ── Resizing ─────────────────────────────────────────────

  onPointerDown(e) {
    const grip = e.target.closest("[data-retro-table-resizer]");
    if (!grip) return;

    const th = grip.closest(".retro-table__head");
    if (!th) return;

    e.preventDefault();
    this.applyWidths();

    this.drag = {
      column: th.dataset.column,
      startX: e.clientX,
      startWidth:
        this.widths.get(th.dataset.column) || Math.round(th.getBoundingClientRect().width),
      moved: false,
    };
    this.el.dataset.resizing = "true";

    // Without capture the drag still tracks, it just ends early if the pointer
    // leaves the table — so a browser that has none is not a reason to abort.
    if (typeof grip.setPointerCapture !== "function") return;

    try {
      grip.setPointerCapture(e.pointerId);
      this.drag.grip = grip;
      this.drag.pointerId = e.pointerId;
    } catch (error) {
      log.warn("[RetroTable] pointer capture refused", error);
    }
  },

  onPointerMove(e) {
    if (!this.drag) return;

    const delta = e.clientX - this.drag.startX;
    if (Math.abs(delta) > 2) this.drag.moved = true;

    this.widths.set(this.drag.column, Math.max(MIN_COLUMN_WIDTH, this.drag.startWidth + delta));
    this.pinWidths();
  },

  onPointerUp() {
    if (!this.drag) return;

    if (this.drag.grip && this.drag.grip.hasPointerCapture?.(this.drag.pointerId)) {
      this.drag.grip.releasePointerCapture(this.drag.pointerId);
    }

    // A drag that ends over the heading would otherwise fire its sort click.
    this.suppressClick = this.drag.moved;
    this.drag = null;
    delete this.el.dataset.resizing;
  },

  onDoubleClick(e) {
    const grip = e.target.closest("[data-retro-table-resizer]");
    if (!grip) return;

    const th = grip.closest(".retro-table__head");
    if (!th) return;

    e.preventDefault();
    this.autoFit(th.dataset.column);
  },

  /**
   * Widen a column to its longest visible value.
   *
   * Measured by asking the browser rather than by adding up text: the columns
   * are unpinned, the measuring state lets the table grow to its content, and
   * the heading is read back. One forced reflow per double-click, and it
   * accounts for padding, borders and the sort arrow without this code knowing
   * about any of them.
   */
  autoFit(column) {
    const target = this.headings().find((th) => th.dataset.column === column);
    if (!target) return;

    const restore = this.headings().map((th) => [th, th.style.getPropertyValue(COLUMN_WIDTH)]);
    const layout = this.el.dataset.layout;

    for (const [th] of restore) th.style.removeProperty(COLUMN_WIDTH);
    delete this.el.dataset.layout;
    this.el.dataset.measuring = "true";

    const measured = Math.ceil(target.getBoundingClientRect().width);

    delete this.el.dataset.measuring;
    if (layout) this.el.dataset.layout = layout;
    for (const [th, width] of restore) {
      if (width) th.style.setProperty(COLUMN_WIDTH, width);
    }

    this.widths.set(column, Math.max(MIN_COLUMN_WIDTH, measured));
    this.applyWidths();
  },

  onClickCapture(e) {
    if (!this.suppressClick) return;
    this.suppressClick = false;
    e.stopPropagation();
    e.preventDefault();
  },

  // ── Choosing columns ─────────────────────────────────────

  onContextMenu(e) {
    if (!e.target.closest("[data-retro-table-head-row]")) return;

    e.preventDefault();
    this.openMenu(e.clientX, e.clientY);
  },

  openMenu(x, y) {
    const menu = this.menu();
    if (!menu) return;

    menu.style.left = `${x}px`;
    menu.style.top = `${y}px`;
    menu.classList.remove("u-hidden");
    repositionMenu(menu);
  },

  closeMenu() {
    this.menu()?.classList.add("u-hidden");
  },

  menuOpen() {
    const menu = this.menu();
    return Boolean(menu) && !menu.classList.contains("u-hidden");
  },

  onClick(e) {
    const toggle = e.target.closest("[data-retro-table-column]");
    if (toggle) {
      this.toggleColumn(toggle.dataset.retroTableColumn);
      this.closeMenu();
      return;
    }

    if (e.target.closest("[data-retro-table-columns-reset]")) {
      this.hiddenColumns.clear();
      this.applyHidden();
      this.pinWidths();
      this.closeMenu();
      return;
    }

    this.onRowClick(e);
  },

  toggleColumn(column) {
    if (this.hiddenColumns.has(column)) {
      this.hiddenColumns.delete(column);
    } else if (this.visibleHeadings().length > 1) {
      this.hiddenColumns.add(column);
    } else {
      // The last column standing is what names the rows; hiding it would leave
      // a grid of blanks with no way back except the reset item.
      return;
    }

    this.applyHidden();
    this.pinWidths();
  },

  onDocumentPointerDown(e) {
    if (this.menuOpen() && !this.menu().contains(e.target)) this.closeMenu();
  },

  onDocumentKeyDown(e) {
    if (e.key === "Escape" && this.menuOpen()) {
      e.stopPropagation();
      this.closeMenu();
    }
  },

  // ── Selection ────────────────────────────────────────────

  onRowClick(e) {
    const row = e.target.closest(".retro-table__row");
    if (!row || !this.el.contains(row)) return;

    this.moveTo(row.dataset.rowId, { extend: e.shiftKey, toggle: e.ctrlKey || e.metaKey });
  },

  onKeyDown(e) {
    // Windows opens a context menu from the keyboard with the Menu key or
    // Shift+F10, and the header's menu is the one this table has.
    if (e.key === "ContextMenu" || (e.shiftKey && e.key === "F10")) {
      const header = this.el.querySelector("[data-retro-table-head-row]");
      if (!header) return;
      const rect = header.getBoundingClientRect();
      e.preventDefault();
      this.openMenu(Math.round(rect.left + 8), Math.round(rect.bottom));
      return;
    }

    // Arrows inside a sort button or a filter field belong to that control.
    if (!document.activeElement?.classList?.contains("retro-table__row")) return;

    const rows = this.rows();
    if (rows.length === 0) return;

    if (e.ctrlKey || e.metaKey) {
      if (e.key === "a" || e.key === "A") {
        e.preventDefault();
        this.selection = new Set(rows.map((row) => row.dataset.rowId));
        this.applySelection();
        return;
      }

      if (e.key === "c" || e.key === "C") {
        e.preventDefault();
        this.copySelection();
        return;
      }
    }

    const target = this.targetIndex(e.key, rows);
    if (target === null) return;

    e.preventDefault();
    this.moveTo(rows[target].dataset.rowId, { extend: e.shiftKey, toggle: false });
  },

  /** Where a navigation key lands, or null when the key is not one. */
  targetIndex(key, rows) {
    const last = rows.length - 1;
    const index = rows.findIndex((row) => row.dataset.rowId === this.cursorRow);
    const from = index < 0 ? 0 : index;

    switch (key) {
      case "ArrowDown":
        return Math.min(last, from + 1);
      case "ArrowUp":
        return Math.max(0, from - 1);
      case "PageDown":
        return Math.min(last, from + this.rowsPerPage(rows));
      case "PageUp":
        return Math.max(0, from - this.rowsPerPage(rows));
      case "Home":
        return 0;
      case "End":
        return last;
      default:
        return null;
    }
  },

  rowsPerPage(rows) {
    const scroller = this.el.closest(".retro-scrollbar") || this.el;
    const rowHeight = rows[0].getBoundingClientRect().height || 1;
    return Math.max(1, Math.floor(scroller.clientHeight / rowHeight));
  },

  moveTo(rowId, { extend, toggle }) {
    const rows = this.rows();
    const target = rows.find((row) => row.dataset.rowId === rowId);
    if (!target) return;

    if (extend && this.anchorRow) {
      const from = rows.findIndex((row) => row.dataset.rowId === this.anchorRow);
      const to = rows.indexOf(target);
      this.selection = new Set(
        rows.slice(Math.min(from, to), Math.max(from, to) + 1).map((row) => row.dataset.rowId),
      );
    } else if (toggle) {
      if (this.selection.has(rowId)) {
        this.selection.delete(rowId);
      } else {
        this.selection.add(rowId);
      }
      this.anchorRow = rowId;
    } else {
      this.selection = new Set([rowId]);
      this.anchorRow = rowId;
    }

    this.cursorRow = rowId;
    this.applySelection();
    target.focus({ preventScroll: true });
    target.scrollIntoView({ block: "nearest" });
  },

  /** Copy the selected rows as tab-separated text, headings included. */
  copySelection() {
    if (this.selection.size === 0) return;

    const columns = this.visibleHeadings().map((th) => th.dataset.column);
    const heading = this.visibleHeadings().map((th) => th.textContent.trim());
    const lines = [heading.join("\t")];

    for (const row of this.rows()) {
      if (!this.selection.has(row.dataset.rowId)) continue;
      lines.push(
        columns
          .map((column) => row.querySelector(`[data-column="${column}"]`)?.textContent.trim() ?? "")
          .join("\t"),
      );
    }

    const text = lines.join("\n");

    if (!navigator.clipboard?.writeText) {
      log.warn("[RetroTable] no clipboard available, selection not copied");
      return;
    }

    navigator.clipboard.writeText(text).catch((error) => {
      log.error("[RetroTable] copying the selection failed", error);
    });
  },
};

export default RetroTableHook;
