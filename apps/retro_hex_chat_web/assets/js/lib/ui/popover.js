/**
 * How a `<details>` behaves once LiveView owns the page around it.
 *
 * A disclosure keeps its own state in the `open` attribute, which the server
 * never renders: every patch would hand it back closed, and in a chat a patch
 * arrives with every message. `keepDisclosureStateAcrossPatch` is a morphdom
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

const GAP = 4;

/**
 * Where a panel goes, in viewport pixels, for a trigger rect and a placement —
 * kept on screen with a small margin. A pure function so the geometry can be
 * tested without a layout engine.
 */
export function panelPosition(trigger, panel, placement, viewport) {
  const above = placement.startsWith("above");
  let top = above ? trigger.top - GAP - panel.height : trigger.bottom + GAP;
  let left;
  if (placement.endsWith("-end")) left = trigger.right - panel.width;
  else if (placement.endsWith("-start")) left = trigger.left;
  else left = trigger.left + trigger.width / 2 - panel.width / 2;

  left = Math.min(Math.max(left, GAP), viewport.width - panel.width - GAP);
  top = Math.min(Math.max(top, GAP), viewport.height - panel.height - GAP);
  return { top: Math.round(top), left: Math.round(left) };
}

/**
 * Pin an open popover's panel to the viewport. A trigger often sits inside a
 * scrolling strip, and `overflow` clips an absolutely positioned panel even
 * when it hangs outside — so the panel is laid out as `fixed`, from where the
 * trigger is now.
 */
export function placePanel(popover) {
  const summary = popover.querySelector(":scope > summary");
  const panel = popover.querySelector(":scope > [data-popover-panel]");
  if (!summary || !panel) return;
  const view = popover.ownerDocument.defaultView;
  const rect = panel.getBoundingClientRect();
  const { top, left } = panelPosition(
    summary.getBoundingClientRect(),
    { width: rect.width, height: rect.height },
    popover.dataset.placement || "below-end",
    { width: view.innerWidth, height: view.innerHeight },
  );
  Object.assign(panel.style, {
    position: "fixed",
    top: `${top}px`,
    left: `${left}px`,
    right: "auto",
    bottom: "auto",
    transform: "none",
  });
}

/**
 * Carry what the browser owns into a patch: a disclosure's open state, and the
 * viewport position `placePanel` gave an open popover's panel (the server
 * renders neither, so a patch would otherwise drop both).
 */
export function keepDisclosureStateAcrossPatch(fromEl, toEl) {
  if (fromEl?.tagName === "DETAILS" && toEl?.tagName === "DETAILS") {
    toEl.open = fromEl.open;
  }
  if (fromEl?.hasAttribute?.("data-popover-panel") && fromEl.hasAttribute("style")) {
    toEl.setAttribute("style", fromEl.getAttribute("style"));
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

  // `toggle` does not bubble, so it is caught on the way down.
  doc.addEventListener(
    "toggle",
    (event) => {
      if (event.target.matches?.("details[data-popover][open]")) placePanel(event.target);
    },
    true,
  );

  const reposition = () => visibleOpenPopovers(doc).forEach(placePanel);
  doc.defaultView.addEventListener("resize", reposition);
  doc.addEventListener("scroll", reposition, true);

  doc.addEventListener(POPOVER_CLOSE_EVENT, (event) => {
    const popover = event.target.closest?.("details[data-popover]");
    if (popover) close(popover);
  });
}
