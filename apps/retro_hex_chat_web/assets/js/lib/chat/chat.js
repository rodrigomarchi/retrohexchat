/**
 * Pure helpers for reading a chat message row: what a right-click landed on,
 * and the text and URLs a row carries.
 */

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
    message_id: msgEl.dataset.realId || msgEl.dataset.messageId || "",
    is_system: msgEl.dataset.systemMessage === "true",
    has_selection: window.getSelection().toString().length > 0,
    message_text: buildMessageText(msgEl),
    message_source: buildMessageSource(msgEl),
    message_format: msgEl.dataset.messageFormat || "irc",
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
  const timestampEl = msgEl.querySelector(".chat-message__time, .chat-timestamp");
  const nickEl = msgEl.querySelector(".chat-nick");
  const contentEl = msgEl.querySelector(".chat-content");
  const canonicalText = normalizeText(msgEl.dataset.messageText || "");

  if (timestampEl && nickEl && (canonicalText || contentEl)) {
    const time = timestampEl.textContent.trim();
    const nick = (msgEl.dataset.author || "").trim();
    const content = canonicalText || normalizeText(contentEl.textContent);
    return `[${time}] <${nick}> ${content}`;
  }

  return canonicalText || normalizeText(msgEl.textContent);
}

/**
 * Original user-authored message source, if carried by the row.
 *
 * @param {HTMLElement} msgEl
 * @returns {string}
 */
export function buildMessageSource(msgEl) {
  const encodedSource = msgEl.dataset.messageSourceB64 || "";
  const decodedSource = encodedSource ? decodeBase64Utf8(encodedSource) : null;

  if (decodedSource !== null) return decodedSource;
  if (msgEl.dataset.messageSource) return msgEl.dataset.messageSource;

  return normalizeText(msgEl.dataset.messageText || msgEl.textContent);
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

function normalizeText(text) {
  return (text || "").trim().replace(/\s+/g, " ");
}

function decodeBase64Utf8(value) {
  try {
    const binary = window.atob(value);

    if (typeof window.TextDecoder === "function") {
      const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
      return new window.TextDecoder().decode(bytes);
    }

    return decodeURIComponent(
      binary
        .split("")
        .map((char) => `%${char.charCodeAt(0).toString(16).padStart(2, "0")}`)
        .join(""),
    );
  } catch {
    return null;
  }
}
