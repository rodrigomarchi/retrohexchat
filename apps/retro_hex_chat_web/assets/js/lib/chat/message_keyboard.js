/**
 * The conversation as one stop of the Tab key.
 *
 * Every row carries controls of its own — the reaction smiley, its chips,
 * links, players — and left alone each is a stop, so crossing fifty lines is
 * fifty-odd presses. Instead one row is the conversation's stop (a roving
 * tabindex): Tab lands on it, the arrows move it, and only that row's own
 * controls follow it in the Tab order.
 *
 *   ↑ / ↓        the previous / next line
 *   Home / End   the first / last line loaded
 *   Enter        the line's reactions
 *   Menu, ⇧F10   the line's context menu, as a right-click would open it
 *   Escape       from one of the line's controls, back to the line
 *
 * LiveView re-renders a row from the server whenever it changes, which drops
 * the attributes set here, so they are re-applied to the rows a patch touched.
 * Only those rows: a long scrollback re-scanned on every incoming line would
 * cost more the longer someone reads. The writes are idempotent, which is what
 * keeps the observer from feeding itself.
 */

const ROW = ".chat-message";
const FOCUSABLE = [
  "a[href]",
  "button",
  "summary",
  "input",
  "select",
  "textarea",
  "audio[controls]",
  "video[controls]",
  "iframe",
  "[contenteditable]",
  "[tabindex]",
].join(", ");
const PARKED = "data-kb-parked";
// A keyboard-opened menu is drawn here; the browser's own `contextmenu` for the
// same key press, where it sends one, arrives right after and is dropped.
const NATIVE_MENU_ECHO_MS = 500;

/** The line a key moves to from `current`, or null for a key that moves nothing. */
export function nextRow(rows, current, key) {
  if (rows.length === 0) return null;
  const index = rows.indexOf(current);
  if (key === "ArrowUp") return index > 0 ? rows[index - 1] : null;
  if (key === "ArrowDown") return index >= 0 && index < rows.length - 1 ? rows[index + 1] : null;
  if (key === "Home") return rows[0];
  if (key === "End") return rows[rows.length - 1];
  return null;
}

/** Whether `event` asks for the context menu without a mouse. */
export function isContextMenuKey(event) {
  return event.key === "ContextMenu" || (event.shiftKey && event.key === "F10");
}

/** Whether a key carries a modifier the line keys leave to the browser. */
export function hasCommandModifier(event) {
  return Boolean(event.ctrlKey || event.metaKey || event.altKey);
}

/**
 * Make `row` the conversation's stop (`isCurrent`) or park it and its controls
 * out of the Tab order. A control the server gave a tabindex of its own is
 * remembered, so a row that becomes current gets it back.
 */
export function applyRow(row, isCurrent) {
  setAttr(row, "tabindex", isCurrent ? "0" : "-1");

  for (const control of row.querySelectorAll(FOCUSABLE)) {
    if (isCurrent || insideOpenPopover(control, row)) unpark(control);
    else park(control);
  }
}

/** `applyRow` over a whole list, with `current` as the stop. */
export function applyRovingFocus(rows, current) {
  for (const row of rows) applyRow(row, row === current);
}

function park(control) {
  if (control.hasAttribute(PARKED)) {
    setAttr(control, "tabindex", "-1");
    return;
  }
  control.setAttribute(PARKED, control.getAttribute("tabindex") ?? "");
  control.setAttribute("tabindex", "-1");
}

function unpark(control) {
  if (!control.hasAttribute(PARKED)) return;
  const original = control.getAttribute(PARKED);
  control.removeAttribute(PARKED);
  if (original === "") control.removeAttribute("tabindex");
  else control.setAttribute("tabindex", original);
}

function setAttr(el, name, value) {
  if (el.getAttribute(name) !== value) el.setAttribute(name, value);
}

function insideOpenPopover(control, row) {
  const popover = control.closest("details[data-popover][open]");
  return Boolean(popover && row.contains(popover));
}

/** The rows a batch of mutations touched, inside `stream`. */
function touchedRows(mutations, stream) {
  const rows = new Set();
  const add = (node) => {
    if (node.nodeType !== 1) return;
    const own = node.closest(ROW);
    if (own && stream.contains(own)) rows.add(own);
    node.querySelectorAll?.(ROW).forEach((row) => rows.add(row));
  };
  for (const mutation of mutations) {
    add(mutation.target);
    mutation.addedNodes.forEach(add);
  }
  return rows;
}

/**
 * Wire the keyboard to the rows under `stream`, listening on `scroller`.
 * Returns `destroy`.
 */
export function createMessageKeyboard(scroller, stream) {
  const doc = stream.ownerDocument;
  let current = null;
  let applied = null;
  let menuEchoUntil = 0;

  const rows = () => Array.from(stream.querySelectorAll(ROW));
  const newest = () => {
    const all = stream.querySelectorAll(ROW);
    return all[all.length - 1] || null;
  };

  // While the reader is elsewhere the stop rides the newest line, so coming
  // back to the conversation lands on what just arrived rather than on a line
  // that was newest an hour ago.
  const resolveCurrent = () => {
    const inside = stream.contains(doc.activeElement);
    if (!inside || !current || !current.isConnected || !stream.contains(current)) {
      current = newest();
    }
    return current;
  };

  const sync = (touched) => {
    const row = resolveCurrent();
    if (row !== applied) {
      if (applied?.isConnected) touched.add(applied);
      if (row) touched.add(row);
      applied = row;
    }
    touched.forEach((r) => r.isConnected && applyRow(r, r === row));
  };

  const moveTo = (row) => {
    current = row;
    sync(new Set());
    row.focus();
  };

  const openReactions = (row) => {
    const popover = row.querySelector("details[data-popover]");
    if (!popover) return;
    popover.open = true;
    applyRow(row, true);
    popover.querySelector("[data-popover-panel] button")?.focus();
  };

  const openContextMenu = (row) => {
    const rect = row.getBoundingClientRect();
    const menu = new MouseEvent("contextmenu", {
      bubbles: true,
      cancelable: true,
      clientX: rect.left + 6,
      clientY: rect.top + 6,
    });
    menu.fromLineKeyboard = true;
    menuEchoUntil = Date.now() + NATIVE_MENU_ECHO_MS;
    row.dispatchEvent(menu);
  };

  const onKeydown = (event) => {
    if (event.isComposing || hasCommandModifier(event)) return;
    const row = event.target.closest?.(ROW);
    if (!row || !stream.contains(row)) return;

    if (event.target === row) {
      const next = nextRow(rows(), row, event.key);
      if (next && !event.shiftKey) {
        event.preventDefault();
        moveTo(next);
      } else if (event.key === "Enter" && !event.shiftKey) {
        event.preventDefault();
        openReactions(row);
      } else if (isContextMenuKey(event)) {
        event.preventDefault();
        openContextMenu(row);
      }
      return;
    }

    // Escape on a control whose popover is open belongs to the popover; any
    // other Escape here is the line's, and must not also close a window.
    if (event.key === "Escape" && !event.target.closest("details[data-popover][open]")) {
      event.preventDefault();
      event.stopPropagation();
      moveTo(row);
    }
  };

  const onNativeMenu = (event) => {
    if (!event.fromLineKeyboard && Date.now() < menuEchoUntil) {
      event.preventDefault();
      event.stopPropagation();
    }
  };

  const onFocusin = (event) => {
    const row = event.target.closest?.(ROW);
    if (!row || !stream.contains(row) || row === current) return;
    current = row;
    sync(new Set());
  };

  const observer = new MutationObserver((mutations) => sync(touchedRows(mutations, stream)));
  observer.observe(stream, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["tabindex", "open"],
  });

  scroller.addEventListener("keydown", onKeydown);
  scroller.addEventListener("focusin", onFocusin);
  scroller.addEventListener("contextmenu", onNativeMenu, true);
  applied = resolveCurrent();
  applyRovingFocus(rows(), applied);

  return {
    destroy() {
      observer.disconnect();
      scroller.removeEventListener("keydown", onKeydown);
      scroller.removeEventListener("focusin", onFocusin);
      scroller.removeEventListener("contextmenu", onNativeMenu, true);
    },
  };
}
