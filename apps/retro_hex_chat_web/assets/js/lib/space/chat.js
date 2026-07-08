/**
 * Ephemeral channel-space bubble state. Public channel messages arrive as
 * `space_message` events and briefly appear above the matching avatar; text
 * history remains owned by the LiveView chat log.
 * @module space/chat
 */

const DEFAULT_BUBBLE_MS = 5000;
const DEFAULT_LOG_LIMIT = 30;

export class ChatState {
  /** @param {{bubbleMs?: number, logLimit?: number}} [opts] */
  constructor({ bubbleMs, logLimit } = {}) {
    this._bubbleMs = bubbleMs ?? DEFAULT_BUBBLE_MS;
    this._logLimit = logLimit ?? DEFAULT_LOG_LIMIT;
    this._bubbles = new Map();
    this._log = [];
  }

  /**
   * Record an incoming `space_message`: refresh the sender's bubble and keep a
   * bounded diagnostic buffer for tests/debug tooling.
   * @param {{key:string, nickname:string, text:string}} message
   * @param {number} now
   */
  receive(message, now) {
    this._bubbles.set(message.key, {
      text: message.text,
      nickname: message.nickname,
      until: now + this._bubbleMs,
    });

    this._log.push({ key: message.key, nickname: message.nickname, text: message.text });
    if (this._log.length > this._logLimit) {
      this._log.splice(0, this._log.length - this._logLimit);
    }
  }

  /**
   * @returns {{text:string, nickname:string}|null} the live bubble for a key.
   */
  bubble(key, now) {
    const entry = this._bubbles.get(key);
    if (!entry) return null;
    // Evict on read so expired senders (including departed avatars) don't
    // accumulate in the Map for the life of the session.
    if (now >= entry.until) {
      this._bubbles.delete(key);
      return null;
    }
    return { text: entry.text, nickname: entry.nickname };
  }

  /** @returns {Array<{key:string, nickname:string, text:string}>} recent bubble events. */
  log() {
    return this._log;
  }
}
