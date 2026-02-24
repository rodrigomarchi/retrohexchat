/**
 * Interactive chat element utilities.
 *
 * Shared helpers for hover tooltips, click-vs-drag detection,
 * context menu coordination, and viewport boundary repositioning.
 *
 * Extracted from: scroll_hook.js (hook = wiring, lib = logic)
 */

/**
 * Determine if a mouse interaction was a click (not a drag/text-selection).
 *
 * Returns true when the mouse moved fewer than `threshold` pixels between
 * mousedown and mouseup AND no text was selected.
 *
 * @param {{ x: number, y: number } | null} downPos - mousedown position
 * @param {{ x: number, y: number }} upPos - mouseup/click position
 * @param {number} [threshold=3] - max pixel movement to count as a click
 * @returns {boolean}
 */
export function isClickNotDrag(downPos, upPos, threshold = 3) {
  if (!downPos) return true;

  const dx = Math.abs(upPos.x - downPos.x);
  const dy = Math.abs(upPos.y - downPos.y);

  if (dx > threshold || dy > threshold) return false;
  if (window.getSelection().toString().length > 0) return false;

  return true;
}

/** @type {HTMLElement | null} */
let activeTooltip = null;

/**
 * Create and show a positioned tooltip element near the target coordinates.
 *
 * @param {string} text - Tooltip text content
 * @param {number} x - Viewport X coordinate
 * @param {number} y - Viewport Y coordinate
 * @returns {HTMLElement} The created tooltip element
 */
export function createTooltip(text, x, y) {
  removeTooltip();

  const el = document.createElement("div");
  el.className = "interactive-tooltip";
  el.textContent = text;
  document.body.appendChild(el);

  // Position after insertion so we can measure
  const rect = el.getBoundingClientRect();
  const pos = repositionWithinViewport(x, y - rect.height - 4, rect.width, rect.height);
  el.style.left = pos.x + "px";
  el.style.top = pos.y + "px";

  activeTooltip = el;
  return el;
}

/**
 * Remove the currently active tooltip, if any.
 */
export function removeTooltip() {
  if (activeTooltip) {
    activeTooltip.remove();
    activeTooltip = null;
  }
}

/**
 * Check if there is currently an active tooltip.
 *
 * @returns {boolean}
 */
export function hasActiveTooltip() {
  return activeTooltip !== null;
}

let contextMenuOpen = false;

/**
 * Set the context menu open flag.
 *
 * @param {boolean} open
 */
export function setContextMenuOpen(open) {
  contextMenuOpen = open;
}

/**
 * Check if a context menu is currently open.
 *
 * @returns {boolean}
 */
export function isContextMenuOpen() {
  return contextMenuOpen;
}

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

/**
 * Format a channel tooltip text string.
 *
 * @param {string} channel - Channel name (e.g., "#dev")
 * @param {number} count - User count
 * @param {boolean} joined - Whether the user is already in this channel
 * @returns {string}
 */
export function formatChannelTooltip(channel, count, joined) {
  const users = count === 1 ? "1 user" : `${count} users`;
  const action = joined ? "Click to switch" : "Click to join";
  return `${channel} \u2014 ${users} \u2014 ${action}`;
}

/** @type {number | null} */
let nickHoverTimer = null;

/** @type {string | null} */
let nickHoverTarget = null;

/**
 * Start the nick hover idle timer. Fires callback after `delay` ms of no
 * mouse movement within the nick element.
 *
 * @param {string} nick - The nick being hovered
 * @param {Function} callback - Called when idle threshold is reached
 * @param {number} [delay=500] - Idle delay in milliseconds
 */
export function startNickHoverTimer(nick, callback, delay = 500) {
  cancelNickHoverTimer();
  nickHoverTarget = nick;
  nickHoverTimer = setTimeout(callback, delay);
}

/**
 * Reset the nick hover timer (restart countdown).
 * Called on mousemove within the nick element.
 *
 * @param {Function} callback - Called when idle threshold is reached
 * @param {number} [delay=500]
 */
export function resetNickHoverTimer(callback, delay = 500) {
  if (nickHoverTimer !== null) {
    clearTimeout(nickHoverTimer);
    nickHoverTimer = setTimeout(callback, delay);
  }
}

/**
 * Cancel any pending nick hover timer.
 */
export function cancelNickHoverTimer() {
  if (nickHoverTimer !== null) {
    clearTimeout(nickHoverTimer);
    nickHoverTimer = null;
  }
  nickHoverTarget = null;
}

/**
 * Get the nick currently being hover-tracked.
 *
 * @returns {string | null}
 */
export function getNickHoverTarget() {
  return nickHoverTarget;
}
