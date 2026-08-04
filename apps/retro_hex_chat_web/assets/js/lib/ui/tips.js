import { t } from "../i18n.js";
/**
 * Contextual tip state management.
 *
 * Pure functions for tracking which tips have been seen, global suppression
 * state, and tip definitions. No DOM or browser storage access.
 */

export const TIP_IDS = {
  FIRST_MESSAGE: "first_message",
  FIRST_JOIN: "first_join",
  FIRST_PM: "first_pm",
  FIRST_HIGHLIGHT: "first_highlight",
  IDLE_HELP: "idle_help",
};

export const TIPS = [
  { id: "first_message", text: t("Use ↑ to edit your last message") },
  { id: "first_join", text: t("Channels you join appear in the left panel") },
  { id: "first_pm", text: t("PMs appear as separate conversations in the sidebar") },
  {
    id: "first_highlight",
    text: t("Your nick was mentioned! Configure alerts in Settings"),
  },
  {
    id: "idle_help",
    text: t("Type /help to see all commands"),
    preemptedBy: "help_used",
  },
];

export const AUTO_DISMISS_MS = 8000;
export const QUEUE_GAP_MS = 2000;
export const IDLE_TIMEOUT_MS = 30000;

let seenTips = {};
let suppressed = false;

/**
 * Load a server-provided state snapshot into memory.
 * @param {{seen_tips?: string[], suppressed?: boolean}} state
 */
export function loadTipsState(state = {}) {
  seenTips = {};

  if (Array.isArray(state.seen_tips)) {
    for (const tipId of state.seen_tips) {
      if (isKnownTip(tipId)) {
        seenTips[tipId] = true;
      }
    }
  }

  suppressed = state.suppressed === true;
}

/**
 * Return the in-memory state in the backend wire format.
 * @returns {{seen_tips: string[], suppressed: boolean}}
 */
export function tipsStateSnapshot() {
  return {
    seen_tips: Object.keys(seenTips),
    suppressed,
  };
}

/**
 * Check if tips are globally suppressed.
 * @returns {boolean}
 */
export function isSuppressed() {
  return suppressed;
}

/**
 * Set or clear global suppression in memory.
 * @param {boolean} value
 */
export function setSuppressed(value) {
  suppressed = value === true;
}

/**
 * Check if a specific tip has been seen.
 * @param {string} tipId
 * @returns {boolean}
 */
export function isTipSeen(tipId) {
  return seenTips[tipId] === true;
}

/**
 * Mark a tip as seen in memory.
 * @param {string} tipId
 * @returns {boolean} true when state changed
 */
export function markTipSeen(tipId) {
  if (!isKnownTip(tipId)) return false;
  if (seenTips[tipId] === true) return false;
  seenTips[tipId] = true;
  return true;
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
 * @returns {string[]} Tip IDs that became seen
 */
export function markPreempted(actionId) {
  const marked = [];

  for (const tip of TIPS) {
    if (tip.preemptedBy === actionId) {
      if (markTipSeen(tip.id)) {
        marked.push(tip.id);
      }
    }
  }

  return marked;
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
  seenTips = {};
  suppressed = false;
}

function isKnownTip(tipId) {
  return TIPS.some((tip) => tip.id === tipId);
}
