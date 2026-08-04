/**
 * Input history management.
 *
 * Extracted from: autocomplete_hook.js
 */

const SENSITIVE_COMMANDS = [
  /^\/identify(?:\s|$)/,
  /^\/nickserv(?:\s|$)/,
  /^\/ns(?:\s|$)/,
  /^\/(?:msg|query|notice)\s+nickserv\s+identify(?:\s|$)/,
  /^\/perform\s+add\s+\/(?:identify|nickserv|ns)(?:\s|$)/,
  /^\/alias\s+add\s+\S+\s+\/(?:identify|nickserv|ns)(?:\s|$)/,
  /^\/autorespond\s+add\s+\S+(?:\s+#\S+)?\s+\/(?:identify|nickserv|ns)(?:\s|$)/,
  /^\/timer\s+\S+\s+(?:repeat\s+)?\S+\s+\/(?:identify|nickserv|ns)(?:\s|$)/,
];

/**
 * Check if a command text is sensitive (should not be saved to history).
 *
 * @param {string} text
 * @returns {boolean}
 */
export function isSensitiveCommand(text) {
  const lower = text.toLowerCase().trimStart();
  return SENSITIVE_COMMANDS.some((pattern) => pattern.test(lower));
}

/**
 * Create a history manager instance.
 *
 * @param {Object} config
 * @param {string[]} [config.initialHistory=[]] - Initial history entries
 * @param {string[]} [config.initialRecentCommands=[]] - Initial recent commands
 * @param {number} [config.maxEntries=100] - Max history entries
 * @param {number} [config.maxRecentCommands=5] - Max recent commands
 * @returns {Object} History manager with methods
 */
export function createHistoryManager(config) {
  const {
    initialHistory = [],
    initialRecentCommands = [],
    maxEntries = 100,
    maxRecentCommands = 5,
  } = config || {};

  let history = normalizeList(initialHistory, maxEntries);
  let recentCommands = normalizeList(initialRecentCommands, maxRecentCommands);
  let historyIndex = -1;
  let historyDraft = null;
  let historyBrowsing = false;

  function normalizeList(value, limit) {
    if (!Array.isArray(value)) return [];
    return value.filter((entry) => typeof entry === "string" && entry.trim()).slice(0, limit);
  }

  return {
    /**
     * Get the current history array.
     */
    getHistory() {
      return history;
    },

    /**
     * Get recent commands.
     */
    getRecentCommands() {
      return recentCommands;
    },

    /**
     * Replace history from a server-provided snapshot.
     */
    load(snapshot = {}) {
      if (Object.prototype.hasOwnProperty.call(snapshot, "history")) {
        history = normalizeList(snapshot.history, maxEntries);
      }
      if (Object.prototype.hasOwnProperty.call(snapshot, "recentCommands")) {
        recentCommands = normalizeList(snapshot.recentCommands, maxRecentCommands);
      }
      this.resetBrowsing();
    },

    /**
     * Navigate up in history.
     *
     * @param {string} currentValue - Current input value
     * @param {number} cursorPos - Current cursor position
     * @returns {{ value: string } | null} - New value or null if no change
     */
    up(currentValue, cursorPos) {
      if (history.length === 0) return null;

      if (!historyBrowsing) {
        historyDraft = { text: currentValue, cursor: cursorPos };
        historyBrowsing = true;
        historyIndex = -1;
      }

      const newIndex = Math.min(historyIndex + 1, history.length - 1);
      if (newIndex !== historyIndex) {
        historyIndex = newIndex;
        return { value: history[newIndex] };
      }
      return null;
    },

    /**
     * Navigate down in history.
     *
     * @returns {{ value: string, cursor?: number } | null}
     */
    down() {
      if (!historyBrowsing) return null;

      const newIndex = historyIndex - 1;

      if (newIndex < 0) {
        historyBrowsing = false;
        historyIndex = -1;
        if (historyDraft) {
          const result = { value: historyDraft.text, cursor: historyDraft.cursor };
          historyDraft = null;
          return result;
        }
        return { value: "" };
      }

      historyIndex = newIndex;
      return { value: history[newIndex] };
    },

    /**
     * Save text to history.
     *
     * @param {string} text
     */
    save(text) {
      if (!text.trim()) return;
      if (isSensitiveCommand(text)) return;

      history = history.filter((h) => h !== text);
      history.unshift(text);
      history = history.slice(0, maxEntries);
    },

    /**
     * Search history for a match.
     *
     * @param {string} query
     * @returns {string | null}
     */
    search(query) {
      if (!query) return null;
      const lower = query.toLowerCase();
      return history.find((h) => h.toLowerCase().includes(lower)) || null;
    },

    /**
     * Save a recent command name.
     *
     * @param {string} cmdName
     */
    saveRecentCommand(cmdName) {
      recentCommands = recentCommands.filter((c) => c !== cmdName);
      recentCommands.unshift(cmdName);
      recentCommands = recentCommands.slice(0, maxRecentCommands);
    },

    /**
     * Reset browsing state (call on submit).
     */
    resetBrowsing() {
      historyDraft = null;
      historyBrowsing = false;
      historyIndex = -1;
    },
  };
}
