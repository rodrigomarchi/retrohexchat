/**
 * How a `<details>` behaves once LiveView owns the page around it.
 *
 * A disclosure keeps its own state in the `open` attribute, which the server
 * never renders: every patch would hand it back closed, and in a chat a patch
 * arrives with every message. `keepDisclosureOpenAcrossPatch` is a morphdom
 * `onBeforeElUpdated` step that carries the browser's state into the incoming
 * element, so a patch never opens or closes one.
 *
 * Popovers (`details[data-popover]`) also close the way a menu does: a click
 * outside, Escape, or a `rhc:popover-close` event dispatched from inside one
 * (the server-side `Popover.close_after/1`). None of that goes through
 * `JS.remove_attribute`, which LiveView would replay on every later patch.
 * Closing hands the focus back to the trigger, and inside a `role="menu"`
 * panel the arrow keys move between the rows.
 *
 * @module ui/popover
 */

export const POPOVER_CLOSE_EVENT = "rhc:popover-close";

const OPEN_POPOVERS = "details[data-popover][open]";
const MENU_ROWS = '[role="menuitem"]:not(:disabled), [role="menuitemcheckbox"]:not(:disabled)';

/** Carry a disclosure's open state from the live element into its patch. */
export function keepDisclosureOpenAcrossPatch(fromEl, toEl) {
  if (fromEl?.tagName === "DETAILS" && toEl?.tagName === "DETAILS") {
    toEl.open = fromEl.open;
  }
}

/** The open popovers a click on `target` leaves behind. */
export function popoversOutside(root, target) {
  return Array.from(root.querySelectorAll(OPEN_POPOVERS)).filter(
    (popover) => !popover.contains(target),
  );
}

/**
 * The open popovers someone can actually see. One left open in a hidden
 * window must not take the Escape meant for the dialog in front of it.
 */
export function visibleOpenPopovers(root) {
  return Array.from(root.querySelectorAll(OPEN_POPOVERS)).filter((popover) =>
    typeof popover.checkVisibility === "function" ? popover.checkVisibility() : true,
  );
}

/** The row an arrow key moves to, wrapping at both ends. */
export function nextMenuRow(rows, current, key) {
  if (rows.length === 0) return null;
  const index = rows.indexOf(current);
  if (key === "ArrowDown") return rows[(index + 1) % rows.length];
  if (key === "ArrowUp") return rows[(index - 1 + rows.length) % rows.length];
  if (key === "Home") return rows[0];
  if (key === "End") return rows[rows.length - 1];
  return null;
}

function close(popover) {
  const hadFocus = popover.contains(popover.ownerDocument.activeElement);
  popover.open = false;
  if (hadFocus) popover.querySelector("summary")?.focus();
}

function moveWithinMenu(event) {
  const menu = event.target.closest?.('details[data-popover][open] [role="menu"]');
  if (!menu) return;
  const rows = Array.from(menu.querySelectorAll(MENU_ROWS));
  const next = nextMenuRow(rows, event.target, event.key);
  if (!next) return;
  event.preventDefault();
  next.focus();
}

/**
 * Wire the closing behaviour once per document. Escape that closes a popover
 * stops there: it must not also close the window the popover sits in.
 */
export function installPopoverBehaviour(doc) {
  const root = doc.documentElement;
  if (root.dataset.popoverBehaviour === "on") return;
  root.dataset.popoverBehaviour = "on";

  doc.addEventListener("click", (event) => popoversOutside(doc, event.target).forEach(close), true);

  doc.addEventListener(
    "keydown",
    (event) => {
      if (event.isComposing) return;
      if (event.key !== "Escape") return moveWithinMenu(event);
      const open = visibleOpenPopovers(doc);
      if (open.length === 0) return;
      open.forEach(close);
      event.stopPropagation();
    },
    true,
  );

  doc.addEventListener(POPOVER_CLOSE_EVENT, (event) => {
    const popover = event.target.closest?.("details[data-popover]");
    if (popover) close(popover);
  });
}
