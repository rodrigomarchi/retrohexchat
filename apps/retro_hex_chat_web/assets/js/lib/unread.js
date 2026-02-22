/**
 * Unread badge rendering logic.
 *
 * Pure functions for creating and updating unread badge elements in the conversations sidebar.
 * No side effects — used by server-side HEEx rendering for badge data,
 * and optionally by JS for client-side badge manipulation.
 */

export const MAX_DISPLAY_COUNT = 99;
export const BADGE_CLASS = "conversations-badge";
export const BADGE_HIGHLIGHT_CLASS = "conversations-badge--highlight";

/**
 * Format an unread count for display.
 *
 * @param {number} count - Raw unread count
 * @returns {string} "" if 0, "99+" if > 99, else the number as string
 */
export function formatCount(count) {
  if (count === 0) return "";
  if (count > MAX_DISPLAY_COUNT) return "99+";
  return String(count);
}

/**
 * Create a badge DOM element.
 *
 * @param {number} count - Unread count
 * @param {boolean} isHighlight - Whether this is a mention highlight
 * @returns {HTMLElement} A <span> with appropriate badge classes
 */
export function createBadgeElement(count, isHighlight) {
  const span = document.createElement("span");
  span.className = BADGE_CLASS;
  if (isHighlight) {
    span.classList.add(BADGE_HIGHLIGHT_CLASS);
  }
  span.textContent = formatCount(count);
  return span;
}

/**
 * Update or remove the badge on a conversations list item.
 *
 * @param {HTMLElement} listItem - The <li> element
 * @param {number} count - Unread count
 * @param {boolean} isHighlight - Whether this is a mention highlight
 */
export function updateBadge(listItem, count, isHighlight) {
  let badge = listItem.querySelector(`.${BADGE_CLASS}`);

  if (count === 0) {
    if (badge) badge.remove();
    return;
  }

  if (!badge) {
    badge = document.createElement("span");
    badge.className = BADGE_CLASS;
    listItem.appendChild(badge);
  }

  badge.textContent = formatCount(count);

  if (isHighlight) {
    badge.classList.add(BADGE_HIGHLIGHT_CLASS);
  } else {
    badge.classList.remove(BADGE_HIGHLIGHT_CLASS);
  }
}

/**
 * Remove the badge from a conversations list item.
 *
 * @param {HTMLElement} listItem - The <li> element
 */
export function clearBadge(listItem) {
  const badge = listItem.querySelector(`.${BADGE_CLASS}`);
  if (badge) badge.remove();
}
