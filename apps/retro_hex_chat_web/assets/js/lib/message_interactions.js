/**
 * Pure logic for message interactions (reply, edit, delete).
 * Constitution IV: hook = wiring, lib = logic.
 */

/**
 * Truncate a preview string to a maximum length, adding "..." if truncated.
 * @param {string} text
 * @param {number} [maxLen=100]
 * @returns {string}
 */
export function truncatePreview(text, maxLen = 100) {
  if (text.length <= maxLen) return text;
  return text.slice(0, maxLen - 3) + "...";
}

/**
 * Format an edit timestamp as "HH:MM DD/MM/YYYY" (UTC).
 * @param {Date} date
 * @returns {string}
 */
export function formatEditTimestamp(date) {
  const pad = (n) => String(n).padStart(2, "0");
  const hours = pad(date.getUTCHours());
  const minutes = pad(date.getUTCMinutes());
  const day = pad(date.getUTCDate());
  const month = pad(date.getUTCMonth() + 1);
  const year = date.getUTCFullYear();
  return `${hours}:${minutes} ${day}/${month}/${year}`;
}

/**
 * Determine if the ↑ key should trigger edit mode.
 * @param {string} inputValue - current input textarea value
 * @returns {boolean}
 */
export function shouldTriggerEditMode(inputValue) {
  return inputValue === "";
}

/**
 * Scroll to a message element and apply a 2-second highlight animation.
 * @param {number|string} messageId
 */
export function scrollToMessage(messageId) {
  const el = document.getElementById(`msg-${messageId}`);
  if (!el) return;

  el.scrollIntoView({ behavior: "smooth", block: "center" });
  el.classList.add("chat-message--scroll-highlight");

  setTimeout(() => {
    el.classList.remove("chat-message--scroll-highlight");
  }, 2000);
}

/**
 * Add the editing class to a message element.
 * @param {number|string} messageId
 */
export function highlightEditingMessage(messageId) {
  const el = document.getElementById(`msg-${messageId}`);
  if (el) el.classList.add("chat-message--editing");
}

/**
 * Remove the editing class from a message element.
 * @param {number|string} messageId
 */
export function removeEditingHighlight(messageId) {
  const el = document.getElementById(`msg-${messageId}`);
  if (el) el.classList.remove("chat-message--editing");
}
