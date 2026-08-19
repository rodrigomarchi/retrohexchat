/**
 * Connection-recovery and offer-watchdog decisions for the conference — pure.
 *
 * The hook owns the timers and the live-pc activity probes; the arithmetic that
 * decides how long to back off, when to give up, whether a reason is a
 * disconnect, and whether a recovery may be deferred while media still moves is
 * decided here, against plain numbers, so it can be tested without a connection.
 *
 * @module p2p/recovery
 */

/**
 * The backoff delay for a recovery attempt (1-based), clamped to the last step.
 *
 * @param {number} attempt 1-based attempt number
 * @param {number[]} backoff the backoff ladder in ms
 * @returns {number}
 */
export function recoveryBackoffDelay(attempt, backoff) {
  return backoff[Math.min(attempt - 1, backoff.length - 1)];
}

/**
 * The attempt number a recovery run uses: the next one when it counts, else the
 * current (or 1 the first time it does not count).
 *
 * @param {number} current
 * @param {boolean} countAttempt
 * @returns {number}
 */
export function nextRecoveryAttempt(current, countAttempt) {
  return countAttempt ? current + 1 : current || 1;
}

/** Whether recovery has used up its attempts. */
export function hasExhaustedRecovery(attempts, max) {
  return attempts >= max;
}

/** Whether a recovery reason is a disconnect (eligible for activity deferral). */
export function isDisconnectedReason(reason) {
  return reason === "disconnected" || reason === "ice_disconnected";
}

/** Whether another activity-based deferral is allowed before forcing recovery. */
export function canDeferRecovery(deferrals, limit) {
  return deferrals < limit;
}

/** The offer-watchdog delay grows with the attempt number. */
export function watchdogDelay(attempt, baseDelay) {
  return baseDelay * attempt;
}

/** Whether the offer watchdog has used up its attempts. */
export function hasExhaustedWatchdog(attempts, max) {
  return attempts >= max;
}
