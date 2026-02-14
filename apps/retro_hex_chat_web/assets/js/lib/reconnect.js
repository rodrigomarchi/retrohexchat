/**
 * Reconnection logic.
 *
 * Extracted from: reconnect_hook.js
 */

export const RECONNECT_DEFAULTS = {
  maxAttempts: 10,
  maxDelay: 30,
};

/**
 * Calculate exponential backoff delay.
 *
 * @param {number} attempt - Current attempt number (1-based)
 * @param {number} [maxDelay=30] - Maximum delay in seconds
 * @returns {number} Delay in seconds
 */
export function getBackoffDelay(attempt, maxDelay = RECONNECT_DEFAULTS.maxDelay) {
  const base = Math.pow(2, attempt - 1);
  return Math.min(base, maxDelay);
}
