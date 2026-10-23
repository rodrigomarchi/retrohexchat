import { log } from "../logger.js";

/**
 * DOM interaction utilities shared across hooks.
 *
 * Provides semantic helpers for common patterns:
 * - Delegated event targeting (find closest ancestor with data attribute)
 */

/**
 * Finds the closest ancestor matching `selector` and extracts a data attribute.
 *
 * Used by hooks that delegate events (dblclick, contextmenu) on list/table containers
 * to identify which item was targeted (nick, channel, URL, notification row, etc.).
 *
 * @param {EventTarget} target - The event target (e.target)
 * @param {string} selector - CSS selector to match ancestors (e.g., "li[phx-value-nick]")
 * @param {string} dataKey - The attribute name to extract (e.g., "phx-value-nick") or dataset key
 * @returns {string|null} The attribute value, or null if no matching ancestor found
 */
export function findClosestWithData(target, selector, dataKey) {
  if (!target || typeof target.closest !== "function") return null;
  const el = target.closest(selector);
  if (!el) return null;

  // Support both dataset keys and raw attribute names
  if (dataKey in (el.dataset || {})) {
    return el.dataset[dataKey];
  }
  return el.getAttribute(dataKey);
}

/**
 * Whether an event target sits inside an editable control.
 *
 * Used to let a text field keep a keystroke a global shortcut would otherwise
 * claim — typing "z" in a message box must not fire push-to-talk, and a
 * conference shortcut must not steal a key from an input.
 *
 * @param {EventTarget} target the event target (e.target)
 * @returns {boolean}
 */
export function isEditableTarget(target) {
  if (!(target instanceof Element)) return false;

  return !!target.closest(
    'input, textarea, select, [contenteditable=""], [contenteditable="true"], [contenteditable="plaintext-only"], [role="textbox"]',
  );
}

/**
 * Write text to the clipboard. Thin wrapper so hooks don't reach for
 * navigator.clipboard directly (a controller-in-disguise primitive).
 *
 * It always answers with a promise: a page without the async clipboard (an
 * insecure origin) rejects instead of throwing out of reach of the caller's
 * `.catch`. With a `fallback` (`document.execCommand("copy")` on a selection,
 * say), a refused or missing clipboard runs it and resolves.
 *
 * @param {string} text
 * @param {{ fallback?: () => void }} [options]
 * @returns {Promise<void>}
 */
export function copyText(text, { fallback } = {}) {
  const clipboard = typeof navigator === "undefined" ? undefined : navigator.clipboard;

  if (!clipboard || typeof clipboard.writeText !== "function") {
    if (!fallback) return Promise.reject(new Error("the clipboard is not available here"));
    fallback();
    return Promise.resolve();
  }

  if (!fallback) return clipboard.writeText(text);

  return clipboard.writeText(text).catch((error) => {
    log.debug("[clipboard] write refused, falling back", error);
    fallback();
  });
}

/**
 * `value` escaped for a CSS selector, inside an attribute's quotes or as an
 * identifier: `CSS.escape` where the browser has it, the quote and the
 * backslash otherwise.
 *
 * @param {unknown} value
 * @returns {string}
 */
export function cssEscape(value) {
  if (typeof CSS !== "undefined" && typeof CSS.escape === "function") {
    return CSS.escape(String(value));
  }
  return String(value).replace(/["\\]/g, "\\$&");
}
