/**
 * DOM interaction utilities shared across hooks.
 *
 * Provides semantic helpers for common patterns:
 * - Delegated event targeting (find closest ancestor with data attribute)
 * - CSS custom property application
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
 * Applies a map of CSS custom properties to the document root element.
 *
 * Used by the options hook to reflect server-side preference changes
 * (font family, font size, colors) as CSS variables without page reload.
 *
 * @param {Object<string, string>} styles - Map of CSS property names to values
 *   (e.g., { "--chat-font-family": "Courier New", "--chat-font-size": "14px" })
 */
export function applyCSSProperties(styles) {
  const root = document.documentElement;
  for (const [prop, value] of Object.entries(styles)) {
    root.style.setProperty(prop, value);
  }
}
