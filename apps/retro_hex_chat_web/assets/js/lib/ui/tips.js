/**
 * Contextual tip state management via localStorage.
 *
 * Pure functions for tracking which tips have been seen, global
 * suppression state, and tip definitions. No DOM access.
 */

export const TIP_IDS = {
  FIRST_MESSAGE: "first_message",
  FIRST_JOIN: "first_join",
  FIRST_PM: "first_pm",
  FIRST_HIGHLIGHT: "first_highlight",
  IDLE_HELP: "idle_help",
};

export const TIPS = [
  { id: "first_message", text: "Use ↑ to edit your last message" },
  { id: "first_join", text: "Channels you join appear in the left panel" },
  { id: "first_pm", text: "PMs appear as separate conversations in the sidebar" },
  {
    id: "first_highlight",
    text: "Your nick was mentioned! Configure alerts in Settings",
  },
  {
    id: "idle_help",
    text: "Type /help to see all commands",
    preemptedBy: "help_used",
  },
];

export const STORAGE_KEYS = {
  SEEN: "retro_hex_chat_tips_seen",
  SUPPRESSED: "retro_hex_chat_tips_suppressed",
  SUPPRESSED_BACKUP: "retro_hex_chat_tips_suppressed_backup",
};

export const AUTO_DISMISS_MS = 8000;
export const QUEUE_GAP_MS = 2000;
export const IDLE_TIMEOUT_MS = 30000;

/**
 * Read the seen-tips map from localStorage.
 * @returns {Object} Map of tipId → true
 */
function getSeenMap() {
  try {
    const raw = localStorage.getItem(STORAGE_KEYS.SEEN);
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

/**
 * Write the seen-tips map to localStorage.
 * Gracefully handles storage-full errors.
 * @param {Object} map
 */
function setSeenMap(map) {
  try {
    localStorage.setItem(STORAGE_KEYS.SEEN, JSON.stringify(map));
  } catch {
    // Storage full — silently skip
  }
}

/**
 * Check if tips are globally suppressed.
 * Checks both primary and backup keys for resilience.
 * @returns {boolean}
 */
export function isSuppressed() {
  return (
    localStorage.getItem(STORAGE_KEYS.SUPPRESSED) === "true" ||
    localStorage.getItem(STORAGE_KEYS.SUPPRESSED_BACKUP) === "true"
  );
}

/**
 * Set or clear global suppression in both primary and backup keys.
 * @param {boolean} value
 */
export function setSuppressed(value) {
  try {
    if (value) {
      localStorage.setItem(STORAGE_KEYS.SUPPRESSED, "true");
      localStorage.setItem(STORAGE_KEYS.SUPPRESSED_BACKUP, "true");
    } else {
      localStorage.removeItem(STORAGE_KEYS.SUPPRESSED);
      localStorage.removeItem(STORAGE_KEYS.SUPPRESSED_BACKUP);
    }
  } catch {
    // Storage full — silently skip
  }
}

/**
 * Check if a specific tip has been seen.
 * @param {string} tipId
 * @returns {boolean}
 */
export function isTipSeen(tipId) {
  const map = getSeenMap();
  return map[tipId] === true;
}

/**
 * Mark a tip as seen in localStorage.
 * @param {string} tipId
 */
export function markTipSeen(tipId) {
  const map = getSeenMap();
  map[tipId] = true;
  setSeenMap(map);
}

/**
 * Check if a tip should be shown (not suppressed, not seen, not preempted).
 * @param {string} tipId
 * @returns {boolean}
 */
export function shouldShowTip(tipId) {
  if (isSuppressed()) return false;
  if (isTipSeen(tipId)) return false;
  return true;
}

/**
 * Mark tips preempted by the given action as seen.
 * E.g., "help_used" preempts "idle_help".
 * @param {string} actionId
 */
export function markPreempted(actionId) {
  for (const tip of TIPS) {
    if (tip.preemptedBy === actionId) {
      markTipSeen(tip.id);
    }
  }
}

/**
 * Get a tip definition by ID.
 * @param {string} tipId
 * @returns {Object|undefined}
 */
export function getTipById(tipId) {
  return TIPS.find((t) => t.id === tipId);
}

/**
 * Clear all seen state (for testing/debugging).
 */
export function resetAllTips() {
  localStorage.removeItem(STORAGE_KEYS.SEEN);
  localStorage.removeItem(STORAGE_KEYS.SUPPRESSED);
  localStorage.removeItem(STORAGE_KEYS.SUPPRESSED_BACKUP);
}
