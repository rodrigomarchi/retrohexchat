/**
 * Chat display logic.
 *
 * Extracted from: scroll_hook.js
 */

/**
 * Check if a scrollable element is at (or near) the bottom.
 *
 * @param {HTMLElement} el
 * @param {number} [threshold=50]
 * @returns {boolean}
 */
export function isAtBottom(el, threshold = 50) {
  return el.scrollHeight - el.scrollTop - el.clientHeight < threshold;
}

/**
 * Check if the user has scrolled near the top (should load more).
 *
 * @param {number} scrollTop
 * @param {number} [threshold=10]
 * @returns {boolean}
 */
export function shouldLoadMore(scrollTop, threshold = 10) {
  return scrollTop < threshold;
}

/**
 * Detect the context menu target from a right-click event within a message.
 *
 * Priority: nick > URL > channel > message (most specific wins).
 *
 * @param {Event} event - The contextmenu event
 * @param {HTMLElement} msgEl - The message element
 * @returns {Object} Payload with type, coordinates, and context-specific data
 */
export function detectContextTarget(event, msgEl) {
  const target = event.target;
  const payload = {
    x: event.clientX,
    y: event.clientY,
    author: msgEl.dataset.author || "",
    message_id: msgEl.dataset.messageId || "",
    is_system: msgEl.dataset.systemMessage === "true",
    has_selection: window.getSelection().toString().length > 0,
    message_text: buildMessageText(msgEl),
    message_urls: collectUrls(msgEl),
  };

  // Check nick first (most specific)
  const nickEl = target.closest(".chat-nick[data-nick]");
  if (nickEl) {
    payload.type = "nick";
    payload.nick = nickEl.dataset.nick;
    return payload;
  }

  // Check URL
  const urlEl = target.closest(".chat-link[data-url]");
  if (urlEl) {
    payload.type = "url";
    payload.url = urlEl.dataset.url;
    return payload;
  }

  // Check channel link
  const channelEl = target.closest(".chat-channel-link[data-channel]");
  if (channelEl) {
    payload.type = "channel";
    payload.channel = channelEl.dataset.channel;
    return payload;
  }

  // Default: message context menu
  payload.type = "message";
  if (payload.message_urls.length > 0) {
    payload.url = payload.message_urls[0];
  }
  return payload;
}

/**
 * Build formatted message text: [HH:MM] <Nick> message
 *
 * @param {HTMLElement} msgEl
 * @returns {string}
 */
export function buildMessageText(msgEl) {
  const timestampEl = msgEl.querySelector(".chat-timestamp");
  const nickEl = msgEl.querySelector(".chat-nick");
  const contentEl = msgEl.querySelector(".chat-content");

  if (timestampEl && nickEl && contentEl) {
    const time = timestampEl.textContent.trim();
    const nick = (msgEl.dataset.author || "").trim();
    const content = contentEl.textContent.trim();
    return `[${time}] <${nick}> ${content}`;
  }

  return msgEl.textContent.trim().replace(/\s+/g, " ");
}

/**
 * Collect all URLs from data-url attributes in a message.
 *
 * @param {HTMLElement} msgEl
 * @returns {string[]}
 */
export function collectUrls(msgEl) {
  return Array.from(msgEl.querySelectorAll(".chat-link[data-url]")).map((el) => el.dataset.url);
}
