/**
 * Input history management.
 *
 * Extracted from: autocomplete_hook.js
 */

const SENSITIVE_PATTERNS = ["/identify ", "/identify\n", "/nickserv ", "/ns "];
const SENSITIVE_EXACT = ["/identify", "/nickserv", "/ns"];

/**
 * Check if a command text is sensitive (should not be saved to history).
 *
 * @param {string} text
 * @returns {boolean}
 */
export function isSensitiveCommand(text) {
  const lower = text.toLowerCase().trimStart();
  return SENSITIVE_PATTERNS.some((p) => lower.startsWith(p)) || SENSITIVE_EXACT.includes(lower);
}

/**
 * Create a history manager instance.
 *
 * @param {Object} config
 * @param {string} config.storageKey - localStorage key for history
 * @param {string} config.recentCommandsKey - localStorage key for recent commands
 * @param {number} [config.maxEntries=100] - Max history entries
 * @param {number} [config.maxRecentCommands=5] - Max recent commands
 * @returns {Object} History manager with methods
 */
export function createHistoryManager(config) {
  const {
    storageKey = "retro_hex_chat_history",
    recentCommandsKey = "retro_hex_chat_recent_commands",
    maxEntries = 100,
    maxRecentCommands = 5,
  } = config || {};

  let history = loadFromStorage(storageKey, []);
  let recentCommands = loadFromStorage(recentCommandsKey, []);
  let historyIndex = -1;
  let historyDraft = null;
  let historyBrowsing = false;

  function loadFromStorage(key, fallback) {
    try {
      const stored = localStorage.getItem(key);
      return stored ? JSON.parse(stored) : fallback;
    } catch {
      return fallback;
    }
  }

  function saveToStorage(key, data) {
    try {
      localStorage.setItem(key, JSON.stringify(data));
    } catch {
      // localStorage might be full
    }
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
     * Reload history from localStorage.
     */
    load() {
      history = loadFromStorage(storageKey, []);
      recentCommands = loadFromStorage(recentCommandsKey, []);
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

      try {
        localStorage.setItem(storageKey, JSON.stringify(history));
      } catch {
        history = history.slice(0, Math.floor(maxEntries / 2));
        try {
          localStorage.setItem(storageKey, JSON.stringify(history));
        } catch {
          // Still full, give up
        }
      }
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
      saveToStorage(recentCommandsKey, recentCommands);
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
