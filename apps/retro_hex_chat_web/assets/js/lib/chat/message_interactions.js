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
 * Format an edit timestamp as "HH:MM DD/MM/YYYY" (local time).
 * @param {Date} date
 * @returns {string}
 */
export function formatEditTimestamp(date) {
  const pad = (n) => String(n).padStart(2, "0");
  const hours = pad(date.getHours());
  const minutes = pad(date.getMinutes());
  const day = pad(date.getDate());
  const month = pad(date.getMonth() + 1);
  const year = date.getFullYear();
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

function escapeAttr(value) {
  return String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

/**
 * Find a message element by the ids used across chat message renderers.
 * @param {number|string} messageId
 * @returns {Element|null}
 */
export function findMessageElement(messageId) {
  if (messageId === undefined || messageId === null || messageId === "") {
    return null;
  }

  const id = String(messageId);
  const streamId = id.startsWith("chat_messages-") ? id : `chat_messages-${id}`;

  return (
    document.getElementById(id) ||
    document.getElementById(`msg-${id}`) ||
    document.getElementById(streamId) ||
    document.querySelector(`[data-real-id="${escapeAttr(id)}"]`) ||
    document.querySelector(`[data-message-id="${escapeAttr(streamId)}"]`) ||
    document.querySelector(`[data-message-id="${escapeAttr(id)}"]`)
  );
}

/**
 * Scroll to a message element and apply a 2-second highlight animation.
 * @param {number|string} messageId
 * @returns {boolean} true when the target message was found
 */
export function scrollToMessage(messageId) {
  const el = findMessageElement(messageId);
  if (!el) return false;

  el.scrollIntoView({ behavior: "smooth", block: "center" });
  el.classList.add("chat-message--scroll-highlight");

  setTimeout(() => {
    el.classList.remove("chat-message--scroll-highlight");
  }, 2000);

  return true;
}

/**
 * Add the editing class to a message element.
 * @param {number|string} messageId
 */
export function highlightEditingMessage(messageId) {
  const el = findMessageElement(messageId);
  if (el) el.classList.add("chat-message--editing");
}

/**
 * Remove the editing class from a message element.
 * @param {number|string} messageId
 */
export function removeEditingHighlight(messageId) {
  const el = findMessageElement(messageId);
  if (el) el.classList.remove("chat-message--editing");
}
